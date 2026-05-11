//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import Foundation

enum ToolColor: String, Codable, CaseIterable {
    case blue, green, orange, purple, pink, teal, indigo, red, brown, cyan, mint, yellow

    static func auto(for id: UUID) -> ToolColor {
        let hash = id.uuidString.utf8.reduce(0) { $0 &+ Int($1) }
        return allCases[abs(hash) % allCases.count]
    }
}

struct Command: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var command: String
    var note: String
    var raw: Bool

    init(id: UUID = UUID(), title: String, command: String, note: String = "", raw: Bool = false) {
        self.id = id
        self.title = title
        self.command = command
        self.note = note
        self.raw = raw
    }
}

struct Tool: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var color: ToolColor?
    var commands: [Command]

    init(id: UUID = UUID(), name: String, icon: String = "terminal", color: ToolColor? = nil, commands: [Command] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.commands = commands
    }
}
