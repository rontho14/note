---
type: decision
title: Typed text is never modified
description: The app stores a note's text exactly as typed. Title, drawer, formatting corrections and checkbox state are stored beside the text, never inside it.
tags: [data, storage, integrity]
generated:
  by: claude-fable-5-2
  at: 2026-11-10
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
  - docs/adr/0002-formatting-from-text-shape-without-ai.md
---

# 0003. Typed text is never modified

## Context and Problem

The app adds things to a note that the user did not type as part of its text: a title given at save time, a drawer, formatting worked out by rules ([ADR 0002](0002-formatting-from-text-shape-without-ai.md)), corrections to that formatting, and checkbox state. Each of these has to be stored somewhere. The owner's firmest requirement is that the app never loses or changes what was typed.

## Considered Options

- **Write everything into the text.** Store the title as the first line and corrections as Markdown symbols, as Apple Notes and most Markdown editors do. One field to store, but the app edits the user's text, and write mode would show symbols the user never typed.
- **Rewrite the text and keep revisions.** The first plan did this, with a check that rejected rewrites that dropped content. It needs a revision history and a content check to stay safe.
- **Keep the text untouched and store everything else beside it.** The text is one field that only the user's typing changes. Other data lives in its own fields and tables.

## Decision

The note's text is stored exactly as typed, and only the user's own editing changes it.

- The title is a separate, optional field. The first line is never treated as a title.
- The drawer is a separate field.
- Formatting is computed from the text when the note is shown and is not stored.
- Corrections and checkbox state are stored in their own table, attached to lines of the note.

## Consequences

- No feature can damage a note's text, so no revision history or content check is needed.
- Write mode always shows exactly what the user typed.
- The formatting rules can improve in an update, and every old note benefits without a migration.
- Corrections and checkbox state must follow their lines through edits. If that tracking fails, a correction lands on the wrong line, but the text is still intact.
- Export has to combine the text, the title and the formatting into a Markdown file, since the stored text alone has none of them.
