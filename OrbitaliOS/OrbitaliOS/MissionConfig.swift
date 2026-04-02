import Foundation

struct MissionConfig: Codable {
    var configVersion: Int
    var refreshInterval: TimeInterval
    var mission: Mission
    var dataSources: DataSources
    var metrics: [Metric]
    var phases: [Phase]
    var trajectory: Trajectory

    struct Mission: Codable {
        var id: String
        var name: String
        var subtitle: String
        var status: String // "prelaunch", "active", "complete"
        var launchDate: String // ISO 8601
        var missionDuration: TimeInterval // seconds
        var crew: [CrewMember]
    }

    struct CrewMember: Codable {
        var name: String
        var role: String
    }

    struct DataSources: Codable {
        var telemetry: TelemetrySource
        var moonPosition: MoonPositionSource?
    }

    struct TelemetrySource: Codable {
        var url: String
        var positionParams: [String]
        var positionUnit: String
        var activityField: String
        var pollInterval: TimeInterval
    }

    struct MoonPositionSource: Codable {
        var horizonsURL: String? // JPL Horizons base URL
        var refreshInterval: TimeInterval? // seconds, default 3600
    }

    struct Phase: Codable {
        var id: String
        var name: String
        var description: String
        var icon: String
    }

    struct Trajectory: Codable {
        var earthRadius: Double
        var moonRadius: Double
        var mu: Double? // gravitational parameter km³/s², default 398600.4418
        var waypoints: [Waypoint]
    }

    struct Waypoint: Codable {
        var met: TimeInterval
        var distanceFromEarth: Double
        var distanceFromMoon: Double
        var speed: Double
        var phase: String
    }

    // MARK: - Helpers

    var launchDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: mission.launchDate)
    }

    var earthRadius: Double { trajectory.earthRadius }
    var moonRadius: Double { trajectory.moonRadius }
    var mu: Double { trajectory.mu ?? 398_600.4418 }
}
