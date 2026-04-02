import Foundation

/// A metric definition from the config. Fully dynamic — the API defines what metrics exist.
struct Metric: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var shortLabel: String
    var icon: String
    var format: String       // "duration", "distance", "speed", "text"
    var source: String       // built-in: "met", "altitude", "moonDistance", "speed", "phase"
                             // or any custom key for future values
    var enabledByDefault: Bool?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Metric, rhs: Metric) -> Bool { lhs.id == rhs.id }
}

/// A metric's current value — can be a number, text, or duration
enum MetricValue {
    case number(Double)
    case text(String)
    case duration(TimeInterval)

    func format(as type: String, units: UnitSystem) -> String {
        switch (self, type) {
        case (.duration(let t), "duration"):
            return Self.formatDuration(t)
        case (.number(let v), "distance"):
            return units.formatDistanceCompact(v)
        case (.number(let v), "speed"):
            return units.formatSpeedCompact(v)
        case (.text(let s), _):
            return s
        case (.number(let v), _):
            return units.formatDistanceCompact(v)
        case (.duration(let t), _):
            return Self.formatDuration(t)
        }
    }

    func formatDetail(as type: String, units: UnitSystem) -> String {
        switch (self, type) {
        case (.duration(let t), "duration"):
            return Self.formatDuration(t)
        case (.number(let v), "distance"):
            return units.formatDistance(v)
        case (.number(let v), "speed"):
            return units.formatSpeed(v)
        case (.text(let s), _):
            return s
        case (.number(let v), _):
            return units.formatDistance(v)
        case (.duration(let t), _):
            return Self.formatDuration(t)
        }
    }

    private static func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if d > 0 {
            return String(format: "%dd %02dh %02dm %02ds", d, h, m, s)
        }
        return String(format: "%02dh %02dm %02ds", h, m, s)
    }
}
