import SwiftUI

/// Onglet « Quotidien » : habitudes et sommeil.
struct DailyView: View {
    enum Part: String, CaseIterable, Identifiable {
        case habits = "Habitudes"
        case sleep = "Sommeil"
        var id: Self { self }
    }

    @AppStorage("dailySection") private var section: Part = .habits

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .habits: HabitsView()
                case .sleep: SleepView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Section", selection: $section) {
                        ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }
            }
        }
    }
}
