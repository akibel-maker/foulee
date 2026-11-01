import SwiftUI
import WatchKit

/// Pages pendant la course : commandes ← mesures → musique.
struct SessionPagingView: View {
    @Environment(WorkoutManager.self) private var workout
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var page: Page = .metrics

    enum Page { case controls, metrics, nowPlaying }

    var body: some View {
        TabView(selection: $page) {
            ControlsView().tag(Page.controls)
            MetricsView().tag(Page.metrics)
            NowPlayingView().tag(Page.nowPlaying)
        }
        .tabViewStyle(.page(indexDisplayMode: isLuminanceReduced ? .never : .automatic))
        .onChange(of: workout.isPaused) { _, _ in
            withAnimation { page = .metrics }
        }
        .onChange(of: isLuminanceReduced) { _, _ in
            withAnimation { page = .metrics }
        }
    }
}
