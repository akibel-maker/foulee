import SwiftUI
import MapKit
import Charts

struct RunDetailView: View {
    @Bindable var run: Run

    var body: some View {
        let points = run.points
        let coordinates = points.map(\.coordinate)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if coordinates.count > 1 { map(coordinates) }
                statsGrid
                if !run.splits.isEmpty { splits }
                if points.count > 10 { elevationChart(points) }
                if !run.bestEfforts.isEmpty { efforts }
                notes
            }
            .padding()
        }
        .navigationTitle(run.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Nom de la course", text: $run.name)
                .font(.title2.weight(.bold))
            Text(Fmt.date(run.startDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func map(_ coordinates: [CLLocationCoordinate2D]) -> some View {
        Map(initialPosition: Geo.mapRect(for: coordinates).map { .rect($0) } ?? .automatic) {
            MapPolyline(coordinates: coordinates)
                .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            if let first = coordinates.first {
                Annotation("Départ", coordinate: first) { dot(.green) }
            }
            if let last = coordinates.last {
                Annotation("Arrivée", coordinate: last) { dot(.red) }
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private var statsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 18) {
            StatTile(title: "Distance", value: Fmt.km(run.distance), unit: "km")
            StatTile(title: "Durée", value: Fmt.duration(run.duration))
            StatTile(title: "Allure moy.", value: Fmt.pace(run.averagePace), unit: "/km")
            StatTile(title: "Dénivelé", value: "\(Int(run.elevationGain))", unit: "m")
            StatTile(title: "FC moy.", value: run.averageHeartRate.map { "\(Int($0))" } ?? "--", unit: "bpm")
            StatTile(title: "Calories", value: run.calories.map { "\(Int($0))" } ?? "--", unit: "kcal")
            if let cadence = run.averageCadence {
                StatTile(title: "Cadence", value: "\(Int(cadence))", unit: "pas/min")
            }
        }
        .padding(.vertical, 8)
    }

    private var splits: some View {
        let splits = run.splits
        let fastest = splits.map(\.pace).filter { $0 > 0 }.min() ?? 1
        return VStack(alignment: .leading, spacing: 8) {
            Text("Temps intermédiaires").font(.headline)
            ForEach(splits) { split in
                HStack(spacing: 10) {
                    Text(split.distance < 999 ? "\(Fmt.km(split.distance, decimals: 1))" : "\(split.index)")
                        .frame(width: 34, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(Fmt.pace(split.pace))
                        .frame(width: 56, alignment: .leading)
                        .fontWeight(.semibold)
                    GeometryReader { geo in
                        Capsule()
                            .fill(split.pace == fastest ? Color.orange : Color.orange.opacity(0.45))
                            .frame(width: geo.size.width * CGFloat(fastest / max(split.pace, 1)))
                    }
                    .frame(height: 10)
                    Text("\(split.elevationGain >= 0 ? "+" : "")\(Int(split.elevationGain)) m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
                .font(.subheadline.monospacedDigit())
            }
        }
    }

    private func elevationChart(_ points: [RoutePoint]) -> some View {
        let track = RunMetrics.Track(points: points)
        let samples = Geo.downsample(Array(zip(track.distance, track.altitude)), maxCount: 200)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Altitude").font(.headline)
            Chart(samples.indices, id: \.self) { i in
                AreaMark(x: .value("Distance (km)", samples[i].0 / 1000),
                         y: .value("Altitude (m)", samples[i].1))
                    .foregroundStyle(.linearGradient(colors: [.orange.opacity(0.5), .orange.opacity(0.05)],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Distance (km)", samples[i].0 / 1000),
                         y: .value("Altitude (m)", samples[i].1))
                    .foregroundStyle(.orange)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 150)
        }
    }

    private var efforts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meilleurs efforts").font(.headline)
            ForEach(RunMetrics.effortDistances, id: \.distance) { item in
                if let time = run.bestEffort(for: item.distance) {
                    HStack {
                        Text(item.label)
                        Spacer()
                        Text(Fmt.duration(time)).fontWeight(.semibold)
                        Text("(\(Fmt.pace(time / (item.distance / 1000)))/km)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            TextField("Sensations, météo, chaussures…", text: $run.notes, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
        }
    }
}
