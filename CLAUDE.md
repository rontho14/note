# Note

A minimal note-taking app for iPhone. Everything stays on the phone.

## Source of truth

The documents in `docs/` are the source of truth.

- [docs/VISION.md](docs/VISION.md) says what the app does.
- [docs/DESIGN.md](docs/DESIGN.md) says how it looks.
- [docs/adr](docs/adr/index.md) holds the decisions and the reasons for them.

## Status

- The app has no users and holds no real notes.
- The author will not use it until the first version is complete. The first version is all five steps of the build order in VISION.md.
- So there are no notes to protect during development. Don't reorder work or add stopgaps for that.
- The data rules still apply in full. Text is stored byte for byte and every migration is tested, because the app will hold real notes once it is finished.

## Rules

Done means `make check` passes. Run `make setup` once to install the pre-commit hook.

A rule that gets broken twice gets a check in `make check`. When a correction repeats a rule below that only review enforces, add the check in the same change and move the rule's row to it.

| Rule | Enforced by |
|---|---|
| Only `NoteStore` imports GRDB. `NoteUI` never imports `NoteStore`. `NoteCore` imports only Foundation. | `scripts/check-imports.sh` |
| The strict compiler settings stay on in every `Package.swift` and the app target. | `scripts/check-settings.sh` |
| Code is formatted. No force unwraps, `try!` or implicitly unwrapped optionals outside tests. | swift-format lint, configured in `.swift-format` |
| Errors are never swallowed: no `2>/dev/null` or `\|\| true` in scripts, no `try?` in app or package sources. | `scripts/check-errors.sh` |
| Scripts generate the Xcode project with `make ios-project`. Info.plist keys live in the target's `info:` properties in `ios/project.yml`. | `scripts/check-owners.sh` |
| Every check fails on a planted violation and names its rule. | `scripts/test-checks.sh` |
| Text is stored byte for byte. | `NoteStorageTests` |
| Every interactive element and each screen's outermost view has an accessibility identifier, a constant in `AccessibilityID` named by the convention in ADR 0005. | Review only |
| Never edit `ios/Note.xcodeproj`. | It is generated from `ios/project.yml` and gitignored. |
| Never add a dependency without an ADR. | Review only |
| Never edit a migration that has shipped. | Review only, until the upgrade test arrives with the second migration |
| A change to behavior a doc describes updates that doc in the same commit. | Review only: a judgment call |
| New `scripts/test-checks.sh` cases go through `expect_fail`, `expect_pass` and the existing fixture helpers. | Review only |
| A name says its main side effect. A parameter that only tests use needs a recorded reason. | Review only: a judgment call |
| Settled decisions in the ADRs are not reopened in review without new information. | Review only |
| Commit straight to `main`. | Review only |
