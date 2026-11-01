import SwiftUI

struct ContentView: View {
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        switch workout.phase {
        case .idle:
            StartView()
        case .active:
            SessionPagingView()
        case .saving:
            ProgressView("Enregistrement…")
        case .summary:
            SummaryView()
        }
    }
}
