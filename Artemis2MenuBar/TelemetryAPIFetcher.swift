import Foundation

/// Fetches pre-computed telemetry from the Orbital API.
/// Replaces direct AROW + Horizons calls when telemetryEndpoint is configured.
actor TelemetryAPIFetcher {

    struct TelemetryData {
        var altitude: Double = 0
        var distanceToMoon: Double = 0
        var speed: Double = 0
        var isLive: Bool = false
        var phase: String?
    }

    private var endpointURL: String

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    init(endpointURL: String) {
        self.endpointURL = endpointURL
    }

    func reconfigure(endpointURL: String) {
        self.endpointURL = endpointURL
    }

    func fetch() async -> TelemetryData? {
        let cacheBust = Int(Date().timeIntervalSince1970)
        let separator = endpointURL.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(endpointURL)\(separator)_=\(cacheBust)") else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            return parse(data)
        } catch {
            return nil
        }
    }

    private func parse(_ data: Data) -> TelemetryData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var result = TelemetryData()
        result.altitude = json["altitude"] as? Double ?? 0
        result.distanceToMoon = json["distanceToMoon"] as? Double ?? 0
        result.speed = json["speed"] as? Double ?? 0
        result.isLive = json["isLive"] as? Bool ?? false
        result.phase = json["phase"] as? String

        return result
    }
}
