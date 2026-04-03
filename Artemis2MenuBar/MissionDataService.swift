import Foundation
import Combine

@MainActor
class MissionDataService: ObservableObject {
    @Published var data = MissionData()
    @Published var isLive: Bool = false
    @Published var lastAROWUpdate: Date?
    @Published var metrics: [Metric] = []
    @Published var enabledMetricIDs: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(enabledMetricIDs), forKey: "enabledMetricIDs") }
    }
    @Published var units: UnitSystem = .imperial {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: "unitSystem") }
    }

    let configService: MissionConfigService

    private var simulator: TrajectorySimulator
    private var arowFetcher: AROWFetcher
    private var telemetryFetcher: TelemetryAPIFetcher?
    private var earthRadius: Double
    private var timer: Timer?
    private var arowTimer: Timer?
    private var configCancellable: AnyCancellable?

    private var liveAltitude: Double?
    private var liveMoonDist: Double?
    private var liveSpeed: Double?
    private var livePhase: MissionPhaseInfo?

    init() {
        let cs = MissionConfigService()
        self.configService = cs

        let config = cs.config
        simulator = TrajectorySimulator(config: config)
        arowFetcher = AROWFetcher(config: config)
        if let endpoint = config.dataSources.telemetryEndpoint {
            telemetryFetcher = TelemetryAPIFetcher(endpointURL: endpoint)
        }
        earthRadius = config.earthRadius
        metrics = config.metrics

        // Load saved enabled metrics — keyed by ID so renames don't reset toggles
        if let saved = UserDefaults.standard.stringArray(forKey: "enabledMetricIDs") {
            enabledMetricIDs = Set(saved)
            // If all saved IDs are gone (config changed entirely), use defaults
            if enabledMetricIDs.intersection(Set(config.metrics.map(\.id))).isEmpty {
                enabledMetricIDs = Self.defaultEnabledIDs(from: config.metrics)
            }
        } else {
            enabledMetricIDs = Self.defaultEnabledIDs(from: config.metrics)
        }

        if let raw = UserDefaults.standard.string(forKey: "unitSystem"),
           let saved = UnitSystem(rawValue: raw) {
            units = saved
        } else {
            units = .imperial
        }

        applyConfig(config)

        configCancellable = cs.$config
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] newConfig in
                self?.onConfigUpdate(newConfig)
            }

        startUpdating()
        fetchAROWData()
        cs.startPeriodicRefresh()
    }

    private static func defaultEnabledIDs(from metrics: [Metric]) -> Set<String> {
        let defaults = metrics.filter { $0.enabledByDefault == true }.map(\.id)
        return defaults.isEmpty ? Set(metrics.prefix(3).map(\.id)) : Set(defaults)
    }

    private func applyConfig(_ config: MissionConfig) {
        data.missionName = config.mission.name
        data.missionSubtitle = config.mission.subtitle
        data.crewMembers = config.mission.crew.map { "\($0.name) (\($0.role))" }
        metrics = config.metrics
    }

    private func onConfigUpdate(_ config: MissionConfig) {
        simulator = TrajectorySimulator(config: config)
        earthRadius = config.earthRadius
        Task { await arowFetcher.reconfigure(config: config) }
        if let endpoint = config.dataSources.telemetryEndpoint {
            if let existing = telemetryFetcher {
                Task { await existing.reconfigure(endpointURL: endpoint) }
            } else {
                telemetryFetcher = TelemetryAPIFetcher(endpointURL: endpoint)
            }
        } else {
            telemetryFetcher = nil
        }
        applyConfig(config)

        liveAltitude = nil
        liveMoonDist = nil
        liveSpeed = nil
        livePhase = nil

        arowTimer?.invalidate()
        let interval = max(config.dataSources.telemetry.pollInterval, 10)
        arowTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchAROWData() }
        }
    }

    func toggleMetric(_ id: String) {
        if enabledMetricIDs.contains(id) {
            if enabledMetricIDs.count > 1 {
                enabledMetricIDs.remove(id)
                Analytics.shared.track("metric_toggle", params: ["metric": id, "enabled": "false"])
            }
        } else {
            enabledMetricIDs.insert(id)
            Analytics.shared.track("metric_toggle", params: ["metric": id, "enabled": "true"])
        }
    }

    func isMetricEnabled(_ id: String) -> Bool {
        enabledMetricIDs.contains(id)
    }

    private func startUpdating() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateData() }
        }
        updateData()

        let interval = max(configService.config.dataSources.telemetry.pollInterval, 10)
        arowTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchAROWData() }
        }
    }

    private func updateData() {
        let simData = simulator.getData(at: Date())
        data.missionElapsedTime = simData.missionElapsedTime
        data.phase = livePhase ?? simData.phase
        data.distanceFromEarth = liveAltitude ?? simData.distanceFromEarth
        data.distanceFromMoon = liveMoonDist ?? simData.distanceFromMoon
        data.speed = liveSpeed ?? simData.speed
        data.updateBuiltInValues()
    }

    private func fetchAROWData() {
        Task {
            // Prefer pre-computed telemetry API when available
            if let fetcher = telemetryFetcher, let telemetry = await fetcher.fetch() {
                await MainActor.run {
                    self.isLive = telemetry.isLive
                    self.lastAROWUpdate = Date()
                    if telemetry.altitude > 0 {
                        self.liveAltitude = telemetry.altitude
                    }
                    if telemetry.distanceToMoon > 0 {
                        self.liveMoonDist = telemetry.distanceToMoon
                    }
                    if telemetry.speed > 0.01 {
                        self.liveSpeed = telemetry.speed
                    }
                    if let phaseId = telemetry.phase {
                        self.livePhase = self.resolvePhase(phaseId)
                    }
                }
                return
            }

            // Fallback: direct AROW fetch for old configs without telemetryEndpoint
            if let arowData = await arowFetcher.fetch() {
                await MainActor.run {
                    self.isLive = arowData.isLive
                    self.lastAROWUpdate = Date()
                    if arowData.distanceFromEarthCenter > 0 {
                        self.liveAltitude = arowData.distanceFromEarthCenter - self.earthRadius
                    }
                    if arowData.distanceFromMoon > 0 {
                        self.liveMoonDist = arowData.distanceFromMoon
                    }
                    if arowData.speed > 0.01 {
                        self.liveSpeed = arowData.speed
                    }
                }
            }
        }
    }

    private func resolvePhase(_ id: String) -> MissionPhaseInfo {
        if let p = configService.config.phases.first(where: { $0.id == id }) {
            return MissionPhaseInfo(id: p.id, name: p.name, description: p.description, icon: p.icon)
        }
        return MissionPhaseInfo(id: id, name: id, description: "", icon: "questionmark.circle")
    }

    deinit {
        timer?.invalidate()
        arowTimer?.invalidate()
    }
}
