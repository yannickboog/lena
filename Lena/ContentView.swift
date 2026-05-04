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

struct PlaceholderSheetData: Identifiable {
    let id = UUID()
    let command: Command
    let placeholders: [String]
}

struct ContentView: View {
    @ObservedObject var store: ToolStore
    @ObservedObject var pinState: PinState
    @State private var query = ""
    @State private var activeSheet: SheetState?
    @State private var placeholderSheet: PlaceholderSheetData?
    @State private var toastMessage: String?
    @State private var collapsedTools: Set<UUID> = []
    @StateObject private var navigator = KeyboardNavigator()
    @FocusState private var searchFocused: Bool

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var navigableCommandIds: [UUID] {
        filteredTools
            .filter { !collapsedTools.contains($0.id) }
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
            return Tool(id: tool.id, name: tool.name, icon: tool.icon,
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
        .onDisappear { navigator.stop() }
        .onChange(of: navigableCommandIds) { ids in
            navigator.navigableIds = ids
            navigator.clearSelection()
        }
        .onChange(of: query) { _ in navigator.clearSelection() }
        .onChange(of: navigator.pendingAction) { action in
            guard let action else { return }
            navigator.pendingAction = nil
            switch action {
            case .focusSearch:
                searchFocused = true
            case .clearSearch:
                if !query.isEmpty { query = "" } else { searchFocused = false }
            case .copy(let id):
                for tool in store.tools {
                    if let cmd = tool.commands.first(where: { $0.id == id }) {
                        copyToClipboard(cmd); return
                    }
                }
            }
        }
        .sheet(item: $activeSheet, content: sheetContent)
        .sheet(item: $placeholderSheet) { data in
            PlaceholderFillView(command: data.command, placeholders: data.placeholders) { filled in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filled, forType: .string)
                showToast("Copied \"\(data.command.title)\"")
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
            Button {
                activeSheet = .addTool
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Add new tool")
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
            TextField("Search commands…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
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
                        if !collapsedTools.contains(tool.id) {
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
                        }
                    }
                }
                .onMove(perform: isSearching ? nil : { source, destination in
                    store.moveTools(from: source, to: destination)
                })
            }
            .listStyle(.plain)
            .onChange(of: navigator.selectedId) { id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
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

            Image(systemName: tool.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16, alignment: .center)
                .padding(.trailing, 6)
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
        }
        .padding(.vertical, 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
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

            Button {
                if let url = URL(string: "https://github.com/yannickboog/lena/issues") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.caption2)
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
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(message)
                .font(.caption)
                .lineLimit(1)
        }
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
            ToolFormView(existingTool: nil) { name, icon in
                store.addTool(name: name, icon: icon)
            }
        case .editTool(let tool):
            ToolFormView(existingTool: tool) { name, icon in
                store.updateTool(tool, name: name, icon: icon)
            }
        case .addCommand(let tool):
            CommandFormView(currentTool: tool, allTools: [], existingCommand: nil) { title, command, note, _ in
                store.addCommand(to: tool, title: title, command: command, note: note)
            }
        case .editCommand(let command, let tool):
            CommandFormView(currentTool: tool, allTools: store.tools, existingCommand: command) { title, commandText, note, targetTool in
                if targetTool.id == tool.id {
                    store.updateCommand(command, in: tool, title: title, commandText: commandText, note: note)
                } else {
                    store.moveCommand(command, from: tool, to: targetTool, title: title, commandText: commandText, note: note)
                }
            }
        }
    }

