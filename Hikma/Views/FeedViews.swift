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

/// A full-screen vertical feed of ideas: swipe up for the next one.
struct FeedView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var filter: FeedFilter = .all
    @State private var items: [FeedItem] = []
    @State private var position: String?
    @State private var detail: FeedItem?

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        FeedCard(item: item) { detail = item }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .scrollTransition(axis: .vertical) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                            }
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $position)
        }
        .onAppear { if items.isEmpty { reload() } }
        .onChange(of: filter) { _, _ in reload(resetPosition: true) }
        .onChange(of: store.books.map(\.id)) { _, _ in
            if case .book(let id) = filter, !store.books.contains(where: { $0.id == id }) { filter = .all }
            reload()
        }
        .sheet(item: $detail) { item in FeedDetailView(item: item) }
    }

    private func reload(resetPosition: Bool = false) {
        items = store.feed(filter)
        if resetPosition || position == nil || !items.contains(where: { $0.id == position }) {
            position = items.first?.id
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("الكل", .all)
                chip("حِكَم", .sayings)
                ForEach(store.books) { book in
                    chip(book.title, .book(book.id))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, _ value: FeedFilter) -> some View {
        let isOn = filter == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { filter = value }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isOn ? Theme.ink : Theme.ink.opacity(0.06), in: Capsule())
                .foregroundStyle(isOn ? Theme.paper : Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

/// One full-screen idea card in the feed.
struct FeedCard: View {
    @EnvironmentObject private var store: HikmaStore
    let item: FeedItem
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: kickerIcon)
                    .font(.system(size: 11, weight: .semibold))
                Text(kicker)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.accent)

            Spacer(minLength: 20)
            content
            Spacer(minLength: 20)

            HStack(alignment: .bottom) {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 16)
                actions
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.tint(for: item.id), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onTapGesture(perform: onOpen)
    }

    @ViewBuilder private var content: some View {
        switch item {
        case .quote(let quote):
            VStack(alignment: .leading, spacing: 22) {
                Text(quote.text)
                    .font(.system(size: 27, weight: .regular))
                    .lineSpacing(11)
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.7)
                Capsule().fill(Theme.accent).frame(width: 28, height: 2)
                VStack(alignment: .leading, spacing: 4) {
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
            VStack(alignment: .leading, spacing: 16) {
                Text(card.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.8)
                Text(card.body)
                    .font(.system(size: 16))
                    .lineSpacing(7)
                    .foregroundStyle(Theme.ink.opacity(0.88))
                    .lineLimit(11)
                    .minimumScaleFactor(0.85)
                if let apply = card.apply, !apply.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("طبّقها")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text(apply)
                            .font(.system(size: 14, weight: .medium))
                            .lineSpacing(4)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(3)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.spring(duration: 0.3)) { store.toggleSaved(item) }
            } label: {
                Image(systemName: store.isSaved(item) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(store.isSaved(item) ? Theme.accent : Theme.ink)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            ShareLink(item: item.shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .light))
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
        case .quote: return "اضغط للتفاصيل"
        case .card(let book, let index): return "\(book.cards[index].chapter) · \(Arabic.number(index + 1))/\(Arabic.number(book.cards.count))"
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
