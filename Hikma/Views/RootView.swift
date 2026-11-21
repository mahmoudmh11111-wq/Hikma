import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HikmaStore

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if store.cycle == nil {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .tint(Theme.ink)
        .animation(.easeInOut(duration: 0.3), value: store.cycle == nil)
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var showsArchive = false
    @State private var showsSettings = false

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
            if store.todaySlots.isEmpty {
                Spacer()
                Text("أول حكمة في الطريق إليك")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.ink)
                Spacer()
            } else {
                TodayCardsView()
            }
        }
        .padding(.vertical, 12)
        .onReceive(clock) { _ in store.tick() }
        .sheet(isPresented: $showsArchive) { ArchiveView() }
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }

    private var header: some View {
        HStack {
            iconButton("list.bullet") { showsArchive = true }
            Spacer()
            VStack(spacing: 2) {
                Text("حِكَم اليوم")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("اليوم \(Arabic.number(store.currentDay)) من \(Arabic.number(Cycle.days))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            iconButton("slider.horizontal.3") { showsSettings = true }
        }
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 17, weight: .light))
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(Theme.ink)
    }
}

// MARK: - Today's cards

/// Today's six sayings, one card per screen; swipe between them.
struct TodayCardsView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var selected: Int?
    @State private var originals: Set<Int> = []

    var body: some View {
        let slots = store.todaySlots
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(slots, id: \.self) { slot in
                        card(slot: slot, position: (slots.firstIndex(of: slot) ?? 0) + 1, total: slots.count)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 20)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.4)
                                    .rotation3DEffect(.degrees(phase.value * -8), axis: (x: 0, y: 1, z: 0))
                            }
                            .id(slot)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selected)

            footer(slots: slots)
                .padding(.horizontal, 28)
        }
        .onAppear { selected = store.focusedSlot ?? store.startingTodaySlot }
        .onChange(of: store.focusedSlot) { _, slot in
            if let slot, slots.contains(slot) {
                withAnimation(.spring(duration: 0.5)) { selected = slot }
            }
        }
        .onChange(of: store.latestSlot) { _, slot in
            if let slot, slots.contains(slot) {
                withAnimation(.spring(duration: 0.5)) { selected = slot }
            }
        }
    }

    @ViewBuilder
    private func card(slot: Int, position: Int, total: Int) -> some View {
        if let cycle = store.cycle, let quote = cycle.quote(ofSlot: slot) {
            let date = cycle.date(ofSlot: slot)
            let isUpcoming = date > store.now
            let isCurrent = slot == store.latestSlot
            VStack(spacing: 0) {
                HStack {
                    Text(isUpcoming ? "تصلك \(Arabic.time(date))" : Arabic.time(date))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isCurrent ? Theme.accent : Theme.accent.opacity(0.12), in: Capsule())
                        .foregroundStyle(isCurrent ? Color.white : Theme.accent)
                    Spacer()
                    Text("\(Arabic.number(position)) / \(Arabic.number(total))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                QuoteView(quote: quote, showsOriginal: originals.contains(slot))
                Spacer(minLength: 16)
                Text(originals.contains(slot) ? "اضغط لإخفاء النص الأصلي" : "اضغط لعرض النص الأصلي")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .opacity(quote.original == nil ? 0 : 1)
            }
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .onTapGesture {
                guard quote.original != nil else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    if originals.contains(slot) { originals.remove(slot) } else { originals.insert(slot) }
                }
            }
        }
    }

    private func footer(slots: [Int]) -> some View {
        HStack {
            if let next = store.nextDate {
                Text("الحكمة التالية \(Arabic.time(next))")
                    .font(Theme.smallFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(slots, id: \.self) { slot in
                    Capsule()
                        .fill(slot == selected ? Theme.accent : Theme.ink.opacity(0.15))
                        .frame(width: slot == selected ? 18 : 6, height: 6)
                        .onTapGesture { withAnimation(.spring(duration: 0.5)) { selected = slot } }
                }
            }
            .animation(.spring(duration: 0.35), value: selected)
            Spacer()
            if let slot = selected, let quote = store.cycle?.quote(ofSlot: slot) {
                ShareLink(item: quote.shareText) {
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

// MARK: - Onboarding / schedule picker

struct OnboardingView: View {
    @EnvironmentObject private var store: HikmaStore
    @State private var startHour = 8
    @State private var starting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Text("حكمة")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Capsule().fill(Theme.accent).frame(width: 28, height: 2)
                Text("حكمةٌ من ثقافات العالم كل أربع ساعات،\nأربعة عشر يومًا دون تكرار.")
                    .font(.system(size: 17))
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SchedulePicker(startHour: $startHour)
            Spacer()
            Button {
                starting = true
                Task {
                    await store.begin(startHour: startHour)
                    starting = false
                }
            } label: {
                Text("ابدأ")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Theme.paper)
            }
            .disabled(starting)
        }
        .padding(28)
        .onAppear { startHour = store.startHour }
    }
}

/// Four possible grids (every 4 hours), labelled by their six times.
struct SchedulePicker: View {
    @Binding var startHour: Int
    static let options = [6, 7, 8, 9]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("مواعيد الحكم اليومية")
                .font(Theme.smallFont)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Self.options, id: \.self) { hour in
                    Button { startHour = hour } label: {
                        HStack {
                            Text(Arabic.schedule(startHour: hour))
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Image(systemName: isSelected(hour) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected(hour) ? Theme.accent : Color.secondary.opacity(0.4))
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if hour != Self.options.last { Divider() }
                }
            }
        }
    }

    private func isSelected(_ hour: Int) -> Bool { startHour % 4 == hour % 4 }
}
