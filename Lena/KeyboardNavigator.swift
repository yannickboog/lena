//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import AppKit

enum KeyboardAction: Equatable {
    case copy(UUID)
    case focusSearch
    case clearSearch
    case newTool
    case newCommand
    case editSelected
    case deleteSelected
}

@MainActor
final class KeyboardNavigator: ObservableObject {
    @Published private(set) var selectedId: UUID?
    @Published var pendingAction: KeyboardAction?

    var navigableIds: [UUID] = []
    var isSearchFocused: Bool = false
    private var currentIndex: Int?

    private var monitor: Any?

    func clearSelection() {
        currentIndex = nil
        selectedId = nil
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }

    private enum Key {
        static let upArrow:      UInt16 = 126
        static let downArrow:    UInt16 = 125
        static let `return`:     UInt16 = 36
        static let numpadReturn: UInt16 = 76
        static let escape:       UInt16 = 53
        static let n:            UInt16 = 45
        static let e:            UInt16 = 14
        static let backspace:    UInt16 = 51
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        let firstResponder = NSApp.keyWindow?.firstResponder
        let isTextView = firstResponder is NSTextView
        let isFieldEditor = (firstResponder as? NSTextView)?.isFieldEditor ?? false
        let isMultiLineEditor = isTextView && !isFieldEditor
        let navigate = !isTextView || (isSearchFocused && !isMultiLineEditor)
        let cmd = event.modifierFlags.contains(.command)

        // Use the produced character, not the keycode, so "/" works on any keyboard layout.
        if !isTextView && event.characters == "/" {
            pendingAction = .focusSearch
            return nil
        }

        switch event.keyCode {
        case Key.upArrow:
            if navigate { move(by: -1); return nil }

        case Key.downArrow:
            if navigate { move(by: 1); return nil }

        case Key.return, Key.numpadReturn:
            if navigate {
                if let id = selectedId { pendingAction = .copy(id) }
                return nil
            }

        case Key.escape:
            pendingAction = .clearSearch; return nil

        case Key.n:
            if cmd && !isTextView {
                let shift = event.modifierFlags.contains(.shift)
                pendingAction = shift ? .newCommand : .newTool
                return nil
            }

        case Key.e:
            if cmd && !isTextView && selectedId != nil { pendingAction = .editSelected; return nil }

        case Key.backspace:
            if cmd && !isTextView && selectedId != nil { pendingAction = .deleteSelected; return nil }

        default: break
        }
        // pass command-key combos through (system shortcuts like ⌘Q); swallow bare keys to prevent beep
        if !isTextView {
            return event.modifierFlags.contains(.command) ? event : nil
        }
        return event
    }

    private func move(by delta: Int) {
        let ids = navigableIds
        guard !ids.isEmpty else { return }
        if let idx = currentIndex, idx >= ids.count { currentIndex = nil }
        let newIndex: Int
        if let idx = currentIndex {
            newIndex = max(0, min(ids.count - 1, idx + delta))
        } else {
            newIndex = delta > 0 ? 0 : ids.count - 1
        }
        currentIndex = newIndex
        selectedId = ids[newIndex]
    }
}
