import SwiftUI

@main
struct FouleeWatchApp: App {
    @State private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workout)
                .task { PhoneConnector.shared.activate() }
        }
    }
}
