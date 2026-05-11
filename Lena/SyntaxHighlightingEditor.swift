//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI
import AppKit

extension SyntaxColor {
    var nsColor: NSColor {
        switch self {
        case .accent: return .controlAccentColor
        case .green:  return .systemGreen
        case .purple: return .systemPurple
        case .blue:   return .systemBlue
        case .orange: return .systemOrange
        }
    }

    var nsBgColor: NSColor? {
        self == .accent ? NSColor.controlAccentColor.withAlphaComponent(0.12) : nil
    }
}

struct SyntaxHighlightingEditor: NSViewRepresentable {
    @Binding var text: String
    var limit: Int = Int.max
    var raw: Bool = false

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
        let rawChanged = context.coordinator.raw != raw
        context.coordinator.raw = raw
        if textView.string != text {
            let sel = textView.selectedRange()
            textView.string = text
            let safe = NSRange(location: min(sel.location, (text as NSString).length), length: 0)
            textView.setSelectedRange(safe)
            Self.applyHighlighting(to: textView, raw: raw)
        } else if rawChanged {
            Self.applyHighlighting(to: textView, raw: raw)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, limit: limit, raw: raw)
    }

    static func applyHighlighting(to textView: NSTextView, raw: Bool = false) {
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
        let defs = raw ? CLISyntaxHighlighter.tokenDefs.filter { $0.color != .accent } : CLISyntaxHighlighter.tokenDefs
        for def in defs {
            for m in def.regex.matches(in: text, range: fullRange) {
                let r = m.range
                let chars = r.location ..< (r.location + r.length)
                guard !consumed.intersects(integersIn: chars) else { continue }
                consumed.insert(integersIn: chars)
                storage.addAttribute(.foregroundColor, value: def.color.nsColor, range: r)
                if let bg = def.color.nsBgColor { storage.addAttribute(.backgroundColor, value: bg, range: r) }
            }
        }

        if let m = CLISyntaxHighlighter.firstWordRegex.firstMatch(in: text, range: fullRange) {
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
        var raw: Bool

        init(text: Binding<String>, limit: Int, raw: Bool) {
            self.text = text
            self.limit = limit
            self.raw = raw
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
            SyntaxHighlightingEditor.applyHighlighting(to: textView, raw: raw)
        }
    }
}
