import SwiftUI

/// Every quote delivered so far in this cycle, newest first.
struct ArchiveView: View {
    @EnvironmentObject private var store: HikmaStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.deliveredSlots.isEmpty {
                    Text("ستظهر هنا الحكم التي وصلتك.")
                        .font(Theme.sourceFont)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.deliveredSlots, id: \.self) { slot in
                        if let cycle = store.cycle, let quote = cycle.quote(ofSlot: slot) {
                            NavigationLink {
                                QuoteDetailView(quote: quote, date: cycle.date(ofSlot: slot))
                            } label: {
                                row(quote, date: cycle.date(ofSlot: slot))
                            }
                            .listRowBackground(Theme.paper)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.paper)
            .navigationTitle("ما وصلك")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tint(Theme.ink)
    }

    private func row(_ quote: Quote, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(quote.text)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Text("\(quote.sayer)  ·  \(Arabic.dayAndTime(date))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }
}

struct QuoteDetailView: View {
    let quote: Quote
    let date: Date

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 30) {
                    QuoteView(quote: quote, showsOriginal: true)
                    Text(Arabic.dayAndTime(date))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(28)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: quote.shareText) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
