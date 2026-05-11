//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

struct PlaceholderSpec: Hashable {
    let name: String
    let isOptional: Bool
}

struct PlaceholderSheetData: Identifiable {
    let id = UUID()
    let command: Command
    let placeholders: [PlaceholderSpec]
}

struct PlaceholderFillView: View {
    let command: Command
    let placeholders: [PlaceholderSpec]
    let onCopy: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]
    @FocusState private var focusedField: String?

    init(command: Command, placeholders: [PlaceholderSpec], onCopy: @escaping (String) -> Void) {
        self.command = command
        self.placeholders = placeholders
        self.onCopy = onCopy
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: placeholders.map { ($0.name, "") }))
    }

    private var filled: String {
        var result = command.command
        for spec in placeholders {
            let token = spec.isOptional ? "{{\(spec.name)?}}" : "{{\(spec.name)}}"
            result = result.replacingOccurrences(of: token, with: values[spec.name] ?? "")
        }
        return result
    }

    private var canCopy: Bool {
        placeholders
            .filter { !$0.isOptional }
            .allSatisfy { !(values[$0.name] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Fill in placeholders")
                    .font(.headline)
                Text(command.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(placeholders, id: \.name) { spec in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(spec.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if spec.isOptional {
                            Text("(optional)")
                                .font(.caption)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        }
                    }
                    TextField("", text: Binding(
                        get: { values[spec.name] ?? "" },
                        set: { values[spec.name] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(Text(spec.name))
                    .focused($focusedField, equals: spec.name)
                    .onSubmit {
                        let idx = placeholders.firstIndex(of: spec) ?? 0
                        let next = placeholders.indices.contains(idx + 1) ? placeholders[idx + 1] : nil
                        if let next {
                            focusedField = next.name
                        } else if canCopy {
                            onCopy(filled)
                            dismiss()
                        }
                    }
                }
            }

            Text(filled)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Copy") {
                    onCopy(filled)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCopy)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear { focusedField = placeholders.first?.name }
    }
}
