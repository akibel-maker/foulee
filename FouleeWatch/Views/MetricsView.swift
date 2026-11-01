import SwiftUI

struct MetricsView: View {
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.duration(workout.elapsedTime(at: context.date)))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(workout.isPaused ? .yellow : .orange)
                    .monospacedDigit()
                metric(Fmt.km(workout.distance), unit: "KM", large: true)
                metric(Fmt.pace(workout.currentPace), unit: "/KM")
                HStack(spacing: 4) {
                    metric(workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "--", unit: "BPM")
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: workout.heartRate > 0 && !workout.isPaused)
                }
                metric("\(Int(workout.activeEnergy))", unit: "KCAL")
                if workout.isPaused {
                    Text("EN PAUSE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }

    private func metric(_ value: String, unit: String, large: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(large ? .title : .title3, design: .rounded).weight(.medium))
                .monospacedDigit()
            Text(unit)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
