import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A Hikma reading plan (`.hikmabook`, JSON inside).
    static let hikmaBook = UTType(exportedAs: "com.hikma.book", conformingTo: .json)
}

/// A book studied and turned into a sequence of idea cards.
struct Book: Codable, Identifiable, Equatable {
    let format: Int
    let id: String
    let title: String
    let originalTitle: String?
    let author: String
    let year: Int?
    let about: String
    let cards: [BookCard]

    static func decode(_ data: Data) throws -> Book {
        let book = try JSONDecoder().decode(Book.self, from: data)
        guard !book.id.isEmpty, !book.cards.isEmpty else { throw BookError.empty }
        return book
    }
}

struct BookCard: Codable, Identifiable, Equatable {
    let id: String
    /// e.g. "الفصل ٣ — ثمار دانية لصحة أفضل؟"
    let chapter: String
    let title: String
    let body: String
    /// One practical line: how to apply the idea.
    let apply: String?
}

enum BookError: LocalizedError {
    case empty
    var errorDescription: String? { "الملف لا يحتوي على خطة كتاب صالحة." }
}

/// An active reading plan: when each card of the book is delivered.
struct BookRun: Codable, Equatable {
    let bookID: String
    /// Cards per day (3 or 6).
    let perDay: Int
    /// Delivery time of each card, in order.
    let dates: [Date]

    var count: Int { dates.count }

    /// The latest card whose time has come, or nil before the first.
    func latestDelivered(at now: Date) -> Int? {
        dates.lastIndex(where: { $0 <= now })
    }

    func nextCard(after now: Date) -> Int? {
        dates.firstIndex(where: { $0 > now })
    }

    func isFinished(at now: Date) -> Bool {
        guard let last = dates.last else { return true }
        return now >= last
    }

    /// Number of calendar days the plan spans.
    static func days(cards: Int, perDay: Int) -> Int {
        Int((Double(cards) / Double(max(perDay, 1))).rounded(.up))
    }

    /// Book cards arrive 2 hours after the sayings (between them), so they never collide.
    /// 6 a day uses all six times; 3 a day uses three daytime ones.
    static func dailyHours(sayingsStartHour: Int, perDay: Int) -> [Int] {
        let all = (0..<6).map { (sayingsStartHour + 2 + $0 * 4) % 24 }.sorted()
        guard perDay < 6 else { return all }
        let firstDaytime = all.firstIndex(where: { $0 >= 9 }) ?? 0
        return (0..<perDay).map { all[(firstDaytime + $0) % all.count] }
    }

    static func make(book: Book, perDay: Int, sayingsStartHour: Int, now: Date,
                     calendar: Calendar = .current) -> BookRun {
        let hours = dailyHours(sayingsStartHour: sayingsStartHour, perDay: perDay)
        var dates: [Date] = []
        var day = calendar.startOfDay(for: now)
        while dates.count < book.cards.count {
            for hour in hours where dates.count < book.cards.count {
                if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now {
                    dates.append(date)
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        }
        return BookRun(bookID: book.id, perDay: perDay, dates: dates)
    }
}
