import SwiftUI
import SwiftData

struct StretchPlayerView: View {
    @Bindable var player: StretchPlayer
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StretchSession.date) private var sessions: [StretchSession]
    @AppStorage("saveToHealth") private var saveToHealth = true
    @State private var saved = false
    @State private var confirmQuit = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if player.phase == .finished {
                summary
            } else {
                session
            }
        }
        .onAppear { player.start() }
        .onDisappear { player.stop() }
        .onChange(of: player.phase) { _, phase in
            if phase == .finished { save() }
        }
        .confirmationDialog("Arrêter la routine ?", isPresented: $confirmQuit, titleVisibility: .visible) {
            if player.activeSeconds >= 30 {
                Button("Arrêter et enregistrer") {
                    save()
                    close()
                }
            }
            Button("Quitter sans enregistrer", role: .destructive) { close() }
            Button("Continuer", role: .cancel) {}
        }
    }

    // MARK: - Séance

    private var session: some View {
        let item = player.current
        let tint = item?.move.zones.first?.tint ?? player.routine.tint
        let fraction = player.currentDuration > 0 ? player.remaining / player.currentDuration : 0
        return VStack(spacing: 18) {
            HStack {
                Button {
                    if player.activeSeconds > 2 { confirmQuit = true } else { close() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(.background.secondary, in: Circle())
                }
                .accessibilityLabel("Fermer")
                Spacer()
                Text(player.routine.name).font(.headline)
                Spacer()
                Text(player.phase == .prepare ? "" : "\(player.index + 1)/\(player.items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
            ProgressView(value: player.overallProgress)
                .tint(tint.color)

            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(tint.color.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: fraction)
                VStack(spacing: 10) {
                    if let item {
                        StretchArtwork(symbol: item.move.symbol, tint: tint, size: 110)
                            .opacity(player.phase == .prepare ? 0.6 : 1)
                    }
                    Text("\(Int(player.remaining.rounded(.up)))")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .frame(width: 270, height: 270)

            VStack(spacing: 6) {
                if player.phase == .prepare {
                    Text("Prépare-toi").font(.title2.weight(.bold))
                    if let item { Text("Premier mouvement : \(item.move.name)").foregroundStyle(.secondary) }
                } else if let item {
                    Text(item.move.name).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                    Text(item.move.englishName).font(.subheadline).foregroundStyle(.secondary)
                    if item.move.bilateral {
                        Text(player.onSecondSide ? "Côté 2 sur 2" : "Côté 1 sur 2")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(tint.color.opacity(0.18), in: Capsule())
                            .foregroundStyle(tint.color)
                    }
                    Text(item.move.instruction)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            if let next = player.phase == .prepare ? nil : player.next {
                HStack(spacing: 10) {
                    Text("Ensuite").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    StretchArtwork(symbol: next.move.symbol, tint: next.move.zones.first?.tint ?? tint, size: 26)
                    Text(next.move.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(next.seconds) s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 40) {
                control("backward.fill", label: "Mouvement précédent") { player.previous() }
                    .disabled(player.phase != .active)
                Button {
                    player.togglePause()
                } label: {
                    Image(systemName: player.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(width: 76, height: 76)
                        .background(tint.color, in: Circle())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(player.isPaused ? "Reprendre" : "Pause")
                control("forward.fill", label: "Mouvement suivant") { player.skip() }
            }
            .padding(.bottom, 8)
        }
        .padding()
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(.background.secondary, in: Circle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - Résumé

    private var summary: some View {
        let stats = StretchStatsCalculator.stats(for: sessions)
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(player.routine.tint.color)
            Text("Bravo !").font(.largeTitle.weight(.bold))
            Text(player.routine.name).font(.title3).foregroundStyle(.secondary)
            HStack(spacing: 30) {
                summaryValue(Fmt.duration(player.activeSeconds), "durée")
                summaryValue("\(player.items.count)", "mouvements")
                summaryValue("\(stats.currentStreak) 🔥", "jours d'affilée")
            }
            .padding(.top, 10)
            Spacer()
            Button {
                close()
            } label: {
                Text("Terminé").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(player.routine.tint.color)
        }
        .padding()
    }

    private func summaryValue(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.bold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Enregistrement

    private func save() {
        guard !saved, player.activeSeconds >= 30 else { return }
        saved = true
        let completed = player.phase == .finished ? player.items.count : player.index
        context.insert(StretchSession(date: player.startedAt, routineID: player.routine.id,
                                      routineName: player.routine.name, duration: player.activeSeconds,
                                      moveCount: completed))
        try? context.save()
        if saveToHealth {
            let start = player.startedAt
            Task { try? await HealthKitManager.shared.saveFlexibilityWorkout(start: start, end: Date()) }
        }
    }

    private func close() {
        player.stop()
        dismiss()
    }
}
