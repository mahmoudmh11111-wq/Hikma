import SwiftUI

/// The quote, a short gold line, then who said it and where.
struct QuoteView: View {
    let quote: Quote
    var showsOriginal = false

    var body: some View {
        VStack(spacing: 26) {
            Text(quote.text)
                .font(Theme.quoteFont)
                .lineSpacing(12)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            Capsule()
                .fill(Theme.accent)
                .frame(width: 28, height: 2)

            VStack(spacing: 6) {
                Text(quote.sayer)
                    .font(Theme.sayerFont)
                    .foregroundStyle(Theme.ink)
                Text(quote.source)
                    .font(Theme.sourceFont)
                    .foregroundStyle(.secondary)
                Text(quote.culture)
                    .font(Theme.smallFont)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)

            if showsOriginal, let original = quote.original {
                Text(original)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .leftToRight)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 520)
    }
}

extension Quote {
    /// Plain text for sharing.
    var shareText: String {
        "«\(text)»\n— \(sayer)، \(source)"
    }
}
