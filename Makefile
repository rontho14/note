IOS_DIR := ios
DERIVED_DATA := build/DerivedData

.DEFAULT_GOAL := ios-build
.PHONY: ios-project ios-build check-imports test-checks check clean

# Generate ios/Note.xcodeproj from ios/project.yml.
ios-project:
	@command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen"; exit 1; }
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

# Plants a violation of each rule in a scratch copy and expects its check to fail.
test-checks:
	scripts/test-checks.sh

# Everything that must pass before a change is done.
check: check-imports test-checks ios-build

clean:
	rm -rf build $(IOS_DIR)/Note.xcodeproj
