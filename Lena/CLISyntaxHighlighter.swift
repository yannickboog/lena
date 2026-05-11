//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

struct SyntaxTokenDef {
    let regex: NSRegularExpression
    let color: SyntaxColor

    init(_ pattern: String, _ color: SyntaxColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            fatalError("CLISyntaxHighlighter: invalid regex pattern — \(pattern)")
        }
        self.regex = regex
        self.color = color
    }
}

enum SyntaxColor {
    case accent, green, purple, blue, orange
}

enum CLISyntaxHighlighter {

    // Single source of truth for all token patterns — used by both renderers.
    static let tokenDefs: [SyntaxTokenDef] = [
        SyntaxTokenDef(#"\{\{[^}]+\}\}"#,             .accent),
        SyntaxTokenDef(#""[^"\\]*(?:\\.[^"\\]*)*""#,  .green),
        SyntaxTokenDef(#"'[^']*'"#,                   .green),
        SyntaxTokenDef(#"\$\([^)]*\)"#,               .purple),
        SyntaxTokenDef(#"`[^`]*`"#,                   .purple),
        SyntaxTokenDef(#"\$[A-Za-z_]\w*"#,            .purple),
        SyntaxTokenDef(#"--[A-Za-z][A-Za-z0-9_-]*"#,  .blue),
        SyntaxTokenDef(#"(?<!\S)-[A-Za-z]\w*"#,       .blue),
        SyntaxTokenDef(#"2>&1|\|{1,2}|>{1,2}|&&|;"#,  .orange),
    ]

    static let firstWordRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: #"^\s*\S+"#) else {
            fatalError("CLISyntaxHighlighter: invalid firstWord pattern")
        }
        return r
    }()

    static func highlight(_ text: String, raw: Bool = false) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = .system(size: 11, design: .monospaced)
        attr.foregroundColor = .secondary

        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var consumed = IndexSet()
        let defs = raw ? tokenDefs.filter { $0.color != .accent } : tokenDefs

        for def in defs {
            for m in def.regex.matches(in: text, range: fullRange) {
                let r = m.range
                let charRange = r.location ..< (r.location + r.length)
                guard !consumed.intersects(integersIn: charRange),
                      let sr = Range(r, in: text),
                      let ar = Range(sr, in: attr) else { continue }
                consumed.insert(integersIn: charRange)
                attr[ar].foregroundColor = def.color.swiftUIColor
                if let bg = def.color.swiftUIBgColor { attr[ar].backgroundColor = bg }
            }
        }

        if let m = firstWordRegex.firstMatch(in: text, range: fullRange),
           let sr = Range(m.range, in: text),
           let ar = Range(sr, in: attr) {
            attr[ar].font = .system(size: 11, weight: .bold, design: .monospaced)
            attr[ar].foregroundColor = .primary
        }

        return attr
    }
}

extension SyntaxColor {
    var swiftUIColor: Color {
        switch self {
        case .accent: return .accentColor
        case .green:  return Color(NSColor.systemGreen)
        case .purple: return Color(NSColor.systemPurple)
        case .blue:   return Color(NSColor.systemBlue)
        case .orange: return Color(NSColor.systemOrange)
        }
    }

    var swiftUIBgColor: Color? {
        self == .accent ? Color.accentColor.opacity(0.12) : nil
    }
}
