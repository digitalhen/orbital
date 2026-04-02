import Foundation

/// Simulates mission trajectory using waypoints from the config.
class TrajectorySimulator {

    private let launchDate: Date
    private let earthRadius: Double
    private let moonRadius: Double
    private let waypoints: [MissionConfig.Waypoint]
    private let phases: [MissionConfig.Phase]

    init(config: MissionConfig) {
        launchDate = config.launchDate ?? Date()
        earthRadius = config.trajectory.earthRadius
        moonRadius = config.trajectory.moonRadius
        waypoints = config.trajectory.waypoints
        phases = config.phases
    }

    func getData(at date: Date) -> MissionData {
        let met = date.timeIntervalSince(launchDate)
        return getData(met: met)
    }

    func getData(met: TimeInterval) -> MissionData {
        var data = MissionData()
        data.missionElapsedTime = max(0, met)

        guard !waypoints.isEmpty else { return data }

        if met <= waypoints.first!.met {
            let wp = waypoints.first!
            data.distanceFromEarth = max(0, wp.distanceFromEarth - earthRadius)
            data.distanceFromMoon = max(0, wp.distanceFromMoon - moonRadius)
            data.speed = wp.speed
            data.phase = resolvePhase(wp.phase)
            return data
        }

        if met >= waypoints.last!.met {
            let wp = waypoints.last!
            data.distanceFromEarth = max(0, wp.distanceFromEarth - earthRadius)
            data.distanceFromMoon = max(0, wp.distanceFromMoon - moonRadius)
            data.speed = wp.speed
            data.phase = resolvePhase(wp.phase)
            return data
        }

        var lowerIndex = 0
        for i in 0..<waypoints.count - 1 {
            if met >= waypoints[i].met && met < waypoints[i + 1].met {
                lowerIndex = i
                break
            }
        }

        let wp0 = waypoints[lowerIndex]
        let wp1 = waypoints[lowerIndex + 1]
        let dt = wp1.met - wp0.met
        let t = (met - wp0.met) / dt
        let s = smoothstep(t)

        data.distanceFromEarth = max(0, lerp(wp0.distanceFromEarth, wp1.distanceFromEarth, s) - earthRadius)
        data.distanceFromMoon = max(0, lerp(wp0.distanceFromMoon, wp1.distanceFromMoon, s) - moonRadius)
        data.speed = lerp(wp0.speed, wp1.speed, s)
        data.phase = resolvePhase(t < 0.5 ? wp0.phase : wp1.phase)

        return data
    }

    private func resolvePhase(_ id: String) -> MissionPhaseInfo {
        if let p = phases.first(where: { $0.id == id }) {
            return MissionPhaseInfo(id: p.id, name: p.name, description: p.description, icon: p.icon)
        }
        return MissionPhaseInfo(id: id, name: id, description: "", icon: "questionmark.circle")
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func smoothstep(_ t: Double) -> Double {
        let c = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
