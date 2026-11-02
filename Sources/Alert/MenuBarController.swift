import AppKit

/// One menu bar item per watched app, and nothing else. Left click brings that app forward;
/// right click (or control-click) opens a short menu with the way back to Alert's window.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let monitor: BadgeMonitor
    private let watched: WatchedApps
    private let openSettings: () -> Void
    private var appItems: [String: NSStatusItem] = [:]
    private var shownBadges: [String: Badge] = [:]
    private let menu = NSMenu()
    private var menuOwner: NSStatusItem?

    init(monitor: BadgeMonitor, watched: WatchedApps, openSettings: @escaping () -> Void) {
        self.monitor = monitor
        self.watched = watched
        self.openSettings = openSettings
        super.init()

        menu.delegate = self
        watched.onChange = { [weak self] in self?.syncItems() }
        monitor.onChange = { [weak self] in self?.updateIcons() }
        syncItems()
        monitor.start()
    }

    // MARK: - Status items

    private func syncItems() {
        for (bundleID, item) in appItems where !watched.contains(bundleID) {
            NSStatusBar.system.removeStatusItem(item)
            appItems[bundleID] = nil
            shownBadges[bundleID] = nil
        }
        // New items appear to the left of existing ones, so add in reverse to keep the list order.
        for bundleID in watched.bundleIDs.reversed() where appItems[bundleID] == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            // Remembers where the user ⌘-drags it.
            item.autosaveName = "app.\(bundleID)"
            if let button = item.button {
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            appItems[bundleID] = item
        }
        updateIcons()
    }

    private func updateIcons() {
        for (bundleID, item) in appItems {
            let badge = monitor.badge(for: bundleID)
            guard shownBadges[bundleID] != badge, let button = item.button else { continue }
            shownBadges[bundleID] = badge
            button.image = BadgeIcon.image(icon: AppInfo.icon(for: bundleID), badge: badge)

            let name = AppInfo.name(for: bundleID)
            let status: String
            switch badge {
            case .none: status = "no alerts"
            case .dot: status = "unread"
            case .label(let text): status = text
            }
            button.toolTip = "\(name): \(status)"
            button.setAccessibilityLabel("\(name): \(status)")
        }
    }

    // MARK: - Clicks

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let (bundleID, item) = appItems.first(where: { $0.value.button === sender }) else { return }
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu(for: bundleID, from: item)
        } else {
            AppInfo.open(bundleID)
        }
    }

    private func showMenu(for bundleID: String, from item: NSStatusItem) {
        rebuildMenu(for: bundleID)
        // Attaching the menu only for this click keeps left click free for opening the app.
        menuOwner = item
        item.menu = menu
        item.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOwner?.menu = nil
        menuOwner = nil
    }

    // MARK: - Menu

    private func rebuildMenu(for bundleID: String) {
        menu.removeAllItems()

        let name = AppInfo.name(for: bundleID)
        menu.addItem(item("Open \(name)", #selector(openApp(_:)), represented: bundleID))
        menu.addItem(item("Remove from Menu Bar", #selector(removeApp(_:)), represented: bundleID))

        menu.addItem(.separator())

        menu.addItem(item("Alert Settings…", #selector(showSettings)))

        let quit = NSMenuItem(title: "Quit Alert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector, represented: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = represented
        return item
    }

    @objc private func openApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        AppInfo.open(bundleID)
    }

    @objc private func removeApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        watched.remove(bundleID)
    }

    @objc private func showSettings() {
        openSettings()
    }
}
