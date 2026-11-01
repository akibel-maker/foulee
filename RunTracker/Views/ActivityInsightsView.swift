import SwiftUI
import Charts

/// Régularité des sorties : calendrier d'activité + quatre indicateurs.
struct ActivityInsightsView: View {
    let runs: [Run]
    var weeks = 13

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    private static let dayLetters = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heatmap.card()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                favoriteDays
                balance
                averageDuration
                frequency
            }
        }
    }

    // MARK: - Données

    private var weekStarts: [Date] {
        guard let current = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<weeks).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: current) }
    }

    /// Courses des 12 dernières semaines (base des indicateurs).
    private var recentRuns: [Run] {
        guard let start = weekStarts.first else { return [] }
        return runs.filter { $0.startDate >= start }
    }

    private var kmByDay: [Date: Double] {
        var result: [Date: Double] = [:]
        for run in runs { result[calendar.startOfDay(for: run.startDate), default: 0] += run.distance / 1000 }
        return result
    }

    /// 0 = lundi … 6 = dimanche
    private func weekdayIndex(_ date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    // MARK: - Calendrier d'activité

    private var heatmap: some View {
        let totals = kmByDay
        let maxKm = max(totals.values.max() ?? 1, 1)
        let today = calendar.startOfDay(for: .now)
        let starts = weekStarts
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activité").font(.headline)
                Spacer()
                Text("\(weeks) dernières semaines").font(.caption).foregroundStyle(.secondary)
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Color.clear.frame(width: 14, height: 12)
                    ForEach(starts, id: \.self) { start in
                        Color.clear
                            .frame(height: 12)
                            .overlay(alignment: .leading) {
                                if calendar.component(.day, from: start) <= 7 {
                                    Text(start.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                }
                            }
                    }
                }
                ForEach(0..<7, id: \.self) { row in
                    GridRow {
                        Text(Self.dayLetters[row])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        ForEach(starts, id: \.self) { start in
                            let day = calendar.date(byAdding: .day, value: row, to: start) ?? start
                            let km = totals[day] ?? 0
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(day > today ? Color.clear : cellColor(km: km, maxKm: maxKm))
                                .overlay {
                                    if day == today {
                                        RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.6), lineWidth: 1)
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityLabel("\(Fmt.dayShort(day)) : \(km > 0 ? "\(Fmt.km(km * 1000, decimals: 1)) km" : "repos")")
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Spacer()
                Text("Moins").font(.system(size: 9)).foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(km: level, maxKm: 1))
                        .frame(width: 10, height: 10)
                }
                Text("Plus").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
    }

    private func cellColor(km: Double, maxKm: Double) -> Color {
        guard km > 0 else { return Color.secondary.opacity(0.15) }
        return Color.orange.opacity(0.3 + 0.7 * min(km / maxKm, 1))
    }

    // MARK: - Indicateurs

    private struct DayCount: Identifiable {
        let index: Int
        let count: Int
        var id: Int { index }
    }

    private var favoriteDays: some View {
        var counts = Array(repeating: 0, count: 7)
        for run in recentRuns { counts[weekdayIndex(run.startDate)] += 1 }
        let data = counts.enumerated().map { DayCount(index: $0.offset, count: $0.element) }
        let best = counts.max() ?? 0
        return InsightTile(title: "Jours préférés", systemImage: "calendar") {
            Chart(data) { item in
                BarMark(x: .value("Jour", "\(item.index)"), y: .value("Sorties", item.count))
                    .foregroundStyle(item.count == best && best > 0 ? Color.orange : Color.orange.opacity(0.35))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self), let i = Int(s) { Text(Self.dayLetters[i]) }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 70)
        }
    }

    private var balance: some View {
        let weekday = recentRuns.filter { weekdayIndex($0.startDate) < 5 }.count
        let total = recentRuns.count
        let share = total > 0 ? Double(weekday) / Double(total) : 0
        return InsightTile(title: "Équilibre", systemImage: "circle.lefthalf.filled") {
            VStack(alignment: .leading, spacing: 6) {
                Text(total > 0 ? "\(Int((share * 100).rounded())) %" : "—")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("des sorties en semaine").font(.caption).foregroundStyle(.secondary)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        Color.orange.frame(width: geo.size.width * share)
                        Color.orange.opacity(0.3)
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }
        }
    }

    private var averageDuration: some View {
        let avg = recentRuns.isEmpty ? 0 : recentRuns.reduce(0) { $0 + $1.duration } / Double(recentRuns.count)
        return InsightTile(title: "Durée moyenne", systemImage: "stopwatch") {
            VStack(alignment: .leading, spacing: 4) {
                Text(recentRuns.isEmpty ? "—" : "\(Int((avg / 60).rounded())) min")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("par sortie").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var frequency: some View {
        let perWeek = Double(recentRuns.count) / Double(max(weeks, 1))
        return InsightTile(title: "Fréquence", systemImage: "repeat") {
            VStack(alignment: .leading, spacing: 4) {
                Text(perWeek.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "fr_FR"))))
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("sorties par semaine").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct InsightTile<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .card()
    }
}
