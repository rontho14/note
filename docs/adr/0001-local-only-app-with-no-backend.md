---
type: decision
title: Local-only app with no backend
description: All notes live on the phone. The app has no server, no account, no sync and makes no network requests.
tags: [architecture, storage, privacy, scope]
generated:
  by: claude-fable-5-2
  at: 2026-11-10
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
---

# 0001. Local-only app with no backend

## Context and Problem

The first plan had a Go backend holding the master copy of the notes, with sync, per-user encryption, server-side AI and remote access for AI agents over MCP. That was too much to build at once for a single user, and none of it helps with the core job of opening the app and typing.

The app is meant to be sold once, with no subscription. A server has running costs every month, and a one-time price can't pay for them.

## Considered Options

- **Go backend with sync and remote agent access.** The original plan. It lets agents reach the notes from anywhere and backs them up off the phone. It needs hosting, auth, encryption, key management and a sync protocol, and it costs money for as long as the app exists.
- **iCloud sync through CloudKit.** No server to run, but it needs the paid Apple Developer Program, and sync conflicts still have to be designed and tested.
- **Local only.** Everything stays in the app's own storage on the phone. Nothing to host and nothing to pay for.

## Decision

The app stores all data on the phone and makes no network requests. There is no server, no account and no sync.

Backup is covered two ways. iOS device backups include the app's data, and an export action writes every note as a Markdown file into a folder the user picks.

## Consequences

- The app has no running costs, which fits a buy-once price.
- Notes never leave the phone unless the user exports them, so there is no server-side security work.
- A lost phone with no device backup and no export loses the notes. The export has to be easy to find and reliable.
- AI agents cannot reach the notes. Exported Markdown files are the only way in for now.
- Notes do not appear on a second device.
- Adding sync later means retrofitting it onto a schema designed without it. Stable note identifiers and modification times are kept from the start to make that easier.
- The earlier backend, encryption and MCP decisions were removed on 2026-11-10 and remain in git history.
