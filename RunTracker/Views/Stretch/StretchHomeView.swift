import SwiftUI
import SwiftData

struct StretchHomeView: View {
    @Query(sort: \StretchSession.date) private var sessions: [StretchSession]
    @Query(sort: \CustomStretchRoutine.createdAt) private var customRoutines: [CustomStretchRoutine]
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @AppStorage("stretchFavorites") private var favoritesRaw = ""
    @State private var search = ""
    @State private var showStats = false
    @State private var showComposer = false
    @State private var showNewRoutine = false

    private var stats: StretchStats { StretchStatsCalculator.stats(for: sessions) }

    private var ranRecently: Bool {
        guard let last = runs.first else { return false }
        return Date().timeIntervalSince(last.endDate) < 3 * 3600
    }

    private var allRoutines: [StretchRoutine] { customRoutines.map(\.asRoutine) + StretchLibrary.routines }

    private var favorites: [StretchRoutine] {
        let ids = StretchFavorites.ids(favoritesRaw)
        return ids.compactMap { id in allRoutines.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if search.isEmpty {
                        featured
                        composerBanner
                        zones
                        if !favorites.isEmpty { routineCarousel("Favoris", routines: favorites) }
                        myRoutines
                        ForEach(StretchMoment.allCases) { moment in
                            let routines = StretchLibrary.routines.filter { $0.moments.contains(moment) }
                            if !routines.isEmpty {
                                routineCarousel(moment.label, symbol: moment.symbol, routines: routines)
                            }
                        }
                        cautionCard
                    } else {
                        searchResults
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Étirements")
            .searchable(text: $search, prompt: "Rechercher une routine ou un mouvement")
            .navigationDestination(for: StretchRoutine.self) { RoutineDetailView(routine: $0) }
            .navigationDestination(for: StretchZone.self) { ZoneRoutinesView(zone: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Composer une routine", systemImage: "sparkles") { showComposer = true }
                        Button("Créer ma routine", systemImage: "plus.square.on.square") { showNewRoutine = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showStats) { StretchStatsView() }
            .sheet(isPresented: $showComposer) { RoutineComposerView() }
            .sheet(isPresented: $showNewRoutine) { CustomRoutineEditorView(routine: nil) }
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR"))).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(Date().formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "fr_FR"))).capitalized)
                    .font(.largeTitle.weight(.bold))
            }
            Spacer()
            Button {
                showStats = true
            } label: {
                Label("\(stats.currentStreak)", systemImage: "flame.fill")
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.background.secondary, in: Capsule())
                    .foregroundStyle(stats.currentStreak > 0 ? .orange : .secondary)
            }
            .accessibilityLabel("Série de \(stats.currentStreak) jours, voir les statistiques")
        }
        .padding(.horizontal)
    }

    // MARK: - Suggestions

    private var featured: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(ranRecently ? "Après ta course" : "Pour toi maintenant")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(StretchLibrary.suggestions(ranRecently: ranRecently)) { routine in
                        NavigationLink(value: routine) {
                            RoutineCard(routine: routine, width: 280)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var composerBanner: some View {
        Button {
            showComposer = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compose ta routine").font(.headline)
                    Text("Choisis les zones et la durée, Foulée s'occupe du reste.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Zones

    private var zones: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Par zone")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(96), spacing: 10), GridItem(.fixed(96), spacing: 10)], spacing: 10) {
                    ForEach(StretchZone.allCases) { zone in
                        NavigationLink(value: zone) {
                            VStack(spacing: 8) {
                                StretchArtwork(symbol: zone.symbol, tint: zone.tint, size: 44)
                                Text(zone.label)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 118, height: 96)
                            .background(RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Mes routines

    private var myRoutines: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Mes routines")
                Spacer()
                Button("Créer", systemImage: "plus") { showNewRoutine = true }
                    .font(.subheadline.weight(.semibold))
                    .padding(.trailing)
            }
            if customRoutines.isEmpty {
                Text("Assemble tes mouvements préférés dans une routine à toi.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(customRoutines) { custom in
                            NavigationLink(value: custom.asRoutine) { RoutineCard(routine: custom.asRoutine) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func routineCarousel(_ title: String, symbol: String? = nil, routines: [StretchRoutine]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).foregroundStyle(.secondary) }
                sectionTitle(title, padded: symbol == nil)
            }
            .padding(.leading, symbol == nil ? 0 : 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(routines) { routine in
                        NavigationLink(value: routine) { RoutineCard(routine: routine) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recherche

    private var searchResults: some View {
        let query = search.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        func matches(_ text: String) -> Bool {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(query)
        }
        let routines = allRoutines.filter { matches($0.name) || matches($0.originalName ?? "") || matches($0.summary) }
        let moves = StretchLibrary.moves.filter { matches($0.name) || matches($0.englishName) }
        return VStack(alignment: .leading, spacing: 12) {
            if !routines.isEmpty {
                sectionTitle("Routines")
                ForEach(routines) { routine in
                    NavigationLink(value: routine) { RoutineRow(routine: routine) }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                }
            }
            if !moves.isEmpty {
                sectionTitle("Mouvements")
                ForEach(moves) { move in
                    MoveInfoRow(move: move)
                        .padding(.horizontal)
                }
            }
            if routines.isEmpty && moves.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    private var cautionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Précaution", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(StretchLibrary.neckCautionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
        .padding(.horizontal)
    }

    private func sectionTitle(_ text: String, padded: Bool = true) -> some View {
        Text(text.uppercased())
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, padded ? 16 : 0)
    }
}

/// Ligne d'information sur un mouvement (recherche, zones, éditeur).
struct MoveInfoRow: View {
    let move: StretchMove
    var seconds: Int? = nil
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    StretchArtwork(symbol: move.symbol, tint: move.zones.first?.tint ?? .orange, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(move.name).font(.subheadline.weight(.semibold))
                        HStack(spacing: 6) {
                            Text(move.englishName)
                            if move.bilateral { Text("· 2 côtés") }
                            if move.advanced { Text("· avancé").foregroundStyle(.red) }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let seconds {
                        Text("\(seconds) s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                Text(move.instruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 54)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
