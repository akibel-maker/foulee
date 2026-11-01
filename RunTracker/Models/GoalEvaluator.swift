import Foundation

struct GoalProgress {
    let current: Double
    let target: Double
    let interval: DateInterval
    /// Jours restants (période en cours incluse).
    let daysLeft: Int

    var fraction: Double { target > 0 ? min(current / target, 1) : 0 }
    var isCompleted: Bool { current >= target }
    var remaining: Double { max(0, target - current) }
}

/// Calcule l'avancement des objectifs à partir des courses et des nuits de sommeil.
enum GoalEvaluator {
    static var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    static func interval(for goal: Goal, offset: Int = 0, now: Date = .now) -> DateInterval? {
        let cal = calendar
        if goal.period == .custom {
            guard offset == 0, let deadline = goal.deadline,
                  let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: deadline)) else { return nil }
            let start = cal.startOfDay(for: goal.createdAt)
            return end > start ? DateInterval(start: start, end: end) : nil
        }
        guard let component = goal.period.component,
              let reference = cal.date(byAdding: component, value: offset, to: now) else { return nil }
        return cal.dateInterval(of: component, for: reference)
    }

    static func value(of kind: GoalKind, in interval: DateInterval, runs: [Run], nights: [SleepNight],
                      sleepGoalHours: Double) -> Double {
        let periodRuns = runs.filter { interval.contains($0.startDate) }
        let periodNights = nights.filter { interval.contains($0.date) }
        switch kind {
        case .distance: return periodRuns.reduce(0) { $0 + $1.distance } / 1000
        case .runs: return Double(periodRuns.count)
        case .duration: return periodRuns.reduce(0) { $0 + $1.duration } / 3600
        case .elevation: return periodRuns.reduce(0) { $0 + $1.elevationGain }
        case .longestRun: return (periodRuns.map(\.distance).max() ?? 0) / 1000
        case .sleepAverage:
            guard !periodNights.isEmpty else { return 0 }
            return periodNights.reduce(0) { $0 + $1.asleep } / Double(periodNights.count) / 3600
        case .sleepNights:
            return Double(periodNights.filter { $0.asleep >= sleepGoalHours * 3600 }.count)
        }
    }

    static func progress(for goal: Goal, runs: [Run], nights: [SleepNight], sleepGoalHours: Double,
                         offset: Int = 0, now: Date = .now) -> GoalProgress? {
        guard let interval = interval(for: goal, offset: offset, now: now) else { return nil }
        let current = value(of: goal.kind, in: interval, runs: runs, nights: nights, sleepGoalHours: sleepGoalHours)
        let cal = calendar
        let daysLeft = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: now), to: interval.end).day ?? 0)
        return GoalProgress(current: current, target: goal.target, interval: interval, daysLeft: daysLeft)
    }

    /// Nombre de périodes réussies d'affilée (la période en cours compte si elle est déjà réussie).
    static func streak(for goal: Goal, runs: [Run], nights: [SleepNight], sleepGoalHours: Double, now: Date = .now) -> Int {
        guard goal.period != .custom else { return 0 }
        var streak = 0
        if let current = progress(for: goal, runs: runs, nights: nights, sleepGoalHours: sleepGoalHours, now: now),
           current.isCompleted {
            streak += 1
        }
        for offset in 1...52 {
            guard let past = progress(for: goal, runs: runs, nights: nights, sleepGoalHours: sleepGoalHours,
                                      offset: -offset, now: now), past.isCompleted else { break }
            streak += 1
        }
        return streak
    }
}
