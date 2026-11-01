import SwiftUI

/// Détail d'une phase : objectif, condition, exercices et consignes.
struct RehabPhaseView: View {
    let phase: RehabPhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PHASE \(phase.number) · \(phase.weeksLabel.uppercased())")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(phase.title).font(.largeTitle.weight(.bold))
                    Text("Objectif : \(phase.objective)").font(.headline)
                }
                Label(phase.entryCondition, systemImage: "info.circle")
                    .font(.subheadline)
                    .card()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Exercice").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("Séries × répétitions").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    ForEach(phase.prescriptions) { item in
                        if let exercise = item.exercise {
                            RehabExerciseRow(exercise: exercise, prescription: item)
                            Divider()
                        }
                    }
                }
                .card()

                Label(phase.frequency, systemImage: "calendar").font(.subheadline).card()

                if !phase.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Consignes").font(.headline)
                        ForEach(phase.notes, id: \.self) { note in
                            Label(note, systemImage: "checkmark.circle").font(.subheadline)
                        }
                    }
                    .card()
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RehabExerciseRow: View {
    let exercise: RehabExercise
    let prescription: RehabPrescription
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    StretchArtwork(symbol: exercise.symbol, tint: .teal, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                        HStack(spacing: 4) {
                            Image(systemName: exercise.equipment.symbol)
                            Text(exercise.equipment.label)
                            if let note = prescription.note { Text("· \(note)") }
                            if prescription.optional { Text("· optionnel") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(prescription.sets) × \(prescription.reps)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { item in
                        Text("\(item.offset + 1). \(item.element)").font(.footnote)
                    }
                    if let warning = exercise.warning {
                        Label(warning, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                    }
                }
                .padding(.leading, 52)
                .foregroundStyle(.secondary)
            }
        }
    }
}
