import AppKit
import SwiftUI

/// Every app the window can offer: installed apps plus anything in the Dock or running.
@MainActor
final class AppCatalog: ObservableObject {
    struct App: Identifiable, Hashable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    @Published private(set) var apps: [App] = []

    private static let folders = [
        "/Applications", "/Applications/Utilities",
        "/System/Applications", "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
    ]

    func reload(including extra: [String]) {
        let fileManager = FileManager.default
        let installed = Self.folders.flatMap { folder in
            ((try? fileManager.contentsOfDirectory(atPath: folder)) ?? [])
                .filter { $0.hasSuffix(".app") }
                .compactMap { Bundle(path: "\(folder)/\($0)")?.bundleIdentifier }
        }
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
        let ownID = Bundle.main.bundleIdentifier
        apps = Set(installed + running + extra)
            .filter { $0 != ownID && AppInfo.url(for: $0) != nil }
            .map { App(bundleID: $0, name: AppInfo.name(for: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// Alert's only window, where you pick the apps to show in the menu bar. Alert gets a Dock icon and
/// a place in ⌘-Tab while it's open, and goes back to living only in the menu bar when it closes.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let watched: WatchedApps
    private let monitor: BadgeMonitor
    private let catalog = AppCatalog()
    private var window: NSWindow?

    init(watched: WatchedApps, monitor: BadgeMonitor) {
        self.watched = watched
        self.monitor = monitor
    }

    func show() {
        catalog.reload(including: watched.bundleIDs + monitor.items.map(\.bundleID))
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            watched: watched, monitor: monitor, catalog: catalog,
            addOtherApp: { [weak self] in self?.addOtherApp() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Alert"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("Settings")
        return window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func addOtherApp() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.message = "Choose apps to show in the menu bar"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self else { return }
            let bundleIDs = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            bundleIDs.forEach(self.watched.add)
            self.catalog.reload(including: self.watched.bundleIDs + self.monitor.items.map(\.bundleID))
        }
    }
}

struct SettingsView: View {
    @ObservedObject var watched: WatchedApps
    @ObservedObject var monitor: BadgeMonitor
    @ObservedObject var catalog: AppCatalog
    let addOtherApp: () -> Void

    @State private var search = ""
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            if !monitor.isTrusted {
                accessBanner
                Divider()
            }

            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(12)

            List {
                if search.isEmpty {
                    Section("In the Menu Bar") {
                        if watched.bundleIDs.isEmpty {
                            Text("Tick the apps whose badges you want to see.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(watched.bundleIDs, id: \.self) { row($0, name: AppInfo.name(for: $0)) }
                    }
                    Section("All Apps") {
                        ForEach(catalog.apps.filter { !watched.contains($0.bundleID) }) { row($0.bundleID, name: $0.name) }
                    }
                } else {
                    ForEach(catalog.apps.filter { $0.name.localizedCaseInsensitiveContains(search) }) {
                        row($0.bundleID, name: $0.name)
                    }
                }
            }

            Divider()

            HStack {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LaunchAtLogin.set($0) }
                Spacer()
                Button("Add Other App…", action: addOtherApp)
                Button("Quit Alert") { NSApp.terminate(nil) }
            }
            .padding(12)
        }
        .frame(width: 440, height: 560)
    }

    private var accessBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Alert needs Accessibility access").bold()
                Text("Alert reads app badges from the Dock, which macOS only allows with Accessibility access.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Grant Access…") {
                Dock.requestAccess()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(12)
    }

    private func row(_ bundleID: String, name: String) -> some View {
        let isOn = Binding(
            get: { watched.contains(bundleID) },
            set: { $0 ? watched.add(bundleID) : watched.remove(bundleID) }
        )
        return Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(nsImage: AppInfo.icon(for: bundleID))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(name)
                Spacer()
                badgeLabel(monitor.badge(for: bundleID))
            }
        }
        .toggleStyle(.checkbox)
    }

    @ViewBuilder
    private func badgeLabel(_ badge: Badge) -> some View {
        switch badge {
        case .none:
            EmptyView()
        case .dot:
            Circle().fill(.red).frame(width: 8, height: 8)
        case .label(let text):
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.red))
        }
    }
}
