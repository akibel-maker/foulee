import SwiftUI

extension View {
    /// Carte arrondie sur fond secondaire, utilisée dans Progression et Sommeil.
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
