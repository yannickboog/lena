import AppKit

enum KeyboardAction: Equatable {
    case copy(UUID)
    case focusSearch
    case clearSearch
}

@MainActor
final class KeyboardNavigator: ObservableObject {
    @Published private(set) var selectedId: UUID?
    @Published var pendingAction: KeyboardAction?

    var navigableIds: [UUID] = []
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

    private func handle(_ event: NSEvent) -> NSEvent? {
        let inTextField = NSApp.keyWindow?.firstResponder is NSTextView

        switch event.keyCode {
        case 44:        // /  — focus search (only when not already typing)
            if !inTextField { pendingAction = .focusSearch; return nil }

        case 126:       // ↑
            move(by: -1); return nil

        case 125:       // ↓
            move(by: 1); return nil

        case 36, 76:    // Return / numpad Return
            if let id = selectedId { pendingAction = .copy(id); return nil }

        case 53:        // Escape
            pendingAction = .clearSearch; return nil

        default: break
        }
        return event
    }

    private func move(by delta: Int) {
        let ids = navigableIds
        guard !ids.isEmpty else { return }
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
