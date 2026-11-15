IOS_DIR := ios
DERIVED_DATA := build/DerivedData
SWIFT_SOURCES = $(shell find $(IOS_DIR)/Note $(IOS_DIR)/Packages -name '*.swift' -not -path '*/.build/*')

.DEFAULT_GOAL := ios-build
.PHONY: setup require-xcodegen fmt lint ios-project ios-build check-imports check-settings check-fast test-checks test-packages check clean

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

check-imports:
	scripts/check-imports.sh

check-settings:
	scripts/check-settings.sh

# The quick checks the pre-commit hook runs.
check-fast: lint check-imports check-settings

# Plants a violation of each rule in a scratch copy and expects its check to fail.
test-checks:
	scripts/test-checks.sh

# Every package's tests, on the Mac with no simulator.
test-packages:
	for tests in $(IOS_DIR)/Packages/*/Tests; do swift test --package-path "$$(dirname "$$tests")" || exit 1; done

# Everything that must pass before a change is done, fastest first.
check: check-fast test-checks test-packages ios-build

clean:
	rm -rf build $(IOS_DIR)/Note.xcodeproj
