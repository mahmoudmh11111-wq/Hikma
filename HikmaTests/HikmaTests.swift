import XCTest
@testable import Hikma

final class HikmaTests: XCTestCase {
    private let ids = QuoteLibrary.all.map(\.id)

    func testLibraryIsBigEnoughAndComplete() {
        XCTAssertGreaterThanOrEqual(QuoteLibrary.all.count, Cycle.totalSlots)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids")
        XCTAssertEqual(Set(QuoteLibrary.all.map(\.text)).count, ids.count, "duplicate texts")
        for quote in QuoteLibrary.all {
            XCTAssertFalse(quote.text.isEmpty)
            XCTAssertFalse(quote.sayer.isEmpty)
            XCTAssertFalse(quote.source.isEmpty)
            XCTAssertFalse(quote.culture.isEmpty)
        }
    }

    func testCycleHas84DifferentQuotesEveryFourHours() throws {
        let now = Date()
        let cycle = try XCTUnwrap(Cycle.make(startHour: 8, now: now, ids: ids, previous: nil))
        XCTAssertEqual(cycle.order.count, 84)
        XCTAssertEqual(Set(cycle.order).count, 84, "a quote repeats inside 14 days")
        XCTAssertGreaterThan(cycle.start, now)
        XCTAssertLessThanOrEqual(cycle.start.timeIntervalSince(now), Cycle.interval)
        XCTAssertEqual(cycle.date(ofSlot: 1).timeIntervalSince(cycle.date(ofSlot: 0)), 4 * 3600)
        XCTAssertEqual(cycle.date(ofSlot: 83).timeIntervalSince(cycle.start), 83 * 4 * 3600)
        XCTAssertEqual(cycle.day(ofSlot: 83), 14)
    }

    func testFirstSlotLandsOnTheGrid() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 21, minute: 5))!
        let first = Cycle.firstSlot(after: now, startHour: 8, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: first), 0)   // next on 8-12-16-20-0-4 grid
        XCTAssertEqual(calendar.component(.minute, from: first), 0)
    }

    func testPlanRespectsTheSixtyFourLimit() throws {
        let now = Date()
        let cycle = try XCTUnwrap(Cycle.make(startHour: 8, now: now, ids: ids, previous: nil))
        let plan = NotificationScheduler.plan(for: cycle, now: now)
        XCTAssertEqual(plan.slots.count, 63)
        XCTAssertEqual(plan.slots.first, 0)
        XCTAssertFalse(plan.reminderEndsCycle)
        XCTAssertEqual(plan.reminderDate, cycle.date(ofSlot: 63))

        // Ten days in, the rest fits and the reminder announces the end.
        let later = cycle.date(ofSlot: 60).addingTimeInterval(60)
        let late = NotificationScheduler.plan(for: cycle, now: later)
        XCTAssertEqual(late.slots, Array(61..<84))
        XCTAssertTrue(late.reminderEndsCycle)
    }

    func testNextCyclePrefersQuotesNotJustSeen() throws {
        let now = Date()
        let first = try XCTUnwrap(Cycle.make(startHour: 8, now: now, ids: ids, previous: nil))
        let second = try XCTUnwrap(Cycle.make(startHour: 8, now: now, ids: ids, previous: first))
        let unseen = ids.count - 84
        XCTAssertTrue(Set(second.order.prefix(unseen)).isDisjoint(with: Set(first.order)))
        XCTAssertEqual(Set(second.order).count, 84)
    }
}
