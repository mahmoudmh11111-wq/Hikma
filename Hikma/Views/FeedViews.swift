import SwiftUI

// MARK: - Tabs

/// Explore (the scrolling feed) · Today (today's cards and the book) · Saved.
struct MainTabView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            FeedView()
                .background(Theme.paper.ignoresSafeArea())
                .tabItem { Label("استكشف", systemImage: "rectangle.stack") }
                .tag(0)
            HomeView()
                .background(Theme.paper.ignoresSafeArea())
                .tabItem { Label("اليوم", systemImage: "sun.max") }
                .tag(1)
            SavedView()
                .background(Theme.paper.ignoresSafeArea())
                .tabItem { Label("المحفوظات", systemImage: "bookmark") }
                .tag(2)
        }
        .toolbarBackground(Theme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        // A tapped notification opens its card in "Today".
        .onChange(of: store.focusedSlot) { _, slot in if slot != nil { tab = 1 } }
        .onChange(of: store.focusedCard) { _, card in if card != nil { tab = 1 } }
        .onChange(of: store.justImportedBookID) { _, id in if id != nil { tab = 1 } }
    }
}

// MARK: - Feed

/// One slot in the endless feed: the same idea can come round again on a later pass.
private struct FeedEntry: Identifiable, Hashable {
    let pass: Int
    let item: FeedItem
    var id: String { "\(pass)|\(item.id)" }
}

/// A continuous, free-scrolling feed of ideas. Cards show their full text,
/// ease in and out at the edges, and the feed refills itself as you near the end.
struct FeedView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var filter: FeedFilter = .all
    @State private var base: [FeedItem] = []
    @State private var entries: [FeedEntry] = []
    @State private var passes = 0
    @State private var position: String?
    @State private var detail: FeedItem?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 14) {
                    Color.clear.frame(height: 0).id("top")
                    ForEach(entries) { entry in
                        FeedCard(item: entry.item) { detail = entry.item }
                            .frame(maxWidth: 640)
                            .padding(.horizontal, 16)
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.965)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                            .onAppear { extendIfNeeded(after: entry) }
                            .id(entry.id)
                    }
                    if entries.isEmpty {
                        emptyState
                    }
                }
                .padding(.vertical, 12)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $position, anchor: .top)
            .refreshable { reshuffle() }
            .safeAreaInset(edge: .top, spacing: 0) { filterBar }
            .onChange(of: filter) { _, _ in
                reload()
                withAnimation(.smooth(duration: 0.35)) { proxy.scrollTo("top", anchor: .top) }
            }
        }
        .onAppear { if entries.isEmpty { reload() } }
        .onChange(of: store.books.map(\.id)) { _, _ in
            if case .book(let id) = filter, !store.books.contains(where: { $0.id == id }) { filter = .all }
            if case .topic(let name) = filter, !store.topics.contains(name) { filter = .all }
            reload(keepPosition: true)
        }
        .sheet(item: $detail) { item in FeedDetailView(item: item) }
    }

    // MARK: Endless feed

    private func reload(keepPosition: Bool = false) {
        base = store.feed(filter)
        passes = 1
        entries = base.map { FeedEntry(pass: 0, item: $0) }
        if !keepPosition || !entries.contains(where: { $0.id == position }) {
            position = entries.first?.id
        }
    }

    /// Pull to refresh: a fresh order of the same ideas.
    private func reshuffle() {
        base = base.shuffled()
        passes = 1
        entries = base.map { FeedEntry(pass: 0, item: $0) }
        position = entries.first?.id
    }

    /// When a card a few from the end appears, quietly append another shuffled pass.
    private func extendIfNeeded(after entry: FeedEntry) {
        guard base.count > 1, let index = entries.firstIndex(of: entry),
              index >= entries.count - 4 else { return }
        var next = base.shuffled()
        // Avoid the same idea twice in a row across the seam.
        if next.first == entries.last?.item, next.count > 1 { next.swapAt(0, 1) }
        entries += next.map { FeedEntry(pass: passes, item: $0) }
        passes += 1
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Theme.accent)
            Text("لا شيء هنا بعد")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.top, 120)
    }

    // MARK: Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("الكل", .all)
                chip("حِكَم", .sayings)
                ForEach(store.topics, id: \.self) { topic in
                    chip(topic, .topic(topic))
                }
                if store.books.count > 1 {
                    Menu {
                        ForEach(store.topics, id: \.self) { topic in
                            Section(topic) {
                                ForEach(store.books.filter { $0.topicName == topic }) { book in
                                    Button(book.title) { filter = .book(book.id) }
                                }
                            }
                        }
                    } label: {
                        Label(bookChipTitle, systemImage: "book.closed")
                            .font(.system(size: 13, weight: isBookFilter ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isBookFilter ? Theme.ink : Theme.ink.opacity(0.06), in: Capsule())
                            .foregroundStyle(isBookFilter ? Theme.paper : Theme.ink)
                    }
                } else if let book = store.books.first {
                    chip(book.title, .book(book.id))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    private var isBookFilter: Bool {
        if case .book = filter { return true }
        return false
    }

    private var bookChipTitle: String {
        if case .book(let id) = filter, let book = store.books.first(where: { $0.id == id }) { return book.title }
        return "كتاب"
    }

    private func chip(_ title: String, _ value: FeedFilter) -> some View {
        let isOn = filter == value
        return Button {
            withAnimation(.smooth(duration: 0.25)) { filter = value }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? Theme.ink : Theme.ink.opacity(0.06), in: Capsule())
                .foregroundStyle(isOn ? Theme.paper : Theme.ink)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// One idea card in the feed, sized to its full content.
struct FeedCard: View {
    @EnvironmentObject private var store: HikmaStore
    let item: FeedItem
    let onOpen: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            content
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tint(for: item.id), in: shape)
        .overlay(shape.strokeBorder(Theme.ink.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
        .contentShape(shape)
        .onTapGesture(perform: onOpen)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: kickerIcon)
                .font(.system(size: 11, weight: .semibold))
            Text(kicker)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.accent)
    }

    @ViewBuilder private var content: some View {
        switch item {
        case .quote(let quote):
            VStack(alignment: .leading, spacing: 16) {
                Text(quote.text)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .lineSpacing(10)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Capsule().fill(Theme.accent).frame(width: 28, height: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(quote.sayer)
                        .font(Theme.sayerFont)
                        .foregroundStyle(Theme.ink)
                    Text(quote.source)
                        .font(Theme.sourceFont)
                        .foregroundStyle(.secondary)
                }
            }
        case .card(let book, let index):
            let card = book.cards[index]
            VStack(alignment: .leading, spacing: 12) {
                Text(card.title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.body)
                    .font(.system(size: 16.5))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.ink.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                if let apply = card.apply, !apply.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(book.applyLabel, systemImage: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text(apply)
                            .font(.system(size: 15, weight: .medium))
                            .lineSpacing(4)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 4)
                }
            }
            .environment(\.layoutDirection, book.direction)
        }
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Text(footnote)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button {
                withAnimation(.spring(duration: 0.3)) { store.toggleSaved(item) }
            } label: {
                Image(systemName: store.isSaved(item) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(store.isSaved(item) ? Theme.accent : Theme.ink)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: store.isSaved(item))
            ShareLink(item: item.shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
    }

    private var kicker: String {
        switch item {
        case .quote(let quote): return quote.culture
        case .card(let book, _): return book.title
        }
    }

    private var kickerIcon: String {
        switch item {
        case .quote: return "quote.opening"
        case .card: return "book.closed"
        }
    }

    private var footnote: String {
        switch item {
        case .quote: return "حكمة"
        case .card(let book, let index):
            let n = book.isEnglish ? "\(index + 1)/\(book.cards.count)" : "\(Arabic.number(index + 1))/\(Arabic.number(book.cards.count))"
            return "\(book.cards[index].chapter) · \(n)"
        }
    }
}

/// The full idea, opened from the feed or from Saved.
struct FeedDetailView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss
    let item: FeedItem

    var body: some View {
        NavigationStack {
            FeedItemDetail(item: item)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("تم") { dismiss() }
                    }
                }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tint(Theme.ink)
    }
}

