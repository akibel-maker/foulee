import Foundation

struct HabitStats {
    var currentStreak = 0
    var bestStreak = 0
    /// Taux de réussite sur 30 jours (0…1).
    var completionRate = 0.0
    var totalDone = 0
    /// Jours réussis dans la semaine en cours.
    var doneThisWeek = 0

    /// Unité de la série : jours, ou semaines pour « X fois par semaine ».
    var streakIsWeekly = false
}

/// Règles de réussite, séries et statistiques des habitudes.
enum HabitLogic {
    typealias ValueProvider = (Date) -> Double

    static func isScheduled(_ habit: Habit, on day: Date) -> Bool {
        switch habit.schedule {
        case .daily, .timesPerWeek: return true
        case .weekdays: return habit.weekdaysMask & (1 << HabitDay.weekdayIndex(day)) != 0
        }
    }

    static func isDone(_ habit: Habit, on day: Date, value: ValueProvider) -> Bool {
        value(day) >= habit.effectiveTarget
    }

    static func doneCount(_ habit: Habit, inWeekOf day: Date, value: ValueProvider) -> Int {
        let cal = HabitDay.calendar
        guard let week = cal.dateInterval(of: .weekOfYear, for: day) else { return 0 }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: week.start) }
            .filter { isDone(habit, on: $0, value: value) }.count
    }

    /// L'habitude compte-t-elle comme accomplie pour cette journée (y compris objectif hebdo déjà atteint) ?
    static func isSatisfied(_ habit: Habit, on day: Date, value: ValueProvider) -> Bool {
        if habit.schedule == .timesPerWeek {
            return isDone(habit, on: day, value: value)
                || doneCount(habit, inWeekOf: day, value: value) >= habit.timesPerWeek
        }
        return isDone(habit, on: day, value: value)
    }

    static func stats(for habit: Habit, value: ValueProvider, now: Date = .now) -> HabitStats {
        let cal = HabitDay.calendar
        let today = cal.startOfDay(for: now)
        let earliestLog = habit.log.keys.compactMap(HabitDay.date(fromKey:)).min()
        var start = cal.startOfDay(for: min(habit.createdAt, earliestLog ?? habit.createdAt))
        if let limit = cal.date(byAdding: .day, value: -730, to: today), start < limit { start = limit }

        var stats = HabitStats()
        stats.doneThisWeek = doneCount(habit, inWeekOf: today, value: value)

        var day = start
        var days: [Date] = []
        while day <= today {
            days.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        stats.totalDone = days.filter { isDone(habit, on: $0, value: value) }.count

        if habit.schedule == .timesPerWeek {
            stats.streakIsWeekly = true
            var weekStarts: [Date] = []
            var w = cal.dateInterval(of: .weekOfYear, for: start)?.start ?? start
            while w <= today {
                weekStarts.append(w)
                guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: w) else { break }
                w = next
            }
            var run = 0
            for (index, weekStart) in weekStarts.enumerated() {
                let success = doneCount(habit, inWeekOf: weekStart, value: value) >= habit.timesPerWeek
                let isCurrent = index == weekStarts.count - 1
                if success {
                    run += 1
                    stats.bestStreak = max(stats.bestStreak, run)
                } else if !isCurrent {
                    run = 0
                }
            }
            stats.currentStreak = run
            // Réussite : semaines terminées sur les 8 dernières.
            let finished = weekStarts.dropLast().suffix(8)
            let succeeded = finished.filter { doneCount(habit, inWeekOf: $0, value: value) >= habit.timesPerWeek }.count
            stats.completionRate = finished.isEmpty
                ? min(Double(stats.doneThisWeek) / Double(max(habit.timesPerWeek, 1)), 1)
                : Double(succeeded) / Double(finished.count)
            return stats
        }

        var run = 0
        for day in days where isScheduled(habit, on: day) {
            if isDone(habit, on: day, value: value) {
                run += 1
                stats.bestStreak = max(stats.bestStreak, run)
            } else if day != today {
                // Aujourd'hui n'est pas encore raté.
                run = 0
            }
        }
        stats.currentStreak = run

        let last30 = days.suffix(30).filter { isScheduled(habit, on: $0) }
        let past = last30.filter { $0 != today || isDone(habit, on: $0, value: value) }
        let done = past.filter { isDone(habit, on: $0, value: value) }.count
        stats.completionRate = past.isEmpty ? 0 : Double(done) / Double(past.count)
        return stats
    }
}
