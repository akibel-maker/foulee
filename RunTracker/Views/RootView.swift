import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var appState = AppState()
    @State private var tracker = RunTracker()
    @State private var sleep = SleepStore()

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
            SleepView()
                .tabItem { Label("Sommeil", systemImage: "bed.double") }
                .tag(AppTab.sleep)
        }
        .environment(appState)
        .environment(tracker)
        .environment(sleep)
        .tint(.orange)
        .task { WatchSyncService.shared.start(container: context.container) }
    }
}
