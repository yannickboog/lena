//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

let lenaPopoverSize = CGSize(width: 380, height: 520)

enum SheetState: Identifiable {
    case addTool
    case editTool(Tool)
    case addCommand(Tool)
    case editCommand(Command, Tool)

    var id: String {
        switch self {
        case .addTool:               return "addTool"
        case .editTool(let t):       return "editTool.\(t.id)"
        case .addCommand(let t):     return "addCommand.\(t.id)"
        case .editCommand(let c, _): return "editCommand.\(c.id)"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: ToolStore
    @ObservedObject var pinState: PinState
    let closePopover: () -> Void
    @State private var query = ""
    @State private var activeSheet: SheetState?
    @State private var placeholderSheet: PlaceholderSheetData?
    @State private var toastMessage: String?
    @State private var isErrorToast = false
    @State private var toastTask: Task<Void, Never>?
    @State private var collapsedTools: Set<UUID> = []
    @StateObject private var navigator = KeyboardNavigator()
    @FocusState private var searchFocused: Bool

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var navigableCommandIds: [UUID] {
        filteredTools
            .filter { isSearching || !collapsedTools.contains($0.id) }
            .flatMap { $0.commands.map { $0.id } }
    }

    private var filteredTools: [Tool] {
        guard isSearching else { return store.tools }
        let q = query.trimmingCharacters(in: .whitespaces)
        return store.tools.compactMap { tool in
            let toolMatches = tool.name.localizedCaseInsensitiveContains(q)
            let matchingCommands = tool.commands.filter {
                $0.title.localizedCaseInsensitiveContains(q) ||
                $0.command.localizedCaseInsensitiveContains(q) ||
                $0.note.localizedCaseInsensitiveContains(q)
            }
            guard toolMatches || !matchingCommands.isEmpty else { return nil }
            return Tool(id: tool.id, name: tool.name, icon: tool.icon, color: tool.color,
                        commands: toolMatches ? tool.commands : matchingCommands)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBarView
            mainContent
            footerView
        }
        .frame(width: lenaPopoverSize.width, height: lenaPopoverSize.height)
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                toastView(message)
                    .padding(.bottom, 38)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .onAppear {
            navigator.navigableIds = navigableCommandIds
            navigator.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lenaPopoverWillShow)) { _ in
            query = ""
            searchFocused = true
        }
        .onChange(of: store.persistenceError) { error in
            if let error { showToast(error, isError: true) }
        }
        .onDisappear {
            navigator.stop()
            toastTask?.cancel()
        }
        .onChange(of: navigableCommandIds) { ids in
            navigator.navigableIds = ids
            navigator.clearSelection()
        }
        .onChange(of: query) { _ in navigator.clearSelection() }
        .onChange(of: searchFocused) { navigator.isSearchFocused = $0 }
        .onChange(of: navigator.pendingAction) { action in
            guard let action else { return }
            navigator.pendingAction = nil
            switch action {
            case .focusSearch:
                searchFocused = true
            case .clearSearch:
                if !query.isEmpty { query = "" }
                else if searchFocused { searchFocused = false }
                else if !pinState.isPinned { closePopover() }
            case .copy(let id):
                for tool in store.tools {
                    if let cmd = tool.commands.first(where: { $0.id == id }) {
                        copyToClipboard(cmd); return
                    }
                }
            case .newTool:
                activeSheet = .addTool
            case .newCommand:
                if let id = navigator.selectedId {
                    for tool in store.tools where tool.commands.contains(where: { $0.id == id }) {
                        activeSheet = .addCommand(tool); return
                    }
                }
                if let first = store.tools.first { activeSheet = .addCommand(first) }
            case .editSelected:
                guard let id = navigator.selectedId else { return }
                for tool in store.tools {
                    if let cmd = tool.commands.first(where: { $0.id == id }) {
                        activeSheet = .editCommand(cmd, tool); return
                    }
                }
            case .deleteSelected:
                guard let id = navigator.selectedId else { return }
                for tool in store.tools {
                    if let cmd = tool.commands.first(where: { $0.id == id }) {
                        store.deleteCommand(cmd, from: tool)
                        navigator.clearSelection()
                        return
                    }
                }
            }
        }
        .sheet(item: $activeSheet, content: sheetContent)
        .sheet(item: $placeholderSheet) { data in
            PlaceholderFillView(command: data.command, placeholders: data.placeholders) { filled in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filled, forType: .string)
                showToast(String(format: NSLocalizedString("Copied \"%@\"", comment: ""), data.command.title))
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .foregroundColor(.accentColor)
            Text("Lena")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            Button {
                pinState.isPinned.toggle()
            } label: {
                Image(systemName: pinState.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 14))
                    .foregroundColor(pinState.isPinned ? .accentColor : Color(NSColor.tertiaryLabelColor))
                    .rotationEffect(.degrees(45))
            }
            .buttonStyle(.plain)
            .help(pinState.isPinned ? "Unpin window" : "Pin window")
            .accessibilityLabel(pinState.isPinned ? Text("Unpin window") : Text("Pin window"))
            Button {
                activeSheet = .addTool
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Add new tool")
            .accessibilityLabel(Text("Add new tool"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)
                .accessibilityHidden(true)
            TextField("Search commands…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit { }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var mainContent: some View {
        if store.tools.isEmpty {
            emptyStateView
        } else if filteredTools.isEmpty {
            noResultsView
        } else {
            toolList
        }
    }

    private var toolList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredTools) { tool in
                    Section(header: toolSectionHeader(for: tool)) {
                        if isSearching || !collapsedTools.contains(tool.id) {
                            if tool.commands.isEmpty {
                                Button {
                                    activeSheet = .addCommand(tool)
                                } label: {
                                    Label("Add Command", systemImage: "plus")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 2)
                            }
                            ForEach(tool.commands) { command in
                                CommandRow(
                                    command: command,
                                    isSelected: navigator.selectedId == command.id
                                ) {
                                    copyToClipboard(command)
                                }
                                .id(command.id)
                                .contextMenu {
                                    Button {
                                        activeSheet = .editCommand(command, tool)
                                    } label: {
                                        Label("Edit Command", systemImage: "pencil")
                                    }
                                    Button {
                                        store.duplicateCommand(command, in: tool)
                                    } label: {
                                        Label("Duplicate Command", systemImage: "doc.on.doc")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        store.deleteCommand(command, from: tool)
                                    } label: {
                                        Label("Delete Command", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete { offsets in
                                offsets.forEach { store.deleteCommand(tool.commands[$0], from: tool) }
                            }
                            .onMove { source, destination in
                                if !isSearching {
                                    store.moveCommands(in: tool, from: source, to: destination)
                                }
                            }
                        }
                    }
                }
                .onMove(perform: isSearching ? nil : { source, destination in
                    store.moveTools(from: source, to: destination)
                })
            }
            .listStyle(.plain)
            .onChange(of: navigator.selectedId) { id in
                if let id { proxy.scrollTo(id, anchor: nil) }
            }
        }
    }

    private func toolSectionHeader(for tool: Tool) -> some View {
        let isCollapsed = collapsedTools.contains(tool.id)
        let color = toolColor(for: tool)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 3, height: 14)
                .padding(.trailing, 7)
                .accessibilityHidden(true)

            Button {
                if isCollapsed {
                    collapsedTools.remove(tool.id)
                } else {
                    collapsedTools.insert(tool.id)
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .accessibilityLabel(isCollapsed ? Text("Expand \(tool.name)") : Text("Collapse \(tool.name)"))

            Image(systemName: tool.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16, alignment: .center)
                .padding(.trailing, 6)
                .accessibilityHidden(true)
            Text(tool.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()

            Menu {
                Button {
                    activeSheet = .addCommand(tool)
                } label: {
                    Label("Add Command", systemImage: "plus")
                }
                Divider()
                Button {
                    activeSheet = .editTool(tool)
                } label: {
                    Label("Edit Tool", systemImage: "pencil")
                }
                Button {
                    store.duplicateTool(tool)
                } label: {
                    Label("Duplicate Tool", systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive) {
                    store.deleteTool(tool)
                } label: {
                    Label("Delete Tool", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(Text("Options for \(tool.name)"))
        }
        .padding(.vertical, 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("No tools yet")
                    .font(.headline)
                Text("Add your first tool to start\nbuilding your command cheatsheet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Add Tool") {
                activeSheet = .addTool
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text("No results for \"\(query)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerView: some View {
        HStack {
            Button {
                if let url = URL(string: "https://yannick.xyz") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Macher")
                    .font(.caption2)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .underline()
            }
            .buttonStyle(.plain)

            Spacer()

            Group {
                if #available(macOS 14.0, *) {
                    SettingsLink { settingsGearIcon }
                } else {
                    Button {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    } label: { settingsGearIcon }
                }
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel(Text("Settings"))

            Button {
                if let url = URL(string: "https://github.com/yannickboog/lena/issues") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text("Report Issue")
                        .font(.caption2)
                }
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }

    private func toastView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isErrorToast ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isErrorToast ? .red : .green)
                .font(.caption)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
    }

    @ViewBuilder
    private func sheetContent(for sheet: SheetState) -> some View {
        switch sheet {
        case .addTool:
            ToolFormView(existingTool: nil) { name, icon, color in
                store.addTool(name: name, icon: icon, color: color)
            }
        case .editTool(let tool):
            ToolFormView(existingTool: tool) { name, icon, color in
                store.updateTool(tool, name: name, icon: icon, color: color)
            }
        case .addCommand(let tool):
            CommandFormView(currentTool: tool, allTools: store.tools, existingCommand: nil) { title, command, note, raw, targetTool in
                store.addCommand(to: targetTool, title: title, command: command, note: note, raw: raw)
            }
        case .editCommand(let command, let tool):
            CommandFormView(currentTool: tool, allTools: store.tools, existingCommand: command) { title, commandText, note, raw, targetTool in
                if targetTool.id == tool.id {
                    store.updateCommand(command, in: tool, title: title, commandText: commandText, note: note, raw: raw)
                } else {
                    store.moveCommand(command, from: tool, to: targetTool, title: title, commandText: commandText, note: note, raw: raw)
                }
            }
        }
    }

    private func copyToClipboard(_ command: Command) {
        let placeholders = command.raw ? [] : Self.extractPlaceholders(from: command.command)
        if placeholders.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command.command, forType: .string)
            showToast(String(format: NSLocalizedString("Copied \"%@\"", comment: ""), command.title))
        } else {
            placeholderSheet = PlaceholderSheetData(command: command, placeholders: placeholders)
        }
    }

    private static let placeholderRegex = try? NSRegularExpression(pattern: #"\{\{(.+?)\}\}"#)

    private static func extractPlaceholders(from text: String) -> [PlaceholderSpec] {
        guard let regex = placeholderRegex else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var result: [PlaceholderSpec] = []
        for match in matches {
            let raw = ns.substring(with: match.range(at: 1))
            let isOptional = raw.hasSuffix("?")
            let name = isOptional ? String(raw.dropLast()) : raw
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            result.append(PlaceholderSpec(name: name, isOptional: isOptional))
        }
        return result
    }

    private func toolColor(for tool: Tool) -> Color {
        (tool.color ?? ToolColor.auto(for: tool.id)).swiftUIColor
    }

    private var settingsGearIcon: some View {
        Image(systemName: "gearshape")
            .font(.caption2)
            .foregroundColor(Color(NSColor.tertiaryLabelColor))
    }

    private func showToast(_ message: String, isError: Bool = false) {
        toastTask?.cancel()
        isErrorToast = isError
        toastMessage = message
        NSAccessibility.post(
            element: (NSApp.mainWindow ?? NSApp) as Any,
            notification: .announcementRequested,
            userInfo: [NSAccessibility.NotificationUserInfoKey.announcement: message]
        )
        toastTask = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                toastMessage = nil
            } catch {
                // cancelled — a newer toast is already showing, leave it alone
            }
        }
    }
}
