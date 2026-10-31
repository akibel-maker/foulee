import SwiftUI
import SwiftData

@main
struct RunTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Run.self)
    }
}
