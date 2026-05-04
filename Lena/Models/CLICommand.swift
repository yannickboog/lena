import Foundation

struct Command: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var command: String
    var note: String

    init(id: UUID = UUID(), title: String, command: String, note: String = "") {
        self.id = id
        self.title = title
        self.command = command
        self.note = note
    }
}

struct Tool: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var commands: [Command]

    init(id: UUID = UUID(), name: String, icon: String = "terminal", commands: [Command] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.commands = commands
    }
}
