import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @State private var runToDelete: Run?

    private var months: [(month: Date, runs: [Run])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { run in
            calendar.dateInterval(of: .month, for: run.startDate)?.start ?? run.startDate
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if runs.isEmpty {
                    ContentUnavailableView("Aucune course",
                                           systemImage: "figure.run",
                                           description: Text("Lance ta première course depuis l'onglet Courir, ou importe tes courses depuis Santé (Progression › Réglages)."))
                } else {
                    List {
                        ForEach(months, id: \.month) { section in
                            Section {
                                ForEach(section.runs) { run in
                                    NavigationLink(value: run) { RunRow(run: run) }
                                        .swipeActions {
                                            Button("Supprimer", systemImage: "trash", role: .destructive) {
                                                runToDelete = run
                                            }
                                        }
                                }
                            } header: {
                                HStack {
                                    Text(Fmt.month(section.month))
                                    Spacer()
                                    Text("\(Fmt.km(section.runs.reduce(0) { $0 + $1.distance }, decimals: 1)) km")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Historique")
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .confirmationDialog("Supprimer cette course ?", isPresented: Binding(
                get: { runToDelete != nil }, set: { if !$0 { runToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let runToDelete {
                        context.delete(runToDelete)
                        try? context.save()
                    }
                    runToDelete = nil
                }
            } message: {
                Text("Elle sera retirée de l'historique de Foulée (pas de l'app Santé).")
            }
        }
    }
}

struct RunRow: View {
    let run: Run

    var body: some View {
        HStack(spacing: 14) {
            RouteShape(coordinates: Geo.downsample(run.points.map(\.coordinate), maxCount: 150))
                .stroke(.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 52, height: 52)
                .padding(4)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(run.name).font(.headline).lineLimit(1)
                    if run.source == "sante" {
                        Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink)
                    } else if run.source == "watch" {
                        Image(systemName: "applewatch").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(Fmt.date(run.startDate)).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Text("\(Fmt.km(run.distance)) km").fontWeight(.semibold)
                    Text(Fmt.duration(run.duration))
                    Text("\(Fmt.pace(run.averagePace))/km")
                }
                .font(.subheadline.monospacedDigit())
            }
        }
        .padding(.vertical, 2)
    }
}
