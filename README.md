# note
minimal and clean note taking app for iOS

## Building the iOS app

Requirements: Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

On a new Mac, finish Xcode's setup once:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

Then build for the iOS Simulator:

```bash
make
```

The Xcode project is generated from [ios/project.yml](ios/project.yml) and is not checked in. Change the spec, never the `.xcodeproj`. `make ios-project` regenerates it if you want to open it in Xcode; `make clean` removes it and the build output.
