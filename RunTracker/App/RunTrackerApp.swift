import SwiftUI
import SwiftData

@main
struct RunTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Run.self, Goal.self, Habit.self, StretchSession.self, CustomStretchRoutine.self])
    }
}
