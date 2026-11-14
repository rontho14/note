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

- Done means `make check` passes. Until that target exists, `make` must build the app.
- A rule that gets broken twice gets a check in `make check`.
- Never edit `ios/Note.xcodeproj`. XcodeGen generates it from `ios/project.yml`.
- Never add a dependency without an ADR.
- Never edit a migration that has shipped.
- Commit straight to `main`.
