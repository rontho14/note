---
type: decision
title: Go backend with SQLite
description: The backend is written in Go and stores data in SQLite on a single instance, backed up continuously with Litestream.
tags: [backend, database, go, sqlite]
generated:
  by: claude-opus-5-5
  at: 2026-10-21
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
---

# 0001. Go backend with SQLite

## Context and Problem

AI agents must be able to read and write notes from anywhere, and the AI jobs (formatting, filing, tagging, linking) must run when the phone app is closed. That requires a backend holding the master copy of the notes. It needs a language and a database.

The first user is the author. The system should still be built to production standards and stay open to more users later.

## Considered Options

**Language**

- **Swift** (Hummingbird or Vapor). The app and server could share model types. Rejected: the author is learning Go, not Swift.
- **Go.** Suited to small, robust network services, simple to deploy as a single binary, and has an official MCP SDK.
- **TypeScript.** The most mature MCP tooling, but a weaker fit for a server whose main job is protecting data.

**Database**

- **Postgres.** Handles many concurrent writers and multiple server instances. Neither applies at this scale, and it adds a separate service to run and back up.
- **SQLite.** Embedded in the server process, no separate service. WAL mode handles one user plus a few agents. FTS5 provides full-text search. Litestream provides continuous, point-in-time backups to object storage.

## Decision

The backend is written in Go. It stores data in SQLite in WAL mode, on exactly one server instance with a persistent volume. Litestream copies the database continuously to S3-compatible storage. The driver is `modernc.org/sqlite`, a pure-Go driver that avoids cgo.

## Consequences

- The server can't scale horizontally. Moving to several instances would mean migrating to Postgres or a replicated SQLite.
- Hosting must provide a persistent disk. Platforms with ephemeral filesystems are ruled out.
- Backups and restores must be tested, since Litestream is the only copy outside the server.
- Data types are defined twice, in Swift and in Go. A shared API contract, still to be decided, has to keep them in step.
- The phone also uses SQLite, so schemas can stay close on both sides.
