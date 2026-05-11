//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import Foundation
import os

@MainActor
final class ToolStore: ObservableObject {

    private enum Constants {
        static let bundleID            = "xyz.yannick.lena"
        static let defaultsVersionKey  = "\(bundleID).defaultsVersion"
        static let storageFileName     = "tools.json"
        static let storageDirectoryName = "Lena"
    }

    @Published private(set) var tools: [Tool] = []
    @Published private(set) var persistenceError: String?

    private let storageURL: URL
    private let logger = Logger(subsystem: Constants.bundleID, category: "persistence")

    init() {
        let url = Self.defaultStorageURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        storageURL = url
        load()
        applyMigrations()
    }

    // MARK: - Migrations
    //
    // Each version block runs exactly once per device. To add a future migration:
    // increment currentDefaultsVersion and add `if version < N { applyVN(); version = N }`.

    private func applyMigrations() {
        var version = UserDefaults.standard.integer(forKey: Constants.defaultsVersionKey)
        let fileAbsent = !FileManager.default.fileExists(atPath: storageURL.path)

        guard version < currentDefaultsVersion || fileAbsent else { return }

        // Re-seed V1 defaults when this is a fresh install OR when the storage
        // file was manually deleted (UserDefaults version persists, file does not).
        if version < 1 || (fileAbsent && tools.isEmpty) {
            applyV1()
            version = max(version, 1)
        }

        UserDefaults.standard.set(version, forKey: Constants.defaultsVersionKey)
        save()
    }

    private let currentDefaultsVersion = 1

    private func seedUUID(_ string: String) -> UUID {
        guard let uuid = UUID(uuidString: string) else {
            fatalError("ToolStore: invalid seed UUID '\(string)'")
        }
        return uuid
    }

    private func applyV1() {
        struct DefaultCommand {
            let id: UUID; let title: String; let command: String; let note: String
        }
        struct DefaultTool {
            let id: UUID; let name: String; let icon: String; let commands: [DefaultCommand]
        }

        // Fixed UUIDs ensure re-running the migration never creates duplicates.
        let defaults: [DefaultTool] = [
            DefaultTool(
                id: seedUUID("10000000-0000-0000-0000-000000000001"),
                name: "git", icon: "arrow.triangle.branch",
                commands: [
                    DefaultCommand(
                        id: seedUUID("20000000-0000-0000-0000-000000000001"),
                        title: "Pretty Log Graph",
                        command: #"git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"#,
                        note: "Colored graph with branch refs, author and relative date — via Lena by Yannick Boog"
                    ),
                    DefaultCommand(
                        id: seedUUID("20000000-0000-0000-0000-000000000002"),
                        title: "Rebase onto Main",
                        command: "git rebase -i $(git merge-base HEAD main)",
                        note: "Interactive rebase of all commits not yet on main"
                    ),
                    DefaultCommand(
                        id: seedUUID("20000000-0000-0000-0000-000000000003"),
                        title: "Top Contributors",
                        command: "git log --format='%aN' | sort | uniq -c | sort -nr | head -n 10",
                        note: "Ranks authors by number of commits"
                    )
                ]
            ),
            DefaultTool(
                id: seedUUID("10000000-0000-0000-0000-000000000002"),
                name: "Network", icon: "network",
                commands: [
                    DefaultCommand(
                        id: seedUUID("20000000-0000-0000-0000-000000000004"),
                        title: "Active TCP Connections",
                        command: "lsof -nP -iTCP -sTCP:ESTABLISHED | awk '{print $1, $9}' | sort | uniq",
                        note: "Lists all established TCP connections with process name"
                    )
                ]
            ),
            DefaultTool(
                id: seedUUID("10000000-0000-0000-0000-000000000003"),
                name: "System", icon: "internaldrive",
                commands: [
                    DefaultCommand(
                        id: seedUUID("20000000-0000-0000-0000-000000000005"),
                        title: "Largest Files/Dirs",
                        command: "du -sh * | sort -hr | head -n {{top_n}}",
                        note: "Shows the top N largest entries in the current directory"
                    )
                ]
            ),
            DefaultTool(
                id: seedUUID("10000000-0000-0000-0000-000000000004"),
                name: "ffmpeg", icon: "film",
                commands: [
                    DefaultCommand(
                        id: seedUUID("20000000-0000-0000-0000-000000000006"),
                        title: "MP4 → GIF",
                        command: #"ffmpeg -i {{input}}.mp4 -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 {{output}}.gif"#,
                        note: "High-quality GIF at 15 fps, 480px wide"
                    )
                ]
            )
        ]

        for dt in defaults {
            if let idx = tools.firstIndex(where: { $0.id == dt.id }) {
                for dc in dt.commands where !tools[idx].commands.contains(where: { $0.id == dc.id }) {
                    tools[idx].commands.append(Command(id: dc.id, title: dc.title, command: dc.command, note: dc.note))
                }
            } else {
                tools.append(Tool(
                    id: dt.id, name: dt.name, icon: dt.icon,
                    commands: dt.commands.map { Command(id: $0.id, title: $0.title, command: $0.command, note: $0.note) }
                ))
            }
        }
    }

