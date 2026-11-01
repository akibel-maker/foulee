import SwiftUI

/// Onglet « Mobilité » : étirements et rééducation / renforcement.
struct MobilityView: View {
    enum Part: String, CaseIterable, Identifiable {
        case stretch = "Étirements"
        case rehab = "Rééducation"
        var id: Self { self }
    }

    @AppStorage("mobilitySection") private var part: Part = .stretch

    var body: some View {
        NavigationStack {
            Group {
                switch part {
                case .stretch: StretchHomeView()
                case .rehab: RehabHomeView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Section", selection: $part) {
                        ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }
            }
        }
    }
}
