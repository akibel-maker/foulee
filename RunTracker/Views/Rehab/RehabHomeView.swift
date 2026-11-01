import SwiftUI
import SwiftData
import Charts

struct RehabHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RehabScreening.date, order: .reverse) private var screenings: [RehabScreening]
    @Query(sort: \RehabSession.date, order: .reverse) private var sessions: [RehabSession]
    @Query(sort: \RehabCheckIn.date, order: .reverse) private var checkIns: [RehabCheckIn]
    @Query private var habits: [Habit]
    @AppStorage("rehabStartDate") private var startTimestamp = 0.0
    @AppStorage("rehabPhase") private var phaseNumber = 1
    @AppStorage("rehabClearance") private var clearance = false
    @AppStorage("rehabPaused") private var paused = false
    @AppStorage("rehabIncludeOptional") private var includeOptional = false
    @AppStorage("stretchNeckCaution") private var neckCaution = false
    @State private var showScreening = false
    @State private var showCheckIn = false
    @State private var showSession = false
    @State private var advanceTarget: RehabPhase?
    @State private var confirmReset = false

    private var started: Bool { startTimestamp > 0 }
    private var startDate: Date { Date(timeIntervalSince1970: startTimestamp) }
    private var week: Int { RehabProgram.week(since: startDate) }
    private var phase: RehabPhase { RehabContent.phase(phaseNumber) }
    private var screening: RehabScreening? { screenings.first }

    private var sessionsThisWeek: Int {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let interval = cal.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return sessions.filter { interval.contains($0.date) }.count
    }

    /// Le programme demande au moins un jour de repos entre deux séances.
    private var needsRestDay: Bool {
        guard let last = sessions.first?.date else { return false }
        let cal = Calendar.current
        return cal.isDateInToday(last) || cal.isDateInYesterday(last)
    }

    private var checkInDue: Bool {
        guard started else { return false }
        guard let last = checkIns.first else { return week > 1 || !sessions.isEmpty }
        return Date().timeIntervalSince(last.date) > 6 * 86400
    }

    private var canAdvance: Bool {
        started && !paused && phaseNumber < 4 && week > phase.weeks.upperBound
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                priorityCard
                if started {
                    if paused { pausedCard }
                    statusCard
                    if canAdvance { advanceCard }
                    checkInCard
                    phasesCard
                    habitsCard
                    neckCautionCard
                    historyCard
                } else {
                    introCard
                    screeningCard
                    phasesCard
                }
                safetyCard
            }
            .padding()
        }
        .navigationTitle("Rééducation")
        .navigationDestination(for: RehabPhase.self) { RehabPhaseView(phase: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Refaire le point", systemImage: "list.clipboard") { showScreening = true }
                    if started {
                        Button("Bilan de la semaine", systemImage: "chart.line.uptrend.xyaxis") { showCheckIn = true }
                        Button("Réinitialiser le programme", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmReset = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showScreening) { RehabScreeningView() }
        .sheet(isPresented: $showCheckIn) { RehabCheckInView() }
        .sheet(item: $advanceTarget) { target in
            RehabAdvanceSheet(phase: target) {
                phaseNumber = target.number
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            RehabSessionView(phase: phase, includeOptional: includeOptional)
        }
        .confirmationDialog("Réinitialiser le programme ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Réinitialiser", role: .destructive) {
                startTimestamp = 0
                phaseNumber = 1
                paused = false
                clearance = false
            }
        } message: {
            Text("L'historique des séances et des bilans est conservé.")
        }
    }

    // MARK: - Priorité médicale

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Priorité", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(RehabContent.priority).font(.footnote)
            Text(RehabContent.urgentSigns).font(.footnote.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Avant de commencer

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Renforcement du dos et du cou").font(.title2.weight(.bold))
            Text(RehabContent.introduction).font(.subheadline).foregroundStyle(.secondary)
            ForEach(RehabContent.organisation, id: \.label) { item in
                HStack(alignment: .top) {
                    Text(item.label).font(.subheadline.weight(.semibold)).frame(width: 80, alignment: .leading)
                    Text(item.value).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(RehabContent.startCondition).font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }

    private var screeningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let screening {
                let result = screening.result
                Label(result.title, systemImage: result.symbol)
                    .font(.headline)
                    .foregroundStyle(color(for: result))
                Text(result.message).font(.subheadline)
                if screening.treatment == .manipulation {
                    Text("Ton cou a été manipulé : en attendant, pas de nouvelle manipulation cervicale forcée.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Text("Point fait le \(Fmt.dayShort(screening.date))").font(.caption).foregroundStyle(.secondary)
                if result != .urgent {
                    Toggle(isOn: $clearance) {
                        Text(result == .ready
                             ? "Un professionnel de santé a confirmé que des exercices doux sont appropriés."
                             : "J'ai été examiné et un médecin ou kinésithérapeute a validé la reprise d'exercices doux.")
                            .font(.subheadline)
                    }
                    Button {
                        startTimestamp = Date().timeIntervalSince1970
                        phaseNumber = 1
                        paused = false
                    } label: {
                        Label("Commencer la phase 1", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!clearance)
                }
                Button("Refaire le point") { showScreening = true }.font(.subheadline)
            } else {
                Label("Avant de commencer : 3 questions", systemImage: "list.clipboard")
                    .font(.headline)
                Text("Le programme s'adapte à ton état actuel plutôt que de te faire suivre aveuglément huit semaines d'exercices. Réponds à quelques questions pour savoir si tu peux commencer par la première phase ou s'il faut d'abord privilégier un examen médical.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    showScreening = true
                } label: {
                    Text("Faire le point").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .card()
    }

    private func color(for result: ScreeningResult) -> Color {
        switch result {
        case .urgent: .red
        case .medical: .orange
        case .wait: .yellow
        case .ready: .green
        }
    }

    // MARK: - Programme en cours

    private var pausedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Programme en pause", systemImage: "pause.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(RehabContent.safetyRule).font(.footnote)
            HStack {
                Button("Refaire le point") { showScreening = true }
                Spacer()
                Button("Reprendre") { paused = false }.buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .card()
    }

    private var statusCard: some View {
        let finished = week > RehabProgram.totalWeeks
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(finished ? "PROGRAMME TERMINÉ · ENTRETIEN" : "SEMAINE \(week) SUR \(RehabProgram.totalWeeks)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Phase \(phase.number) — \(phase.title)").font(.title3.weight(.bold))
                    Text(phase.objective).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 4) {
                ForEach(1...RehabProgram.totalWeeks, id: \.self) { w in
                    Capsule()
                        .fill(w < week ? Color.orange : (w == week ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.2)))
                        .frame(height: 6)
                }
            }
            HStack {
                Label("\(sessionsThisWeek) séance\(sessionsThisWeek > 1 ? "s" : "") cette semaine",
                      systemImage: "calendar")
                Spacer()
                Text("Objectif : \(phase.minSessionsPerWeek) à \(phase.maxSessionsPerWeek)")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            if needsRestDay {
                Label("Laisse au moins un jour de repos entre deux séances.", systemImage: "bed.double")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if phase.number == 4 {
                Toggle("Inclure le tirage avec haltère (optionnel)", isOn: $includeOptional)
                    .font(.subheadline)
            }
            Button {
                showSession = true
            } label: {
                Label("Commencer la séance", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(paused)
        }
        .card()
    }

    private var advanceCard: some View {
        let next = RehabContent.phase(phaseNumber + 1)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Prêt pour la phase \(next.number) ?", systemImage: "arrow.up.forward.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text(next.entryCondition).font(.subheadline)
            Button("Vérifier et passer à la phase \(next.number)") { advanceTarget = next }
                .buttonStyle(.bordered)
        }
        .card()
    }

    // MARK: - Bilans

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comment tu progresses").font(.headline)
                Spacer()
                Button(checkInDue ? "Faire le bilan" : "Nouveau bilan") { showCheckIn = true }
                    .buttonStyle(.bordered)
                    .tint(checkInDue ? .orange : .accentColor)
                    .font(.subheadline)
            }
            if checkInDue {
                Label("Bilan de la semaine à faire", systemImage: "bell.badge")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if checkIns.count >= 2 {
                let trend = RehabProgram.trend(from: checkIns[1], to: checkIns[0])
                Text(trend.worse > trend.better
                     ? "Moins bien que la semaine dernière sur \(trend.worse) indicateur\(trend.worse > 1 ? "s" : ""). Si ça persiste, réévalue le programme."
                     : "Mieux que la semaine dernière sur \(trend.better) indicateur\(trend.better > 1 ? "s" : "").")
                    .font(.subheadline)
                    .foregroundStyle(trend.worse > trend.better ? .orange : .green)
            }
            if !checkIns.isEmpty {
                let ordered = checkIns.reversed()
                Chart {
                    ForEach(Array(ordered)) { item in
                        LineMark(x: .value("Date", item.date), y: .value("Valeur", item.wakePain))
                            .foregroundStyle(by: .value("Indicateur", "Douleur au réveil (0–10)"))
                        PointMark(x: .value("Date", item.date), y: .value("Valeur", item.wakePain))
                            .foregroundStyle(by: .value("Indicateur", "Douleur au réveil (0–10)"))
                        LineMark(x: .value("Date", item.date), y: .value("Valeur", item.rotation * 2))
                            .foregroundStyle(by: .value("Indicateur", "Rotation de la tête"))
                        PointMark(x: .value("Date", item.date), y: .value("Valeur", item.rotation * 2))
                            .foregroundStyle(by: .value("Indicateur", "Rotation de la tête"))
                    }
                }
                .chartForegroundStyleScale(["Douleur au réveil (0–10)": Color.red, "Rotation de la tête": Color.green])
                .chartYScale(domain: 0...10)
                .chartLegend(position: .bottom)
                .frame(height: 160)
            } else {
                Text("Chaque semaine, note la rotation de ta tête, la douleur au réveil et vers l'omoplate, le travail sur écran et tes exercices.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: - Phases

    private var phasesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Les 4 phases").font(.headline)
            ForEach(RehabContent.phases) { item in
                NavigationLink(value: item) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(statusColor(item).opacity(0.18))
                            if started && item.number < phaseNumber {
                                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(statusColor(item))
                            } else {
                                Text("\(item.number)").font(.subheadline.weight(.bold)).foregroundStyle(statusColor(item))
                            }
                        }
                        .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("\(item.weeksLabel) · \(item.objective)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if started && item.number == phaseNumber {
                            Text("En cours").font(.caption2.weight(.bold)).foregroundStyle(.orange)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func statusColor(_ item: RehabPhase) -> Color {
        guard started else { return .secondary }
        if item.number < phaseNumber { return .green }
        if item.number == phaseNumber { return .orange }
        return .secondary
    }

    // MARK: - Habitudes

    private var habitsCard: some View {
        let missing = RehabContent.suggestedHabits.filter { preset in !habits.contains { $0.name == preset.name } }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Les habitudes qui comptent vraiment").font(.headline)
            Text("Le renforcement est utile, mais il ne suffit pas à lui seul à prévenir les récidives.")
                .font(.footnote).foregroundStyle(.secondary)
            tipList("Au travail", RehabContent.workTips)
            tipList("Au quotidien", RehabContent.dailyTips)
            Button {
                addHabits(missing)
            } label: {
                Label(missing.isEmpty ? "Habitudes ajoutées dans Quotidien" : "Ajouter ces habitudes dans Quotidien",
                      systemImage: missing.isEmpty ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(missing.isEmpty)
        }
        .card()
    }

    private func tipList(_ title: String, _ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            ForEach(tips, id: \.self) { tip in
                Label(tip, systemImage: "checkmark.circle").font(.footnote)
            }
        }
    }

    private func addHabits(_ presets: [HabitPreset]) {
        var order = (habits.map(\.sortOrder).max() ?? -1) + 1
        for preset in presets {
            let habit = Habit(name: preset.name, emoji: preset.emoji)
            habit.habitColor = preset.color
            habit.kind = preset.kind
            habit.target = preset.target
            habit.unit = preset.unit
            habit.schedule = preset.schedule
            habit.sortOrder = order
            order += 1
            context.insert(habit)
        }
        try? context.save()
    }

    private var neckCautionCard: some View {
        Toggle(isOn: $neckCaution) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Précaution cervicale dans les étirements").font(.subheadline.weight(.semibold))
                Text("Retire les mouvements du cou et les postures inversées des routines d'étirements.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: - Historique

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Séances").font(.headline)
            if sessions.isEmpty {
                Text("Aucune séance pour l'instant.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(sessions.prefix(8)) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.dayShort(session.date).capitalized).font(.subheadline.weight(.semibold))
                        Text("Phase \(session.phase) · \(Int((session.completion * 100).rounded())) % · \(Fmt.duration(session.duration))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if session.stoppedForPain {
                        Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
                            .accessibilityLabel("Arrêtée pour douleur")
                    }
                    Text("\(session.painBefore) → \(session.painAfter)")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .accessibilityLabel("Douleur \(session.painBefore) avant, \(session.painAfter) après")
                }
                .contextMenu {
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        context.delete(session)
                        try? context.save()
                    }
                }
            }
        }
        .card()
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Règle de sécurité", systemImage: "shield.lefthalf.filled")
                .font(.subheadline.weight(.semibold))
            Text(RehabContent.safetyRule).font(.footnote).foregroundStyle(.secondary)
            Text("Ce programme ne remplace pas l'avis d'un médecin ou d'un kinésithérapeute.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }
}

/// Confirmation des conditions avant de passer à la phase suivante.
struct RehabAdvanceSheet: View {
    let phase: RehabPhase
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var checked: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(phase.entryCondition)
                } header: {
                    Text("Phase \(phase.number) — \(phase.title)")
                }
                Section("Je confirme que") {
                    ForEach(phase.entryChecks, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { checked.contains(item) },
                            set: { if $0 { checked.insert(item) } else { checked.remove(item) } }))
                    }
                }
                Section {
                    Text("Sinon, reste sur la phase actuelle une semaine de plus : la progression se fait selon ta tolérance, pas selon le calendrier.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Phase suivante")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Passer à la phase \(phase.number)") {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(checked.count < phase.entryChecks.count)
                }
            }
        }
    }
}
