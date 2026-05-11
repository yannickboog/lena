//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

struct ToolFormView: View {
    let existingTool: Tool?
    let onSave: (String, String, ToolColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: ToolColor

    private static let nameLimit = 50
    private static let icons = [
        "terminal",    "arrow.triangle.branch", "cloud",          "server.rack",
        "gearshape",   "hammer",                "cube",           "network",
        "doc.text",    "folder",                "bolt",           "lock",
        "key",         "wrench",                "shippingbox",    "flame",
        "cpu",         "memorychip",            "externaldrive",  "film",
        "chart.bar",   "globe",                 "shield",         "cylinder",
        "arrow.clockwise", "play.fill",         "list.bullet",    "curlybraces",
        "magnifyingglass", "chevron.left.forwardslash.chevron.right",
    ]

    init(existingTool: Tool?, onSave: @escaping (String, String, ToolColor) -> Void) {
        self.existingTool = existingTool
        self.onSave = onSave
        _name = State(initialValue: existingTool?.name ?? "")
        _selectedIcon = State(initialValue: existingTool?.icon ?? "terminal")
        let id = existingTool?.id ?? UUID()
        _selectedColor = State(initialValue: existingTool?.color ?? ToolColor.auto(for: id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existingTool == nil ? "New Tool" : "Edit Tool")
                .font(.headline)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Name").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if name.count > Self.nameLimit - 15 {
                        Text("\(Self.nameLimit - name.count)")
                            .font(.caption2)
                            .foregroundColor(name.count >= Self.nameLimit ? .red : .secondary)
                    }
                }
                TextField("e.g. git, Docker, npm", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { val in
                        if val.count > Self.nameLimit { name = String(val.prefix(Self.nameLimit)) }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icon").font(.caption).foregroundColor(.secondary)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(38), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    ForEach(Self.icons, id: \.self) { symbol in
                        iconCell(symbol)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.caption).foregroundColor(.secondary)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(38), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    ForEach(ToolColor.allCases, id: \.self) { tc in
                        colorCell(tc)
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(existingTool == nil ? "Add Tool" : "Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces), selectedIcon, selectedColor)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func iconCell(_ symbol: String) -> some View {
        let isSelected = selectedIcon == symbol
        return Image(systemName: symbol)
            .font(.system(size: 16))
            .frame(width: 34, height: 34)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color(NSColor.separatorColor),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .onTapGesture { selectedIcon = symbol }
    }

    private func colorCell(_ tc: ToolColor) -> some View {
        let isSelected = selectedColor == tc
        return ZStack {
            Circle()
                .fill(tc.swiftUIColor)
                .frame(width: 28, height: 28)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
        }
        .frame(width: 38, height: 38)
        .onTapGesture { selectedColor = tc }
    }
}

extension ToolColor {
    var swiftUIColor: Color {
        switch self {
        case .blue:   return Color(NSColor.systemBlue)
        case .green:  return Color(NSColor.systemGreen)
        case .orange: return Color(NSColor.systemOrange)
        case .purple: return Color(NSColor.systemPurple)
        case .pink:   return Color(NSColor.systemPink)
        case .teal:   return Color(NSColor.systemTeal)
        case .indigo: return Color(NSColor.systemIndigo)
        case .red:    return Color(NSColor.systemRed)
        case .brown:  return Color(NSColor.systemBrown)
        case .cyan:   return Color(NSColor.systemCyan)
        case .mint:   return Color(NSColor.systemMint)
        case .yellow: return Color(NSColor.systemYellow)
        }
    }
}
