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
    @StateObject private var speaker: ArticleSpeaker
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("hikma.readerTheme") private var themeRaw = "auto"
    @AppStorage("hikma.readerFont") private var fontRaw = ReaderFont.standard.rawValue
    @AppStorage("hikma.readerSize") private var size = 17.5
    @State private var showSettings = false

    /// Until you pick a background, the reader follows the phone's light or dark mode.
    private var theme: ReaderTheme {
        ReaderTheme(rawValue: themeRaw) ?? (systemScheme == .dark ? .night : .day)
    }

    private var appearance: ReaderAppearance {
        ReaderAppearance(theme: theme, font: ReaderFont(rawValue: fontRaw) ?? .standard, size: size)
    }

    init(article: Article) {
        self.article = article
        _speaker = StateObject(wrappedValue: ArticleSpeaker(english: article.isEnglish, title: article.title))
    }

    var body: some View {
        NavigationStack {
            ArticleWebView(article: article, speaker: speaker, appearance: appearance)
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ReadAloudBar(speaker: speaker, english: article.isEnglish, theme: theme)
                }
                .onDisappear { speaker.stop() }
                .background(theme.paper.ignoresSafeArea())
                .toolbarBackground(theme.paper, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .sheet(isPresented: $showSettings) {
                    ReaderSettingsSheet(themeRaw: $themeRaw, fontRaw: $fontRaw, size: $size,
                                        current: theme, english: article.isEnglish)
                }
                .navigationTitle(article.book)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(article.isEnglish ? "Done" : "تم") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { showSettings = true } label: {
                            Image(systemName: "textformat.size")
                        }
                        .accessibilityLabel(article.isEnglish ? "Themes & Settings" : "المظهر والإعدادات")
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
        .tint(theme.ink)
        .preferredColorScheme(ReaderTheme(rawValue: themeRaw).map { $0.isDark ? .dark : .light })
    }
}

/// Read-aloud controls: previous paragraph, play/pause, next paragraph, and speed.
struct ReadAloudBar: View {
    @ObservedObject var speaker: ArticleSpeaker
    let english: Bool
    var theme: ReaderTheme = .day

