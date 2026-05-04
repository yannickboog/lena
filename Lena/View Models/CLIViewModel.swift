import Foundation

@MainActor
final class ToolStore: ObservableObject {

    @Published private(set) var tools: [Tool] = []

    private let storageURL: URL
    private let defaultsVersionKey = "xyz.yannick.lena.defaultsVersion"

    init() {
        storageURL = Self.makeStorageURL()
        load()
        applyMigrations()
    }

    // MARK: - Migrations
    //
    // Each version block runs exactly once per device, regardless of whether
    // the user already has data. New defaults in v2 are additive — v1 data
    // is never touched. Deleted defaults do not come back.

    private func applyMigrations() {
        var version = UserDefaults.standard.integer(forKey: defaultsVersionKey)
        guard version < currentDefaultsVersion else { return }

        if version < 1 { applyV1() ; version = 1 }
        // if version < 2 { applyV2() ; version = 2 }

        UserDefaults.standard.set(version, forKey: defaultsVersionKey)
        save()
    }

    private let currentDefaultsVersion = 1

    private func applyV1() {
        struct DefaultCommand {
            let id: UUID; let title: String; let command: String; let note: String
        }
        struct DefaultTool {
            let id: UUID; let name: String; let icon: String; let commands: [DefaultCommand]
        }

        let defaults: [DefaultTool] = [
            DefaultTool(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "git", icon: "arrow.triangle.branch",
                commands: [
                    DefaultCommand(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                        title: "Pretty Log Graph",
                        command: #"git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"#,
                        note: "Colored graph with branch refs, author and relative date"
                    ),
                    DefaultCommand(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                        title: "Rebase onto Main",
                        command: "git rebase -i $(git merge-base HEAD main)",
                        note: "Interactive rebase of all commits not yet on main"
                    ),
                    DefaultCommand(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                        title: "Top Contributors",
                        command: "git log --format='%aN' | sort | uniq -c | sort -nr | head -n 10",
                        note: "Ranks authors by number of commits"
                    )
                ]
            ),
            DefaultTool(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Network", icon: "network",
                commands: [
                    DefaultCommand(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000004")!,
                        title: "Active TCP Connections",
                        command: "lsof -nP -iTCP -sTCP:ESTABLISHED | awk '{print $1, $9}' | sort | uniq",
                        note: "Lists all established TCP connections with process name"
                    )
                ]
            ),
            DefaultTool(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "System", icon: "internaldrive",
                commands: [
                    DefaultCommand(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000005")!,
                        title: "Largest Files/Dirs",
                        command: "du -sh * | sort -hr | head -n {{top_n}}",
                        note: "Shows the top N largest entries in the current directory"
                    )
                ]
            ),
            DefaultTool(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                name: "ffmpeg", icon: "film",
                commands: [
                    DefaultCommand(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000006")!,
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

    func addTool(name: String, icon: String) {
        tools.append(Tool(name: name, icon: icon))
        save()
    }

    func updateTool(_ tool: Tool, name: String, icon: String) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        tools[i].name = name
        tools[i].icon = icon
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

    // MARK: - Commands

    func addCommand(to tool: Tool, title: String, command: String, note: String) {
        guard let i = tools.firstIndex(where: { $0.id == tool.id }) else { return }
        tools[i].commands.append(Command(title: title, command: command, note: note))
        save()
    }

    func updateCommand(_ command: Command, in tool: Tool, title: String, commandText: String, note: String) {
        guard let ti = tools.firstIndex(where: { $0.id == tool.id }),
              let ci = tools[ti].commands.firstIndex(where: { $0.id == command.id }) else { return }
        tools[ti].commands[ci].title = title
        tools[ti].commands[ci].command = commandText
        tools[ti].commands[ci].note = note
        save()
    }

    func moveCommand(_ command: Command, from sourceTool: Tool, to targetTool: Tool,
                     title: String, commandText: String, note: String) {
        guard let si = tools.firstIndex(where: { $0.id == sourceTool.id }),
              let ti = tools.firstIndex(where: { $0.id == targetTool.id }),
              let ci = tools[si].commands.firstIndex(where: { $0.id == command.id }) else { return }
        var updated = tools[si].commands[ci]
        updated.title = title
        updated.command = commandText
        updated.note = note
        tools[si].commands.remove(at: ci)
        tools[ti].commands.append(updated)
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
            let data = try JSONEncoder().encode(tools)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[Lena] save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            tools = try JSONDecoder().decode([Tool].self, from: data)
        } catch {
            print("[Lena] load failed: \(error)")
        }
    }

    private static func makeStorageURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Lena", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tools.json")
    }
}
