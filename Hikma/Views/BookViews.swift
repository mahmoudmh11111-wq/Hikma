import SwiftUI
import UniformTypeIdentifiers

// MARK: - Reading cards (home, book mode)

/// The active book: a cover card, then every card delivered so far, one per screen.
struct BookCardsView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var selected: Int?

    private static let cover = -1

    var body: some View {
        if let book = store.activeBook, let run = store.bookRun {
            let delivered = (store.latestCard ?? -1) + 1
            let pages = [Self.cover] + Array(0..<delivered)
            VStack(spacing: 0) {
                progress(book: book, delivered: delivered)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(pages, id: \.self) { page in
                            Group {
                                if page == Self.cover {
                                    BookCoverCard(book: book, run: run, delivered: delivered)
                                } else {
                                    BookCardView(book: book, index: page, date: run.dates[page])
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.4)
                                    .rotation3DEffect(.degrees(phase.value * -8), axis: (x: 0, y: 1, z: 0))
                            }
                            .id(page)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $selected)

                footer(book: book, pages: pages)
                    .padding(.horizontal, 28)
            }
            .onAppear { selected = store.focusedCard ?? store.latestCard ?? Self.cover }
            .onChange(of: store.focusedCard) { _, card in
                if let card, card < delivered {
                    withAnimation(.spring(duration: 0.5)) { selected = card }
                }
            }
            .onChange(of: store.latestCard) { _, card in
                if let card { withAnimation(.spring(duration: 0.5)) { selected = card } }
            }
        }
    }

    private func progress(book: Book, delivered: Int) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule().fill(Theme.accent)
                        .frame(width: max(6, geo.size.width * store.bookProgress))
                }
            }
            .frame(height: 4)
            HStack {
                Text("\(Arabic.number(delivered)) من \(Arabic.number(book.cards.count)) بطاقة")
                Spacer()
                Text("\(Arabic.number(Int((store.bookProgress * 100).rounded())))٪")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private func footer(book: Book, pages: [Int]) -> some View {
        HStack {
            if let next = store.nextCardDate {
                Text("البطاقة التالية \(Arabic.time(next))")
                    .font(Theme.smallFont)
                    .foregroundStyle(.secondary)
            } else {
                Text("أتممت الكتاب")
                    .font(Theme.smallFont)
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            if let index = selected, index >= 0, book.cards.indices.contains(index) {
                ShareLink(item: book.cards[index].shareText(book: book)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .light))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(Theme.ink)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }
}

struct BookCoverCard: View {
    let book: Book
    let run: BookRun
    let delivered: Int

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: "book.closed")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(Theme.accent)
            Text(book.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if let original = book.originalTitle {
                Text(original)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Text(book.author)
                .font(Theme.sayerFont)
                .foregroundStyle(Theme.ink)
            Capsule().fill(Theme.accent).frame(width: 28, height: 2)
            Text(book.about)
                .font(.system(size: 15))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(delivered == 0
                 ? "أول بطاقة تصلك \(Arabic.dayAndTime(run.dates[0]))"
                 : "اسحب لقراءة ما وصلك")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }
}

struct BookCardView: View {
    @EnvironmentObject private var store: HikmaStore
    let book: Book
    let index: Int
    let date: Date?

    var body: some View {
        let card = book.cards[index]
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(card.chapter)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                    .lineLimit(1)
                Spacer()
                Text("\(Arabic.number(index + 1)) / \(Arabic.number(book.cards.count))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(card.title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    SelectableText(text: card.body, size: 17, lineSpacing: 9,
                                   color: Theme.inkUI(alpha: isRead ? 0.62 : 0.88))
                    if let apply = card.apply, !apply.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.applyLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.accent)
                            SelectableText(text: apply, size: 15, weight: .medium, lineSpacing: 6,
                                           color: Theme.inkUI(alpha: isRead ? 0.7 : 1))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.09),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                ReadTick(item: item, english: book.isEnglish)
                Spacer()
                if let date {
                    Text(Arabic.dayAndTime(date))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Theme.paper.opacity(isRead ? 0.45 : 0))
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.25), value: isRead)
        .environment(\.layoutDirection, book.direction)
    }

    private var item: FeedItem { .card(book: book, index: index) }
    private var isRead: Bool { store.isRead(item) }
}

