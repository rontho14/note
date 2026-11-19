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

Then install the pre-commit hook, once per clone:

```bash
make setup
```

Build for the iOS Simulator:

```bash
make
```

Before calling a change done, run everything: lint, the import and compiler-settings checks, the package tests on the Mac, and the UI tests on the check device, `IOS_CHECK_DEVICE` in the [Makefile](Makefile).

```bash
make check
```

`make ios-test` runs only the UI tests, built in the `DebugE2E` configuration so that launch arguments in `ios/Note/E2EHooks.swift` can put the app in a known state; `-reset-storage` starts it with no notes, and `-seed-notes <count>` adds that many fixed notes. It writes their screenshots to `build/ui-tests/<device> <iOS version>/`. Afterwards it reads the app's database on each simulator and fails if it holds an empty note. `ONLY=NoteE2ETests/LaunchTests/testLaunchOpensABlankNoteThatKeepsWhatIsTyped` runs a single one.

To see the app on several iPhones, and on iOS 26, the oldest version it supports:

```bash
make ios-test-devices
```

It runs the UI tests on every device in `IOS_TEST_DEVICES` in the [Makefile](Makefile), each written `<device>@<iOS>`. The simulators it needs are created on the first run. The iOS runtimes are not: install iOS 26 once in Xcode > Settings > Components.

`make fmt` fixes formatting that `make check` rejects.

The Xcode project is generated from [ios/project.yml](ios/project.yml) and is not checked in. Change the spec, never the `.xcodeproj`. `make ios-project` regenerates it if you want to open it in Xcode; `make clean` removes it and the build output.

## Fonts

The bundled fonts and their license files are in `NoteUI`'s `Fonts` folder. [DESIGN.md](docs/DESIGN.md#fonts-and-licenses) names each face, its license and its copyright line.
