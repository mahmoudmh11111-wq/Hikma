import Foundation
import BackgroundTasks
import UIKit

/// App state: the current 14-day cycle and the daily times.
@MainActor
final class HikmaStore: ObservableObject {
    static let shared = HikmaStore()

    @Published private(set) var cycle: Cycle?
    @Published private(set) var notificationsAllowed = true
    @Published private(set) var now = Date()
    /// First of the six daily times (the others follow every 4 hours).
    @Published private(set) var startHour: Int = 8
    /// A slot opened from a notification; shown on the home screen instead of the latest.
    @Published var focusedSlot: Int?

    private enum Keys {
        static let cycle = "hikma.cycle"
        static let startHour = "hikma.startHour"
    }

    private init() {
        let defaults = UserDefaults.standard
        if let hour = defaults.object(forKey: Keys.startHour) as? Int { startHour = hour }
        if let data = defaults.data(forKey: Keys.cycle),
           let saved = try? JSONDecoder().decode(Cycle.self, from: data) {
            cycle = saved
        }
    }

    // MARK: - Derived

    var latestSlot: Int? { cycle?.latestDeliveredSlot(at: now) }

    /// What the home screen shows.
    var displayedSlot: Int? { focusedSlot ?? latestSlot }

    var nextDate: Date? {
        guard let cycle, let next = cycle.nextSlot(after: now) else { return nil }
        return cycle.date(ofSlot: next)
    }

    /// Delivered slots, newest first.
    var deliveredSlots: [Int] {
        guard let latest = latestSlot else { return [] }
        return Array((0...latest).reversed())
    }

    var currentDay: Int {
        guard let cycle else { return 1 }
        return cycle.day(ofSlot: latestSlot ?? 0)
    }

    // MARK: - Actions

    /// Starts a new 14-day cycle with the given first daily hour.
    func begin(startHour: Int) async {
        self.startHour = startHour
        UserDefaults.standard.set(startHour, forKey: Keys.startHour)
        notificationsAllowed = await NotificationScheduler.requestPermission()
        now = Date()
        save(Cycle.make(startHour: startHour, now: now,
                        ids: QuoteLibrary.all.map(\.id), previous: cycle))
        focusedSlot = nil
        await refresh()
    }

    /// Call when the app opens or refreshes: rolls over a finished cycle and tops up notifications.
    func refresh() async {
        now = Date()
        notificationsAllowed = await NotificationScheduler.isAuthorized()
        guard var current = cycle else { return }
        if current.isFinished(at: now),
           let next = Cycle.make(startHour: startHour, now: now,
                                 ids: QuoteLibrary.all.map(\.id), previous: current) {
            save(next)
            current = next
            focusedSlot = nil
        }
        await NotificationScheduler.apply(cycle: current, now: now)
        BackgroundRefresh.schedule()
    }

    func tick() { now = Date() }

    func openFromNotification(slot: Int) {
        guard let cycle, cycle.order.indices.contains(slot) else { return }
        now = Date()
        focusedSlot = slot == latestSlot ? nil : slot
    }

    func sendTest() async {
        let quote = displayedSlot.flatMap { cycle?.quote(ofSlot: $0) } ?? QuoteLibrary.all.first
        if let quote { await NotificationScheduler.sendTest(quote) }
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func save(_ new: Cycle?) {
        cycle = new
        if let new, let data = try? JSONEncoder().encode(new) {
            UserDefaults.standard.set(data, forKey: Keys.cycle)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.cycle)
        }
    }
}

/// Lets iOS wake the app now and then to top up the notification queue.
enum BackgroundRefresh {
    static let identifier = "com.hikma.app.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
