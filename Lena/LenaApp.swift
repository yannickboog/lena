//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI
import Combine
import Carbon.HIToolbox

@main
struct LenaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(storageURL: ToolStore.defaultStorageURL)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: ToolStore!

    private let pinState = PinState()
    private var cancellables = Set<AnyCancellable>()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var hotkeyObserver: Any?

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store = ToolStore()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Lena")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = lenaPopoverSize
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ContentView(store: store, pinState: pinState, closePopover: { [weak self] in
                self?.popover.performClose(nil)
            })
        )

        pinState.$isPinned
            .sink { [weak self] isPinned in
                self?.popover.behavior = isPinned ? .applicationDefined : .transient
            }
            .store(in: &cancellables)

        setupHotKey()
    }

    // MARK: - Global Hotkey

    private func setupHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { delegate.handleHotKey() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            NSLog("Lena: InstallEventHandler failed (%d) — global hotkey disabled", handlerStatus)
            return
        }
        registerKey(setting: HotkeySetting.load())
        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .lenaHotkeyChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reregisterHotKey()
        }
    }

    private func reregisterHotKey() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        registerKey(setting: HotkeySetting.load())
    }

    private func registerKey(setting: HotkeySetting) {
        var id = EventHotKeyID()
        id.signature = 0x4C454E41  // "LENA"
        id.id = 1
        let status = RegisterEventHotKey(setting.keyCode, setting.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Lena: RegisterEventHotKey failed (%d)", status)
            let alert = NSAlert()
            alert.messageText = "Global Shortcut Unavailable"
            alert.informativeText = "\(setting.displayString) couldn't be registered — it may already be in use by another app. You can still open Lena by clicking its menu bar icon."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func handleHotKey() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Status Bar Button

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem.button,
              let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit Lena", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
            return
        }

        if popover.isShown {
            if !pinState.isPinned { popover.performClose(nil) }
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        NotificationCenter.default.post(name: .lenaPopoverWillShow, object: nil)
    }
}

extension AppDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        if let obs = hotkeyObserver { NotificationCenter.default.removeObserver(obs) }
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }
}
