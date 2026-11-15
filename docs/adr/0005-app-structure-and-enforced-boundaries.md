---
type: decision
title: App structure and enforced boundaries
description: The iOS code is split into NoteCore, NoteStore and NoteUI plus a thin app target, with dependencies pointing one way. Each screen is a view and one observable model. Checks are added as the code they protect is written, starting with three import rules and the strict compiler settings.
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

The code is split into three local Swift packages and a thin app target.

| Module | Owns | May import |
|---|---|---|
| `NoteCore` | Note, drawer and theme types. Trash expiry, draft rules, the shape formatter and search ranking. The `NoteStorage` protocol that describes reading and writing notes. | Foundation only |
| `NoteStore` | The SQLite implementation of `NoteStorage`: GRDB, migrations and the FTS5 index from [ADR 0004](0004-sqlite-with-grdb-and-fts5-search.md). | `NoteCore`, GRDB |
| `NoteUI` | SwiftUI screens and their models. | `NoteCore`, SwiftUI |
| App target | Opens the database and hands it to `NoteUI`. Nothing else. | All three |

Dependencies point one way. `NoteStore` and `NoteUI` depend on `NoteCore`, and neither depends on the other. Only the app target knows both exist.

`NoteCore` does no input or output. Code that needs the time or a random value receives it as an argument, so tests control it.

`NoteStore` returns `NoteCore` types and never exposes a GRDB type. Its interface is `async`. It can open the database on disk or in memory. Tests use the in-memory database, so they run the same SQL as the app.

### Screens

Each screen is a SwiftUI view and one `@Observable` model, in files named after the screen, such as `NotesScreen.swift` and `NotesModel.swift`. The model receives a `NoteStorage` when it is created and uses `NoteCore` for any rule. A view holds no logic beyond layout.

Lists observe the database and refresh themselves when it changes, as in GRDB's demo app, instead of reloading after every save.

SwiftUI is the default. A screen moves to UIKit only when a measurement shows SwiftUI is too slow or cannot do the job. The write screen is the likely case, because it must restore the cursor and handle long notes. NetNewsWire follows the same rule.

### Checks

This record sets the structure. It does not try to automate all of it up front.

- A check is added in the same change as the code it protects, not before that code exists.
- A rule that gets broken twice gets a check.
- Every check runs in `make check`, so a broken rule fails the build with a message that names the rule.

Three checks come with the packages, because each is a one-line text search and needs no tool:

- Only `NoteStore` imports GRDB.
- `NoteUI` never imports `NoteStore`.
- `NoteCore` imports nothing but Foundation.

A fourth check keeps the compiler strict, so data races and other unsafe code fail the build. The app target builds in Swift 6 language mode. Every package manifest and the app target turn on the `ExistentialAny`, `MemberImportVisibility` and `InternalImportsByDefault` upcoming features, approachable concurrency, strict memory safety and warnings as errors. `NoteUI` and the app target also default to `MainActor` isolation; `NoteCore` and `NoteStore` stay nonisolated because they run off the main thread. `scripts/check-settings.sh` reads the settings SwiftPM and Xcode actually resolve, through `swift package dump-package` and `xcodebuild -showBuildSettings`, and fails `make check`, naming the setting, when one is removed, commented out or overridden.

Xcode does not enforce module boundaries on its own. Modules built together share search paths, so a package can import a module it never declared. That is why the import rules are text checks, not something the package manifests guarantee.

Candidates for later, each added when its code appears: no `Date()` in `NoteCore`, no networking code, an allowlist of dependencies, no values pasted into SQL text, no `print` or `try!`, and a strict import build of `NoteCore` and `NoteStore` with `swift build`.

### Performance

- `NoteCore` and `NoteStore` contain no iOS-only code, so they build and test on the Mac with `swift test`, with no simulator. Formatter and search tests run there against large sets of notes.
- `NoteStore` opens SQLite in WAL mode through a `DatabasePool`, so reads do not wait for writes. Views cannot reach GRDB and the store's interface is `async`, so no query runs on the main thread.
- Launch to keyboard and search time have budgets checked by tests, as the vision requires.

### Security

- The app contains no code that can make a network request.
- SQL values are always bound through GRDB's arguments or its `literal:` interpolation, never pasted into the SQL text.
- The database relies on iOS file protection, as [ADR 0004](0004-sqlite-with-grdb-and-fts5-search.md) says. It keeps the default class, which unlocks at the first unlock after a restart. The strictest class makes open files unwritable once the phone locks, and the app saves drafts as the user leaves it, so drafts would sometimes be lost.
- Note text never reaches a log. Logging goes through the system `Logger`, which redacts variable values by default.

## Consequences

- Every change has an obvious place to go: a rule in `NoteCore`, SQL in `NoteStore`, a screen in `NoteUI`.
- The formatter, search ranking and the database are tested without launching the app.
- The first feature costs a little more setup: three packages instead of one app target.
- At the start only the three import rules and the strict compiler settings are checked. The other rules hold by convention and review until a check is added, so early on they can be broken without the build noticing.
- Text checks can be fooled by unusual spellings. They catch honest mistakes, not deliberate evasion.
- `NoteCore` and `NoteStore` cannot use UIKit or other iOS-only APIs.
- `NoteUI` cannot build its previews from `NoteStore`. The app target or a preview helper has to supply an in-memory store.
