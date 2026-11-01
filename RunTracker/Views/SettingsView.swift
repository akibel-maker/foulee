import SwiftUI
import SwiftData

@MainActor
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @AppStorage("weightKg") private var weightKg = 70.0
    @AppStorage("voiceCoach") private var voiceCoach = true
    @AppStorage("saveToHealth") private var saveToHealth = true

    @State private var isImporting = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Objectif de sommeil : \(Fmt.sleep(sleepGoalHours * 3600))", value: $sleepGoalHours, in: 5...11, step: 0.25)
                } header: {
                    Text("Objectifs")
                } footer: {
                    Text("Tes objectifs de course se créent dans l'onglet Progression (bouton +).")
                }
                Section {
                    Stepper("Poids : \(Int(weightKg)) kg", value: $weightKg, in: 30...200)
                    Button("Récupérer mon poids depuis Santé") {
                        Task {
                            try? await HealthKitManager.shared.requestAuthorization()
                            if let kg = await HealthKitManager.shared.latestBodyMass() { weightKg = kg.rounded() }
                        }
                    }
                } header: {
                    Text("Profil")
                } footer: {
                    Text("Le poids sert à estimer les calories dépensées.")
                }
                Section("Pendant la course") {
                    Toggle("Coach vocal (annonce à chaque km)", isOn: $voiceCoach)
                }
                Section {
                    Toggle("Enregistrer mes courses dans Santé", isOn: $saveToHealth)
                    Button("Autoriser l'accès à Santé") {
                        Task { try? await HealthKitManager.shared.requestAuthorization() }
                    }
                    Button {
                        importFromHealth()
                    } label: {
                        HStack {
                            Text("Importer mes courses depuis Santé")
                            if isImporting { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isImporting)
                    if let importMessage {
                        Text(importMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Santé")
                } footer: {
                    Text("L'import récupère tes courses Apple Watch ou d'autres apps (distance, durée, tracé, fréquence cardiaque). La fréquence cardiaque n'est disponible que si tu portes une Apple Watch.")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
    }

    private func importFromHealth() {
        isImporting = true
        importMessage = nil
        Task {
            do {
                let count = try await HealthImporter.importRuns(into: context)
                importMessage = count == 0 ? "Aucune nouvelle course à importer." : "\(count) course\(count > 1 ? "s" : "") importée\(count > 1 ? "s" : "")."
            } catch {
                importMessage = "Import impossible : \(error.localizedDescription)"
            }
            isImporting = false
        }
    }
}
