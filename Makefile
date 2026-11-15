IOS_DIR := ios
IOS_CHECK_DEVICE ?= iPhone 14 Pro Max@latest
IOS_TEST_DEVICES ?= $(IOS_CHECK_DEVICE),iPhone 15@latest,iPhone 17 Pro@latest,iPhone 17e@latest,iPhone 14 Pro Max@26
DEVICES ?= $(IOS_CHECK_DEVICE)
DERIVED_DATA := build/DerivedData
SWIFT_SOURCES = $(shell find $(IOS_DIR)/Note $(IOS_DIR)/NoteE2ETests $(IOS_DIR)/Packages -name '*.swift' -not -path '*/.build/*')

.DEFAULT_GOAL := ios-build
.PHONY: setup require-xcodegen fmt lint ios-project ios-build ios-test ios-test-devices check-imports check-settings check-errors check-owners check-logging check-fast test-checks test-packages check clean

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

check-imports:
	scripts/check-imports.sh

check-settings:
	scripts/check-settings.sh

check-errors:
	scripts/check-errors.sh

check-owners:
	scripts/check-owners.sh

check-logging:
	scripts/check-logging.sh

# The quick checks the pre-commit hook runs.
check-fast: lint check-imports check-settings check-errors check-owners check-logging

# Plants a violation of each rule in a scratch copy and expects its check to fail.
test-checks:
	scripts/test-checks.sh

# Every package's tests, on the Mac with no simulator.
test-packages:
	for tests in $(IOS_DIR)/Packages/*/Tests; do swift test --package-path "$$(dirname "$$tests")" || exit 1; done

# Everything that must pass before a change is done, fastest first.
check: check-fast test-checks test-packages ios-test

clean:
	rm -rf build $(IOS_DIR)/Note.xcodeproj
