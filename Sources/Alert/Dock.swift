import AppKit
import ApplicationServices

/// What an app's Dock icon badge is showing.
enum Badge: Equatable {
    case none
    /// A badge with no number, like Slack's "•" for unread channels.
    case dot
    /// A count or short label, like "3".
    case label(String)

    init(statusLabel: String?) {
        let text = statusLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            self = .none
        } else if text.rangeOfCharacter(from: .alphanumerics) == nil {
            self = .dot
        } else if let count = Int(text), count > 99 {
            self = .label("99+")
        } else {
            self = .label(text)
        }
    }
}

struct DockItem: Equatable {
    let bundleID: String
    let name: String
    let badge: Badge
}

/// Reads app badges out of the Dock's accessibility tree. Each app tile is an AXApplicationDockItem
/// whose AXStatusLabel is the badge text. This works whether or not the Dock is hidden, but it needs
/// Accessibility access, and an app only has a tile while it's running or kept in the Dock.
@MainActor
enum Dock {
    private static var bundleIDs: [URL: String] = [:]

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system "Alert would like to control this computer" prompt if access isn't granted yet.
    static func requestAccess() {
        // The kAXTrustedCheckOptionPrompt global isn't concurrency-safe in Swift 6; this is its value.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func items() -> [DockItem] {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?
            .processIdentifier
        else { return [] }

        let dock = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(dock, 0.5)

        let lists: [AXUIElement] = attribute(dock, kAXChildrenAttribute) ?? []
        return lists
            .filter { attribute($0, kAXRoleAttribute) == kAXListRole as String }
            .flatMap { attribute($0, kAXChildrenAttribute) ?? [] as [AXUIElement] }
            .compactMap { tile in
                guard attribute(tile, kAXSubroleAttribute) == "AXApplicationDockItem",
                      let url: URL = attribute(tile, kAXURLAttribute),
                      let bundleID = bundleID(for: url)
                else { return nil }
                let name: String = attribute(tile, kAXTitleAttribute) ?? url.deletingPathExtension().lastPathComponent
                return DockItem(bundleID: bundleID, name: name, badge: Badge(statusLabel: attribute(tile, "AXStatusLabel")))
            }
    }

    private static func bundleID(for url: URL) -> String? {
        if let cached = bundleIDs[url] { return cached }
        let id = Bundle(url: url)?.bundleIdentifier
        bundleIDs[url] = id
        return id
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
