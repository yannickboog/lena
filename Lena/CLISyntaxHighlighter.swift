import SwiftUI

enum CLISyntaxHighlighter {

    // Token patterns in priority order — higher priority is applied first,
    // already-colored character positions are skipped by later patterns.
    private static let tokens: [(pattern: String, color: Color, bgColor: Color?, bold: Bool)] = [
        // Placeholders  {{name}}
        (#"\{\{[^}]+\}\}"#,                           .accentColor,                    Color.accentColor.opacity(0.12), false),
        // Double-quoted strings  "…"  (handles escaped quotes inside)
        (#""[^"\\]*(?:\\.[^"\\]*)*""#,                Color(NSColor.systemGreen),      nil,                             false),
        // Single-quoted strings  '…'
        (#"'[^']*'"#,                                 Color(NSColor.systemGreen),      nil,                             false),
        // Command substitution  $(…)  or  `…`
        (#"\$\([^)]*\)"#,                             Color(NSColor.systemPurple),     nil,                             false),
        (#"`[^`]*`"#,                                 Color(NSColor.systemPurple),     nil,                             false),
        // Variables  $VAR
        (#"\$[A-Za-z_]\w*"#,                          Color(NSColor.systemPurple),     nil,                             false),
        // Long flags  --flag
        (#"--[A-Za-z][A-Za-z0-9_-]*"#,               Color(NSColor.systemBlue),       nil,                             false),
        // Short flags  -f  -nP  (must be preceded by whitespace or start)
        (#"(?<!\S)-[A-Za-z]\w*"#,                     Color(NSColor.systemBlue),       nil,                             false),
        // Pipes & redirects  |  ||  >  >>  &&  ;  2>&1
        (#"2>&1|\|{1,2}|>{1,2}|&&|;"#,               Color(NSColor.systemOrange),     nil,                             false),
    ]

    static func highlight(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = .system(size: 11, design: .monospaced)
        attr.foregroundColor = .secondary

        let ns = text as NSString
        var consumed = IndexSet()

        for (pattern, color, bgColor, bold) in tokens {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let r = m.range
                let charRange = r.location ..< (r.location + r.length)
                guard consumed.intersects(integersIn: charRange) == false,
                      let sr = Range(r, in: text),
                      let ar = Range(sr, in: attr) else { continue }
                consumed.insert(integersIn: charRange)
                attr[ar].foregroundColor = color
                if let bg = bgColor { attr[ar].backgroundColor = bg }
                if bold { attr[ar].font = .system(size: 11, weight: .bold, design: .monospaced) }
            }
        }

        // Bold first word (base command), but only if it hasn't been consumed by another token
        if let m = try? NSRegularExpression(pattern: #"^\s*\S+"#)
            .firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
           let sr = Range(m.range, in: text),
           let ar = Range(sr, in: attr) {
            attr[ar].font = .system(size: 11, weight: .bold, design: .monospaced)
            attr[ar].foregroundColor = .primary
        }

        return attr
    }
}
