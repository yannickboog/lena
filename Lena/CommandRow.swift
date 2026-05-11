//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

struct CommandRow: View {
    let command: Command
    let isSelected: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(command.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(CLISyntaxHighlighter.highlight(command.command, raw: command.raw))
                        .lineLimit(2)
                    if !command.note.isEmpty {
                        Text(command.note)
                            .font(.caption2)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(command.title))
        .accessibilityHint(Text("Copies command to clipboard"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .background(
            isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
