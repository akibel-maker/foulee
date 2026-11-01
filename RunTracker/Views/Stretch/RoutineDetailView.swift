import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    let routine: StretchRoutine
    @Query(sort: \CustomStretchRoutine.createdAt) private var customRoutines: [CustomStretchRoutine]
    @AppStorage("stretchFavorites") private var favoritesRaw = ""
    @AppStorage("stretchPace") private var pace = 1.0
    @AppStorage("stretchIncludeAdvanced") private var includeAdvanced = false
    @AppStorage("stretchNeckCaution") private var neckCaution = false
    @AppStorage("stretchVoice") private var voice = true
    @State private var player: StretchPlayer?
    @State private var showEditor = false
    @State private var showSaveAsCustom = false

    private var custom: CustomStretchRoutine? {
        customRoutines.first { "custom-\($0.id.uuidString)" == routine.id }
    }

    /// La routine à jour (une routine perso a pu être modifiée).
    private var current: StretchRoutine { custom?.asRoutine ?? routine }

    private var playable: [(move: StretchMove, seconds: Int)] {
        current.playableSteps(includeAdvanced: includeAdvanced, neckCaution: neckCaution, pace: pace)
    }

    private var isFavorite: Bool { StretchFavorites.ids(favoritesRaw).contains(routine.id) }
    private var isComposed: Bool { routine.id.hasPrefix("composed-") }

    var body: some View {
        let steps = playable
        let total = steps.reduce(0) { $0 + $1.seconds }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 10) {
                    StretchArtwork(symbol: current.symbol, tint: current.tint, size: 96)
                    Text(current.name).font(.title.weight(.bold)).multilineTextAlignment(.center)
                    if let original = current.originalName, original != current.name {
                        Text(original).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(current.summary).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    HStack(spacing: 18) {
                        Label(Fmt.duration(TimeInterval(total)), systemImage: "clock")
                        Label("\(steps.count) mouvements", systemImage: "list.bullet")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                if let caution = current.caution {
                    Label(caution, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .card()
                }
                if neckCaution && current.moves.contains(where: \.neck) {
                    Label("Précaution cervicale activée : les mouvements du cou sont retirés.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .card()
                }

                options

                VStack(alignment: .leading, spacing: 4) {
                    Text("MOUVEMENTS").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(Array(steps.enumerated()), id: \.offset) { item in
                        MoveInfoRow(move: item.element.move, seconds: item.element.seconds)
                        if item.offset < steps.count - 1 { Divider() }
                    }
                }
                .card()
            }
            .padding()
            .padding(.bottom, 80)
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                player = StretchPlayer(routine: current, steps: steps, voice: voice)
            } label: {
                Label("Commencer", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(current.tint.color)
            .disabled(steps.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if custom != nil {
                    Button("Modifier") { showEditor = true }
                } else if isComposed {
                    Button("Enregistrer", systemImage: "square.and.arrow.down") { showSaveAsCustom = true }
                }
                if !isComposed {
                    Button(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                           systemImage: isFavorite ? "bookmark.fill" : "bookmark") {
                        favoritesRaw = StretchFavorites.toggled(routine.id, in: favoritesRaw)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) { CustomRoutineEditorView(routine: custom) }
        .sheet(isPresented: $showSaveAsCustom) {
            CustomRoutineEditorView(routine: nil, initialName: current.name,
                                    initialSteps: current.steps.map { StretchStep(moveID: $0.moveID, seconds: $0.seconds) })
        }
        .fullScreenCover(isPresented: Binding(get: { player != nil }, set: { if !$0 { player = nil } })) {
            if let player { StretchPlayerView(player: player) }
        }
    }

    private var options: some View {
        VStack(spacing: 12) {
            Picker("Durée", selection: $pace) {
                Text("Courte").tag(0.7)
                Text("Normale").tag(1.0)
                Text("Longue").tag(1.5)
            }
            .pickerStyle(.segmented)
            Toggle("Guide vocal", systemImage: "speaker.wave.2", isOn: $voice)
            Toggle("Précaution cervicale", systemImage: "cross.case", isOn: $neckCaution)
            if current.hasAdvanced {
                Toggle("Inclure les postures avancées", systemImage: "exclamationmark.triangle", isOn: $includeAdvanced)
                    .disabled(neckCaution)
            }
        }
        .font(.subheadline)
        .card()
    }
}

/// Routines et mouvements d'une zone du corps.
struct ZoneRoutinesView: View {
    let zone: StretchZone
    @AppStorage("stretchNeckCaution") private var neckCaution = false
    @State private var express: StretchRoutine?

    private var routines: [StretchRoutine] {
        StretchLibrary.routines
            .map { routine in (routine, routine.moves.filter { $0.zones.contains(zone) }.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    StretchArtwork(symbol: zone.symbol, tint: zone.tint, size: 64)
                    Text(zone.label).font(.largeTitle.weight(.bold))
                }
                if let express {
                    NavigationLink(value: express) {
                        HStack {
                            Image(systemName: "bolt.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text("Express 5 minutes").font(.headline)
                                Text("Les meilleurs mouvements pour cette zone").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
                if !routines.isEmpty {
                    Text("ROUTINES").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(routines) { routine in
                        NavigationLink(value: routine) { RoutineRow(routine: routine) }.buttonStyle(.plain)
                    }
                }
                Text("MOUVEMENTS").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(StretchLibrary.moves.filter { $0.zones.contains(zone) }) { move in
                        MoveInfoRow(move: move)
                    }
                }
                .card()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if express == nil {
                express = StretchLibrary.compose(zones: [zone], minutes: 5, neckCaution: neckCaution, calm: false)
            }
        }
    }
}
