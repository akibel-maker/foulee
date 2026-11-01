import SwiftUI
import Charts

struct HabitDetailView: View {
    @Bindable var habit: Habit
    let value: HabitLogic.ValueProvider
    @State private var showEditor = false

    var body: some View {
        let stats = HabitLogic.stats(for: habit, value: value)
        ScrollView {
            VStack(spacing: 16) {
                header
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    tile("Série actuelle", "\(stats.currentStreak) \(stats.streakIsWeekly ? "sem." : "j")", "flame.fill", .orange)
                    tile("Meilleure série", "\(stats.bestStreak) \(stats.streakIsWeekly ? "sem." : "j")", "trophy.fill", .yellow)
                    tile("Réussite", "\(Int((stats.completionRate * 100).rounded())) %", "chart.pie.fill", habit.color)
                    tile("Jours réussis", "\(stats.totalDone)", "checkmark.seal.fill", .green)
                }
                heatmap
                if habit.kind == .count { recentChart }
            }
            .padding()
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Modifier") { showEditor = true }
        }
        .sheet(isPresented: $showEditor) { HabitEditorView(habit: habit) }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(habit.emoji)
                .font(.system(size: 40))
                .frame(width: 70, height: 70)
                .background(habit.color.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name).font(.title2.weight(.bold))
                Text(habit.scheduleDescription).font(.subheadline).foregroundStyle(.secondary)
                if habit.kind == .count {
                    Text("Objectif : \(habit.formatValue(habit.effectiveTarget)) \(habit.unit) par jour")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if habit.reminderEnabled {
                    Label(String(format: "Rappel à %02d:%02d", habit.reminderHour, habit.reminderMinute), systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func tile(_ title: String, _ value: String, _ systemImage: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
            Text(value).font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Calendrier

    private var heatmap: some View {
        let cal = HabitDay.calendar
        let today = cal.startOfDay(for: .now)
        let current = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weeks = (0..<17).reversed().compactMap { cal.date(byAdding: .weekOfYear, value: -$0, to: current) }
        let letters = ["L", "M", "M", "J", "V", "S", "D"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Historique").font(.headline)
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(0..<7, id: \.self) { row in
                    GridRow {
                        Text(letters[row]).font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 12)
                        ForEach(weeks, id: \.self) { weekStart in
                            let day = cal.date(byAdding: .day, value: row, to: weekStart) ?? weekStart
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: day, today: today))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .card()
    }

    private func color(for day: Date, today: Date) -> Color {
        if day > today { return .clear }
        let fraction = min(value(day) / habit.effectiveTarget, 1)
        if fraction >= 1 { return habit.color }
        if fraction > 0 { return habit.color.opacity(0.25 + 0.45 * fraction) }
        return HabitLogic.isScheduled(habit, on: day) ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.06)
    }

    // MARK: - 14 derniers jours

    private struct DayValue: Identifiable {
        let day: Date
        let value: Double
        var id: Date { day }
    }

    private var recentChart: some View {
        let cal = HabitDay.calendar
        let today = cal.startOfDay(for: .now)
        let data = (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
            .map { DayValue(day: $0, value: value($0)) }
        return VStack(alignment: .leading, spacing: 10) {
            Text("14 derniers jours").font(.headline)
            Chart {
                ForEach(data) { item in
                    BarMark(x: .value("Jour", item.day, unit: .day), y: .value(habit.unit, item.value))
                        .foregroundStyle(item.value >= habit.effectiveTarget ? habit.color : habit.color.opacity(0.4))
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Objectif", habit.effectiveTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
        }
        .card()
    }
}
