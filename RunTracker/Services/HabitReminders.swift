import Foundation
import UserNotifications

/// Rappels quotidiens des habitudes (notifications locales).
@MainActor
enum HabitReminders {
    private static func prefix(_ id: UUID) -> String { "habit-\(id.uuidString)" }

    static func update(for habit: Habit) async {
        let id = habit.id
        let enabled = habit.reminderEnabled && !habit.isArchived
        let title = "\(habit.emoji) \(habit.name)"
        let hour = habit.reminderHour
        let minute = habit.reminderMinute
        let weekdays: [Int?]
        if habit.schedule == .weekdays {
            // Index 0 = lundi → weekday Apple 2 ; dimanche → 1.
            weekdays = (0..<7).filter { habit.weekdaysMask & (1 << $0) != 0 }.map { ($0 + 1) % 7 + 1 }
        } else {
            weekdays = [nil]
        }

        await remove(for: id)
        guard enabled else { return }

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "C'est le moment pour ton habitude du jour."
        content.sound = .default

        for weekday in weekdays {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "\(prefix(id))-\(weekday ?? 0)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func remove(for id: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix(id)) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
