import SwiftUI
import SwiftData
import Charts

struct StretchStatsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case stats = "Statistiques", history = "Historique"
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \StretchSession.date, order: .reverse) private var sessions: [StretchSession]
    @State private var tab: Tab = .stats
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Vue", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if tab == .stats { statsContent } else { historyContent }
                }
                .padding()
            }
            .navigationTitle("Tableau de bord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
    }

    // MARK: - Statistiques

    private var statsContent: some View {
        let stats = StretchStatsCalculator.stats(for: sessions)
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 12) {
                tile("Série active", stats.currentStreak > 0 ? days(stats.currentStreak) : "—", "flame.fill", .orange)
                tile("Plus longue série", stats.longestStreak > 0 ? days(stats.longestStreak) : "—", "trophy.fill", .yellow)
                tile("Jours complétés", "\(stats.daysCompleted)", "checkmark.seal.fill", .green)
                tile("Temps total", "\(stats.totalMinutes) min", "clock.fill", .teal)
            }
            if let last = stats.lastSession {
                HStack {
                    Label("Dernier étirement", systemImage: "calendar")
                    Spacer()
                    Text(last.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR"))))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .card()
            }
            weeklyChart
            favoriteRoutines
        }
    }

    private func days(_ n: Int) -> String { n > 1 ? "\(n) jours" : "1 jour" }

    private func tile(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.uppercased(), systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value).font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .card()
    }

    private struct WeekMinutes: Identifiable {
        let start: Date
        let minutes: Double
        var id: Date { start }
    }

    private var weeklyChart: some View {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let current = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let weeks: [WeekMinutes] = (0..<8).reversed().compactMap { offset in
            guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: current),
                  let end = cal.date(byAdding: .day, value: 7, to: start) else { return nil }
            let minutes = sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.duration } / 60
            return WeekMinutes(start: start, minutes: minutes)
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Minutes par semaine").font(.headline)
            Chart(weeks) { week in
                BarMark(x: .value("Semaine", week.start, unit: .weekOfYear), y: .value("Minutes", week.minutes))
                    .foregroundStyle(.orange.gradient)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
        }
        .card()
    }

    private var favoriteRoutines: some View {
        let counts = Dictionary(grouping: sessions, by: \.routineName).mapValues(\.count)
            .sorted { $0.value > $1.value }.prefix(3)
        return Group {
            if !counts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Routines les plus pratiquées").font(.headline)
                    ForEach(Array(counts), id: \.key) { item in
                        HStack {
                            Text(item.key)
                            Spacer()
                            Text("\(item.value) fois").foregroundStyle(.secondary).monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                }
                .card()
            }
        }
    }

    // MARK: - Historique

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            calendar
            Text("MON HISTORIQUE").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
            if sessions.isEmpty {
                Text("Aucune séance pour l'instant. Lance une routine pour commencer ta série !")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(sessions) { session in
                HStack(spacing: 12) {
                    let routine = StretchLibrary.routine(session.routineID)
                    StretchArtwork(symbol: routine?.symbol ?? "star.fill", tint: routine?.tint ?? .orange, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()
                            .locale(Locale(identifier: "fr_FR"))))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.routineName).font(.headline)
                    }
                    Spacer()
                    Text(Fmt.duration(session.duration)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        context.delete(session)
                        try? context.save()
                    }
                }
            }
        }
    }

    private var calendar: some View {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let days = Set(sessions.map { cal.startOfDay(for: $0.date) })
        let firstWeekday = (cal.component(.weekday, from: month) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let cells: [Date?] = Array(repeating: nil, count: firstWeekday)
            + (0..<count).map { cal.date(byAdding: .day, value: $0, to: month) }
        let today = cal.startOfDay(for: .now)
        let letters = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
        return VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))).uppercased())
                    .font(.headline)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(month >= (cal.dateInterval(of: .month, for: .now)?.start ?? .now))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(letters, id: \.self) { Text($0).font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
                ForEach(Array(cells.enumerated()), id: \.offset) { item in
                    if let day = item.element {
                        let done = days.contains(day)
                        Text("\(cal.component(.day, from: day))")
                            .font(.subheadline.weight(done ? .bold : .regular))
                            .frame(width: 36, height: 36)
                            .background(done ? Color.orange : Color.clear, in: Circle())
                            .foregroundStyle(done ? .white : (day > today ? .secondary : .primary))
                            .overlay { if day == today { Circle().stroke(Color.primary, lineWidth: 1.5) } }
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .card()
    }

    private func shiftMonth(_ value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: month) { month = newMonth }
    }
}
