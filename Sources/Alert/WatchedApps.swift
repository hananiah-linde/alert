import AppKit
import ServiceManagement

/// The apps shown in the menu bar, in the order they were added. Stored as bundle IDs in UserDefaults.
@MainActor
final class WatchedApps: ObservableObject {
    private static let key = "watchedApps"

    @Published private(set) var bundleIDs: [String] = UserDefaults.standard.stringArray(forKey: WatchedApps.key) ?? []

    /// Called after the list changes so the menu bar can add or remove items.
    var onChange: (() -> Void)?

    func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    func toggle(_ bundleID: String) {
        contains(bundleID) ? remove(bundleID) : add(bundleID)
    }

    func add(_ bundleID: String) {
        guard !contains(bundleID) else { return }
        bundleIDs.append(bundleID)
        save()
    }

    func remove(_ bundleID: String) {
        bundleIDs.removeAll { $0 == bundleID }
        save()
    }

    private func save() {
        UserDefaults.standard.set(bundleIDs, forKey: Self.key)
        onChange?()
    }
}

/// Name and icon for an installed app, looked up by bundle ID.
@MainActor
enum AppInfo {
    private static var icons: [String: NSImage] = [:]

    static func url(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func name(for bundleID: String) -> String {
        guard let url = url(for: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundleID: String) -> NSImage {
        if let cached = icons[bundleID] { return cached }
        let icon = url(for: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
        icons[bundleID] = icon
        return icon
    }

    static func open(_ bundleID: String) {
        guard let url = url(for: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Alert: launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}
