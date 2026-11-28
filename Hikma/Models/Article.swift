import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// One long chapter article (`.hikmaarticle`, JSON inside).
    static let hikmaArticle = UTType(exportedAs: "com.hikma.article", conformingTo: .json)
}

/// A long study article covering one chapter of a book.
/// The text is an HTML fragment (headings, paragraphs, tables, inline SVG figures);
/// the app wraps it in its own reading style, so the look can change without new files.
struct Article: Codable, Identifiable, Equatable {
    let format: Int?
    let id: String
    let bookID: String
    let book: String
    let author: String
    let topic: String
    let language: String?
    let chapter: Int
    let title: String
    let subtitle: String?
    let minutes: Int?
    let html: String

    var isEnglish: Bool { (language ?? "en").lowercased().hasPrefix("en") }

    enum ArticleError: LocalizedError {
        case empty
        var errorDescription: String? { "ملف المقال فارغ أو غير صالح." }
    }

    static func decode(_ data: Data) throws -> Article {
        let article = try JSONDecoder().decode(Article.self, from: data)
        guard !article.id.isEmpty, !article.html.isEmpty else { throw ArticleError.empty }
        return article
    }
}

/// Article files kept in the app's Documents/Articles folder.
enum ArticleShelf {
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("Articles", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "-")
        return folder.appendingPathComponent(safe).appendingPathExtension("hikmaarticle")
    }

    static func save(_ data: Data, id: String) throws {
        try data.write(to: url(for: id), options: .atomic)
    }

    static func delete(id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    static func loadAll() -> [Article] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "hikmaarticle" }
            .compactMap { try? Article.decode(Data(contentsOf: $0)) }
            .sorted { ($0.book, $0.chapter) < ($1.book, $1.chapter) }
    }
}
