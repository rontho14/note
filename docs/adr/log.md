# Decision log

- 2026-11-10: Numbering restarted at 0001. The three ADRs written on 2026-10-21 for the backend plan (Go backend with SQLite, per-user envelope encryption, remote MCP) were removed when the app became local-only. They remain in git history.
- 2026-11-10: Created [0001](0001-local-only-app-with-no-backend.md), accepted. A buy-once app can't fund a server, and the backend plan was too large for one user.
- 2026-11-10: Created [0002](0002-formatting-from-text-shape-without-ai.md), accepted. Formatting without typed symbols and without a model.
- 2026-11-10: Created [0003](0003-typed-text-is-never-modified.md), accepted. Nothing but the user's typing may change a note's text.
- 2026-11-10: Created [0004](0004-sqlite-with-grdb-and-fts5-search.md), accepted. One local store for notes and the search index.
- 2026-11-13: Created [0005](0005-app-structure-and-enforced-boundaries.md), accepted. Agents follow a structure only as far as `make check` enforces it.
- 2026-11-15: Updated [0005](0005-app-structure-and-enforced-boundaries.md). Added the error and single-owner checks, and a Settled details section for decisions reviews kept reopening.
- 2026-11-15: Updated [0005](0005-app-structure-and-enforced-boundaries.md). `make check` runs a UI test on the Simulator, `make ios-test-devices` runs it on more devices, and screens follow an accessibility identifier convention.
- 2026-11-15: Updated [0005](0005-app-structure-and-enforced-boundaries.md). Added `NoteTelemetry` as a fourth package, the only code that imports `os`, with a check for stray `print` calls.
- 2026-11-15: Updated [0005](0005-app-structure-and-enforced-boundaries.md). `make check-fast` runs every `scripts/check-*.sh`, and `check-rules.sh` fails when a rule a check names drifts from CLAUDE.md.
- 2026-11-16: Updated [0005](0005-app-structure-and-enforced-boundaries.md). `NoteCore` owns the empty-note rule, `NoteStore` refuses empty notes, emptied drafts are deleted rather than trashed, and the UI test run checks every simulator's database for empty notes.
- 2026-11-16: Updated [0005](0005-app-structure-and-enforced-boundaries.md). `check-migrations.sh` fails when a migration already on `main` is edited, `MigrationTests` upgrades a database from an earlier version, and the caret is stored as a UTF-8 offset.
- 2026-11-16: Updated [0005](0005-app-structure-and-enforced-boundaries.md). The launch ends at keyboard-up on the write screen, which stays on SwiftUI's `TextEditor`, and `check-owners.sh` keeps the launch screen's paper equal to `Palette.paper`.
- 2026-11-16: Updated [0005](0005-app-structure-and-enforced-boundaries.md). The write screen takes the store, saves its draft when typing pauses for `WriteScreen.saveDelay` and on backgrounding, and stops the app when a save fails.
- 2026-11-18: Updated [0005](0005-app-structure-and-enforced-boundaries.md). `NoteStorage` saves notes in all-or-none batches, and the notes list observes the store through `noteSummaries()`.
- 2026-11-19: Updated [0005](0005-app-structure-and-enforced-boundaries.md). The screens sit in `ScreenStrip`, a paging scroll view that opens on write, and the UI tests build a `DebugE2E` configuration whose launch arguments no other build contains.
- 2026-11-19: Updated [0005](0005-app-structure-and-enforced-boundaries.md). The notes list follows `noteSummaries()` through `NotesModel`, tapping a note opens it on write, and `-seed-notes` fills the database for UI tests.
