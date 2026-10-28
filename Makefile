IOS_DIR := ios
DERIVED_DATA := build/DerivedData

.DEFAULT_GOAL := ios-build
.PHONY: ios-project ios-build clean

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

clean:
	rm -rf build $(IOS_DIR)/Note.xcodeproj
