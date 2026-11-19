---
type: decision
title: App structure and enforced boundaries
description: The iOS code is split into NoteCore, NoteStore, NoteUI and NoteTelemetry plus a thin app target, with dependencies pointing one way. Each screen is a view and one observable model. Checks are added as the code they protect is written, starting with three import rules, the strict compiler settings and the swift-format lint.
tags: [architecture, modules, swift, quality, performance, security]
generated:
  by: claude-opus-5-5
  at: 2026-11-13
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
  - docs/adr/0001-local-only-app-with-no-backend.md
  - docs/adr/0003-typed-text-is-never-modified.md
  - docs/adr/0004-sqlite-with-grdb-and-fts5-search.md
  - docs/research/agent-guardrails-and-testing.md
  - https://github.com/Ranchero-Software/NetNewsWire/tree/main/Modules
  - https://github.com/Ranchero-Software/NetNewsWire/blob/main/Technotes/SwiftUI-UIKit-AppKit-Guidelines.markdown
  - https://github.com/pointfreeco/isowords/tree/main/Sources/LocalDatabaseClient
  - https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps/GRDBDemo
  - https://forums.swift.org/t/should-swiftpm-diagnose-missing-dependencies/70926
  - https://forums.swift.org/t/swiftpm-vs-xcode-build-behavior/76274
  - https://developer.apple.com/forums/thread/718416
---

# 0005. App structure and enforced boundaries

## Context and Problem

