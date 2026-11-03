import SwiftUI
import SwiftData

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
            HistoryView()
                .tabItem { Label("Historique", systemImage: "list.bullet") }
                .tag(AppTab.history)
            StatsView()
                .tabItem { Label("Progression", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.stats)
            MobilityView()
                .tabItem { Label("Mobilité", systemImage: "figure.flexibility") }
                .tag(AppTab.stretch)
            DailyView()
                .tabItem { Label("Quotidien", systemImage: "checklist") }
                .tag(AppTab.daily)
        }
        .environment(appState)
        .environment(tracker)
        .environment(sleep)
        .tint(.orange)
        .task { WatchSyncService.shared.start(container: context.container) }
    }
}
