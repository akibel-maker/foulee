import SwiftUI
import SwiftData
import HealthKit

struct RehabSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rehabPaused") private var paused = false
    @AppStorage("saveToHealth") private var saveToHealth = true
    @AppStorage("stretchVoice") private var voice = true
    @AppStorage("rehabRestSeconds") private var restSeconds = 45
    @State private var model: RehabSessionModel?
    @State private var showPainOptions = false
    @State private var confirmQuit = false

    let phase: RehabPhase
    let includeOptional: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    switch model.stage {
                    case .painCheck: painCheck(model)
                    case .exercise: exercise(model)
                    case .rest: rest(model)
                    case .finish: finish(model)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Phase \(phase.number) — \(phase.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model?.stage != .finish {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Quitter") {
                            if (model?.doneSets ?? 0) > 0 { confirmQuit = true } else { close() }
                        }
                    }
                }
            }
            .confirmationDialog("Quitter la séance ?", isPresented: $confirmQuit, titleVisibility: .visible) {
                Button("Terminer et enregistrer") { model?.finish() }
                Button("Quitter sans enregistrer", role: .destructive) { close() }
                Button("Continuer", role: .cancel) {}
            }
        }
        .onAppear {
            if model == nil {
                model = RehabSessionModel(phase: phase, includeOptional: includeOptional,
                                          restSeconds: restSeconds, voice: voice)
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            model?.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Douleur avant

    private func painCheck(_ model: RehabSessionModel) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Douleur actuelle : \(Int(model.painBefore))/10").font(.headline)
                    Slider(value: Binding(get: { model.painBefore }, set: { model.painBefore = $0 }), in: 0...10, step: 1)
                }
            } header: {
                Text("Avant de commencer")
            } footer: {
                Text("0 = aucune douleur, 10 = douleur maximale.")
            }
            if model.painBefore >= 6 {
                Section {
                    Label("Douleur forte aujourd'hui : ne fais pas la séance. Si la douleur reste forte, s'aggrave ou te réveille la nuit, fais-toi examiner rapidement par un médecin.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Ne pas faire la séance") { close() }
                }
            } else {
                Section("Rappels") {
                    Label("Lentement, sans élan, dans une amplitude confortable.", systemImage: "tortoise")
                    Label("Le cou reste dans une position confortable.", systemImage: "person.bust")
                    Label("Douleur vive ou qui descend vers l'omoplate : arrête l'exercice.", systemImage: "hand.raised")
                }
                .font(.subheadline)
                Section {
                    Button {
                        model.begin()
                    } label: {
                        Label("Commencer", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    // MARK: - Exercice

    private func exercise(_ model: RehabSessionModel) -> some View {
        let item = model.current
        let exercise = item?.exercise
        return VStack(spacing: 0) {
            ProgressView(value: model.progress).tint(.teal).padding(.horizontal)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let item, let exercise {
                        Text("EXERCICE \(model.index + 1) SUR \(model.items.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            StretchArtwork(symbol: exercise.symbol, tint: .teal, size: 70)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name).font(.title2.weight(.bold))
                                Text("\(item.sets) × \(item.reps)\(item.note.map { " · \($0)" } ?? "")")
                                    .font(.headline)
                                    .foregroundStyle(.teal)
                                Label(exercise.equipment.label, systemImage: exercise.equipment.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            ForEach(0..<item.sets, id: \.self) { set in
                                let done = set < model.setsDone[model.index]
                                Text("Série \(set + 1)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(done ? Color.teal : Color.secondary.opacity(0.15), in: Capsule())
                                    .foregroundStyle(done ? .white : .primary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { step in
                                Text("\(step.offset + 1). \(step.element)").font(.callout)
                            }
                            if let warning = exercise.warning {
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .card()

                        if exercise.holdSeconds != nil {
                            guideCard(model, item: item)
                        }
                    }
                }
                .padding()
            }
            VStack(spacing: 10) {
                Button {
                    model.completeSet()
                } label: {
                    Text("Série terminée").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(model.guideActive)
                HStack {
                    Button("Passer l'exercice") { model.skipExercise() }
                    Spacer()
                    Button(role: .destructive) {
                        showPainOptions = true
                    } label: {
                        Label("Stop — douleur", systemImage: "exclamationmark.octagon.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .font(.subheadline)
            }
            .padding()
            .background(.bar)
        }
        .confirmationDialog("Douleur vive ou qui descend vers l'omoplate ?", isPresented: $showPainOptions,
                            titleVisibility: .visible) {
            Button("Arrêter cet exercice et passer au suivant") { model.stopForPain(endSession: false) }
            Button("Arrêter la séance", role: .destructive) { model.stopForPain(endSession: true) }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Une légère fatigue musculaire est acceptable, une douleur vive non : arrête l'exercice.")
        }
    }

    private func guideCard(_ model: RehabSessionModel, item: RehabPrescription) -> some View {
        VStack(spacing: 10) {
            if model.guideActive {
                Text(model.guideHolding ? "Maintiens" : "Relâche")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(model.guideHolding ? .teal : .secondary)
                Text("\(model.guideRemaining)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("Répétition \(model.guideRep) sur \(item.targetReps)").font(.subheadline)
                Button("Arrêter le guidage") { model.stopGuide() }.font(.subheadline)
            } else {
                Text("Laisse l'app compter le maintien et les répétitions de cette série.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    model.startGuide()
                } label: {
                    Label("Guider la série", systemImage: "metronome")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: - Repos

    private func rest(_ model: RehabSessionModel) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Repos").font(.largeTitle.weight(.bold))
            Text("\(max(0, model.restRemaining))")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
            if let item = model.current {
                let done = model.setsDone[model.index]
                Text(done >= item.sets
                     ? "Ensuite : \(model.items.indices.contains(model.index + 1) ? (model.items[model.index + 1].exercise?.name ?? "") : "fin")"
                     : "Ensuite : série \(done + 1) sur \(item.sets)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Passer le repos") { model.skipRest() }
                .buttonStyle(.bordered)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fin

    private func finish(_ model: RehabSessionModel) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(model.stoppedForPain ? "Séance interrompue" : "Séance terminée",
                          systemImage: model.stoppedForPain ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(model.stoppedForPain ? .red : .green)
                    Text("\(model.doneSets) séries sur \(model.totalSets) · \(Fmt.duration(Date().timeIntervalSince(model.startedAt)))")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Douleur après la séance : \(Int(model.painAfter))/10") {
                Slider(value: Binding(get: { model.painAfter }, set: { model.painAfter = $0 }), in: 0...10, step: 1)
            }
            if model.stoppedForPain || model.painAfter > model.painBefore + 1 {
                Section {
                    Text(RehabContent.safetyRule).font(.footnote)
                    Text(RehabContent.urgentSigns).font(.footnote.weight(.semibold))
                }
            }
            Section("Notes") {
                TextField("Exercice difficile, sensations…", text: Binding(get: { model.notes }, set: { model.notes = $0 }),
                          axis: .vertical)
                    .lineLimit(2...5)
            }
            Section {
                Button {
                    save(model)
                } label: {
                    Text("Enregistrer la séance").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func save(_ model: RehabSessionModel) {
        let session = RehabSession(date: model.startedAt, phase: phase.number)
        session.duration = Date().timeIntervalSince(model.startedAt)
        session.painBefore = Int(model.painBefore)
        session.painAfter = Int(model.painAfter)
        session.stoppedForPain = model.stoppedForPain
        session.notes = model.notes
        session.logs = model.items.enumerated().map { index, item in
            RehabExerciseLog(exerciseID: item.exerciseID, setsPlanned: item.sets, setsDone: model.setsDone[index],
                             stoppedForPain: model.painStops.contains(index))
        }
        context.insert(session)
        try? context.save()
        if model.stoppedForPain { paused = true }
        if saveToHealth {
            let start = model.startedAt
            Task { try? await HealthKitManager.shared.saveSimpleWorkout(.functionalStrengthTraining, start: start, end: Date()) }
        }
        close()
    }

    private func close() {
        model?.stop()
        dismiss()
    }
}