    private func copyToClipboard(_ command: Command) {
        let placeholders = Self.extractPlaceholders(from: command.command)
        if placeholders.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command.command, forType: .string)
            showToast("Copied \"\(command.title)\"")
        } else {
            placeholderSheet = PlaceholderSheetData(command: command, placeholders: placeholders)
        }
    }

    private static func extractPlaceholders(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}") else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            let name = ns.substring(with: match.range(at: 1))
            if seen.insert(name).inserted { result.append(name) }
        }
        return result
    }

    private static let toolPalette: [Color] = [
        Color(NSColor.systemBlue),
        Color(NSColor.systemGreen),
        Color(NSColor.systemOrange),
        Color(NSColor.systemPurple),
        Color(NSColor.systemPink),
        Color(NSColor.systemTeal),
        Color(NSColor.systemIndigo),
        Color(NSColor.systemRed),
        Color(NSColor.systemBrown),
        Color(NSColor.systemCyan),
        Color(NSColor.systemMint),
        Color(NSColor.systemYellow),
    ]

    private func toolColor(for tool: Tool) -> Color {
        Self.toolPalette[abs(tool.id.hashValue) % Self.toolPalette.count]
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastMessage = nil
        }
    }
}

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
                    Text(CLISyntaxHighlighter.highlight(command.command))
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
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}

struct ToolFormView: View {
    let existingTool: Tool?
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIcon: String

    private static let nameLimit = 50
    private static let icons = [
        "terminal",              "arrow.triangle.branch", "cloud",        "server.rack",
        "gearshape",             "hammer",                "cube",         "network",
        "doc.text",              "folder",                "sparkles",     "bolt",
        "lock",                  "key",                   "ant",          "wrench",
        "shippingbox",           "puzzlepiece",           "flame",        "wand.and.stars",
        "cpu",                   "memorychip",            "externaldrive","internaldrive",
        "film",                  "waveform",              "photo",        "chart.bar",
        "person",                "tray",
    ]

    init(existingTool: Tool?, onSave: @escaping (String, String) -> Void) {
        self.existingTool = existingTool
        self.onSave = onSave
        _name = State(initialValue: existingTool?.name ?? "")
        _selectedIcon = State(initialValue: existingTool?.icon ?? "terminal")
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

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(existingTool == nil ? "Add Tool" : "Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces), selectedIcon)
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
}

struct CommandFormView: View {
    let currentTool: Tool
    let allTools: [Tool]
    let existingCommand: Command?
    let onSave: (String, String, String, Tool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var commandText: String
    @State private var note: String
    @State private var selectedToolId: UUID

    private static let titleLimit = 80
    private static let commandLimit = 2000
    private static let noteLimit = 150

    init(currentTool: Tool, allTools: [Tool], existingCommand: Command?,
         onSave: @escaping (String, String, String, Tool) -> Void) {
        self.currentTool = currentTool
        self.allTools = allTools
        self.existingCommand = existingCommand
        self.onSave = onSave
        _title = State(initialValue: existingCommand?.title ?? "")
        _commandText = State(initialValue: existingCommand?.command ?? "")
        _note = State(initialValue: existingCommand?.note ?? "")
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

            if existingCommand != nil && allTools.count > 1 {
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

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(existingCommand == nil ? "Add Command" : "Save") {
                    onSave(
                        title.trimmingCharacters(in: .whitespaces),
                        commandText.trimmingCharacters(in: .whitespaces),
                        note.trimmingCharacters(in: .whitespaces),
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
            SyntaxHighlightingEditor(text: $commandText, limit: Self.commandLimit)
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

struct PlaceholderFillView: View {
    let command: Command
    let placeholders: [String]
    let onCopy: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]
    @FocusState private var focusedField: String?

    init(command: Command, placeholders: [String], onCopy: @escaping (String) -> Void) {
        self.command = command
        self.placeholders = placeholders
        self.onCopy = onCopy
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: placeholders.map { ($0, "") }))
    }

    private var filled: String {
        var result = command.command
        for key in placeholders {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: values[key] ?? "")
        }
        return result
    }

    private var canCopy: Bool {
        placeholders.allSatisfy { !(values[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
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

            ForEach(placeholders, id: \.self) { key in
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: Binding(
                        get: { values[key] ?? "" },
                        set: { values[key] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: key)
                    .onSubmit {
                        let idx = placeholders.firstIndex(of: key) ?? 0
                        let next = placeholders.indices.contains(idx + 1) ? placeholders[idx + 1] : nil
                        if let next {
                            focusedField = next
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
        .onAppear { focusedField = placeholders.first }
    }
}
