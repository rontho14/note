IOS_DIR := ios
IOS_CHECK_DEVICE ?= iPhone 14 Pro Max@latest
IOS_TEST_DEVICES ?= $(IOS_CHECK_DEVICE),iPhone 15@latest,iPhone 17 Pro@latest,iPhone 17e@latest,iPhone 14 Pro Max@26
DEVICES ?= $(IOS_CHECK_DEVICE)
DERIVED_DATA := build/DerivedData
CHECKS := $(patsubst scripts/%.sh,%,$(wildcard scripts/check-*.sh))
SWIFT_SOURCES = $(shell find $(IOS_DIR)/Note $(IOS_DIR)/NoteE2ETests $(IOS_DIR)/Packages -name '*.swift' -not -path '*/.build/*')

.DEFAULT_GOAL := ios-build
.PHONY: setup require-xcodegen fmt lint ios-project ios-build ios-test ios-test-devices $(CHECKS) check-fast test-checks test-packages check clean

# Install the pre-commit hook and confirm the tools the build needs.
setup: require-xcodegen
	git config core.hooksPath .githooks

require-xcodegen:
	@command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen"; exit 1; }

fmt:
	xcrun swift-format format --in-place $(SWIFT_SOURCES)

lint:
	xcrun swift-format lint --strict $(SWIFT_SOURCES)

# Generate ios/Note.xcodeproj from ios/project.yml.
ios-project: require-xcodegen
	cd $(IOS_DIR) && xcodegen generate --quiet

# Build the app for the iOS Simulator. Simulator builds need no signing.
ios-build: ios-project
	xcodebuild build \
		-project $(IOS_DIR)/Note.xcodeproj \
		-scheme Note \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(DERIVED_DATA) \
		-quiet

# Run the UI tests on DEVICES and export their screenshots to build/ui-tests.
# ONLY=<Target/Class/test> runs one test.
ios-test: ios-project
	scripts/run-ui-tests.sh $(IOS_DIR)/Note.xcodeproj $(DERIVED_DATA) '$(DEVICES)' '$(ONLY)'

# The same, on every device in IOS_TEST_DEVICES.
ios-test-devices: DEVICES = $(IOS_TEST_DEVICES)
ios-test-devices: ios-test

# Every scripts/check-<name>.sh is a target named check-<name>, and check-fast runs them all.
$(CHECKS): check-%: scripts/check-%.sh
	bash $<

# The quick checks the pre-commit hook runs.
check-fast: lint $(CHECKS)

# Plants a violation of each rule in a scratch copy and expects its check to fail.
test-checks:
	scripts/test-checks.sh

# The tests of every package that builds for macOS, on the Mac with no simulator. An iOS-only package's tests run in
# the Simulator through ios-test, and check-test-targets.sh makes sure the Note scheme lists them.
test-packages:
	scripts/test-packages.sh

# Everything that must pass before a change is done, fastest first.
check: check-fast test-checks test-packages ios-test

clean:
	rm -rf build $(IOS_DIR)/Note.xcodeproj
