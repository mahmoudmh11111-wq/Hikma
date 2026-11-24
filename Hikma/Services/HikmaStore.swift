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
    /// Whether the 4-hourly sayings are sent.
    @Published private(set) var sayingsEnabled = true

    /// Imported reading plans.
    @Published private(set) var books: [Book] = []
    /// The book currently being delivered, if any.
    @Published private(set) var bookRun: BookRun?
    /// A book card opened from a notification.
    @Published var focusedCard: Int?
    /// Set when a book was just imported, so the library can open it.
    @Published var justImportedBookID: String?
    /// Shown when an imported file could not be read.
    @Published var importError: String?
    /// Ideas saved from the feed (FeedItem ids), newest first.
    @Published private(set) var savedIDs: [String] = []

    private enum Keys {
        static let cycle = "hikma.cycle"
        static let startHour = "hikma.startHour"
        static let sayingsEnabled = "hikma.sayingsEnabled"
        static let bookRun = "hikma.bookRun"
        static let saved = "hikma.saved"
    }

    private init() {
        let defaults = UserDefaults.standard
        if let hour = defaults.object(forKey: Keys.startHour) as? Int { startHour = hour }
        if let data = defaults.data(forKey: Keys.cycle),
           let saved = try? JSONDecoder().decode(Cycle.self, from: data) {
            cycle = saved
        }
        if defaults.object(forKey: Keys.sayingsEnabled) != nil {
            sayingsEnabled = defaults.bool(forKey: Keys.sayingsEnabled)
        }
        savedIDs = defaults.stringArray(forKey: Keys.saved) ?? []
        books = BookShelf.loadAll()
        if let data = defaults.data(forKey: Keys.bookRun),
           let run = try? JSONDecoder().decode(BookRun.self, from: data),
           books.contains(where: { $0.id == run.bookID }) {
            bookRun = run
        }
    }

    // MARK: - Feed & saved

    func feed(_ filter: FeedFilter) -> [FeedItem] {
        Feed.items(filter: filter, quotes: QuoteLibrary.all, books: books, day: now)
    }

    /// Book topics, by number of books (most first).
    var topics: [String] {
        let counts = Dictionary(grouping: books, by: \.topicName).mapValues(\.count)
        return counts.keys.sorted { (counts[$0] ?? 0, $1) > (counts[$1] ?? 0, $0) }
    }

    func isSaved(_ item: FeedItem) -> Bool { savedIDs.contains(item.id) }

    func toggleSaved(_ item: FeedItem) {
        if let index = savedIDs.firstIndex(of: item.id) {
            savedIDs.remove(at: index)
        } else {
            savedIDs.insert(item.id, at: 0)
        }
        UserDefaults.standard.set(savedIDs, forKey: Keys.saved)
    }

    /// Saved items that still exist (a deleted book's cards drop out).
    var savedItems: [FeedItem] {
        let items = QuoteLibrary.all.map(FeedItem.quote)
            + books.flatMap { book in book.cards.indices.map { FeedItem.card(book: book, index: $0) } }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return savedIDs.compactMap { byID[$0] }
    }

    // MARK: - Books

    var activeBook: Book? {
        guard let run = bookRun else { return nil }
        return books.first { $0.id == run.bookID }
    }

    var latestCard: Int? { bookRun?.latestDelivered(at: now) }

    var nextCardDate: Date? {
        guard let run = bookRun, let next = run.nextCard(after: now) else { return nil }
        return run.dates[next]
    }

    /// Progress (0…1) through the active book.
    var bookProgress: Double {
        guard let run = bookRun, run.count > 0 else { return 0 }
        return Double((latestCard ?? -1) + 1) / Double(run.count)
    }

    func progress(of book: Book) -> (delivered: Int, total: Int, isActive: Bool) {
        guard let run = bookRun, run.bookID == book.id else { return (0, book.cards.count, false) }
        return ((latestCard ?? -1) + 1, run.count, true)
    }

    /// Imports a `.hikmabook` file (from Files, AirDrop, Mail or a chat app).
    @discardableResult
    func importBook(from url: URL) throws -> Book {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let book = try Book.decode(data)
        try BookShelf.save(data, id: book.id)
        books.removeAll { $0.id == book.id }
        books.insert(book, at: 0)
        justImportedBookID = book.id
        return book
    }

    func startBook(_ book: Book, perDay: Int) async {
        if !notificationsAllowed || cycle == nil {
            notificationsAllowed = await NotificationScheduler.requestPermission()
        }
        now = Date()
        let run = BookRun.make(book: book, perDay: perDay, sayingsStartHour: startHour, now: now)
        saveRun(run)
        focusedCard = nil
        await refresh()
    }

    func stopBook() async {
        saveRun(nil)
        focusedCard = nil
        await refresh()
    }

    func deleteBook(_ book: Book) async {
        if bookRun?.bookID == book.id { saveRun(nil) }
        BookShelf.delete(id: book.id)
        books.removeAll { $0.id == book.id }
        await refresh()
    }

    func setSayingsEnabled(_ enabled: Bool) async {
        sayingsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.sayingsEnabled)
        await refresh()
    }

    func openFromNotification(card: Int) {
        guard let run = bookRun, run.dates.indices.contains(card) else { return }
        now = Date()
        focusedCard = card
    }

    private func saveRun(_ run: BookRun?) {
        bookRun = run
        if let run, let data = try? JSONEncoder().encode(run) {
            UserDefaults.standard.set(data, forKey: Keys.bookRun)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.bookRun)
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

    /// Today's slots for the home cards. Before the first quote of a new cycle,
    /// the day of the first quote is shown instead.
    var todaySlots: [Int] {
        guard let cycle else { return [] }
        let today = cycle.slots(onDayOf: now)
        if !today.isEmpty { return today }
        guard let next = cycle.nextSlot(after: now) else { return [] }
        return cycle.slots(onDayOf: cycle.date(ofSlot: next))
    }

    /// The card to open on: the latest delivered today, otherwise the first.
    var startingTodaySlot: Int? {
        let slots = todaySlots
        if let latest = latestSlot, slots.contains(latest) { return latest }
        return slots.first
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
        guard var current = cycle else {
            await NotificationScheduler.apply(sayings: nil, book: activeBook, run: bookRun, now: now)
            return
        }
        if current.isFinished(at: now),
           let next = Cycle.make(startHour: startHour, now: now,
                                 ids: QuoteLibrary.all.map(\.id), previous: current) {
            save(next)
            current = next
            focusedSlot = nil
        }
        await NotificationScheduler.apply(sayings: sayingsEnabled ? current : nil,
                                          book: activeBook, run: bookRun, now: now)
        BackgroundRefresh.schedule()
    }

    /// Called every minute. Only publishes when something on screen would actually change
    /// (a saying or card arrives, or the day turns), so open screens aren't redrawn for nothing.
    func tick() {
        let date = Date()
        let changed = cycle?.latestDeliveredSlot(at: date) != latestSlot
            || bookRun?.latestDelivered(at: date) != latestCard
            || !Calendar.current.isDate(date, inSameDayAs: now)
        if changed { now = date }
    }

    func openFromNotification(slot: Int) {
        guard let cycle, cycle.order.indices.contains(slot) else { return }
        now = Date()
        focusedSlot = slot
    }

    func sendTest() async {
        let quote = displayedSlot.flatMap { cycle?.quote(ofSlot: $0) } ?? QuoteLibrary.all.first
        if let quote { await NotificationScheduler.sendTest(NotificationScheduler.content(for: quote, slot: nil)) }
    }

    func sendBookTest() async {
        guard let book = activeBook ?? books.first else { return }
        let index = latestCard ?? 0
        await NotificationScheduler.sendTest(NotificationScheduler.content(for: book, cardIndex: index))
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

/// Imported books live as files in Documents/Books.
enum BookShelf {
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("Books", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "-")
        return folder.appendingPathComponent(safe).appendingPathExtension("hikmabook")
    }

    static func save(_ data: Data, id: String) throws {
        try data.write(to: url(for: id), options: .atomic)
    }

    static func delete(id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    static func loadAll() -> [Book] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "hikmabook" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
            .compactMap { try? Book.decode(Data(contentsOf: $0)) }
    }
}
