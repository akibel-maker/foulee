import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Run.startDate) private var runs: [Run]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Environment(\.modelContext) private var context
    /// Ancien réglage « objectif hebdo » : converti une fois en objectif.
    @AppStorage("weeklyGoalKm") private var legacyWeeklyGoalKm = 20.0
    @AppStorage("didSeedGoals") private var didSeedGoals = false
    @State private var period: Period = .month
    @State private var showSettings = false

    enum Period: String, CaseIterable, Identifiable {
        case week = "Semaine", month = "Mois", year = "Année", all = "Total"
        var id: Self { self }
        var component: Calendar.Component? {
            switch self {
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
            case .all: nil
            }
        }
    }

    private struct Totals {
        var distance = 0.0
        var duration = 0.0
        var gain = 0.0
        var count = 0
    }

    private struct WeekTotal: Identifiable {
        let start: Date
        let km: Double
        var id: Date { start }
    }

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // lundi
        return c
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    GoalsSection()
                    if !runs.isEmpty { ActivityInsightsView(runs: runs) }
                    totalsCard
                    weeklyChart
                    if runs.filter({ $0.distance >= 1000 }).count >= 2 { paceTrend }
                    records
                }
                .padding()
            }
            .navigationTitle("Progression")
            .toolbar {
                Button("Réglages", systemImage: "gearshape") { showSettings = true }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear(perform: seedDefaultGoal)
        }
    }

    /// Objectif « km par semaine » utilisé comme repère sur le graphique hebdomadaire.
    private var weeklyGoalKm: Double {
        goals.first { $0.kind == .distance && $0.period == .week }?.target ?? 0
    }

    private func seedDefaultGoal() {
        guard !didSeedGoals else { return }
        didSeedGoals = true
        if goals.isEmpty, legacyWeeklyGoalKm > 0 {
            context.insert(Goal(kind: .distance, period: .week, target: legacyWeeklyGoalKm))
            try? context.save()
        }
    }

    // MARK: - Calculs

    private func totals(in interval: DateInterval?) -> Totals {
        var t = Totals()
        for run in runs where interval.map({ $0.contains(run.startDate) }) ?? true {
            t.distance += run.distance
            t.duration += run.duration
            t.gain += run.elevationGain
            t.count += 1
        }
        return t
    }

    private func interval(for period: Period, offset: Int = 0) -> DateInterval? {
        guard let component = period.component,
              let reference = calendar.date(byAdding: component, value: offset, to: .now) else { return nil }
        return calendar.dateInterval(of: component, for: reference)
    }

    private var weeks: [WeekTotal] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<12).reversed().compactMap { i in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -i, to: thisWeek),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            let km = runs.filter { $0.startDate >= start && $0.startDate < end }
                .reduce(0) { $0 + $1.distance } / 1000
            return WeekTotal(start: start, km: km)
        }
    }

    // MARK: - Sections

    private var totalsCard: some View {
        let current = totals(in: interval(for: period))
        let previous = period == .all ? nil : totals(in: interval(for: period, offset: -1))
        return VStack(spacing: 16) {
            Picker("Période", selection: $period) {
                ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                StatTile(title: "Distance", value: Fmt.km(current.distance, decimals: 1), unit: "km")
                StatTile(title: "Courses", value: "\(current.count)")
            }
            HStack {
                StatTile(title: "Temps", value: Fmt.duration(current.duration))
                StatTile(title: "Dénivelé", value: "\(Int(current.gain))", unit: "m")
                StatTile(title: "Allure moy.",
                         value: Fmt.pace(current.distance > 0 ? current.duration / (current.distance / 1000) : 0))
            }
            if let previous, previous.distance > 0 {
                let delta = (current.distance - previous.distance) / previous.distance * 100
                Label("\(delta >= 0 ? "+" : "")\(Int(delta.rounded())) % de distance par rapport à la période précédente",
                      systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.footnote)
                    .foregroundStyle(delta >= 0 ? .green : .secondary)
            }
        }
        .card()
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Distance par semaine").font(.headline)
            Chart {
                ForEach(weeks) { week in
                    BarMark(x: .value("Semaine", week.start, unit: .weekOfYear),
                            y: .value("km", week.km))
                        .foregroundStyle(.orange.gradient)
                        .cornerRadius(4)
                }
                if weeklyGoalKm > 0 {
                    RuleMark(y: .value("Objectif", weeklyGoalKm))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Objectif").font(.caption2).foregroundStyle(.secondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 180)
        }
        .card()
    }

    private var paceTrend: some View {
        let recent = Array(runs.filter { $0.distance >= 1000 }.suffix(20))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Évolution de l'allure").font(.headline)
            Text("20 dernières courses — plus haut = plus rapide").font(.caption).foregroundStyle(.secondary)
            Chart(recent) { run in
                LineMark(x: .value("Date", run.startDate), y: .value("Allure", run.averagePace))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.orange)
                PointMark(x: .value("Date", run.startDate), y: .value("Allure", run.averagePace))
                    .foregroundStyle(.orange)
            }
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let pace = value.as(Double.self) { Text(Fmt.pace(pace)) }
                    }
                }
            }
            .frame(height: 180)
        }
        .card()
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Records personnels").font(.headline)
            ForEach(RunMetrics.effortDistances, id: \.distance) { item in
                let best = runs.compactMap { run in run.bestEffort(for: item.distance).map { (run, $0) } }
                    .min { $0.1 < $1.1 }
                HStack {
                    Text(item.label)
                    Spacer()
                    if let best {
                        VStack(alignment: .trailing) {
                            Text(Fmt.duration(best.1)).fontWeight(.semibold)
                            Text(Fmt.shortDate(best.0.startDate)).font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("—").foregroundStyle(.tertiary)
                    }
                }
                .font(.subheadline.monospacedDigit())
                Divider()
            }
            if let longest = runs.max(by: { $0.distance < $1.distance }) {
                recordRow("Plus longue course", value: "\(Fmt.km(longest.distance)) km", date: longest.startDate)
            }
            if let climb = runs.max(by: { $0.elevationGain < $1.elevationGain }), climb.elevationGain > 0 {
                recordRow("Plus gros dénivelé", value: Fmt.meters(climb.elevationGain), date: climb.startDate)
            }
        }
        .card()
    }

    private func recordRow(_ title: String, value: String, date: Date) -> some View {
        HStack {
            Text(title)
            Spacer()
            VStack(alignment: .trailing) {
                Text(value).fontWeight(.semibold)
                Text(Fmt.shortDate(date)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.monospacedDigit())
    }
}
