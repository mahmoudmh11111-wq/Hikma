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

    func testEachFullDayHasSixSlots() throws {
        let cycle = try XCTUnwrap(Cycle.make(startHour: 8, now: Date(), ids: ids, previous: nil))
        let middle = cycle.date(ofSlot: 40)
        XCTAssertEqual(cycle.slots(onDayOf: middle).count, 6)
    }

    func testPlanRespectsTheSixtyFourLimit() throws {
        let now = Date()
        let cycle = try XCTUnwrap(Cycle.make(startHour: 8, now: now, ids: ids, previous: nil))
        let plan = NotificationScheduler.plan(sayings: cycle, book: nil, now: now)
        XCTAssertEqual(plan.items.count, 63)
        XCTAssertEqual(plan.sayingSlots.first, 0)
        XCTAssertFalse(plan.reminderEndsCycle)
        XCTAssertEqual(plan.reminderDate, cycle.date(ofSlot: 63))

        // Ten days in, the rest fits and the reminder announces the end.
        let later = cycle.date(ofSlot: 60).addingTimeInterval(60)
        let late = NotificationScheduler.plan(sayings: cycle, book: nil, now: later)
        XCTAssertEqual(late.sayingSlots, Array(61..<84))
        XCTAssertTrue(late.reminderEndsCycle)
    }

    private func sampleBook(cards: Int) -> Book {
        Book(format: 1, id: "test", title: "كتاب", originalTitle: nil, author: "مؤلف", year: nil,
             about: "عن الكتاب",
             cards: (0..<cards).map { BookCard(id: "c\($0)", chapter: "الفصل", title: "عنوان \($0)",
                                               body: "نص", apply: nil) })
    }

    func testBookRunDeliversEveryCardInOrderBetweenSayings() throws {
        let now = Date()
        let book = sampleBook(cards: 59)
        let run = BookRun.make(book: book, perDay: 3, sayingsStartHour: 8, now: now)
        XCTAssertEqual(run.count, 59)
        XCTAssertEqual(run.dates, run.dates.sorted())
        XCTAssertGreaterThan(run.dates[0], now)
        XCTAssertEqual(BookRun.dailyHours(sayingsStartHour: 8, perDay: 3), [10, 14, 18])
        XCTAssertEqual(BookRun.dailyHours(sayingsStartHour: 8, perDay: 6), [2, 6, 10, 14, 18, 22])
        XCTAssertEqual(BookRun.days(cards: 59, perDay: 3), 20)
        let hours = Set(run.dates.map { Calendar.current.component(.hour, from: $0) })
        XCTAssertEqual(hours, [10, 14, 18])
    }

    func testMergedPlanKeepsBothStreamsUnderTheLimit() throws {
        let now = Date()
        let cycle = try XCTUnwrap(Cycle.make(startHour: 8, now: now, ids: ids, previous: nil))
        let run = BookRun.make(book: sampleBook(cards: 59), perDay: 3, sayingsStartHour: 8, now: now)
        let plan = NotificationScheduler.plan(sayings: cycle, book: run, now: now)
        XCTAssertEqual(plan.items.count, 63)
        XCTAssertEqual(plan.items.map(\.date), plan.items.map(\.date).sorted())
        XCTAssertFalse(plan.cardIndices.isEmpty)
        XCTAssertEqual(plan.cardIndices, Array(0..<plan.cardIndices.count))
        XCTAssertNotNil(plan.reminderDate)

        let bookOnly = NotificationScheduler.plan(sayings: nil, book: run, now: now)
        XCTAssertEqual(bookOnly.cardIndices, Array(0..<59))
        XCTAssertNil(bookOnly.reminderDate)
    }

    func testFeedMixesEverythingAndKeepsBookOrder() {
        let book = sampleBook(cards: 20)
        let today = Date()
        let feed = Feed.items(filter: .all, quotes: QuoteLibrary.all, books: [book], day: today)
        XCTAssertEqual(feed.count, QuoteLibrary.all.count + 20)
        XCTAssertEqual(Set(feed.map(\.id)).count, feed.count)
        let cardOrder = feed.compactMap { item -> Int? in
            if case .card(_, let index) = item { return index }
            return nil
        }
        XCTAssertEqual(cardOrder, Array(0..<20))
        // Same order all day, different tomorrow.
        XCTAssertEqual(feed.map(\.id), Feed.items(filter: .all, quotes: QuoteLibrary.all, books: [book], day: today).map(\.id))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        XCTAssertNotEqual(feed.map(\.id), Feed.items(filter: .all, quotes: QuoteLibrary.all, books: [book], day: tomorrow).map(\.id))
        XCTAssertEqual(Feed.items(filter: .book("test"), quotes: QuoteLibrary.all, books: [book], day: today).count, 20)
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
