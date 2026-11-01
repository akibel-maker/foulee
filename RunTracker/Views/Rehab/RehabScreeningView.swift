import SwiftUI
import SwiftData

/// « Avant de commencer : j'ai besoin de vérifier trois points. »
struct RehabScreeningView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rehabPaused") private var paused = false
    @AppStorage("stretchNeckCaution") private var neckCaution = false

    @State private var painTrend: PainTrend?
    @State private var mobility: MobilityChange?
    @State private var treatment: OsteoTreatment?
    @State private var stillStrong = false
    @State private var worsening = false
    @State private var nightPain = false
    @State private var urgentSigns = false
    @State private var result: ScreeningResult?

    private var complete: Bool { painTrend != nil && mobility != nil && treatment != nil }

    var body: some View {
        NavigationStack {
            Form {
                if let result {
                    resultSection(result)
                } else {
                    Section {
                        Text("Comme ta douleur a été importante et s'aggravait en position allongée, le programme s'adapte à ton état actuel plutôt que de te faire suivre aveuglément huit semaines d'exercices.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("1. Depuis la séance d'ostéopathie, ta douleur est :") {
                        choices(PainTrend.allCases, selection: $painTrend, label: \.label)
                    }
                    Section("2. Peux-tu baisser la tête et la tourner vers la gauche plus facilement qu'avant la séance ?") {
                        choices(MobilityChange.allCases, selection: $mobility, label: \.label)
                    }
                    Section("3. L'ostéopathe a-t-il fait craquer ou manipulé ton cou, ou a-t-il uniquement utilisé des massages, des exercices et de l'électrostimulation ?") {
                        choices(OsteoTreatment.allCases, selection: $treatment, label: \.label)
                    }
                    Section("Aujourd'hui") {
                        Toggle("La douleur est toujours forte", isOn: $stillStrong)
                        Toggle("La douleur s'aggrave", isOn: $worsening)
                        Toggle("La douleur me réveille la nuit", isOn: $nightPain)
                    }
                    Section {
                        Toggle("Faiblesse, engourdissements importants, fièvre ou mal de tête intense", isOn: $urgentSigns)
                    } header: {
                        Text("Signes d'alerte")
                    }
                    Section {
                        Button("Voir le résultat") { evaluate() }
                            .frame(maxWidth: .infinity)
                            .disabled(!complete)
                    }
                }
            }
            .navigationTitle("Faire le point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Annuler" : "Fermer") { dismiss() } }
            }
        }
    }

    private func choices<T: Hashable>(_ options: [T], selection: Binding<T?>, label: KeyPath<T, String>) -> some View {
        ForEach(options, id: \.self) { option in
            Button {
                selection.wrappedValue = option
            } label: {
                HStack {
                    Text(option[keyPath: label]).foregroundStyle(.primary)
                    Spacer()
                    if selection.wrappedValue == option {
                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultSection(_ result: ScreeningResult) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label(result.title, systemImage: result.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(result == .ready ? .green : (result == .urgent ? .red : .orange))
                Text(result.message)
                if treatment == .manipulation {
                    Text("Ton cou a été manipulé : en attendant, évite toute nouvelle manipulation cervicale forcée.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if result != .ready {
                    Text("La précaution cervicale a été activée dans les étirements.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        Section {
            Button("Terminé") { dismiss() }.frame(maxWidth: .infinity)
        }
    }

    private func evaluate() {
        guard let painTrend, let mobility, let treatment else { return }
        let outcome = RehabScreening.evaluate(painTrend: painTrend, mobility: mobility, stillStrong: stillStrong,
                                              worsening: worsening, nightPain: nightPain, urgentSigns: urgentSigns)
        let screening = RehabScreening()
        screening.painTrend = painTrend
        screening.mobility = mobility
        screening.treatment = treatment
        screening.stillStrong = stillStrong
        screening.worsening = worsening
        screening.nightPain = nightPain
        screening.urgentSigns = urgentSigns
        screening.resultRaw = outcome.rawValue
        context.insert(screening)
        try? context.save()
        if outcome != .ready {
            neckCaution = true
            if outcome == .urgent || outcome == .medical { paused = true }
        }
        withAnimation { result = outcome }
    }
}
