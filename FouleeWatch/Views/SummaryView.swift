import SwiftUI

struct SummaryView: View {
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        ScrollView {
            if let run = workout.summary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bravo !")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.orange)
                    row("Distance", "\(Fmt.km(run.distance)) km")
                    row("Durée", Fmt.duration(run.duration))
                    row("Allure moy.", "\(Fmt.pace(run.averagePace))/km")
                    if let hr = run.averageHeartRate { row("FC moy.", "\(Int(hr)) bpm") }
                    if let max = run.maxHeartRate { row("FC max", "\(Int(max)) bpm") }
                    if let kcal = run.calories { row("Calories", "\(Int(kcal)) kcal") }
                    if run.isOutdoor { row("Dénivelé", "\(Int(run.elevationGain)) m") }

                    Label(workout.sentToPhone ? "Envoyée à l'iPhone" : "Non envoyée (trop courte ?)",
                          systemImage: workout.sentToPhone ? "iphone.gen3" : "iphone.slash")
                        .font(.footnote)
                        .foregroundStyle(workout.sentToPhone ? .green : .secondary)
                    if let message = workout.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                    Button("Terminé") { workout.dismissSummary() }
                        .tint(.orange)
                        .padding(.top, 6)
                }
                .scenePadding()
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.title3, design: .rounded)).monospacedDigit()
        }
    }
}
