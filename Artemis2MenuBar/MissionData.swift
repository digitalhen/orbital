import Foundation

struct MissionPhaseInfo: Equatable {
    var id: String = "prelaunch"
    var name: String = "Pre-Launch"
    var description: String = ""
    var icon: String = "clock"
}

struct MissionData {
    var missionElapsedTime: TimeInterval = 0
    var distanceFromEarth: Double = 0       // km altitude (from surface)
    var distanceFromMoon: Double = 0        // km
    var speed: Double = 0                   // km/s
    var phase = MissionPhaseInfo()
    var crewMembers: [String] = []
    var missionName: String = ""
    var missionSubtitle: String = ""

    /// Dynamic metric values keyed by source ID
    var values: [String: MetricValue] = [:]

    /// Compute all built-in metric values from the current state
    mutating func updateBuiltInValues() {
        values["met"] = .duration(missionElapsedTime)
        values["altitude"] = .number(distanceFromEarth)
        values["moonDistance"] = .number(distanceFromMoon)
        values["speed"] = .number(speed)
        values["phase"] = .text(phase.name)
    }

    /// Get the formatted value for a metric definition
    func formattedValue(for metric: Metric, units: UnitSystem) -> String {
        guard let value = values[metric.source] else { return "—" }
        return value.format(as: metric.format, units: units)
    }

    /// Get the detailed formatted value for a metric definition
    func formattedDetailValue(for metric: Metric, units: UnitSystem) -> String {
        guard let value = values[metric.source] else { return "—" }
        return value.formatDetail(as: metric.format, units: units)
    }
}