    var body: some View {
        HStack(spacing: 6) {
            Button { speaker.skip(-1) } label: {
                Image(systemName: english ? "backward.fill" : "forward.fill").font(.system(size: 15))
                    .frame(width: 44, height: 44)
            }
            .disabled(!speaker.isActive)
            .accessibilityLabel(english ? "Previous paragraph" : "الفقرة السابقة")

            Button { speaker.togglePlay() } label: {
                Image(systemName: speaker.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(theme.paper)
                    .frame(width: 48, height: 48)
                    .background(theme.ink, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(!speaker.isReady)
            .accessibilityLabel(speaker.isPlaying ? (english ? "Pause" : "إيقاف مؤقت")
                                                  : (english ? "Read aloud" : "اقرأ لي"))

            Button { speaker.skip(1) } label: {
                Image(systemName: english ? "forward.fill" : "backward.fill").font(.system(size: 15))
                    .frame(width: 44, height: 44)
            }
            .disabled(!speaker.isActive)
            .accessibilityLabel(english ? "Next paragraph" : "الفقرة التالية")

            Spacer(minLength: 8)

            Menu {
                Picker(english ? "Reading speed" : "سرعة القراءة", selection: $speaker.speed) {
                    ForEach(ArticleSpeaker.Speed.allCases, id: \.self) { speed in
                        Label(speed.label(english: english), systemImage: speed.symbol).tag(speed)
                    }
                }
            } label: {
                Label(speaker.speed.label(english: english), systemImage: speaker.speed.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(theme.ink.opacity(0.08), in: Capsule())
            }
            .accessibilityLabel(english ? "Reading speed" : "سرعة القراءة")

            if speaker.isActive {
                Button { speaker.stop() } label: {
                    Image(systemName: "stop.fill").font(.system(size: 13))
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel(english ? "Stop reading" : "إيقاف القراءة")
                .transition(.opacity)
            }
        }
        .foregroundStyle(theme.ink)
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.paper.opacity(0.94).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider().opacity(0.5) }
        .environment(\.layoutDirection, english ? .leftToRight : .rightToLeft)
        .animation(.easeInOut(duration: 0.2), value: speaker.isActive)
    }
}

/// The article text in a web view: native selection with Look Up and Translate,
/// tables and inline SVG figures, light and dark mode, and a remembered scroll position.
struct ArticleWebView: UIViewRepresentable {
    let article: Article
    var speaker: ArticleSpeaker? = nil
    var appearance = ReaderAppearance()

    func makeCoordinator() -> Coordinator { Coordinator(articleID: article.id, speaker: speaker) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        view.scrollView.delegate = context.coordinator
        view.scrollView.indicatorStyle = appearance.theme.isDark ? .white : .black
        context.coordinator.applied = appearance
        view.loadHTMLString(ArticleTemplate.page(for: article, appearance: appearance), baseURL: nil)
        return view
    }

    /// Applies theme, font and size changes live, keeping your place in the text.
    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.applied != appearance else { return }
        context.coordinator.applied = appearance
        view.scrollView.indicatorStyle = appearance.theme.isDark ? .white : .black
        let js = """
        (function () {
          var d = document.documentElement, se = document.scrollingElement;
          var max = Math.max(1, se.scrollHeight - se.clientHeight), r = se.scrollTop / max;
          d.setAttribute('data-theme', '\(appearance.theme.css)');
          d.setAttribute('data-font', '\(appearance.font.rawValue)');
          d.style.setProperty('--fs', '\(appearance.size)px');
          requestAnimationFrame(function () { se.scrollTop = r * (se.scrollHeight - se.clientHeight); });
        })();
        """
        view.evaluateJavaScript(js)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.save(view.scrollView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        let key: String
        weak var speaker: ArticleSpeaker?
        var applied: ReaderAppearance?
        init(articleID: String, speaker: ArticleSpeaker?) {
            key = "hikma.articleOffset." + articleID
            self.speaker = speaker
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            speaker?.attach(webView)
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
    static func page(for article: Article, appearance: ReaderAppearance) -> String {
        let dir = article.isEnglish ? "ltr" : "rtl"
        let lang = article.isEnglish ? "en" : "ar"
        let chapterLabel = article.isEnglish ? "Chapter \(article.chapter)" : "الفصل \(Arabic.number(article.chapter))"
        let subtitle = article.subtitle.map { "<p class=\"subtitle\">\(escape($0))</p>" } ?? ""
        return """
        <!DOCTYPE html>
        <html lang="\(lang)" dir="\(dir)" data-theme="\(appearance.theme.css)" data-font="\(appearance.font.rawValue)" style="--fs: \(appearance.size)px">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
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
    :root, [data-theme="day"], [data-theme="invert"] {
      --paper: #FAF8F4; --card: #FFFFFF; --ink: #1C1C1F; --soft: rgba(28,28,31,.72);
      --faint: rgba(28,28,31,.08); --accent: #B58C54; --accent-soft: rgba(181,140,84,.12);
    }
    [data-theme="night"] {
      --paper: #121213; --card: #1F1F21; --ink: #E4E4E4; --soft: rgba(228,228,228,.72);
      --faint: rgba(228,228,228,.10); --accent: #C9A06A; --accent-soft: rgba(201,160,106,.16);
    }
    [data-theme="eye"] {
      --paper: #CCE8CF; --card: #DCEFDE; --ink: #1E2B21; --soft: rgba(30,43,33,.74);
      --faint: rgba(30,43,33,.12); --accent: #3D7A4D; --accent-soft: rgba(61,122,77,.14);
    }
    [data-theme="vintage"] {
      --paper: #F1E5C9; --card: #F8EFDA; --ink: #47392A; --soft: rgba(71,57,42,.76);
      --faint: rgba(71,57,42,.13); --accent: #8C5A2B; --accent-soft: rgba(140,90,43,.14);
    }
    [data-theme="invert"] { filter: invert(1) hue-rotate(180deg); }
    html { background: var(--paper); }
    [data-font="standard"] body { font-family: -apple-system, system-ui, sans-serif; }
    [data-font="serif"] body { font-family: "New York", ui-serif, Georgia, "Times New Roman", serif; }
    [data-font="rounded"] body { font-family: ui-rounded, "SF Pro Rounded", -apple-system, system-ui, sans-serif; }
    * { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; }
    body { margin: 0; background: var(--paper); color: var(--ink);
           font-size: var(--fs, 17.5px); line-height: 1.72;
           padding: 8px 22px 120px; -webkit-hyphens: auto; }
    article, .masthead { max-width: 680px; margin: 0 auto; }
    .masthead { padding: 18px 0 8px; border-bottom: 1px solid var(--faint); margin-bottom: 22px; }
    .kicker { color: var(--accent); font-size: 0.714em; font-weight: 600; letter-spacing: .02em; margin: 0 0 8px; }
    h1 { font-family: "New York", ui-serif, Georgia, serif; font-size: 1.714em; line-height: 1.2; margin: 0 0 10px; }
    .subtitle { color: var(--soft); font-size: 0.971em; margin: 0 0 10px; }
    .byline { color: var(--soft); font-size: 0.743em; margin: 0 0 8px; }
    h2 { font-family: "New York", ui-serif, Georgia, serif; font-size: 1.314em; line-height: 1.3; margin: 38px 0 10px; }
    h3 { font-size: 1.029em; margin: 26px 0 6px; }
    p { margin: 0 0 16px; }
    strong { font-weight: 650; }
    ul, ol { padding-inline-start: 22px; margin: 0 0 16px; }
    li { margin-bottom: 7px; }
    blockquote { margin: 20px 0; padding: 2px 18px; border-inline-start: 3px solid var(--accent);
                 font-family: "New York", ui-serif, Georgia, serif; font-size: 1.057em; color: var(--soft); }
    .box { background: var(--card); border: 1px solid var(--faint); border-radius: 16px; padding: 16px 18px; margin: 22px 0; }
    .box h3, .box h4 { margin-top: 0; }
    .box.key { background: var(--accent-soft); border-color: transparent; }
    .box > :last-child { margin-bottom: 0; }
    .box-title { color: var(--accent); font-size: 0.686em; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 8px; }
    table { width: 100%; border-collapse: collapse; margin: 18px 0 22px; font-size: 0.857em; line-height: 1.45; }
    .table-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }
    th, td { text-align: start; padding: 9px 10px; border-bottom: 1px solid var(--faint); vertical-align: top; }
    th { font-weight: 650; background: var(--card); }
    figure { margin: 26px 0; background: var(--card); border: 1px solid var(--faint); border-radius: 16px; padding: 14px; }
    figure svg, figure img { display: block; width: 100%; height: auto; }
    figcaption { color: var(--soft); font-size: 0.771em; line-height: 1.5; margin-top: 10px; }
    figure svg { color: var(--ink); }
    svg text { font-family: -apple-system, sans-serif; fill: currentColor; }
    svg .accent { fill: var(--accent); } svg .accent-stroke { stroke: var(--accent); }
    svg .soft { fill: var(--accent-soft); } svg .card { fill: var(--card); } svg .muted { fill: var(--soft); }
    .analysis { margin-top: 46px; padding: 22px 20px; border-radius: 20px; background: var(--accent-soft); }
    .analysis h2 { margin-top: 0; }
    .analysis-label { color: var(--accent); font-size: 0.686em; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; }
    .tts-current { background: var(--accent-soft); border-radius: 8px; box-shadow: 0 0 0 6px var(--accent-soft); transition: background .25s; }
    hr { border: none; border-top: 1px solid var(--faint); margin: 32px 0; }
    """
}

// MARK: - Reading appearance (Apple Books–style themes & settings)

enum ReaderTheme: String, CaseIterable {
    case day, night, eye, vintage, invert

    var css: String { rawValue }
    var isDark: Bool { self == .night || self == .invert }

    func label(english: Bool) -> String {
        switch self {
        case .day: return english ? "Day" : "نهاري"
        case .night: return english ? "Night" : "ليلي"
        case .eye: return english ? "Eye Protection" : "حماية العين"
        case .vintage: return english ? "Vintage" : "عتيق"
        case .invert: return english ? "Invert Colors" : "عكس الألوان"
        }
    }

    /// Page colour, used for the reader's own bars too.
    var paper: Color {
        switch self {
        case .day: return Color(red: 0.980, green: 0.973, blue: 0.957)
        case .night: return Color(red: 0.071, green: 0.071, blue: 0.075)
        case .eye: return Color(red: 0.800, green: 0.910, blue: 0.812)
        case .vintage: return Color(red: 0.945, green: 0.898, blue: 0.788)
        case .invert: return Color(red: 0.020, green: 0.027, blue: 0.043)
        }
    }

    var ink: Color {
        switch self {
        case .day: return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .night: return Color(white: 0.89)
        case .eye: return Color(red: 0.118, green: 0.169, blue: 0.129)
        case .vintage: return Color(red: 0.278, green: 0.224, blue: 0.165)
        case .invert: return Color(white: 0.95)
        }
    }
}

enum ReaderFont: String, CaseIterable {
    case standard, serif, rounded

    func label(english: Bool) -> String {
        switch self {
        case .standard: return english ? "Standard" : "عادي"
        case .serif: return english ? "Serif" : "كتابي"
        case .rounded: return english ? "Rounded" : "دائري"
        }
    }

    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
}

struct ReaderAppearance: Equatable {
    var theme: ReaderTheme = .day
    var font: ReaderFont = .standard
    var size: Double = 17.5

    static let sizes: [Double] = [14, 15.5, 17.5, 19.5, 22, 25, 28, 32]
}

/// The Aa panel: smaller/larger text, font, and page background.
struct ReaderSettingsSheet: View {
    @Binding var themeRaw: String
    @Binding var fontRaw: String
    @Binding var size: Double
    let current: ReaderTheme
    let english: Bool

    private var sizeIndex: Int {
        ReaderAppearance.sizes.firstIndex { $0 >= size - 0.01 } ?? 2
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(english ? "Themes & Settings" : "المظهر والإعدادات")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 6)

            // Smaller A | larger A, like Apple Books.
            HStack(spacing: 0) {
                Button { step(-1) } label: {
                    Text("A").font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .disabled(sizeIndex == 0)
                .accessibilityLabel(english ? "Smaller text" : "تصغير الخط")
                Rectangle().fill(.secondary.opacity(0.3)).frame(width: 1, height: 26)
                Button { step(1) } label: {
                    Text("A").font(.system(size: 25, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .disabled(sizeIndex == ReaderAppearance.sizes.count - 1)
                .accessibilityLabel(english ? "Larger text" : "تكبير الخط")
            }
            .buttonStyle(.plain)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottom) {
                HStack(spacing: 5) {
                    ForEach(ReaderAppearance.sizes.indices, id: \.self) { i in
                        Circle().fill(i <= sizeIndex ? Color.primary : Color.secondary.opacity(0.35))
                            .frame(width: 4, height: 4)
                    }
                }
                .offset(y: 12)
            }
            .padding(.bottom, 6)

            Picker(english ? "Font" : "الخط", selection: $fontRaw) {
                ForEach(ReaderFont.allCases, id: \.rawValue) { font in
                    Text(font.label(english: english)).tag(font.rawValue)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text(english ? "Display Background" : "خلفية العرض")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    ForEach(ReaderTheme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { themeRaw = theme.rawValue }
                        } label: {
                            VStack(spacing: 6) {
                                Text("Aa")
                                    .font(.system(size: 17, weight: .semibold,
                                                  design: ReaderFont(rawValue: fontRaw)?.design ?? .default))
                                    .foregroundStyle(theme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(theme == current ? Theme.accent : .secondary.opacity(0.25),
                                                          lineWidth: theme == current ? 2.5 : 0.5)
                                    )
                                Text(theme.label(english: english))
                                    .font(.system(size: 10.5, weight: theme == current ? .semibold : .regular))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(theme == current ? .isSelected : [])
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .presentationDetents([.height(370)])
        .presentationDragIndicator(.visible)
        .environment(\.layoutDirection, english ? .leftToRight : .rightToLeft)
        .sensoryFeedback(.selection, trigger: size)
        .sensoryFeedback(.selection, trigger: themeRaw)
    }

    private func step(_ delta: Int) {
        let sizes = ReaderAppearance.sizes
        size = sizes[min(max(0, sizeIndex + delta), sizes.count - 1)]
    }
}
