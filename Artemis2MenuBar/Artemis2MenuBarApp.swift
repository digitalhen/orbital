import SwiftUI
import AppKit

@main
struct MissionTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var updateController: UpdateController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateController = UpdateController()
        statusBarController = StatusBarController(updateController: updateController)
        Analytics.shared.track("app_launch")
    }
}
