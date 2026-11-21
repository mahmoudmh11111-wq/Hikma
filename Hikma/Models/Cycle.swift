import Foundation

/// A 14-day run: one quote every 4 hours (6 a day, 84 in total), none repeated.
/// Slot `i` is delivered at `start + i × 4 hours` and shows quote `order[i]`.
struct Cycle: Codable, Equatable {
    static let slotsPerDay = 6
    static let days = 14
    static let totalSlots = slotsPerDay * days          // 84
    static let interval: TimeInterval = 4 * 60 * 60     // 4 hours

    /// Time of the first quote.
    let start: Date
    /// Quote ids, one per slot, all different.
    let order: [String]

    func date(ofSlot slot: Int) -> Date {
        start.addingTimeInterval(Double(slot) * Self.interval)
    }

    func quoteID(ofSlot slot: Int) -> String? {
        order.indices.contains(slot) ? order[slot] : nil
    }

    func quote(ofSlot slot: Int) -> Quote? {
        quoteID(ofSlot: slot).flatMap(QuoteLibrary.quote(id:))
    }

    /// The latest slot whose time has come, or nil before the first one.
    func latestDeliveredSlot(at now: Date) -> Int? {
        guard now >= start else { return nil }
        let index = Int(now.timeIntervalSince(start) / Self.interval)
        return min(index, Self.totalSlots - 1)
    }

    /// The next slot still to come, or nil when the cycle has delivered everything.
    func nextSlot(after now: Date) -> Int? {
        let next = (latestDeliveredSlot(at: now) ?? -1) + 1
        return next < Self.totalSlots ? next : nil
    }

    /// True once the last quote's 4-hour window is over.
    func isFinished(at now: Date) -> Bool {
        now >= date(ofSlot: Self.totalSlots)
    }

    /// Day number (1…14) of a slot.
    func day(ofSlot slot: Int) -> Int {
        min(slot / Self.slotsPerDay + 1, Self.days)
    }

    /// Slots that fall on the same calendar day as `date` (six on a normal day).
    func slots(onDayOf date: Date, calendar: Calendar = .current) -> [Int] {
        (0..<Self.totalSlots).filter { calendar.isDate(self.date(ofSlot: $0), inSameDayAs: date) }
    }

    /// The first upcoming time on the 4-hour grid anchored at `startHour`:00.
    static func firstSlot(after now: Date, startHour: Int, calendar: Calendar = .current) -> Date {
        let anchor = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now) ?? now
        let steps = floor(now.timeIntervalSince(anchor) / interval) + 1
        return anchor.addingTimeInterval(steps * interval)
    }

    /// A new cycle. Quotes that were not in `previous` come first, so a new
    /// cycle feels fresh as soon as the library holds more than 84 quotes.
    static func make(startHour: Int, now: Date, ids: [String], previous: Cycle?,
                     calendar: Calendar = .current) -> Cycle? {
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        guard unique.count >= totalSlots else { return nil }
        let recent = Set(previous?.order ?? [])
        let fresh = unique.filter { !recent.contains($0) }.shuffled()
        let reused = unique.filter { recent.contains($0) }.shuffled()
        let order = Array((fresh + reused).prefix(totalSlots))
        return Cycle(start: firstSlot(after: now, startHour: startHour, calendar: calendar), order: order)
    }

    /// The six daily times for a schedule starting at `startHour`, in day order.
    static func dailyHours(startHour: Int) -> [Int] {
        (0..<slotsPerDay).map { (startHour + $0 * 4) % 24 }.sorted()
    }
}
