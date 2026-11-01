import SwiftUI

struct StartView: View {
    @Environment(WorkoutManager.self) private var workout
    @State private var isStarting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    startButton(title: "Course extérieure", subtitle: "GPS + tracé", systemImage: "figure.run", outdoor: true)
                    startButton(title: "Tapis de course", subtitle: "Sans GPS", systemImage: "figure.run.treadmill", outdoor: false)
                    if let message = workout.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .navigationTitle("Foulée")
        }
        .task { await workout.requestAuthorization() }
    }

    private func startButton(title: String, subtitle: String, systemImage: String, outdoor: Bool) -> some View {
        Button {
            guard !isStarting else { return }
            isStarting = true
            Task {
                await workout.start(outdoor: outdoor)
                isStarting = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        }
        .disabled(isStarting)
    }
}