The vision says AI agents will write most of the code, guarded by strict build checks ([VISION.md](../VISION.md#engineering)). Before the first feature, the code needs a shape that every change follows, so that the hundredth screen looks like the first.

The app is small: five screens, one local database and no network ([ADR 0001](0001-local-only-app-with-no-backend.md)). Its hard parts are pure logic, the shape formatter and search ranking, plus one promise about data, that typed text is never changed ([ADR 0003](0003-typed-text-is-never-modified.md)). The structure has to keep that logic testable without a simulator, keep SQLite in one place, and keep screens responsive.

Several open-source iOS apps were read before deciding. NetNewsWire keeps its domain and its database in separate local packages. isowords puts its database behind a small interface with a live and an in-memory version. GRDB's demo app keeps all SQL in one database type and has each screen's model observe the database.

## Considered Options

- **MVC.** Apple's original UIKit pattern. One controller per screen tends to absorb everything, and nothing stops logic from spreading into views.
- **MVVM with coordinators**, as in Element X. One view model per screen, plus coordinator objects that own navigation. The app has five fixed screens joined by swipes, so there is no navigation stack for coordinators to manage.
- **VIPER or Clean Architecture.** Five types per screen. Too much code for five screens and one author.
- **The Composable Architecture**, as in isowords. Well tested and strict, but every file depends on its framework and vocabulary, and it adds code compared with plain observable models.
- **Plain SwiftUI with observable models in one app target.** Little code, but nothing keeps SQLite out of views or keeps logic testable without the app.
- **Plain SwiftUI with observable models, split into packages.** Chosen.

## Decision

### Modules

The code is split into four local Swift packages and a thin app target.

| Module | Owns | May import |
|---|---|---|
| `NoteCore` | Note, drawer and theme types. Trash expiry, draft rules, the shape formatter and search ranking. The `NoteStorage` protocol that describes reading and writing notes. | Foundation only |
| `NoteStore` | The SQLite implementation of `NoteStorage`: GRDB, migrations and the FTS5 index from [ADR 0004](0004-sqlite-with-grdb-and-fts5-search.md). | `NoteCore`, GRDB |
| `NoteUI` | SwiftUI screens and their models. | `NoteCore`, SwiftUI |
| `NoteTelemetry` | The only code that writes logs and signposts. Typed `Event`, `Op` and `Field` values, so note text can't reach a log, and the launch measurement. | `os` |
| App target | Starts the launch measurement, opens the database and hands it to `NoteUI`. Nothing else. | All four |

Dependencies point one way. `NoteStore` and `NoteUI` depend on `NoteCore`, and neither target depends on the other. Only the app target knows both exist. `NoteUI`'s manifest lists `NoteStore` for `NoteUITests` alone, which runs `WriteModel` against the real in-memory store. The `NoteCore` package also has `NoteCoreTesting`, a library of test builders such as `Note.sample` and fixed dates. It depends only on `NoteCore`, and only test targets import it. `NoteTelemetry` depends on no package of ours, and a package adds it as a dependency in the change where it first logs.

`NoteCore` does no input or output. Code that needs the time or a random value receives it as an argument, so tests control it.

`NoteStore` returns `NoteCore` types and never exposes a GRDB type. Its interface is `async`. It can open the database on disk or in memory. Tests use the in-memory database, so they run the same SQL as the app.

### Screens

Each screen is a SwiftUI view and one `@Observable` model, in files named after the screen, such as `NotesScreen.swift` and `NotesModel.swift`. The model receives a `NoteStorage` when it is created and uses `NoteCore` for any rule. A view holds no logic beyond layout.

Every interactive element, and each screen's outermost view, has an accessibility identifier, so UI tests find elements without depending on their text:

- An identifier is lowercase words joined by dots, `<screen>.<element>`, where `<screen>` is the screen's file name without `Screen`: `write.text`, `notes.list`.
- A screen's outermost view is identified by `<screen>` alone, such as `write`.
- A repeated element appends the note or drawer ID: `notes.row.<uuid>`.
- Every identifier is a constant in `AccessibilityID` in `NoteUI`. The UI tests read the same constant, so one file owns each string.

UI tests attach a screenshot at each state worth seeing, named after the identifier of the screen shown. When one test captures the same screen twice, the later shots add `.<state>`, such as `write.saved`, because `scripts/run-ui-tests.sh` fails on two screenshots with the same name.

The notes list follows `NoteStorage.noteSummaries()` through `NotesModel`, which holds nil until the store first answers so the list never flashes empty. Tapping a row calls `WriteModel.open(id:)`, which shows the note after the save that leaving write queued, and the strip then moves to write. Lists observe the database and refresh themselves when it changes, as in GRDB's demo app, instead of reloading after every save.

SwiftUI is the default. A screen moves to UIKit only when a measurement shows SwiftUI is too slow or cannot do the job. NetNewsWire follows the same rule. The write screen was the likely case, because it must restore the cursor and keep text byte for byte. On iOS 27, `TextEditor(text:selection:)` does both: an edit leaves CRLF, combining marks and emoji as they were, and the caret can be set and read through its `TextSelection`. So the write screen stays on SwiftUI until long notes measure too slow.

### Checks

This record sets the structure. It does not try to automate all of it up front.

- A check is added in the same change as the code it protects, not before that code exists.
- A rule that gets broken twice gets a check.
- Every check runs in `make check`, so a broken rule fails the build with a message that names the rule.

`make check` also launches the app. The UI tests in the `NoteE2ETests` target run on a simulator of the check device, `IOS_CHECK_DEVICE` in the Makefile, with the newest iOS that supports it, so a screen that crashes or loses its identifier fails the build. UI tests use XCTest, because Xcode doesn't make Swift Testing available to UI test bundles. `make ios-test-devices` runs the same tests on more iPhones and on iOS 26, the app's minimum. Both export the screenshots to `build/ui-tests/`. The device run happens on request, not in `make check`. `scripts/run-ui-tests.sh` creates the simulators these runs need, named `Note <device> <iOS version>`, and touches no other simulator. A missing iOS runtime stops the run, because downloading one is the author's call.

After the UI tests, `scripts/run-ui-tests.sh` runs `NoteInvariants`, an executable in the `NoteStore` package, on the database of each simulator it ran on. It opens the file read-only and fails, naming the device, the path and the note's id, when it finds an empty note. A missing app container or database file fails the run too, because the tests just launched the app.

`scripts/check-imports.sh` reads every import in the app, the packages and their tests, and the UI tests, in any form (`@testable`, access levels, `import struct`), and needs no extra tool:

- Only `NoteStore` imports GRDB.
- `NoteUI` never imports `NoteStore`.
- `NoteCore` imports nothing but Foundation.
- Only `NoteTelemetry` imports `os` or `OSLog`, in source or test code. The GRDB rule also covers test code. The `NoteUI` and `NoteCore` rules skip package test targets, which may import `NoteStore` and `Testing`.

Another check keeps the compiler strict, so data races and other unsafe code fail the build. The app target builds in Swift 6 language mode. Every package manifest and the app target turn on the `ExistentialAny`, `MemberImportVisibility` and `InternalImportsByDefault` upcoming features, approachable concurrency, strict memory safety and warnings as errors. `NoteUI` and the app target also default to `MainActor` isolation; `NoteCore` and `NoteStore` stay nonisolated because they run off the main thread. `scripts/check-settings.sh` reads the settings SwiftPM and Xcode actually resolve, through `swift package dump-package` and `xcodebuild -showBuildSettings`, and fails `make check`, naming the setting, when one is removed, commented out or overridden.

Xcode does not enforce module boundaries on its own. Modules built together share search paths, so a package can import a module it never declared. That is why the import rules are text checks, not something the package manifests guarantee.

swift-format's lint runs in `make check` too. On top of its default rules it bans force unwraps, `try!` and implicitly unwrapped optionals outside tests.

`scripts/check-errors.sh` fails when an error is swallowed: `2>/dev/null` or `|| true` in a script, the Makefile or the hook, and `try?` in app or package sources. Each of these once hid a real failure here. An exception sits on the line itself as a comment, `check-errors: allowed until YYYY-MM-DD by NAME: reason`, and fails again once its date passes.

`scripts/check-logging.sh` keeps logging in `NoteTelemetry`. It fails on a call to `print`, `debugPrint`, `dump` or `NSLog` in app, package or test code. No other module can create a `Logger` or `OSSignposter`, because both need `import os`, which `check-imports.sh` allows only in `NoteTelemetry` and its tests. Each unit of work writes one line, and its duration goes in a signpost interval and a field on that line. `Telemetry.begin(_:)` takes an `Op` and returns an interval whose `end()` closes the signpost and writes the op's completion event with its duration, so no caller can do one without the other. The interval is noncopyable and `end()` consumes it, so the compiler rejects ending it twice.

`scripts/check-rules.sh` keeps CLAUDE.md's rules table in step with the checks: every rule name a check prints must appear, word for word, in the row that names that check. `make check-fast` runs every `scripts/check-*.sh`, so a new check needs no wiring.

`scripts/check-owners.sh` keeps one owner for facts that were once kept in two places: only the Makefile runs xcodegen (scripts call `make ios-project`), and Info.plist keys live only in each target's XcodeGen `info:` properties, never in `INFOPLIST_KEY_*` or `GENERATE_INFOPLIST_FILE` settings. The paper color lives in `Palette.paper` and again in the asset catalog's `LaunchBackground`, because the launch screen can't run code, so the check fails when the two differ.

`scripts/check-migrations.sh` keeps a shipped migration as it shipped. For each `registerMigration` in `Migrations.swift`, it finds the first commit on `main` that registers that name and fails, naming the migration, when the block differs from that commit's. A migration `main` doesn't have yet may still change. `MigrationTests` covers the other half: it leaves a database at an earlier version, opens it with the current migrator and reads the note back byte for byte. That test runs today's code for the old migration, so it can't notice the old migration being edited, which is why the check exists.

Candidates for later, each added when its code appears: no `Date()` in `NoteCore`, no networking code, an allowlist of dependencies, no values pasted into SQL text, and a strict import build of `NoteCore` and `NoteStore` with `swift build`.

### Settled details

These came up in review again and again. Each was decided on purpose, so a review that raises one needs new information.

- `NoteDatabase.defaultLocation(fileManager:)` returns `<Application Support>/Note/notes.sqlite` and creates the folder. The `FileManager` is a parameter so tests never write into the Mac's real Application Support.
- Opening the database tries once more after any failure, about 200 ms later. Then the app crashes with only the SQLite result code. This is the author's choice, and the opening step is injected so tests can make it fail.
- The app target opens the store and passes it to `ScreenStrip`, `NoteUI`'s one public screen. The strip owns `WriteModel` and `NotesModel` and hands each to its screen, because tapping a note on notes changes what write shows. The strip itself has no model, only which screen is shown.
- `ScreenStrip` is a horizontal paging `ScrollView` with no gesture code of its own. Paging moves one screen per swipe and stops at both ends, and a vertical scroller inside a page keeps a drag that starts vertical. It opens on write by anchoring at its trailing end, because a `scrollPosition` set before the first layout doesn't move the view. Leaving write saves the draft at once and lowers the keyboard, and coming back raises it.
- The UI tests build the `DebugE2E` configuration, the Note scheme's test configuration, which adds the `E2E` compilation condition. Launch arguments that put the app in a known state, `-reset-storage` and `-seed-notes <count>`, live only in `ios/Note/E2EHooks.swift`, wrapped in `#if E2E`, so Debug and Release builds contain none of them. The name contains `Debug` because Xcode builds Swift packages for a configuration with any other name without testability, and `NoteUITests` needs `@testable import`.
- The write screen saves the draft `DraftSaving.delay` after the last keystroke, through SwiftUI's `task(id:)` on the text, and at once when the screen is left or the scene goes to the background, without asking iOS for extra time. `WriteModel` runs its saves one after another, so the two triggers never store the draft twice. `DraftChange` in `NoteCore` decides what each save does: it creates the draft's id on the first save of text that isn't empty, deletes the draft when its text is erased, so the next typing starts a new note, and moves `modifiedAt` only when the text changes. `WriteModel` carries the decision out against the store. `DraftChange` handles a first save, with no draft yet, in its own branch rather than starting from a blank placeholder note, so creating a note never depends on a placeholder's text.
- Returning to the app is its own step, `WriteModel.returnToForeground(now:)`: it keeps the draft on screen when `DraftReopening.reopens(modifiedAt:now:)` says it is inside the window, and otherwise clears the screen. It does not reload the draft from the store, because the draft on screen is the one just saved.
- A save or load that fails stops the app, as a database that won't open does. The models throw, and the views decide to stop through one shared `stoppingTheAppOnFailure` helper in `NoteUI`, used by the write screen's loads and saves, the notes list's read loop and opening a note from the list, so the models stay testable on a failing store. There is no error screen yet, and hiding the failure would hide a lost draft. The crash loses the typing since the last successful save.
- `Note.isEmpty` in `NoteCore` owns what empty means: every character is whitespace. A zero-width space is content. `NoteStore`'s save throws `NoteStorageError.emptyNote` rather than store one, refusing a whole batch that holds one, and `NoteInvariants` reuses `isEmpty` instead of restating it in SQL.
- A draft whose text is erased is removed with `NoteStorage.deletePermanently(id:)`, not moved to the trash. The trash holds notes the user deleted, and that flow gets its own method.
- `Note.cursor` is the caret as a UTF-8 offset into the text. The text is stored byte for byte, so the offset points at the same place on reopen. `Note.cursorIndex` turns it back into a position, moving an offset inside a character back to that character's start and clamping one outside the text. `cursor` and `text` are plain variables that can change apart, and `cursorIndex` is the one reading of the caret, so it accepts any offset. Making `cursor` read-only, or changing text and caret only through one edit method, was weighed and declined by the author: the first guards nothing while the initializer takes any offset, and the second costs every keystroke a call for a rule `cursorIndex` already keeps.
- `NoteStorage` has one write, `save(contentsOf:)`: a bound SQL upsert per note that keeps the first `createdAt`, all in one transaction, so a batch is stored whole or not at all. `save(_:)` is that write with one note. A note is read whole through `NoteRecord`, an internal GRDB record. The notes list reads `noteSummaries()`, a GRDB `ValueObservation` decoded through `NoteSummaryRecord`, which reads only the start of each note's text and sends the list again after every change. Dates are stored in GRDB's text format, at millisecond precision.
- Every `Package.swift` writes the strict settings out in full, because manifests can't share code. `check-settings.sh` guards the copies.
- `NoteTelemetry`'s `Event`, `Field` and `Op` stay typed even with one case each. No case takes a free-form `String`, which is what lets a line be logged as public, and each new case is a one-line diff that review can question. Replacing them with string literals, or adding cases before code logs them, reopens this.
- Logs and signposts use the subsystem `com.rontho14.note`, a fixed name that log filters and scripts match. It reads like the bundle ID but is not derived from it, so renaming the bundle ID leaves it as it is.
- `LaunchMeasurement` runs on the main actor, where the app begins and records it, so it needs no lock.
- The launch ends at the first `UIResponder.keyboardDidShowNotification` on the write screen, because the vision's budget is launch to keyboard. iOS posts it more than once, and `LaunchMeasurement` records only the first. `WriteScreen` observes the notification and calls the `onKeyboardUp` closure it is given, and the app passes `launch.recordLaunched()`. The screen knows when its own keyboard is up, and the app target stays a few lines of wiring with no observers of its own.
- `WriteScreen` places the text with outer padding that subtracts `TextEditor`'s own insets, `editorSideInset` and `editorTopInset` in its `Layout`, measured from the `write` screenshot, so the text sits where DESIGN.md says.
- `LaunchMeasurement.recordLaunched()` returns the launch duration, or nil on every call after the first. The app ignores it. Tests read it to prove the launch is logged once, without reading the unified log.
- `scripts/test-checks.sh` lists each required setting by hand instead of reading the list in `check-settings.sh`. A test that takes its expected values from the code it tests can't notice that code dropping one.

### Performance

- `NoteCore` and `NoteStore` contain no iOS-only code, so they build and test on the Mac with `swift test`, with no simulator. Formatter and search tests run there against large sets of notes. `NoteUI` is iOS-only, so `scripts/test-packages.sh` runs only the packages that build for macOS, and `NoteUITests` run in the Simulator as a test target of the Note scheme, with the UI tests. `scripts/check-test-targets.sh` fails when an iOS-only package has a test target the scheme doesn't list, so no test runs nowhere.
- `NoteStore` opens SQLite in WAL mode through a `DatabasePool`, so reads do not wait for writes. Views cannot reach GRDB and the store's interface is `async`, so no query runs on the main thread.
- Launch to keyboard and search time have budgets checked by tests, as the vision requires.

### Security

- The app contains no code that can make a network request.
- SQL values are always bound through GRDB's arguments or its `literal:` interpolation, never pasted into the SQL text.
- The database relies on iOS file protection, as [ADR 0004](0004-sqlite-with-grdb-and-fts5-search.md) says. It keeps the default class, which unlocks at the first unlock after a restart. The strictest class makes open files unwritable once the phone locks, and the app saves drafts as the user leaves it, so drafts would sometimes be lost.
- Note text never reaches a log. Every line goes through `NoteTelemetry`, whose `Event` and `Field` cases take no free-form `String` and whose `Op` values are declared once, each with a literal name and its completion event. A line holds only those names and numbers, so it is logged as public.

## Consequences

- Every change has an obvious place to go: a rule in `NoteCore`, SQL in `NoteStore`, a screen in `NoteUI`.
- The formatter, search ranking and the database are tested without launching the app.
- The first feature costs a little more setup: four packages instead of one app target.
- At the start only the three import rules, the strict compiler settings and the swift-format lint were checked. The other rules hold by convention and review until a check is added, so early on they can be broken without the build noticing.
- Text checks can be fooled by unusual spellings. They catch honest mistakes, not deliberate evasion.
- `NoteCore` and `NoteStore` cannot use UIKit or other iOS-only APIs.
- `NoteUI` cannot build its previews from `NoteStore`. The app target or a preview helper has to supply an in-memory store. The write screen has no preview for now: it needs a store, and a store written only for previews would be a second `NoteStorage` to keep correct. Its UI test screenshots show it instead.
