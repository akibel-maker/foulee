import SwiftUI

/// Compose une routine à la demande : zones, durée, ambiance.
struct RoutineComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("stretchNeckCaution") private var neckCaution = false
    @State private var zones: Set<StretchZone> = []
    @State private var minutes = 10
    @State private var calm = false
    @State private var composed: StretchRoutine?

    var body: some View {
        NavigationStack {
            Form {
                Section("Zones à travailler") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(StretchZone.allCases) { zone in
                            let selected = zones.contains(zone)
                            Button {
                                if selected { zones.remove(zone) } else { zones.insert(zone) }
                                composed = nil
                            } label: {
                                Label(zone.label, systemImage: zone.symbol)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(selected ? zone.tint.color : Color.secondary.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(selected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Durée et ambiance") {
                    Picker("Durée", selection: $minutes) {
                        ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Ambiance", selection: $calm) {
                        Text("Dynamique").tag(false)
                        Text("Calme").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Précaution cervicale", isOn: $neckCaution)
                }
                .onChange(of: minutes) { _, _ in composed = nil }
                .onChange(of: calm) { _, _ in composed = nil }

                Section {
                    Button {
                        composed = StretchLibrary.compose(zones: zones, minutes: minutes, neckCaution: neckCaution, calm: calm)
                    } label: {
                        Label(composed == nil ? "Composer ma routine" : "Recomposer", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }

                if let composed {
                    Section("\(composed.steps.count) mouvements · \(composed.minutes) min") {
                        ForEach(Array(composed.moves.enumerated()), id: \.offset) { item in
                            HStack(spacing: 10) {
                                StretchArtwork(symbol: item.element.symbol, tint: item.element.zones.first?.tint ?? .orange, size: 30)
                                Text(item.element.name).font(.subheadline)
                            }
                        }
                        NavigationLink {
                            RoutineDetailView(routine: composed)
                        } label: {
                            Label("Voir et commencer", systemImage: "play.fill").fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Composer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}