    // MARK: - Tools

    func addTool(name: String, icon: String, color: ToolColor) {
        tools.append(Tool(name: name, icon: icon, color: color))
        save()
    }

    func updateTool(_ tool: Tool, name: String, icon: String, color: ToolColor) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        tools[i].name = name
        tools[i].icon = icon
        tools[i].color = color
        save()
    }

    func deleteTool(_ tool: Tool) {
        tools.removeAll { $0.id == tool.id }
        save()
    }

    func moveTools(from source: IndexSet, to destination: Int) {
        tools.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func moveCommands(in tool: Tool, from source: IndexSet, to destination: Int) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        tools[i].commands.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Commands

    func addCommand(to tool: Tool, title: String, command: String, note: String, raw: Bool) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        tools[i].commands.append(Command(title: title, command: command, note: note, raw: raw))
        save()
    }

    func updateCommand(_ command: Command, in tool: Tool, title: String, commandText: String, note: String, raw: Bool) {
        guard let ti = tools.firstIndex(where: { $0.id == tool.id }),
              let ci = tools[ti].commands.firstIndex(where: { $0.id == command.id }) else { return }
        tools[ti].commands[ci].title = title
        tools[ti].commands[ci].command = commandText
        tools[ti].commands[ci].note = note
        tools[ti].commands[ci].raw = raw
        save()
    }

    func moveCommand(_ command: Command, from sourceTool: Tool, to targetTool: Tool,
                     title: String, commandText: String, note: String, raw: Bool) {
        guard let si = tools.firstIndex(where: { $0.id == sourceTool.id }),
              let ti = tools.firstIndex(where: { $0.id == targetTool.id }),
              let ci = tools[si].commands.firstIndex(where: { $0.id == command.id }) else { return }
        var updated = tools[si].commands[ci]
        updated.title = title
        updated.command = commandText
        updated.note = note
        updated.raw = raw
        tools[si].commands.remove(at: ci)
        tools[ti].commands.append(updated)
        save()
    }

    func duplicateTool(_ tool: Tool) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        var copy = tools[i]
        copy.id = UUID()
        copy.commands = copy.commands.map { cmd in
            var c = cmd; c.id = UUID(); return c
        }
        tools.insert(copy, at: i + 1)
        save()
    }

    func duplicateCommand(_ command: Command, in tool: Tool) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }),
              let ci = tools[i].commands.firstIndex(where: { $0.id == command.id }) else { return }
        var copy = tools[i].commands[ci]
        copy.id = UUID()
        tools[i].commands.insert(copy, at: ci + 1)
        save()
    }

    func deleteCommand(_ command: Command, from tool: Tool) {
        guard let ti = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        tools[ti].commands.removeAll { $0.id == command.id }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tools)
            try data.write(to: storageURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "Could not save data"
            logger.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            tools = try JSONDecoder().decode([Tool].self, from: data)
            persistenceError = nil
        } catch {
            persistenceError = "Could not load data"
            logger.error("load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static var defaultStorageURL: URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("ToolStore: Application Support directory not found")
        }
        return base
            .appendingPathComponent(Constants.storageDirectoryName, isDirectory: true)
            .appendingPathComponent(Constants.storageFileName)
    }
}
