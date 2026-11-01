import SwiftUI
import SwiftData
import Charts

struct SleepView: View {
    @Environment(SleepStore.self) private var sleep
    @Query(sort: \Run.startDate) private var runs: [Run]
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @State private var range: NightRange = .twoWeeks

    enum NightRange: Int, CaseIterable, Identifiable {
        case week = 7, twoWeeks = 14, month = 30
        var id: Self { self }
        var label: String {
            switch self {
            case .week: "7 nuits"
            case .twoWeeks: "14 nuits"
            case .month: "30 nuits"
            }
        }
    }

    private var goalSeconds: TimeInterval { sleepGoalHours * 3600 }

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    if sleep.nights.isEmpty {
                        emptyState
                    } else {
                        if let night = sleep.lastNight { lastNightCard(night) }
                        chartCard
                        statsGrid
                        runningInsight
                    }
                    goalCard
                }
                .padding()
            }
            .navigationTitle("Sommeil")
            .refreshable { await sleep.load() }
            .task { await sleep.loadIfNeeded() }
            .overlay {
                if sleep.isLoading && sleep.nights.isEmpty { ProgressView() }
            }
    }

    // MARK: - Dernière nuit

    private func lastNightCard(_ night: SleepNight) -> some View {
        let fraction = min(night.asleep / goalSeconds, 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Nuit du \(Fmt.dayShort(night.date))", systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                if let bed = night.bedtime, let wake = night.wakeTime {
                    Text("\(Fmt.clock(bed)) → \(Fmt.clock(wake))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.sleep(night.asleep))
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Int(fraction * 100)) %")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(fraction >= 1 ? .green : .primary)
                    Text("de l'objectif").font(.caption).foregroundStyle(.secondary)
                }
            }
            if night.hasStages {
                stageBar(night)
                stageLegend(night)
            } else {
                Text("Porte ton Apple Watch la nuit pour voir les phases de sommeil.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func stageBar(_ night: SleepNight) -> some View {
        let stages = SleepStage.allCases.filter { night.duration(of: $0) > 0 }
        let total = stages.reduce(0) { $0 + night.duration(of: $1) }
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(stages) { stage in
                    stage.color
                        .frame(width: max(2, (geo.size.width - CGFloat(stages.count - 1) * 2)
                                          * CGFloat(night.duration(of: stage) / max(total, 1))))
                }
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
    }

    private func stageLegend(_ night: SleepNight) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(SleepStage.allCases.filter { night.duration(of: $0) > 0 }) { stage in
                HStack(spacing: 6) {
                    Circle().fill(stage.color).frame(width: 9, height: 9)
                    Text(stage.label).font(.caption)
                    Spacer(minLength: 4)
                    Text(Fmt.sleep(night.duration(of: stage)))
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
    }

    // MARK: - Graphique

    private struct StageValue: Identifiable {
        let date: Date
        let stage: SleepStage
        let hours: Double
        var id: String { "\(date.timeIntervalSince1970)-\(stage.rawValue)" }
    }

    private var chartCard: some View {
        let nights = sleep.recentNights(range.rawValue)
        let values = nights.flatMap { night in
            SleepStage.asleepStages.compactMap { stage -> StageValue? in
                let d = night.duration(of: stage)
                return d > 0 ? StageValue(date: night.date, stage: stage, hours: d / 3600) : nil
            }
        }
        let average = nights.isEmpty ? 0 : nights.reduce(0) { $0 + $1.asleep } / Double(nights.count) / 3600
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Durée de sommeil").font(.headline)
                Spacer()
                Picker("Période", selection: $range) {
                    ForEach(NightRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
            }
            if !nights.isEmpty {
                Text("Moyenne : \(Fmt.sleep(average * 3600))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Chart {
                ForEach(values) { value in
                    BarMark(x: .value("Nuit", value.date, unit: .day),
                            y: .value("Heures", value.hours))
                        .foregroundStyle(by: .value("Phase", value.stage.label))
                }
                RuleMark(y: .value("Objectif", sleepGoalHours))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Objectif \(Fmt.sleep(goalSeconds))").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartForegroundStyleScale(domain: SleepStage.asleepStages.map(\.label),
                                       range: SleepStage.asleepStages.map(\.color))
            .chartYAxis {
                AxisMarks(values: .stride(by: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel { if let h = value.as(Double.self) { Text("\(Int(h)) h") } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .month ? 7 : (range == .twoWeeks ? 3 : 1))) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
        .card()
    }

    // MARK: - Statistiques

    private var statsGrid: some View {
        let recent = sleep.recentNights(30)
        let reached = recent.filter { $0.asleep >= goalSeconds }.count
        let bedtimes = recent.compactMap(\.bedtime).map { SleepAggregator.minutesSinceEvening($0) }
        let meanBed = bedtimes.isEmpty ? nil : bedtimes.reduce(0, +) / Double(bedtimes.count)
        let deviation: Double? = meanBed.map { mean in
            sqrt(bedtimes.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(bedtimes.count))
        }
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            insight("Moyenne 7 nuits", systemImage: "calendar",
                    value: sleep.averageSleep(lastDays: 7).map(Fmt.sleep) ?? "—")
            insight("Moyenne 30 nuits", systemImage: "calendar.badge.clock",
                    value: sleep.averageSleep(lastDays: 30).map(Fmt.sleep) ?? "—")
            insight("Objectif atteint", systemImage: "checkmark.seal",
                    value: recent.isEmpty ? "—" : "\(reached)/\(recent.count)",
                    detail: "nuits sur 30 jours")
            insight("Coucher moyen", systemImage: "bed.double",
                    value: meanBed.map { clockFromEvening($0) } ?? "—",
                    detail: deviation.map { "régularité ± \(Int($0.rounded())) min" })
        }
    }

    private func clockFromEvening(_ minutes: Double) -> String {
        let total = (Int(minutes.rounded()) + 18 * 60) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func insight(_ title: String, systemImage: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .card()
    }

    // MARK: - Sommeil et course

    private var runningInsight: some View {
        var rested: [Double] = []
        var tired: [Double] = []
        for run in runs where run.distance >= 2000 {
            guard let night = sleep.night(before: run.startDate) else { continue }
            if night.asleep >= goalSeconds { rested.append(run.averagePace) } else { tired.append(run.averagePace) }
        }
        let average: ([Double]) -> Double = { $0.reduce(0, +) / Double(max($0.count, 1)) }
        return VStack(alignment: .leading, spacing: 10) {
            Label("Sommeil et performance", systemImage: "figure.run")
                .font(.headline)
            if rested.count >= 2 && tired.count >= 2 {
                HStack {
                    paceColumn("Après une bonne nuit", pace: average(rested), count: rested.count, color: .green)
                    Divider()
                    paceColumn("Après une nuit courte", pace: average(tired), count: tired.count, color: .orange)
                }
                let gain = average(tired) - average(rested)
                if gain > 1 {
                    Text("Tu cours en moyenne \(Int(gain.rounded())) s/km plus vite quand tu as bien dormi.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Encore quelques courses avec des données de sommeil (au moins 2 après une bonne nuit et 2 après une nuit courte) pour voir l'effet du sommeil sur ton allure.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func paceColumn(_ title: String, pace: Double, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(Fmt.pace(pace))/km")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text("\(count) courses").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Objectif & état vide

    private var goalCard: some View {
        Stepper(value: $sleepGoalHours, in: 5...11, step: 0.25) {
            HStack {
                Label("Objectif de sommeil", systemImage: "target")
                Spacer()
                Text(Fmt.sleep(goalSeconds)).fontWeight(.semibold).monospacedDigit()
            }
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 44))
                .foregroundStyle(.indigo)
            Text("Pas encore de données de sommeil")
                .font(.headline)
            Text("Foulée lit ton sommeil dans l'app Santé. Pour l'enregistrer : porte ton Apple Watch la nuit avec le suivi du sommeil activé (app Santé › Sommeil › Configurer), ou utilise une autre app de sommeil reliée à Santé.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let message = sleep.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await sleep.load() }
            } label: {
                Label("Autoriser et actualiser", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(.vertical, 20)
        .card()
    }
}
