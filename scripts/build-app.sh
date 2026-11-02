#!/usr/bin/env bash
# Builds dist/Alert.app from the SwiftPM package.
#
# Environment:
#   UNIVERSAL=1      build arm64 + x86_64 (default: host arch only)
#   BUILD=<n>        CFBundleVersion (default: 1)
#   BUNDLE_ID=<id>   CFBundleIdentifier (default: io.github.hananiah-linde.alert)
#   SIGN_IDENTITY=…  codesign identity (default: "-" for ad-hoc)
#
# CFBundleShortVersionString comes from the VERSION file.
set -euo pipefail

APP_NAME="Alert"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="${BUILD:-1}"
BUNDLE_ID="${BUNDLE_ID:-io.github.hananiah-linde.alert}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
UNIVERSAL="${UNIVERSAL:-0}"

# The Command Line Tools lack some x86_64 Swift libraries; use Xcode's toolchain when it's installed.
if [ -z "${DEVELOPER_DIR:-}" ] && [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ] \
    && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# Bash 3.2 + set -u treats "${arr[@]}" on an empty array as unbound,
# so expand with ${arr[@]+"${arr[@]}"}.
SWIFT_ARGS=()
if [ "$UNIVERSAL" = "1" ]; then
    SWIFT_ARGS=(--arch arm64 --arch x86_64)
fi

echo "==> swift build -c release ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"}"
swift build -c release ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"}
BIN_DIR="$(swift build -c release ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"} --show-bin-path)"

APP="dist/$APP_NAME.app"
echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
# Compiles the icon to Assets.car + AppIcon.icns. actool ships with Xcode, not the Command Line Tools.
xcrun actool Resources/Assets.xcassets --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 13.0 --app-icon AppIcon \
    --output-partial-info-plist "$(mktemp)" > /dev/null
sed -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD/g" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"

echo "==> Signing with identity: $SIGN_IDENTITY"
# Notarization requires a secure timestamp; ad-hoc signatures can't have one.
TIMESTAMP_ARG="--timestamp"
if [ "$SIGN_IDENTITY" = "-" ]; then
    TIMESTAMP_ARG="--timestamp=none"
fi
codesign --force --options runtime "$TIMESTAMP_ARG" --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Built $APP ($VERSION build $BUILD, $BUNDLE_ID)"
lipo -archs "$APP/Contents/MacOS/$APP_NAME"
