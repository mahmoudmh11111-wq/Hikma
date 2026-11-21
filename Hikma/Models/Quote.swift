import Foundation

/// One saying, already translated into Arabic.
struct Quote: Codable, Identifiable, Hashable {
    let id: String
    /// Where the saying comes from (country, people or civilisation), in Arabic.
    let culture: String
    /// Who said it, in Arabic.
    let sayer: String
    /// The book, speech or tradition it comes from, in Arabic.
    let source: String
    /// The saying in Arabic.
    let text: String
    /// The saying in its original language, when that isn't Arabic.
    let original: String?
}

/// The curated library shipped inside the app (Resources/Quotes.json).
enum QuoteLibrary {
    private final class BundleToken {}

    static let all: [Quote] = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "Quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data)
        else { return [] }
        return quotes
    }()

    private static let byID: [String: Quote] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func quote(id: String) -> Quote? { byID[id] }

    static var cultureCount: Int { Set(all.map(\.culture)).count }
}
