import Foundation

/// Polls the Dock for badge changes. The Dock doesn't post an accessibility notification when a
/// badge changes, so polling is the only option; one pass reads a few dozen attributes and is cheap.
@MainActor
final class BadgeMonitor: ObservableObject {
    @Published private(set) var items: [DockItem] = []
    @Published private(set) var isTrusted = Dock.isTrusted

    /// Called when any badge or the Accessibility permission changes.
    var onChange: (() -> Void)?

    private var timer: Timer?

    func start(interval: TimeInterval = 2) {
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // .common so badges keep updating while a menu is open (event-tracking run loop mode).
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func badge(for bundleID: String) -> Badge {
        items.first { $0.bundleID == bundleID }?.badge ?? .none
    }

    func refresh() {
        let trusted = Dock.isTrusted
        let items = trusted ? Dock.items() : []
        guard trusted != isTrusted || items != self.items else { return }
        isTrusted = trusted
        self.items = items
        onChange?()
    }
}
