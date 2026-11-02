APP := dist/Alert.app
TAP_DIR ?= ../homebrew-tap

# macOS ties the Accessibility grant to the code signature. Ad-hoc builds get a new one every time, so
# sign local builds with a Developer ID when there is one and the grant survives rebuilds.
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')

.PHONY: build run clean release

build:
	SIGN_IDENTITY="$(or $(SIGN_IDENTITY),-)" ./scripts/build-app.sh

run: build
	@pkill -x Alert || true
	open $(APP)

# Sign, notarize, publish the GitHub Release for VERSION, and bump the cask. See $(TAP_DIR)/scripts/release-macos-app.sh.
release:
	$(TAP_DIR)/scripts/release-macos-app.sh Alert alert

clean:
	rm -rf .build dist
