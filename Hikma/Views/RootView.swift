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
    @State private var showsOriginal = false

    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 24)
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
            Spacer(minLength: 24)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .onReceive(clock) { _ in store.tick() }
        .sheet(isPresented: $showsArchive) { ArchiveView() }
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }

    private var header: some View {
        HStack {
            iconButton("list.bullet") { showsArchive = true }
            Spacer()
            Text("اليوم \(Arabic.number(store.currentDay)) من \(Arabic.number(Cycle.days))")
                .font(Theme.smallFont)
                .foregroundStyle(.secondary)
            Spacer()
            iconButton("slider.horizontal.3") { showsSettings = true }
        }
    }

    @ViewBuilder private var content: some View {
        if let slot = store.displayedSlot, let quote = store.cycle?.quote(ofSlot: slot) {
            QuoteView(quote: quote, showsOriginal: showsOriginal)
                .id(quote.id)
                .transition(.opacity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { showsOriginal.toggle() }
                }
        } else {
            VStack(spacing: 14) {
                Text("أول حكمة في الطريق إليك")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.ink)
                if let next = store.nextDate {
                    Text("تصلك الساعة \(Arabic.time(next))")
                        .font(Theme.sourceFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if store.focusedSlot != nil {
                Button("عرض الأحدث") { withAnimation { store.focusedSlot = nil } }
                    .font(Theme.smallFont)
            } else if let next = store.nextDate {
                Text("الحكمة التالية \(Arabic.time(next))")
                    .font(Theme.smallFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let slot = store.displayedSlot, let quote = store.cycle?.quote(ofSlot: slot) {
                ShareLink(item: quote.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .light))
                        .frame(width: 44, height: 44)
                }
            }
        }
        .foregroundStyle(Theme.ink)
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