struct FeedItemDetail: View {
    @EnvironmentObject private var store: HikmaStore
    let item: FeedItem

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            switch item {
            case .quote(let quote):
                ScrollView {
                    QuoteView(quote: quote, showsOriginal: true)
                        .padding(28)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                }
            case .card(let book, let index):
                BookCardView(book: book, index: index, date: nil)
                    .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    store.toggleSaved(item)
                } label: {
                    Image(systemName: store.isSaved(item) ? "bookmark.fill" : "bookmark")
                }
                ShareLink(item: item.shareText) { Image(systemName: "square.and.arrow.up") }
            }
        }
    }
}

// MARK: - Saved

struct SavedView: View {
    @EnvironmentObject private var store: HikmaStore

    var body: some View {
        NavigationStack {
            Group {
                let saved = store.savedItems
                if saved.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 30, weight: .ultraLight))
                            .foregroundStyle(Theme.accent)
                        Text("لا شيء محفوظ بعد")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("اضغط علامة الحفظ على أي فكرة في «استكشف» لتجدها هنا.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(saved) { item in
                            NavigationLink {
                                FeedItemDetail(item: item)
                            } label: {
                                row(item)
                            }
                            .listRowBackground(Theme.paper)
                        }
                        .onDelete { offsets in
                            for index in offsets { store.toggleSaved(saved[index]) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.paper)
            .navigationTitle("المحفوظات")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ item: FeedItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                switch item {
                case .quote(let quote):
                    Text(quote.text)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(quote.sayer)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                case .card(let book, let index):
                    Text(book.cards[index].title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(book.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
