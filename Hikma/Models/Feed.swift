import Foundation

/// One idea in the scrolling feed: a saying, or a card from an imported book.
enum FeedItem: Identifiable, Hashable {
    case quote(Quote)
    case card(book: Book, index: Int)

    var id: String {
        switch self {
        case .quote(let quote): return "q:" + quote.id
        case .card(let book, let index): return "b:" + book.id + ":" + book.cards[index].id
        }
    }

    static func == (lhs: FeedItem, rhs: FeedItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var shareText: String {
        switch self {
        case .quote(let quote): return quote.shareText
        case .card(let book, let index): return book.cards[index].shareText(book: book)
        }
    }
}

/// What the feed shows.
enum FeedFilter: Hashable {
    case all
    case sayings
    case book(String)   // book id
}

enum Feed {
    /// All items for a filter, mixed in an order that stays the same for the whole day
    /// (so scrolling back finds the same cards) and changes the next day.
    static func items(filter: FeedFilter, quotes: [Quote], books: [Book], day: Date,
                      calendar: Calendar = .current) -> [FeedItem] {
        let sayings = quotes.map(FeedItem.quote)
        let bookItems: (Book) -> [FeedItem] = { book in
            book.cards.indices.map { FeedItem.card(book: book, index: $0) }
        }

        let seed = UInt64(calendar.ordinality(of: .day, in: .era, for: day) ?? 1)
        var rng = SeededGenerator(seed: seed)

        switch filter {
        case .sayings:
            return sayings.shuffled(using: &rng)
        case .book(let id):
            // A single book reads in order, like the book itself.
            return books.first { $0.id == id }.map(bookItems) ?? []
        case .all:
            // Sayings shuffled; each book's cards keep their order but are spread through the feed.
            var result = sayings.shuffled(using: &rng)
            for book in books {
                let cards = bookItems(book)
                guard !cards.isEmpty else { continue }
                let total = result.count + cards.count
                let step = Double(total) / Double(cards.count)
                for (n, card) in cards.enumerated() {
                    let position = min(result.count, Int(Double(n) * step + step / 2))
                    result.insert(card, at: position)
                }
            }
            return result
        }
    }
}

/// Small deterministic random generator (SplitMix64) for a stable daily order.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