extension View {
    /// The shared card look: white (or soft dark) rounded card with a light shadow.
    func cardBackground() -> some View {
        self
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

extension BookCard {
    func shareText(book: Book) -> String {
        var text = "\(title)\n\n\(body)"
        if let apply, !apply.isEmpty { text += "\n\n\(book.applyLabel): \(apply)" }
        text += book.isEnglish ? "\n\n— from “\(book.title)”, \(book.author)"
                               : "\n\n— من «\(book.title)»، \(book.author)"
        return text
    }
}

// MARK: - Library

/// Imported books: import, start, stop, delete.
struct LibraryView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.books.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 30, weight: .ultraLight))
                                .foregroundStyle(Theme.accent)
                            Text("لا توجد كتب بعد")
                                .font(.system(size: 17, weight: .semibold))
                            Text("افتح ملف خطة الكتاب (‎.hikmabook‎) بتطبيق حكمة، أو استورده من هنا.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(store.topics, id: \.self) { topic in
                        Section(topic) {
                            ForEach(store.books.filter { $0.topicName == topic }) { book in
                                NavigationLink(value: book.id) { row(book) }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        importing = true
                    } label: {
                        Label("استيراد خطة كتاب", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("الكتب")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let book = store.books.first(where: { $0.id == id }) {
                    BookDetailView(book: book)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.hikmaBook, .json],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    var imported: [Book] = []
                    var failed = 0
                    for url in urls {
                        if let book = try? store.importBook(from: url) { imported.append(book) } else { failed += 1 }
                    }
                    if imported.count == 1, failed == 0 { path = [imported[0].id] }
                    store.justImportedBookID = nil
                    if failed > 0 {
                        store.importError = "تعذّر قراءة \(Arabic.number(failed)) من الملفات المختارة."
                    }
                case .failure(let error):
                    store.importError = error.localizedDescription
                }
            }
            .onAppear {
                if let id = store.justImportedBookID {
                    path = [id]
                    store.justImportedBookID = nil
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tint(Theme.ink)
    }

    private func row(_ book: Book) -> some View {
        let progress = store.progress(of: book)
        return VStack(alignment: .leading, spacing: 5) {
            Text(book.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(book.author) · \(book.topicName)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(progress.isActive
                 ? "تقرؤه الآن · \(Arabic.number(progress.delivered)) من \(Arabic.number(progress.total))"
                 : "\(Arabic.number(book.cards.count)) بطاقة")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(progress.isActive ? Theme.accent : Color.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct BookDetailView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var perDay = 3
    @State private var confirmsDelete = false
    @State private var working = false

    private var isActive: Bool { store.bookRun?.bookID == book.id }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(.system(size: 24, weight: .bold))
                    Text(book.author)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(book.about)
                        .font(.system(size: 15))
                        .lineSpacing(5)
                        .padding(.top, 6)
                }
                .padding(.vertical, 6)
            }

            if isActive {
                Section {
                    let progress = store.progress(of: book)
                    LabeledContent("التقدّم", value: "\(Arabic.number(progress.delivered)) من \(Arabic.number(progress.total))")
                    if let run = store.bookRun, let last = run.dates.last {
                        LabeledContent("آخر بطاقة", value: Arabic.dayAndTime(last))
                    }
                    Button("إيقاف قراءة هذا الكتاب", role: .destructive) {
                        working = true
                        Task { await store.stopBook(); working = false }
                    }
                }
            } else {
                Section {
                    Picker("الوتيرة", selection: $perDay) {
                        Text("٣ يوميًا").tag(3)
                        Text("٦ يوميًا").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)

                    LabeledContent("المدة",
                                   value: "\(Arabic.number(BookRun.days(cards: book.cards.count, perDay: perDay))) يومًا")
                    LabeledContent("المواعيد", value: hoursText)
                    Button {
                        working = true
                        Task {
                            await store.startBook(book, perDay: perDay)
                            working = false
                            dismiss()
                        }
                    } label: {
                        Text(store.bookRun == nil ? "ابدأ القراءة" : "ابدأ هذا الكتاب بدل الحالي")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("تصل بطاقات الكتاب بين مواعيد الحكم، فلا تتزاحم معها. \(Arabic.number(book.cards.count)) بطاقة بالترتيب حتى نهاية الكتاب.")
                }
            }

            Section {
                Button("حذف الكتاب", role: .destructive) { confirmsDelete = true }
            }
        }
        .disabled(working)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("حذف «\(book.title)»؟", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("حذف", role: .destructive) {
                Task { await store.deleteBook(book); dismiss() }
            }
            Button("إلغاء", role: .cancel) {}
        }
    }

    private var hoursText: String {
        BookRun.dailyHours(sayingsStartHour: store.startHour, perDay: perDay)
            .map { Arabic.hour($0) }
            .joined(separator: " · ")
    }
}

// MARK: - All cards of one book

/// Every card of one book in one continuous scroll, opened by tapping the book's name on a card.
/// Opens at the first card you haven't ticked as read.
struct BookAllCardsView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss
    let book: Book

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(book.cards.indices, id: \.self) { index in
                            if index == 0 || book.cards[index].chapter != book.cards[index - 1].chapter {
                                Text(book.cards[index].chapter)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 24)
                                    .padding(.top, index == 0 ? 4 : 14)
                            }
                            FeedCard(item: .card(book: book, index: index))
                                .frame(maxWidth: 640)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .background(Theme.paper)
                .onAppear {
                    let firstUnread = book.cards.indices.first { !store.isRead(.card(book: book, index: $0)) }
                    if let firstUnread, firstUnread > 0 {
                        DispatchQueue.main.async { proxy.scrollTo(firstUnread, anchor: .top) }
                    }
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(book.isEnglish ? "Done" : "تم") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Text(progress)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .environment(\.layoutDirection, book.direction)
        .tint(Theme.ink)
    }

    private var progress: String {
        let read = store.readCount(book), total = book.cards.count
        return book.isEnglish ? "\(read)/\(total) read" : "\(Arabic.number(read))/\(Arabic.number(total)) مقروءة"
    }
}
