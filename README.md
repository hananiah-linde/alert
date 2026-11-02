# Alert

A tiny macOS menu bar app that puts the Dock badges of apps you pick, like Slack or Messages, in your menu bar.

If you keep the Dock hidden, an app's unread badge is out of sight until you go looking for it. Pick apps in Alert's window, and each one gets its own icon in the menu bar. Alert adds nothing else there:

| Icon | Meaning |
| --- | --- |
| Greyed-out app icon | No badge: nothing unread |
| App icon with a red dot | A badge with no number, like Slack's unread channels |
| App icon with a red number | A count, like Slack mentions or unread Messages |

- **Click** an app's icon to bring that app to the front.
- **Right-click** (or two-finger tap) an icon to remove it, open **Alert Settings…**, or quit.
- **⌘-drag** icons to reorder them. Alert remembers where you put them.

Alert's window opens on first launch. In it you tick the apps to watch, search everything installed, add apps from elsewhere with **Add Other App…**, and turn on **Launch at Login**. Close the window and Alert keeps running from the menu bar alone. To get the window back, open Alert again from Spotlight or Finder, or right-click any of its icons.

Requires macOS 13 Ventura or later.

## How it works

Alert reads the badge from each app's Dock tile through the Accessibility API, the same way VoiceOver does. The Dock keeps those badges up to date even when it's hidden, so Alert polls them every 2 seconds.

That means:

- **Alert needs Accessibility access.** It asks on first launch. You can also grant it under System Settings → Privacy & Security → Accessibility.
- **The app has to be running** or kept in the Dock, since a badge only exists on a Dock tile. Quit Messages and its badge goes with it.
- **The app's badge has to be turned on.** Check System Settings → Notifications → (the app) → Badge application icon. Slack also has its own setting under Preferences → Notifications.

Alert doesn't read notification content, and it makes no network connections.

## Install

Homebrew:

```sh
brew tap hananiah-linde/tap
brew trust --cask hananiah-linde/tap/alert
brew install --cask hananiah-linde/tap/alert
```

Homebrew only loads casks from third-party taps you've trusted, which is what `brew trust` does.

Or download `Alert-<version>.zip` from [Releases](https://github.com/hananiah-linde/alert/releases), unzip, and move `Alert.app` to `/Applications`.

## Build from source

Requires Xcode 16 or later (Swift 6).

```sh
git clone https://github.com/hananiah-linde/alert.git
cd alert
make build        # -> dist/Alert.app
make run          # build, quit any running copy, and launch
```

`scripts/build-app.sh` accepts these environment variables:

| Variable        | Default                          | Purpose                                 |
| --------------- | -------------------------------- | --------------------------------------- |
| `UNIVERSAL`     | `0`                              | `1` builds for both arm64 and x86_64     |
| `BUILD`         | `1`                              | `CFBundleVersion`                        |
| `BUNDLE_ID`     | `io.github.hananiah-linde.alert` | `CFBundleIdentifier`                     |
| `SIGN_IDENTITY` | `-` (ad-hoc)                     | `codesign` identity                      |

The version comes from the `VERSION` file.

The app icon is drawn by `scripts/make-icon.swift`. After changing the drawing, run `swift scripts/make-icon.swift` to regenerate `Resources/Assets.xcassets`.

macOS ties the Accessibility grant to the app's code signature. `make build` signs with your Developer ID Application certificate when the keychain has one, so the grant survives rebuilds. Ad-hoc builds (no certificate, or running `scripts/build-app.sh` directly) get a new signature every time. After rebuilding one of those, remove Alert from the Accessibility list with the − button and add it again, or run `tccutil reset Accessibility io.github.hananiah-linde.alert`.

## Releasing

Releases are built on this Mac with the shared script in [hananiah-linde/homebrew-tap](https://github.com/hananiah-linde/homebrew-tap), cloned next to this repo:

1. Bump `VERSION`, commit, and push.
2. `make release`

That tags `v<VERSION>`, builds a universal app, signs it with Developer ID, notarizes and staples it, publishes `Alert-<version>.zip` to a GitHub Release, and updates the cask. See the tap's README for the one-time keychain setup. A manual CI fallback is under Actions → Release.

## License

[MIT](LICENSE)
