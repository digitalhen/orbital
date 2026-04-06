import Foundation
#if !APPSTORE
import Sparkle
#endif

@MainActor
final class UpdateController: ObservableObject {
    #if !APPSTORE
    private let updaterController: SPUStandardUpdaterController
    #endif

    @Published var canCheckForUpdates = false

    init() {
        #if !APPSTORE
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        #endif
    }

    func checkForUpdates() {
        #if !APPSTORE
        updaterController.checkForUpdates(nil)
        #endif
    }
}
