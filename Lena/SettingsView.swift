//  Lena — CLI Command Cheatsheet for macOS
//  Copyright © 2026 Yannick Boog. All rights reserved.
//  Licensed under the Apache License, Version 2.0
//  https://github.com/yannickboog/lena

import SwiftUI

struct SettingsView: View {
    let storageURL: URL

    @StateObject private var recorder = ShortcutRecorder()
    @State private var hotkey = HotkeySetting.load()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection(title: "Keyboard Shortcuts") {
                VStack(spacing: 0) {
                    openCloseRow
                    shortcutRow("Navigate", "↑  ↓")
                    shortcutRow("Copy selected", "↵")
                    shortcutRow("Clear search / Close", "Esc")
                    shortcutRow("New Tool", "⌘N")
                    shortcutRow("New Command", "⌘⇧N")
                    shortcutRow("Edit selected", "⌘E")
                    shortcutRow("Delete selected", "⌘⌫", last: true)
                }
            }

            settingsSection(title: "Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Location")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(storageURL.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 240, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([storageURL])
                    }
                }
            }

            settingsSection(title: "About") {
                VStack(spacing: 0) {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(appVersion)
                    }
                    .padding(.vertical, 6)
                    Divider()
                    HStack {
                        Text("Author")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Yannick Boog") {
                            NSWorkspace.shared.open(URL(string: "https://yannick.xyz")!)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.vertical, 6)
                    Divider()
                    HStack {
                        Text("License")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Apache 2.0")
                    }
                    .padding(.vertical, 6)
                    Divider()
                    HStack {
                        Spacer()
                        Text("© 2026 Yannick Boog")
                            .font(.caption)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                    .padding(.top, 6)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 420)
        .onDisappear { recorder.cancel() }
    }

    private var openCloseRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open / Close")
                    .foregroundColor(.secondary)
                Spacer()
                if hotkey != .defaultSetting {
                    Button("Reset") {
                        recorder.cancel()
                        hotkey = .defaultSetting
                        HotkeySetting.defaultSetting.save()
                        NotificationCenter.default.post(name: .lenaHotkeyChanged, object: nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.trailing, 8)
                }
                Button {
                    if recorder.isRecording { recorder.cancel() }
                    else {
                        recorder.start { newSetting in
                            hotkey = newSetting
                            newSetting.save()
                            NotificationCenter.default.post(name: .lenaHotkeyChanged, object: nil)
                        }
                    }
                } label: {
                    if recorder.isRecording {
                        Text("Type shortcut…").foregroundColor(.secondary)
                    } else {
                        Text(hotkey.displayString)
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(.body, design: .monospaced))
            }
            .padding(.vertical, 6)
            Divider()
        }
    }

    private func shortcutRow(_ label: LocalizedStringKey, _ keys: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(keys)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            if !last {
                Divider()
            }
        }
    }

    private func settingsSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
