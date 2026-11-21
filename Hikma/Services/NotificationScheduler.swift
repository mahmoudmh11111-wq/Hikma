import Foundation
import UserNotifications

/// Schedules sayings and book cards as local notifications (no server needed).
///
/// iOS keeps at most 64 pending notifications per app. Both streams are merged
/// in time order and the earliest 63 are scheduled, plus one gentle "open Hikma"
/// notification at the next time. Opening the app (or a background refresh) tops
/// the queue up again, so in normal use nothing is missed.
enum NotificationScheduler {
    static let pendingLimit = 64
    static let reminderID = "hikma.reminder"
    static let testID = "hikma.test"

    enum Item: Equatable {
        case saying(Int)
        case card(Int)
    }

    struct Timed: Equatable {
        let item: Item
        let date: Date
    }

    struct Plan: Equatable {
        let items: [Timed]
        let reminderDate: Date?
        /// True when the reminder announces the end of the 14 days of sayings.
        let reminderEndsCycle: Bool

        var sayingSlots: [Int] {
            items.compactMap { (timed: Timed) -> Int? in
                if case .saying(let slot) = timed.item { return slot }
                return nil
            }
        }
        var cardIndices: [Int] {
            items.compactMap { (timed: Timed) -> Int? in
                if case .card(let index) = timed.item { return index }
                return nil
            }
        }
    }

    static func plan(sayings: Cycle?, book: BookRun?, now: Date) -> Plan {
        var all: [Timed] = []
        if let cycle = sayings, let first = cycle.nextSlot(after: now) {
            all += (first..<Cycle.totalSlots).map { Timed(item: .saying($0), date: cycle.date(ofSlot: $0)) }
        }
        if let book {
            all += book.dates.indices.filter { book.dates[$0] > now }
                .map { Timed(item: .card($0), date: book.dates[$0]) }
        }
        all.sort { $0.date < $1.date }

        let kept = Array(all.prefix(pendingLimit - 1))
        if all.count > kept.count {
            return Plan(items: kept, reminderDate: all[kept.count].date, reminderEndsCycle: false)
        }
        if let cycle = sayings {
            return Plan(items: kept, reminderDate: cycle.date(ofSlot: Cycle.totalSlots), reminderEndsCycle: true)
        }
        return Plan(items: kept, reminderDate: nil, reminderEndsCycle: false)
    }

    // MARK: - Permission

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    // MARK: - Scheduling

    static func apply(sayings: Cycle?, book: Book?, run: BookRun?, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let bookRun = (book != nil) ? run : nil
        let schedule = plan(sayings: sayings, book: bookRun, now: now)

        for timed in schedule.items {
            let identifier: String
            let content: UNMutableNotificationContent
            switch timed.item {
            case .saying(let slot):
                guard let quote = sayings?.quote(ofSlot: slot) else { continue }
                identifier = "hikma.slot.\(slot)"
                content = self.content(for: quote, slot: slot)
            case .card(let index):
                guard let book, book.cards.indices.contains(index) else { continue }
                identifier = "hikma.card.\(index)"
                content = self.content(for: book, cardIndex: index)
            }
            try? await center.add(UNNotificationRequest(
                identifier: identifier, content: content, trigger: trigger(at: timed.date)))
        }

        if let date = schedule.reminderDate {
            let reminder = UNMutableNotificationContent()
            reminder.title = "حكمة"
            reminder.body = schedule.reminderEndsCycle
                ? "اكتملت أربعة عشر يومًا من الحكمة. افتح التطبيق لتبدأ دورة جديدة."
                : "حان موعدك التالي. افتح التطبيق لتصلك البقية."
            reminder.sound = .default
            reminder.threadIdentifier = "hikma"
            try? await center.add(UNNotificationRequest(
                identifier: reminderID, content: reminder, trigger: trigger(at: date)))
        }
    }

    static func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Sends a notification in a few seconds, to check how it looks.
    static func sendTest(_ content: UNMutableNotificationContent) async {
        let request = UNNotificationRequest(
            identifier: testID, content: content,
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

    static func content(for book: Book, cardIndex: Int) -> UNMutableNotificationContent {
        let card = book.cards[cardIndex]
        let content = UNMutableNotificationContent()
        content.title = card.title
        content.subtitle = "\(book.title) · \(cardIndex + 1)/\(book.cards.count)"
        var body = card.body
        if let apply = card.apply, !apply.isEmpty { body += "\n\nطبّقها: " + apply }
        content.body = body
        content.sound = .default
        content.threadIdentifier = "hikma.book"
        content.userInfo = ["card": cardIndex]
        return content
    }

    private static func trigger(at date: Date) -> UNCalendarNotificationTrigger {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    }
}
