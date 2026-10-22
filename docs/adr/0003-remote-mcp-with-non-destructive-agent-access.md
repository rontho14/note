---
type: decision
title: Remote MCP with non-destructive agent access
description: AI agents reach notes through a remote MCP server with per-agent OAuth; they can read, create and edit, but never destroy.
tags: [mcp, agents, security, api]
generated:
  by: claude-opus-5-5
  at: 2026-10-21
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
  - docs/adr/0001-go-backend-with-sqlite.md
---

# 0003. Remote MCP with non-destructive agent access

## Context and Problem

The owner wants their AI agents to read, write and change notes, wherever those agents run: claude.ai, the Claude phone app, cloud agents, Claude Code on any machine. Agents make mistakes and can be steered by prompt injection, so their access needs bounds that keep the owner's data recoverable.

## Considered Options

**Where agents connect**

- **A local MCP server on a Mac companion app,** with notes synced over iCloud. No server to run, but it only works while the Mac is on, and agents outside it can't connect.
- **Markdown files in iCloud Drive** that agents edit directly. Concurrent edits produce conflict copies, and the revision and content-check guarantees are lost.
- **A remote MCP server on the backend.** Reachable from anywhere, and every write goes through the same server code as the app's.

**What agents may do**

- **Full access,** including deletion and changes to drawers and tags.
- **Read-only.** Safe, but drops writing, which the owner asked for.
- **Read, create and edit, never destroy.**

## Decision

The Go backend serves a remote MCP endpoint. Each agent authorizes with its own OAuth grant, and the owner can revoke any grant individually. Agents can:

- read every note, including notes in closed drawers;
- create notes;
- edit notes. Each edit is stored as a revision attributed to the agent.

Agents cannot hard-delete. A delete from an agent moves the note to a trash that empties after 30 days. Agents cannot change the drawer list, the tag list, or settings; they can use them but not modify them.

## Consequences

- Any agent mistake is visible in the revision history and can be undone.
- The backend must implement an OAuth authorization server, or delegate to one, and keep a store of grants.
- Every write path (app sync, the AI jobs, MCP) shares one revision mechanism, so that mechanism is critical and needs thorough tests.
- Agent edits can conflict with offline phone edits. That resolution strategy is deferred, but every revision records the revision it was based on.
- The MCP endpoint is public attack surface and needs rate limiting, input validation and audit logging.
