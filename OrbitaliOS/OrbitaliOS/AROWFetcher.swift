import Foundation

actor AROWFetcher {

    struct AROWData {
        var distanceFromEarthCenter: Double = 0
        var distanceFromMoon: Double = 0
        var speed: Double = 0
        var isLive: Bool = false
    }

    private var telemetryBaseURL: String
    private var positionParams: [String]
    private var positionUnitToKm: Double
    private var activityField: String
    private var earthRadius: Double
    private var mu: Double

    private let moonService = MoonPositionService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private var prevPosition: (x: Double, y: Double, z: Double)?
    private var prevTimestamp: String = ""
    private var lastComputedSpeed: Double = 0

    init(config: MissionConfig) {
        telemetryBaseURL = config.dataSources.telemetry.url
        positionParams = config.dataSources.telemetry.positionParams
        activityField = config.dataSources.telemetry.activityField
        earthRadius = config.earthRadius
        mu = config.mu
        positionUnitToKm = Self.unitConversion(config.dataSources.telemetry.positionUnit)

        if let moonConfig = config.dataSources.moonPosition {
            Task { await moonService.configure(
                horizonsURL: moonConfig.horizonsURL,
                refreshInterval: moonConfig.refreshInterval
            )}
        }
    }

    func reconfigure(config: MissionConfig) {
        telemetryBaseURL = config.dataSources.telemetry.url
        positionParams = config.dataSources.telemetry.positionParams
        activityField = config.dataSources.telemetry.activityField
        earthRadius = config.earthRadius
        mu = config.mu
        positionUnitToKm = Self.unitConversion(config.dataSources.telemetry.positionUnit)
    }

    private static func unitConversion(_ unit: String) -> Double {
        switch unit {
        case "feet": return 0.0003048
        case "meters": return 0.001
        case "km", "kilometers": return 1.0
        default: return 0.0003048
        }
    }

    func fetch() async -> AROWData? {
        let separator = telemetryBaseURL.contains("?") ? "&" : "?"
        let cacheBust = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "\(telemetryBaseURL)\(separator)_=\(cacheBust)") else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            return await parseTelemetry(data)
        } catch {
            return nil
        }
    }

    private func parseTelemetry(_ data: Data) async -> AROWData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var result = AROWData()

        if let file = json["File"] as? [String: Any],
           let activity = file["Activity"] as? String {
            result.isLive = (activity == activityField)
        }

        guard positionParams.count >= 3 else { return nil }
        let rawX = extractParam(json, positionParams[0])
        let rawY = extractParam(json, positionParams[1])
        let rawZ = extractParam(json, positionParams[2])
        guard rawX != 0 || rawY != 0 || rawZ != 0 else { return nil }

        let posX = rawX * positionUnitToKm
        let posY = rawY * positionUnitToKm
        let posZ = rawZ * positionUnitToKm

        let distFromCenter = sqrt(posX * posX + posY * posY + posZ * posZ)
        guard distFromCenter > earthRadius else { return nil }

        result.distanceFromEarthCenter = distFromCenter
        result.distanceFromMoon = await moonService.distanceToMoon(fromX: posX, y: posY, z: posZ)

        // Velocity from telemetry timestamps
        let timestamp = extractTimestamp(json, positionParams[0])
        if let prev = prevPosition, !prevTimestamp.isEmpty, timestamp != prevTimestamp {
            let dt = telemetryTimeDelta(from: prevTimestamp, to: timestamp)
            if dt > 1 && dt < 600 {
                let dx = posX - prev.x
                let dy = posY - prev.y
                let dz = posZ - prev.z
                let posDelta = sqrt(dx * dx + dy * dy + dz * dz)
                if posDelta > 0.001 {
                    lastComputedSpeed = posDelta / dt
                }
            }
        }

        result.speed = lastComputedSpeed

        prevPosition = (x: posX, y: posY, z: posZ)
        prevTimestamp = timestamp

        return result
    }

    private func extractParam(_ json: [String: Any], _ number: String) -> Double {
        let key = "Parameter_\(number)"
        guard let param = json[key] as? [String: Any],
              let status = param["Status"] as? String,
              status == "Good",
              let valueStr = param["Value"] as? String,
              let value = Double(valueStr) else {
            return 0
        }
        return value
    }

    private func extractTimestamp(_ json: [String: Any], _ number: String) -> String {
        let key = "Parameter_\(number)"
        guard let param = json[key] as? [String: Any],
              let time = param["Time"] as? String else {
            return ""
        }
        return time
    }

    private func telemetryTimeDelta(from t1: String, to t2: String) -> Double {
        func toSeconds(_ t: String) -> Double? {
            let parts = t.split(separator: ":")
            guard parts.count >= 5,
                  let year = Double(parts[0]),
                  let day = Double(parts[1]),
                  let hour = Double(parts[2]),
                  let min = Double(parts[3]),
                  let sec = Double(parts[4]) else { return nil }
            return year * 366 * 86400 + day * 86400 + hour * 3600 + min * 60 + sec
        }
        guard let s1 = toSeconds(t1), let s2 = toSeconds(t2) else { return 0 }
        return s2 - s1
    }
}
