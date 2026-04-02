import Foundation
import Combine

@MainActor
class MissionDataService: ObservableObject {
    @Published var data = MissionData()
    @Published var isLive: Bool = false
    @Published var lastAROWUpdate: Date?
    @Published var metrics: [Metric] = []
    @Published var units: UnitSystem = .imperial {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: "unitSystem") }
    }

    let configService: MissionConfigService

    private var simulator: TrajectorySimulator
    private var arowFetcher: AROWFetcher
    private var earthRadius: Double
    private var timer: Timer?
    private var arowTimer: Timer?
    private var configCancellable: AnyCancellable?

    private var liveAltitude: Double?
    private var liveMoonDist: Double?
    private var liveSpeed: Double?

    init() {
        let cs = MissionConfigService()
        self.configService = cs

        let config = cs.config
        simulator = TrajectorySimulator(config: config)
        arowFetcher = AROWFetcher(config: config)
        earthRadius = config.earthRadius
        metrics = config.metrics

        if let raw = UserDefaults.standard.string(forKey: "unitSystem"),
           let saved = UnitSystem(rawValue: raw) {
            units = saved
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
        applyConfig(config)

        liveAltitude = nil
        liveMoonDist = nil
        liveSpeed = nil

        arowTimer?.invalidate()
        let interval = max(config.dataSources.telemetry.pollInterval, 10)
        arowTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchAROWData() }
        }
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
        data.phase = simData.phase
        data.distanceFromEarth = liveAltitude ?? simData.distanceFromEarth
        data.distanceFromMoon = liveMoonDist ?? simData.distanceFromMoon
        data.speed = liveSpeed ?? simData.speed
        data.updateBuiltInValues()
    }

    private func fetchAROWData() {
        Task {
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

    deinit {
        timer?.invalidate()
        arowTimer?.invalidate()
    }
}
