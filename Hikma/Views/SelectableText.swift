import SwiftUI
import UIKit

/// Read-only text you can select word by word. Long-press a word to get the iPhone menu
/// with Copy, Look Up and Translate. SwiftUI's own `.textSelection` only selects the whole
/// block on iPhone, so this wraps a non-editable `UITextView`.
struct SelectableText: UIViewRepresentable {
    let text: String
    var size: CGFloat = 16.5
    var weight: UIFont.Weight = .regular
    var serif = false
    var lineSpacing: CGFloat = 6
    var color: UIColor = Theme.inkUIColor

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = []
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let rtl = context.environment.layoutDirection == .rightToLeft
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = .natural
        paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight

        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
        if view.attributedText != attributed { view.attributedText = attributed }
        view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        view.textAlignment = rtl ? .right : .left
    }

    /// Height that fits the full text at the width SwiftUI offers.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - 64
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fit.height))
    }

    private var font: UIFont {
        var base = UIFont.systemFont(ofSize: size, weight: weight)
        if serif, let descriptor = base.fontDescriptor.withDesign(.serif) {
            base = UIFont(descriptor: descriptor, size: size)
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }
}
