import SwiftUI
import MapKit
import SwiftData

@MainActor
struct RunView: View {
    @Environment(RunTracker.self) private var tracker
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @AppStorage("voiceCoach") private var voiceCoach = true
    @AppStorage("saveToHealth") private var saveToHealth = true
    @AppStorage("weightKg") private var weightKg = 70.0

    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var showStopConfirmation = false
    @State private var showTooShortAlert = false
    @State private var finishedRun: Run?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                panel
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appState.plannedRoute != nil, !tracker.isActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Retirer l'itinéraire", systemImage: "xmark.circle") {
                            appState.plannedRoute = nil
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) { gpsIndicator }
            }
            .onAppear { tracker.startPreview() }
            .confirmationDialog("Terminer la course ?", isPresented: $showStopConfirmation, titleVisibility: .visible) {
                Button("Terminer et enregistrer") { finish() }
                Button("Supprimer sans enregistrer", role: .destructive) { tracker.discard() }
                Button("Continuer", role: .cancel) {}
            }
            .alert("Course trop courte", isPresented: $showTooShortAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Moins de 50 m parcourus : la course n'a pas été enregistrée.")
            }
            .sheet(item: $finishedRun) { run in
                NavigationStack {
                    RunDetailView(run: run)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("OK") { finishedRun = nil }
                            }
                        }
                }
            }
        }
    }

    private var title: String {
        switch tracker.state {
        case .idle: "Courir"
        case .running: "En course"
        case .paused: "En pause"
        }
    }

    // MARK: - Carte

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let planned = appState.plannedRoute {
                MapPolyline(coordinates: planned.coordinates)
                    .stroke(.blue.opacity(0.55), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
            if tracker.points.count > 1 {
                MapPolyline(coordinates: tracker.points.map(\.coordinate))
                    .stroke(.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onChange(of: appState.plannedRoute) { _, route in
            if let route, let rect = Geo.mapRect(for: route.coordinates) {
                withAnimation { camera = .rect(rect) }
            }
        }
    }

    private var gpsIndicator: some View {
        let accuracy = tracker.gpsAccuracy
        let color: Color = switch accuracy {
        case .none: .gray
        case .some(let a) where a <= 10: .green
        case .some(let a) where a <= 25: .yellow
        default: .red
        }
        return Label("GPS", systemImage: "location.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    // MARK: - Panneau

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: 16) {
            if !tracker.hasLocationPermission && tracker.authorization != .notDetermined {
                permissionWarning
            } else if tracker.isActive {
                liveStats
                controls
            } else {
                idlePanel
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var idlePanel: some View {
        VStack(spacing: 14) {
            if let planned = appState.plannedRoute {
                Label("Itinéraire de \(Fmt.km(planned.distance, decimals: 1)) km chargé", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.subheadline.weight(.medium))
            }
            Button {
                tracker.start(voiceCoach: voiceCoach)
            } label: {
                Text("Démarrer")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!tracker.hasLocationPermission)
            Toggle("Coach vocal", systemImage: "speaker.wave.2", isOn: $voiceCoach)
                .font(.subheadline)
            Label("Tu peux aussi lancer une course depuis l'app Foulée de ta Watch.", systemImage: "applewatch")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var liveStats: some View {
        VStack(spacing: 14) {
            StatTile(title: "Kilomètres", value: Fmt.km(tracker.distance), large: true)
            HStack {
                StatTile(title: "Durée", value: Fmt.duration(tracker.movingTime))
                StatTile(title: "Allure", value: Fmt.pace(tracker.currentPace), unit: "/km")
                StatTile(title: "Moyenne", value: Fmt.pace(tracker.averagePace), unit: "/km")
            }
            HStack {
                StatTile(title: "D+", value: "\(Int(tracker.elevationGain))", unit: "m")
                StatTile(title: "Cadence", value: tracker.cadence > 0 ? "\(Int(tracker.cadence))" : "--", unit: "pas/min")
                StatTile(title: "Dernier km", value: Fmt.pace(tracker.lastKmPace))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if tracker.state == .running {
                Button { tracker.pause() } label: {
                    Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            } else {
                Button { tracker.resume() } label: {
                    Label("Reprendre", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            Button(role: .destructive) { showStopConfirmation = true } label: {
                Label("Terminer", systemImage: "stop.fill").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .font(.headline)
        .buttonBorderShape(.capsule)
    }

    private var permissionWarning: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash").font(.largeTitle).foregroundStyle(.orange)
            Text("Accès à la position refusé").font(.headline)
            Text("Autorise la localisation « Lorsque l'app est active » et la position exacte pour enregistrer tes courses.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Fin de course

    private func finish() {
        guard let result = tracker.finish() else { return }
        guard result.distance >= 50 else {
            showTooShortAlert = true
            return
        }
        let run = Run(name: Run.defaultName(for: result.startDate),
                      startDate: result.startDate,
                      endDate: result.endDate,
                      duration: result.movingTime,
                      distance: result.distance)
        run.elevationGain = result.elevationGain
        run.steps = result.steps
        // Estimation classique : ~1 kcal par kg et par km.
        run.calories = weightKg * result.distance / 1000 * 1.036
        run.setPoints(result.points)
        run.updateDerivedMetrics(recomputeDistance: false)
        context.insert(run)
        try? context.save()
        appState.plannedRoute = nil
        finishedRun = run

        let locations = result.locations
        let shouldSave = saveToHealth
        Task {
            let health = HealthKitManager.shared
            guard health.isAvailable else { return }
            if let hr = await health.averageHeartRate(from: run.startDate, to: run.endDate) {
                run.averageHeartRate = hr
            }
            if shouldSave {
                run.healthKitID = try? await health.saveWorkout(run: run, locations: locations)
            }
            try? context.save()
        }
    }
}
