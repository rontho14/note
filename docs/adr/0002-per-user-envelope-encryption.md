---
type: decision
title: Per-user envelope encryption
description: Note content is encrypted with a per-user data key wrapped by a KMS master key; the server decrypts in memory only when needed.
tags: [security, encryption, data]
generated:
  by: claude-opus-5-5
  at: 2026-10-21
status: stable
decision_status: proposed
sources:
  - docs/VISION.md
  - docs/adr/0001-go-backend-with-sqlite.md
---

# 0002. Per-user envelope encryption

> **Deferred on 2026-11-10.** The first iteration is a local-only app with no backend ([VISION](../VISION.md)). This decision is not in force and stays here as a proposal for a later iteration.

## Context and Problem

The owner wants the safest encryption that's feasible, and the app may serve other people later. The server, though, has to read note content: it runs the AI jobs, serves notes to agents over MCP, and supports search. Whatever is chosen must protect the data without breaking those features.

## Considered Options

- **Standard hardening only.** TLS, an encrypted disk, strong auth, encrypted backups. Note content sits in plaintext in the database, so anyone who obtains the database file can read it.
- **One application-level key for everything.** Protects a stolen database file, but the key lives next to the data, and users aren't isolated from each other.
- **End-to-end encryption.** Only the user's devices hold keys, which is the strongest protection. Rejected because it rules out server-side AI, remote MCP and server search, and remote MCP is a core requirement ([ADR 0003](0003-remote-mcp-with-non-destructive-agent-access.md)).
- **Per-user envelope encryption.** Each user's content is encrypted with their own data key. Each data key is encrypted ("wrapped") by a master key held in a key management service. The server unwraps a data key only when it needs to work on that user's notes.

## Decision

Use per-user envelope encryption. The master key lives in a KMS (AWS KMS, GCP KMS, or HashiCorp Vault; the choice comes with hosting). The database and Litestream backups contain only ciphertext for note content. Plaintext exists only in server memory while it's being processed. Everything else from the standard-hardening option (TLS, disk encryption, auth) applies too.

## Consequences

- A stolen database file or backup reveals no note content.
- A bug that returns another user's rows exposes only ciphertext.
- Deleting a user's data key makes all of their notes unreadable, including those in old backups (crypto-shredding).
- The KMS logs every unwrap, which gives an audit trail of key use.
- An attacker controlling the running server, with access to the KMS, can still read notes. Only end-to-end encryption would prevent that.
- SQLite FTS5 can't index ciphertext. At personal scale, search decrypts notes in memory. Larger scale would need a different design, such as blind indexes or an index held only in memory.
- Encryption, key rotation and data-key caching become part of the backend's core code and need thorough tests.
- Note text is still sent to the AI provider, outside this encryption boundary.
