import SwiftUI
import WebKit

// MARK: - Articles tab

/// Long chapter articles, grouped by book and ordered by chapter.
struct ArticlesView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var importing = false
    @State private var opened: Article?

    private var books: [(name: String, items: [Article])] {
        Dictionary(grouping: store.articles, by: \.book)
            .map { ($0.key, $0.value.sorted { $0.chapter < $1.chapter }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.articles.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(books, id: \.name) { group in
                            Section {
                                ForEach(group.items) { article in
                                    Button { opened = article } label: { row(article) }
                                        .buttonStyle(.plain)
                                        .listRowBackground(Theme.card)
                                        .swipeActions {
                                            Button(role: .destructive) { store.deleteArticle(article) } label: {
                                                Label("حذف", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text(group.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .textCase(nil)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.paper)
            .navigationTitle("مقالات")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                        .accessibilityLabel("استيراد مقال")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.hikmaArticle, .json],
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                let failed = urls.filter { (try? store.importArticle(from: $0)) == nil }.count
                store.justImportedArticleID = nil
                if failed > 0 { store.importError = "تعذّر قراءة \(Arabic.number(failed)) من الملفات المختارة." }
            }
            .fullScreenCover(item: $opened) { article in ArticleReaderView(article: article) }
            .onChange(of: store.justImportedArticleID) { _, id in
                if let id, let article = store.articles.first(where: { $0.id == id }) {
                    opened = article
                    store.justImportedArticleID = nil
                }
            }
        }
        .tint(Theme.ink)
    }

    private func row(_ article: Article) -> some View {
        let read = store.isRead(article)
        return HStack(alignment: .top, spacing: 14) {
            Text(article.isEnglish ? "\(article.chapter)" : Arabic.number(article.chapter))
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink.opacity(read ? 0.55 : 1))
                    .multilineTextAlignment(.leading)
                if let subtitle = article.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if let minutes = article.minutes {
                    Text(article.isEnglish ? "\(minutes) min read" : "\(Arabic.number(minutes)) دقيقة قراءة")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 4)
            if read {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 6)
        .environment(\.layoutDirection, article.isEnglish ? .leftToRight : .rightToLeft)
        .contentShape(Rectangle())
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(Theme.accent)
            Text("لا مقالات بعد")
                .font(.system(size: 17, weight: .semibold))
            Text("افتح ملف المقال (‎.hikmaarticle‎) بتطبيق حكمة، أو استورده من هنا.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("استيراد مقال") { importing = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reader

/// Full-screen reader for one article. Remembers where you stopped.
struct ArticleReaderView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss
    let article: Article

    var body: some View {
        NavigationStack {
            ArticleWebView(article: article)
                .ignoresSafeArea(edges: .bottom)
                .background(Theme.paper)
                .navigationTitle(article.book)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(article.isEnglish ? "Done" : "تم") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        let read = store.isRead(article)
                        Button {
                            withAnimation { store.toggleRead(article) }
                        } label: {
                            Image(systemName: read ? "checkmark.circle.fill" : "circle")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .sensoryFeedback(.success, trigger: read)
                        .accessibilityLabel(read ? (article.isEnglish ? "Read" : "مقروء")
                                                 : (article.isEnglish ? "Mark as read" : "علّمه مقروءًا"))
                    }
                }
        }
        .tint(Theme.ink)
    }
}

/// The article text in a web view: native selection with Look Up and Translate,
/// tables and inline SVG figures, light and dark mode, and a remembered scroll position.
struct ArticleWebView: UIViewRepresentable {
    let article: Article

    func makeCoordinator() -> Coordinator { Coordinator(articleID: article.id) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        view.scrollView.delegate = context.coordinator
        view.loadHTMLString(ArticleTemplate.page(for: article), baseURL: nil)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.save(view.scrollView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        let key: String
        init(articleID: String) { key = "hikma.articleOffset." + articleID }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let fraction = UserDefaults.standard.double(forKey: key)
            guard fraction > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let scroll = webView.scrollView
                let maxY = max(0, scroll.contentSize.height - scroll.bounds.height)
                scroll.setContentOffset(CGPoint(x: 0, y: maxY * fraction), animated: false)
            }
        }

        // Links inside an article open in Safari, never inside the reader.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func scrollViewDidEndDecelerating(_ scroll: UIScrollView) { save(scroll) }
        func scrollViewDidEndDragging(_ scroll: UIScrollView, willDecelerate: Bool) {
            if !willDecelerate { save(scroll) }
        }

        func save(_ scroll: UIScrollView) {
            let maxY = scroll.contentSize.height - scroll.bounds.height
            guard maxY > 0 else { return }
            UserDefaults.standard.set(min(1, max(0, scroll.contentOffset.y / maxY)), forKey: key)
        }
    }
}

/// The reading style every article is shown in.
enum ArticleTemplate {
    static func page(for article: Article) -> String {
        let dir = article.isEnglish ? "ltr" : "rtl"
        let lang = article.isEnglish ? "en" : "ar"
        let chapterLabel = article.isEnglish ? "Chapter \(article.chapter)" : "الفصل \(Arabic.number(article.chapter))"
        let subtitle = article.subtitle.map { "<p class=\"subtitle\">\(escape($0))</p>" } ?? ""
        return """
        <!DOCTYPE html>
        <html lang="\(lang)" dir="\(dir)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <meta name="color-scheme" content="light dark">
        <style>\(css)</style>
        </head>
        <body>
        <header class="masthead">
          <p class="kicker">\(escape(chapterLabel)) · \(escape(article.book))</p>
          <h1>\(escape(article.title))</h1>
          \(subtitle)
          <p class="byline">\(escape(article.author))</p>
        </header>
        <article>\(article.html)</article>
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let css = """
    :root {
      --paper: #FAF8F4; --card: #FFFFFF; --ink: #1C1C1F; --soft: rgba(28,28,31,.72);
      --faint: rgba(28,28,31,.08); --accent: #B58C54; --accent-soft: rgba(181,140,84,.12);
    }
    @media (prefers-color-scheme: dark) {
      :root { --paper: #121213; --card: #1F1F21; --ink: #EDEDED; --soft: rgba(237,237,237,.74);
              --faint: rgba(237,237,237,.10); --accent: #C9A06A; --accent-soft: rgba(201,160,106,.16); }
    }
    * { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; }
    body { margin: 0; background: var(--paper); color: var(--ink);
           font: -apple-system-body; font-size: 17.5px; line-height: 1.72;
           padding: 8px 22px 80px; -webkit-hyphens: auto; }
    article, .masthead { max-width: 680px; margin: 0 auto; }
    .masthead { padding: 18px 0 8px; border-bottom: 1px solid var(--faint); margin-bottom: 22px; }
    .kicker { color: var(--accent); font-size: 12.5px; font-weight: 600; letter-spacing: .02em; margin: 0 0 8px; }
    h1 { font-family: "New York", ui-serif, Georgia, serif; font-size: 30px; line-height: 1.2; margin: 0 0 10px; }
    .subtitle { color: var(--soft); font-size: 17px; margin: 0 0 10px; }
    .byline { color: var(--soft); font-size: 13px; margin: 0 0 8px; }
    h2 { font-family: "New York", ui-serif, Georgia, serif; font-size: 23px; line-height: 1.3; margin: 38px 0 10px; }
    h3 { font-size: 18px; margin: 26px 0 6px; }
    p { margin: 0 0 16px; }
    strong { font-weight: 650; }
    ul, ol { padding-inline-start: 22px; margin: 0 0 16px; }
    li { margin-bottom: 7px; }
    blockquote { margin: 20px 0; padding: 2px 18px; border-inline-start: 3px solid var(--accent);
                 font-family: "New York", ui-serif, Georgia, serif; font-size: 18.5px; color: var(--soft); }
    .box { background: var(--card); border: 1px solid var(--faint); border-radius: 16px; padding: 16px 18px; margin: 22px 0; }
    .box h3, .box h4 { margin-top: 0; }
    .box.key { background: var(--accent-soft); border-color: transparent; }
    .box > :last-child { margin-bottom: 0; }
    .box-title { color: var(--accent); font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 8px; }
    table { width: 100%; border-collapse: collapse; margin: 18px 0 22px; font-size: 15px; line-height: 1.45; }
    .table-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }
    th, td { text-align: start; padding: 9px 10px; border-bottom: 1px solid var(--faint); vertical-align: top; }
    th { font-weight: 650; background: var(--card); }
    figure { margin: 26px 0; background: var(--card); border: 1px solid var(--faint); border-radius: 16px; padding: 14px; }
    figure svg, figure img { display: block; width: 100%; height: auto; }
    figcaption { color: var(--soft); font-size: 13.5px; line-height: 1.5; margin-top: 10px; }
    figure svg { color: var(--ink); }
    svg text { font-family: -apple-system, sans-serif; fill: currentColor; }
    svg .accent { fill: var(--accent); } svg .accent-stroke { stroke: var(--accent); }
    svg .soft { fill: var(--accent-soft); } svg .card { fill: var(--card); } svg .muted { fill: var(--soft); }
    .analysis { margin-top: 46px; padding: 22px 20px; border-radius: 20px; background: var(--accent-soft); }
    .analysis h2 { margin-top: 0; }
    .analysis-label { color: var(--accent); font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; }
    hr { border: none; border-top: 1px solid var(--faint); margin: 32px 0; }
    """
}
