import Foundation

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric = "metric"
    case imperial = "imperial"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: return "Metric (km, km/h)"
        case .imperial: return "Imperial (mi, mph)"
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    private static let oneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    private func formatted(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formatted1(_ value: Double) -> String {
        Self.oneDecimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func formatDistance(_ km: Double) -> String {
        switch self {
        case .metric:
            if km >= 1_000 {
                return "\(formatted(km)) km"
            }
            return "\(formatted1(km)) km"
        case .imperial:
            let mi = km * 0.621371
            if mi >= 1_000 {
                return "\(formatted(mi)) mi"
            }
            return "\(formatted1(mi)) mi"
        }
    }

    func formatSpeed(_ kms: Double) -> String {
        switch self {
        case .metric:
            return "\(formatted(kms * 3600)) km/h"
        case .imperial:
            return "\(formatted(kms * 3600 * 0.621371)) mph"
        }
    }

    func formatDistanceCompact(_ km: Double) -> String {
        let d = max(0, km)
        switch self {
        case .metric:
            if d >= 1_000 {
                return "\(formatted(d)) km"
            }
            return "\(formatted1(d)) km"
        case .imperial:
            let mi = d * 0.621371
            if mi >= 1_000 {
                return "\(formatted(mi)) mi"
            }
            return "\(formatted1(mi)) mi"
        }
    }

    func formatSpeedCompact(_ kms: Double) -> String {
        switch self {
        case .metric:
            return "\(formatted(kms * 3600)) km/h"
        case .imperial:
            return "\(formatted(kms * 3600 * 0.621371)) mph"
        }
    }
}
