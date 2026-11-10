---
type: decision
title: SQLite with GRDB and FTS5 search
description: Notes are stored in one SQLite database through GRDB. Search uses SQLite's FTS5 index, with typo tolerance built on the index's word list.
tags: [storage, database, search, sqlite]
generated:
  by: claude-fable-5-2
  at: 2026-11-10
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
  - docs/adr/0001-local-only-app-with-no-backend.md
---

# 0004. SQLite with GRDB and FTS5 search

## Context and Problem

With everything on the phone ([ADR 0001](0001-local-only-app-with-no-backend.md)), the app needs a local store for notes, drawers, the trash and formatting corrections. It also needs search that updates on every keystroke, matches partial words, ignores accents and tolerates typos.

## Considered Options

**Storage**

- **Plain text files, one per note.** Easy to export, but titles, drawers and corrections need a second store, and search needs an index anyway.
- **SwiftData or Core Data.** Apple's own frameworks. They hide the SQL, give no direct access to FTS5, and make schema migrations harder to test.
- **SQLite through GRDB.** Direct SQL, explicit migrations, and full access to FTS5. GRDB is a widely used Swift library for SQLite.

**Search**

- **Scan every note on each keystroke.** Simple, but it slows down as notes accumulate and gives no ranking.
- **A separate search library.** Another dependency and a second copy of the data to keep in step.
- **SQLite FTS5.** A full-text index inside the same database, updated in the same transaction as the note.

## Decision

The app stores all data in one SQLite database, accessed through GRDB. Search uses an FTS5 index over note titles and text.

- Partial words match through prefix queries.
- Accents are ignored through the index's tokenizer settings.
- Typo tolerance is a second pass. When a search word finds little or nothing, the app compares it with the index's word list, finds the closest real words by edit distance, and searches again. Very short words get no correction, medium words allow one wrong letter, and long words allow two.
- Exact and partial matches always rank above typo-corrected ones.

## Consequences

- Notes and their search index change together in one transaction, so the index cannot fall out of step.
- GRDB is the app's one significant third-party dependency. Only the storage module may import it.
- Schema changes are explicit migrations, and each one gets a test.
- Search speed is a tested budget that fails the build when exceeded.
- The edit-distance thresholds decide how forgiving search feels. They need a test set of real typos.
- The database is not encrypted by the app. It relies on iOS file protection, which encrypts app data while the phone is locked.
