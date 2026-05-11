//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

struct CommandFormView: View {
    let currentTool: Tool
    let allTools: [Tool]
    let existingCommand: Command?
    let onSave: (String, String, String, Bool, Tool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var commandText: String
    @State private var note: String
    @State private var isRaw: Bool
    @State private var selectedToolId: UUID

    private static let titleLimit = 80
    private static let commandLimit = 2000
    private static let noteLimit = 150

    init(currentTool: Tool, allTools: [Tool], existingCommand: Command?,
         onSave: @escaping (String, String, String, Bool, Tool) -> Void) {
        self.currentTool = currentTool
        self.allTools = allTools
        self.existingCommand = existingCommand
        self.onSave = onSave
        _title = State(initialValue: existingCommand?.title ?? "")
        _commandText = State(initialValue: existingCommand?.command ?? "")
        _note = State(initialValue: existingCommand?.note ?? "")
        _isRaw = State(initialValue: existingCommand?.raw ?? false)
        _selectedToolId = State(initialValue: currentTool.id)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !commandText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var resolvedTargetTool: Tool {
        allTools.first(where: { $0.id == selectedToolId }) ?? currentTool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(existingCommand == nil ? "New Command" : "Edit Command")
                    .font(.headline)
                if existingCommand == nil {
                    Text("Tool: \(currentTool.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if allTools.count > 1 {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tool").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $selectedToolId) {
                        ForEach(allTools) { t in
                            HStack(spacing: 5) {
                                Image(systemName: t.icon)
                                Text(t.name)
                            }
                            .tag(t.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Title").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if title.count > Self.titleLimit - 20 {
                        Text("\(Self.titleLimit - title.count)")
                            .font(.caption2)
                            .foregroundColor(title.count >= Self.titleLimit ? .red : .secondary)
                    }
                }
                TextField("e.g. Pretty Log Graph", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: title) { val in
                        if val.count > Self.titleLimit { title = String(val.prefix(Self.titleLimit)) }
                    }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Command").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if commandText.count > Self.commandLimit - 300 {
                        Text("\(Self.commandLimit - commandText.count)")
                            .font(.caption2)
                            .foregroundColor(commandText.count >= Self.commandLimit ? .red : .secondary)
                    }
                }
                commandEditorView
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Note  (optional)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if note.count > Self.noteLimit - 30 {
                        Text("\(Self.noteLimit - note.count)")
                            .font(.caption2)
                            .foregroundColor(note.count >= Self.noteLimit ? .red : .secondary)
                    }
                }
                TextField("Short hint or description", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: note) { val in
                        if val.count > Self.noteLimit { note = String(val.prefix(Self.noteLimit)) }
                    }
            }

            Toggle("No placeholders", isOn: $isRaw)
                .toggleStyle(.checkbox)
                .font(.caption)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(existingCommand == nil ? "Add Command" : "Save") {
                    onSave(
                        title.trimmingCharacters(in: .whitespaces),
                        commandText.trimmingCharacters(in: .whitespaces),
                        note.trimmingCharacters(in: .whitespaces),
                        isRaw,
                        resolvedTargetTool
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var commandEditorView: some View {
        ZStack(alignment: .topLeading) {
            SyntaxHighlightingEditor(text: $commandText, limit: Self.commandLimit, raw: isRaw)
                .frame(minHeight: 72, maxHeight: 120)
            if commandText.isEmpty {
                Text("e.g. git log --graph --pretty=…")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(NSColor.placeholderTextColor))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}
