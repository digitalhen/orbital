import SwiftUI

@main
struct OrbitalApp: App {
    @StateObject private var service = MissionDataService()

    var body: some Scene {
        WindowGroup {
            ContentView(service: service)
                .preferredColorScheme(.dark)
        }
    }
}
