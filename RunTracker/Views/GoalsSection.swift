import SwiftUI
import SwiftData

/// Liste des objectifs avec leur avancement (en tête de l'onglet Progression).
struct GoalsSection: View {
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: \Run.startDate) private var runs: [Run]
    @Environment(SleepStore.self) private var sleep
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @State private var editingGoal: Goal?
    @State private var showNewGoal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Objectifs").font(.title2.weight(.bold))
                Spacer()
                Button {
                    showNewGoal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(.orange, in: Circle())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Nouvel objectif")
            }
            if goals.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(goals) { goal in
                        GoalCard(goal: goal,
                                 progress: GoalEvaluator.progress(for: goal, runs: runs, nights: sleep.nights,
                                                                  sleepGoalHours: sleepGoalHours),
                                 streak: GoalEvaluator.streak(for: goal, runs: runs, nights: sleep.nights,
                                                              sleepGoalHours: sleepGoalHours))
                            .onTapGesture { editingGoal = goal }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewGoal) { GoalEditorView(goal: nil) }
        .sheet(item: $editingGoal) { GoalEditorView(goal: $0) }
        .task(id: goals.contains(where: { $0.kind.isSleep })) {
            if goals.contains(where: { $0.kind.isSleep }) { await sleep.loadIfNeeded() }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fixe-toi un cap : kilomètres par semaine, nombre de sorties, sortie longue, heures de sommeil…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Créer mon premier objectif") { showNewGoal = true }
                .buttonStyle(.borderedProminent)
        }
        .card()
    }
}

struct GoalCard: View {
    let goal: Goal
    let progress: GoalProgress?
    let streak: Int

    var body: some View {
        let kind = goal.kind
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().stroke(kind.color.opacity(0.18), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: progress?.fraction ?? 0)
                        .stroke(kind.color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: progress?.isCompleted == true ? "checkmark" : kind.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(kind.color)
                }
                .frame(width: 52, height: 52)
                Spacer()
                if streak > 1 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("\(streak) \(goal.period.streakUnit) réussies d'affilée")
                }
            }
            Text(goal.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let progress {
                Text("\(kind.format(progress.current)) / \(kind.formatWithUnit(progress.target))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(statusText(progress))
                    .font(.caption2)
                    .foregroundStyle(progress.isCompleted ? .green : .secondary)
            } else {
                Text("Objectif terminé").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .card()
        .contentShape(Rectangle())
    }

    private func statusText(_ progress: GoalProgress) -> String {
        if progress.isCompleted { return "Atteint 🎉" }
        let days = progress.daysLeft
        let daysText = days <= 1 ? "Dernier jour" : "\(days) j restants"
        if goal.kind.isCumulative, days > 0 {
            let perDay = progress.remaining / Double(days)
            return "\(daysText) · ≈ \(goal.kind.formatWithUnit(perDay))/jour"
        }
        return daysText
    }
}

/// Création / modification d'un objectif.
struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let goal: Goal?
    @State private var kind: GoalKind
    @State private var period: GoalPeriod
    @State private var target: Double
    @State private var deadline: Date
    @State private var title: String
    @State private var confirmDelete = false

    init(goal: Goal?) {
        self.goal = goal
        _kind = State(initialValue: goal?.kind ?? .distance)
        _period = State(initialValue: goal?.period ?? .week)
        _target = State(initialValue: goal?.target ?? GoalKind.distance.defaultTarget)
        _deadline = State(initialValue: goal?.deadline
                          ?? Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now)
        _title = State(initialValue: goal?.title ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if goal == nil {
                    Section("Idées") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(GoalPreset.all) { preset in
                                    Button {
                                        kind = preset.kind
                                        period = preset.period
                                        target = preset.target
                                    } label: {
                                        Label(Goal.autoTitle(kind: preset.kind, period: preset.period,
                                                             target: preset.target, deadline: nil),
                                              systemImage: preset.kind.systemImage)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(preset.kind.color.opacity(0.15), in: Capsule())
                                            .foregroundStyle(preset.kind.color)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(GoalKind.allCases) { k in
                            Label(k.label, systemImage: k.systemImage).tag(k)
                        }
                    }
                    .onChange(of: kind) { _, newKind in
                        if goal == nil || goal?.kind != newKind { target = newKind.defaultTarget }
                    }
                } footer: {
                    Text(kind.explanation)
                }

                Section("Cible") {
                    Stepper(value: $target, in: kind.range, step: kind.step) {
                        Text(kind.formatWithUnit(target))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(kind.color)
                    }
                }

                Section("Période") {
                    Picker("Période", selection: $period) {
                        ForEach(GoalPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    if period == .custom {
                        DatePicker("Date limite", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                }

                Section("Nom (facultatif)") {
                    TextField(Goal.autoTitle(kind: kind, period: period, target: target,
                                             deadline: period == .custom ? deadline : nil),
                              text: $title)
                }

                if goal != nil {
                    Section {
                        Button("Supprimer l'objectif", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(goal == nil ? "Nouvel objectif" : "Modifier l'objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() } }
            }
            .confirmationDialog("Supprimer cet objectif ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let goal { context.delete(goal) }
                    try? context.save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let target = min(max(target, kind.range.lowerBound), kind.range.upperBound)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = period == .custom ? deadline : nil
        if let goal {
            goal.kind = kind
            goal.period = period
            goal.target = target
            goal.title = trimmed
            goal.deadline = deadline
        } else {
            context.insert(Goal(kind: kind, period: period, target: target, title: trimmed, deadline: deadline))
        }
        try? context.save()
        dismiss()
    }
}
