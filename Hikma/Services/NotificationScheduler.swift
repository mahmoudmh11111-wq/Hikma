import Foundation
import UserNotifications

/// Schedules the cycle as local notifications (no server, no push certificate needed).
///
/// iOS keeps at most 64 pending notifications per app, but a cycle has 84.
/// So we schedule the next 63 quotes plus one gentle "open Hikma" notification
/// at the 64th time. Every time the app opens (or iOS lets it refresh in the
/// background) the queue is topped up again, so in normal use nothing is missed.
enum NotificationScheduler {
    static let pendingLimit = 64
    static let slotPrefix = "hikma.slot."
    static let reminderID = "hikma.reminder"
    static let testID = "hikma.test"

    struct Plan: Equatable {
        /// Slots to schedule as quote notifications, in order.
        let slots: [Int]
        /// When to send the extra "open the app" notification.
        let reminderDate: Date
        /// True when the reminder announces the end of the 14 days.
        let reminderEndsCycle: Bool
    }

    static func plan(for cycle: Cycle, now: Date) -> Plan {
        let first = cycle.nextSlot(after: now) ?? Cycle.totalSlots
        let remaining = Array(first..<Cycle.totalSlots)
        let slots = Array(remaining.prefix(pendingLimit - 1))
        if remaining.count > slots.count, let last = slots.last {
            return Plan(slots: slots, reminderDate: cycle.date(ofSlot: last + 1), reminderEndsCycle: false)
        }
        return Plan(slots: slots, reminderDate: cycle.date(ofSlot: Cycle.totalSlots), reminderEndsCycle: true)
    }

    // MARK: - Permission

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    // MARK: - Scheduling

    static func apply(cycle: Cycle, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let schedule = Self.plan(for: cycle, now: now)
        for slot in schedule.slots {
            guard let quote = cycle.quote(ofSlot: slot) else { continue }
            let request = UNNotificationRequest(
                identifier: slotPrefix + String(slot),
                content: content(for: quote, slot: slot),
                trigger: trigger(at: cycle.date(ofSlot: slot)))
            try? await center.add(request)
        }

        let reminder = UNMutableNotificationContent()
        reminder.title = "حكمة"
        reminder.body = schedule.reminderEndsCycle
            ? "اكتملت أربعة عشر يومًا من الحكمة. افتح التطبيق لتبدأ دورة جديدة."
            : "حان موعد حكمتك. افتح التطبيق لتصلك بقية الحكم."
        reminder.sound = .default
        reminder.threadIdentifier = "hikma"
        try? await center.add(UNNotificationRequest(
            identifier: reminderID, content: reminder, trigger: trigger(at: schedule.reminderDate)))
    }

    static func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Sends `quote` in a few seconds, to check how notifications look.
    static func sendTest(_ quote: Quote) async {
        let request = UNNotificationRequest(
            identifier: testID,
            content: content(for: quote, slot: nil),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func content(for quote: Quote, slot: Int?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = quote.sayer
        content.subtitle = quote.source
        content.body = "«" + quote.text + "»"
        content.sound = .default
        content.threadIdentifier = "hikma"
        if let slot { content.userInfo = ["slot": slot] }
        return content
    }

    private static func trigger(at date: Date) -> UNCalendarNotificationTrigger {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    }
}
