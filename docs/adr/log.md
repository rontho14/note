# Decision log

- 2026-11-10: Numbering restarted at 0001. The three ADRs written on 2026-10-21 for the backend plan (Go backend with SQLite, per-user envelope encryption, remote MCP) were removed when the app became local-only. They remain in git history.
- 2026-11-10: Created [0001](0001-local-only-app-with-no-backend.md), accepted. A buy-once app can't fund a server, and the backend plan was too large for one user.
- 2026-11-10: Created [0002](0002-formatting-from-text-shape-without-ai.md), accepted. Formatting without typed symbols and without a model.
- 2026-11-10: Created [0003](0003-typed-text-is-never-modified.md), accepted. Nothing but the user's typing may change a note's text.
- 2026-11-10: Created [0004](0004-sqlite-with-grdb-and-fts5-search.md), accepted. One local store for notes and the search index.
