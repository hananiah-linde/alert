APP := dist/Alert.app
TAP_DIR ?= ../homebrew-tap

.PHONY: build run clean release

build:
	./scripts/build-app.sh

run: build
	@pkill -x Alert || true
	open $(APP)

# Sign, notarize, publish the GitHub Release for VERSION, and bump the cask. See $(TAP_DIR)/scripts/release-macos-app.sh.
release:
	$(TAP_DIR)/scripts/release-macos-app.sh Alert alert

clean:
	rm -rf .build dist
