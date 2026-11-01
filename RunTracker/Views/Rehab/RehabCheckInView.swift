import SwiftUI
import SwiftData

/// Bilan hebdomadaire : « Comment savoir si tu progresses ? »
struct RehabCheckInView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rehabPaused") private var paused = false

    @State private var rotation = 3
    @State private var wakePain = 2.0
    @State private var scapulaPain = 1
    @State private var screenTolerance = 3
    @State private var controlled = true
    @State private var worsening = false
    @State private var urgentSigns = false
    @State private var notes = ""
    @State private var outcome: String?

    private static let expected: [(String, String)] = [
        ("Rotation de la tête", "Plus facile et plus symétrique"),
        ("Douleur au réveil", "Moins fréquente et moins intense"),
        ("Douleur vers l'omoplate", "Moins fréquente"),
        ("Travail sur écran", "Mieux toléré"),
        ("Exercices", "Mouvements plus contrôlés, sans aggravation"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let outcome {
                    Section {
                        Text(outcome)
                        Button("Fermer") { dismiss() }
                    }
                } else {
                    Section("Résultats attendus") {
                        ForEach(Self.expected, id: \.0) { item in
                            HStack(alignment: .top) {
                                Text(item.0).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(item.1).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    Section("Rotation de la tête") {
                        Picker("Rotation", selection: $rotation) {
                            Text("Très difficile").tag(1)
                            Text("Difficile").tag(2)
                            Text("Moyenne").tag(3)
                            Text("Assez facile").tag(4)
                            Text("Facile et symétrique").tag(5)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    Section("Douleur au réveil : \(Int(wakePain))/10") {
                        Slider(value: $wakePain, in: 0...10, step: 1)
                    }
                    Section("Douleur vers l'omoplate") {
                        Picker("Fréquence", selection: $scapulaPain) {
                            ForEach(0..<RehabCheckIn.scapulaLabels.count, id: \.self) { Text(RehabCheckIn.scapulaLabels[$0]).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Travail sur écran") {
                        Picker("Tolérance", selection: $screenTolerance) {
                            Text("Mal").tag(1)
                            Text("Bof").tag(2)
                            Text("Moyen").tag(3)
                            Text("Bien").tag(4)
                            Text("Très bien").tag(5)
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Exercices") {
                        Toggle("Mouvements contrôlés, sans aggravation", isOn: $controlled)
                        Toggle("Douleur vive, qui descend davantage vers l'omoplate ou le bras, ou aggravation qui persiste après les séances",
                               isOn: $worsening)
                    }
                    Section("Signes d'alerte") {
                        Toggle("Faiblesse, engourdissements importants, fièvre ou mal de tête intense", isOn: $urgentSigns)
                    }
                    Section("Notes") {
                        TextField("Sensations, contexte, oreiller, travail…", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
            }
            .navigationTitle("Bilan de la semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if outcome == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() } }
                }
            }
        }
    }

    private func save() {
        let checkIn = RehabCheckIn()
        checkIn.rotation = rotation
        checkIn.wakePain = Int(wakePain)
        checkIn.scapulaPain = scapulaPain
        checkIn.screenTolerance = screenTolerance
        checkIn.exercisesControlled = controlled
        checkIn.worsening = worsening
        checkIn.urgentSigns = urgentSigns
        checkIn.notes = notes
        context.insert(checkIn)
        try? context.save()

        if urgentSigns {
            paused = true
            outcome = "⚠️ " + RehabContent.urgentSigns
        } else if worsening || !controlled {
            paused = true
            outcome = "Programme mis en pause. " + RehabContent.safetyRule + " Parles-en à un professionnel de santé avant de reprendre."
        } else {
            outcome = "Bilan enregistré. Continue à ton rythme : augmente d'abord les répétitions, puis la résistance, sans aller à l'échec."
        }
    }
}
