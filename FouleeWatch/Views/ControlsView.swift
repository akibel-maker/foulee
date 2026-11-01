import SwiftUI
import WatchKit

struct ControlsView: View {
    @Environment(WorkoutManager.self) private var workout
    @State private var confirmEnd = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                control(title: "Terminer", systemImage: "xmark", tint: .red) {
                    confirmEnd = true
                }
                control(title: workout.isPaused ? "Reprendre" : "Pause",
                        systemImage: workout.isPaused ? "play.fill" : "pause.fill",
                        tint: .yellow) {
                    workout.togglePause()
                }
            }
            control(title: "Verrou eau", systemImage: "drop.fill", tint: .cyan) {
                WKInterfaceDevice.current().enableWaterLock()
            }
        }
        .confirmationDialog("Terminer la course ?", isPresented: $confirmEnd) {
            Button("Terminer", role: .destructive) { workout.end() }
            Button("Continuer", role: .cancel) {}
        }
    }

    private func control(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title2)
            }
            .tint(tint)
            Text(title).font(.caption2)
        }
    }
}
