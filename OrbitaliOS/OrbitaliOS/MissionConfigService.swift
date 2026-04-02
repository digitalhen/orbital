import Foundation
import Combine

@MainActor
class MissionConfigService: ObservableObject {
    @Published var config: MissionConfig

    private let configURL = "https://api.cleartextlabs.com/space/api/v1/mission/active"

    private let cacheFile: URL
    private var refreshTimer: Timer?

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    init() {
        // Cache location
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Orbital", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        cacheFile = appDir.appendingPathComponent("config.json")

        // Load priority: disk cache > bundled default
        if let cached = Self.loadFromDisk(cacheFile) {
            config = cached
        } else {
            config = Self.loadBundledDefault()
        }

        // Fetch fresh config from remote
        Task { await fetchRemoteConfig() }
    }

    func startPeriodicRefresh() {
        let interval = max(config.refreshInterval, 300) // minimum 5 min
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchRemoteConfig()
            }
        }
    }

    private func fetchRemoteConfig() async {
        let cacheBust = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "\(configURL)?_=\(cacheBust)") else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let decoder = JSONDecoder()
            let remote = try decoder.decode(MissionConfig.self, from: data)

            // Only update if newer version
            if remote.configVersion >= config.configVersion {
                config = remote
                saveToDisk(data)
                Analytics.shared.track("config_update", params: ["version": "\(remote.configVersion)", "mission": remote.mission.id])

                // Update refresh interval if changed
                refreshTimer?.invalidate()
                startPeriodicRefresh()
            }
        } catch {
            // Silently fail — keep using cached/bundled config
        }
    }

    private func saveToDisk(_ data: Data) {
        try? data.write(to: cacheFile, options: .atomic)
    }

    private static func loadFromDisk(_ url: URL) -> MissionConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MissionConfig.self, from: data)
    }

    static func loadBundledDefault() -> MissionConfig {
        guard let url = Bundle.main.url(forResource: "default-config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(MissionConfig.self, from: data) else {
            fatalError("Missing default-config.json in app bundle")
        }
        return config
    }
}
