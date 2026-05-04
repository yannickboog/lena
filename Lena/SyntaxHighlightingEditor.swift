import SwiftUI
import AppKit

struct SyntaxHighlightingEditor: NSViewRepresentable {
    @Binding var text: String
    var limit: Int = Int.max

    private static let tokens: [(pattern: String, color: NSColor, bgColor: NSColor?, bold: Bool)] = [
        (#"\{\{[^}]+\}\}"#,             .controlAccentColor, NSColor.controlAccentColor.withAlphaComponent(0.12), false),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#,  .systemGreen,        nil,                                                 false),
        (#"'[^']*'"#,                   .systemGreen,        nil,                                                 false),
        (#"\$\([^)]*\)"#,               .systemPurple,       nil,                                                 false),
        (#"`[^`]*`"#,                   .systemPurple,       nil,                                                 false),
        (#"\$[A-Za-z_]\w*"#,            .systemPurple,       nil,                                                 false),
        (#"--[A-Za-z][A-Za-z0-9_-]*"#, .systemBlue,         nil,                                                 false),
        (#"(?<!\S)-[A-Za-z]\w*"#,       .systemBlue,         nil,                                                 false),
        (#"2>&1|\|{1,2}|>{1,2}|&&|;"#, .systemOrange,       nil,                                                 false),
    ]

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.widthTracksTextView = true
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.textContainerInset = NSSize(width: 4, height: 6)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.limit = limit
        if textView.string != text {
            let sel = textView.selectedRange()
            textView.string = text
            let safe = NSRange(location: min(sel.location, (text as NSString).length), length: 0)
            textView.setSelectedRange(safe)
        }
        Self.applyHighlighting(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, limit: limit)
    }

    static func applyHighlighting(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let text = textView.string
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard fullRange.length > 0 else { return }

        let baseFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)

        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ], range: fullRange)

        var consumed = IndexSet()
        for (pattern, color, bgColor, isBold) in tokens {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            for m in re.matches(in: text, range: fullRange) {
                let r = m.range
                let chars = r.location ..< (r.location + r.length)
                guard !consumed.intersects(integersIn: chars) else { continue }
                consumed.insert(integersIn: chars)
                storage.addAttribute(.foregroundColor, value: color, range: r)
                if let bg = bgColor { storage.addAttribute(.backgroundColor, value: bg, range: r) }
                if isBold { storage.addAttribute(.font, value: boldFont, range: r) }
            }
        }

        if let m = try? NSRegularExpression(pattern: #"^\s*\S+"#).firstMatch(in: text, range: fullRange) {
            let chars = m.range.location ..< (m.range.location + m.range.length)
            if !consumed.intersects(integersIn: chars) {
                storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: m.range)
                storage.addAttribute(.font, value: boldFont, range: m.range)
            }
        }

        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var limit: Int

        init(text: Binding<String>, limit: Int) {
            self.text = text
            self.limit = limit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            var newText = textView.string
            if newText.count > limit {
                newText = String(newText.prefix(limit))
                let sel = textView.selectedRange()
                textView.string = newText
                textView.setSelectedRange(NSRange(location: min(sel.location, (newText as NSString).length), length: 0))
            }
            text.wrappedValue = newText
            SyntaxHighlightingEditor.applyHighlighting(to: textView)
        }
    }
}
