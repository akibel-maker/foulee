import SwiftUI
import MapKit
import SwiftData
import Charts

@MainActor
struct RoutesView: View {
    @Environment(AppState.self) private var appState
    @Environment(RunTracker.self) private var tracker
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]

    @State private var suggester = RouteSuggester()
    @AppStorage("routeTargetKm") private var targetKm = 5.0
    @State private var difficulty: Difficulty = .modere
    @State private var selectedID: SuggestedRoute.ID?
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    private var selected: SuggestedRoute? {
        suggester.suggestions.first { $0.id == selectedID }
    }

    /// Allure habituelle (moyenne des 10 dernières courses), 6'00"/km par défaut.
    private var usualPace: Double {
        let recent = runs.prefix(10).filter { $0.distance > 1000 }
        guard !recent.isEmpty else { return 360 }
        return recent.map(\.averagePace).reduce(0, +) / Double(recent.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                controls
            }
            .navigationTitle("Itinéraires")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { tracker.startPreview() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(suggester.suggestions.filter { $0.id != selectedID }) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(.gray.opacity(0.5), lineWidth: 3)
            }
            if let selected {
                MapPolyline(coordinates: selected.coordinates)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Distance").font(.headline)
                Spacer()
                Text("\(targetKm.formatted(.number.precision(.fractionLength(1)))) km")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Slider(value: $targetKm, in: 1...30, step: 0.5)

            Picker("Difficulté", selection: $difficulty) {
                ForEach(Difficulty.allCases) { d in
                    Label(d.label, systemImage: d.systemImage).tag(d)
                }
            }
            .pickerStyle(.segmented)

            Button {
                generate()
            } label: {
                HStack {
                    if suggester.isLoading { ProgressView().tint(.white) }
                    Text(suggester.isLoading ? "Calcul des parcours…" : "Proposer des itinéraires")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(suggester.isLoading || tracker.currentLocation == nil)

            if tracker.currentLocation == nil {
                Text("En attente de ta position…").font(.footnote).foregroundStyle(.secondary)
            }
            if let message = suggester.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.red)
            }

            if !suggester.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(suggester.suggestions.enumerated()), id: \.element.id) { index, route in
                            RouteCard(route: route, pace: usualPace, isRecommended: index == 0,
                                      isSelected: route.id == selectedID)
                                .onTapGesture { select(route) }
                        }
                    }
                }
                if let selected {
                    Button {
                        appState.plannedRoute = selected
                        appState.selectedTab = .run
                        dismiss()
                    } label: {
                        Label("Courir cet itinéraire", systemImage: "figure.run")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(tracker.isActive)
                }
            }
        }
        .padding()
        .background(.background)
    }

    private func generate() {
        guard let start = tracker.currentLocation?.coordinate else { return }
        selectedID = nil
        Task {
            await suggester.suggest(from: start, targetKm: targetKm, difficulty: difficulty)
            if let first = suggester.suggestions.first { select(first) }
        }
    }

    private func select(_ route: SuggestedRoute) {
        selectedID = route.id
        if let rect = Geo.mapRect(for: route.coordinates) {
            withAnimation { camera = .rect(rect) }
        }
    }
}

private struct RouteCard: View {
    let route: SuggestedRoute
    let pace: Double
    let isRecommended: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if isRecommended {
                    Text("Recommandé")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
                if let difficulty = route.difficulty {
                    Label(difficulty.label, systemImage: difficulty.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(Fmt.km(route.distance, decimals: 1)) km")
                .font(.title3.weight(.bold))
            HStack(spacing: 10) {
                Label(route.elevationGain.map { Fmt.meters($0) } ?? "–", systemImage: "arrow.up.right")
                Label("~\(Fmt.duration(route.estimatedDuration(pace: pace)))", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if route.elevationProfile.count > 1 {
                Chart(Array(route.elevationProfile.enumerated()), id: \.offset) { item in
                    AreaMark(x: .value("Point", item.offset), y: .value("Altitude", item.element))
                        .foregroundStyle(.orange.opacity(0.3))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 30)
            }
            Text("Départ \(route.direction)").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 190, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.orange : .clear, lineWidth: 2))
    }
}
