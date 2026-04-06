import Foundation

/// Fetches the Moon's geocentric J2000 position from JPL Horizons API.
actor MoonPositionService {

    struct MoonState {
        var x: Double // km, J2000 geocentric
        var y: Double
        var z: Double
    }

    private var cached: MoonState?
    private var lastFetch: Date?
    private var refreshInterval: TimeInterval = 3600
    private var horizonsBaseURL: String = "https://ssd.jpl.nasa.gov/api/horizons.api"

    func configure(horizonsURL: String?, refreshInterval: TimeInterval?) {
        if let url = horizonsURL { self.horizonsBaseURL = url }
        if let interval = refreshInterval { self.refreshInterval = interval }
    }

    /// Compute distance from a J2000 position (km) to the Moon
    func distanceToMoon(fromX x: Double, y: Double, z: Double) async -> Double {
        let moon = await getPosition()
        let dx = x - moon.x
        let dy = y - moon.y
        let dz = z - moon.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    private func getPosition() async -> MoonState {
        if let cached = cached, let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval {
            return cached
        }

        if let fresh = await fetchFromHorizons() {
            cached = fresh
            lastFetch = Date()
            return fresh
        }

        // Fallback: approximate Moon position using simple model
        let fallback = approximateMoonPosition()
        cached = fallback
        lastFetch = Date()
        return fallback
    }

    private func fetchFromHorizons() async -> MoonState? {
        let now = Date()
        let soon = now.addingTimeInterval(60)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        df.timeZone = TimeZone(identifier: "UTC")
        let start = df.string(from: now)
        let stop = df.string(from: soon)

        // Build URL with properly encoded query parameters
        var components = URLComponents(string: horizonsBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "COMMAND", value: "'301'"),
            URLQueryItem(name: "OBJ_DATA", value: "'NO'"),
            URLQueryItem(name: "MAKE_EPHEM", value: "'YES'"),
            URLQueryItem(name: "EPHEM_TYPE", value: "'VECTORS'"),
            URLQueryItem(name: "CENTER", value: "'500@399'"),
            URLQueryItem(name: "REF_PLANE", value: "'FRAME'"),
            URLQueryItem(name: "START_TIME", value: "'\(start)'"),
            URLQueryItem(name: "STOP_TIME", value: "'\(stop)'"),
            URLQueryItem(name: "STEP_SIZE", value: "'1d'"),
            URLQueryItem(name: "VEC_TABLE", value: "'1'"),
        ]

        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            return parseHorizonsResponse(data)
        } catch {
            return nil
        }
    }

    private func parseHorizonsResponse(_ data: Data) -> MoonState? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? String else {
            return nil
        }

        let lines = result.components(separatedBy: "\n")
        var inData = false

        for line in lines {
            if line.contains("$$SOE") {
                inData = true
                continue
            }
            if line.contains("$$EOE") {
                break
            }
            if inData && line.contains("X =") {
                return parseVectorLine(line)
            }
        }

        return nil
    }

    private func parseVectorLine(_ line: String) -> MoonState? {
        // Handle both "X = 1.234E+05" and "X =1.234E+05" formats
        let pattern = /([XYZ])\s*=\s*([^\s]+)/
        var x: Double?, y: Double?, z: Double?
        for match in line.matches(of: pattern) {
            guard let v = Double(match.output.2) else { continue }
            switch match.output.1 {
            case "X": x = v
            case "Y": y = v
            case "Z": z = v
            default: break
            }
        }

        guard let px = x, let py = y, let pz = z else { return nil }
        let dist = sqrt(px * px + py * py + pz * pz)
        guard dist > 300_000 else { return nil }

        return MoonState(x: px, y: py, z: pz)
    }

    /// Simple approximate Moon position when Horizons is unavailable.
    /// Uses the Moon's mean orbital elements to get within ~1-2 degrees.
    private func approximateMoonPosition() -> MoonState {
        let now = Date()
        // J2000 epoch: 2000-01-01 12:00:00 TT
        let j2000 = Date(timeIntervalSince1970: 946728000.0)
        let daysSinceJ2000 = now.timeIntervalSince(j2000) / 86400.0

        // Moon's mean orbital elements (simplified)
        let meanLongDeg = 218.316 + 13.176396 * daysSinceJ2000 // degrees
        let meanAnomDeg = 134.963 + 13.064993 * daysSinceJ2000
        let meanDistKm = 385_000.0 // approximate

        let longRad = meanLongDeg * .pi / 180.0
        let anomRad = meanAnomDeg * .pi / 180.0

        // Simplified ecliptic position (ignoring inclination for rough approximation)
        let r = meanDistKm + 20_900 * cos(anomRad) // distance varies by ~20,900 km
        let eclLon = longRad + (6.289 * .pi / 180.0) * sin(anomRad)

        // Ecliptic to approximate J2000 equatorial (obliquity ~23.44°)
        let obliquity = 23.44 * .pi / 180.0
        let x = r * cos(eclLon)
        let y = r * sin(eclLon) * cos(obliquity)
        let z = r * sin(eclLon) * sin(obliquity)

        return MoonState(x: x, y: y, z: z)
    }
}
