import SwiftUI

struct RootView: View {
    @State private var appState = AppState()
    @State private var tracker = RunTracker()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            RunView()
                .tabItem { Label("Courir", systemImage: "figure.run") }
                .tag(AppTab.run)
            RoutesView()
                .tabItem { Label("Itinéraires", systemImage: "map") }
                .tag(AppTab.routes)
            HistoryView()
                .tabItem { Label("Historique", systemImage: "list.bullet") }
                .tag(AppTab.history)
            StatsView()
                .tabItem { Label("Progression", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.stats)
        }
        .environment(appState)
        .environment(tracker)
        .tint(.orange)
    }
}
