//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import AppKit
import Carbon.HIToolbox

struct HotkeySetting: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayKey: String

    static let defaultSetting = HotkeySetting(
        keyCode: UInt32(kVK_ANSI_L),
        carbonModifiers: UInt32(cmdKey | shiftKey),
        displayKey: "L"
    )

    private static let userDefaultsKey = "xyz.yannick.lena.hotkey"

    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + displayKey
    }

    static func load() -> HotkeySetting {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(HotkeySetting.self, from: data) else {
            return .defaultSetting
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}

// Captures a key combination from the user via a local NSEvent monitor.
// Only call start() from the main thread; the monitor fires on the main thread.
final class ShortcutRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    private var monitor: Any?

    func start(onCapture: @escaping (HotkeySetting) -> Void) {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            self.handle(event: event, onCapture: onCapture)
            return nil
        }
    }

    func cancel() { stop() }

    private func handle(event: NSEvent, onCapture: (HotkeySetting) -> Void) {
        if event.keyCode == UInt16(kVK_Escape) { stop(); return }

        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty,
              let base = event.charactersIgnoringModifiers?.uppercased(),
              !base.isEmpty else { return }

        var carbonMods: UInt32 = 0
        if mods.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if mods.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        if mods.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if mods.contains(.control) { carbonMods |= UInt32(controlKey) }

        let setting = HotkeySetting(keyCode: UInt32(event.keyCode), carbonModifiers: carbonMods, displayKey: base)
        stop()
        onCapture(setting)
    }

    private func stop() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
