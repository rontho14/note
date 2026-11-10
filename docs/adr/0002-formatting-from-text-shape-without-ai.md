---
type: decision
title: Formatting from text shape, without AI
description: View mode works out headings, lists and paragraphs from the shape of the text using fixed rules. No model is involved, and the user corrects wrong guesses.
tags: [formatting, view-mode, ai, product]
generated:
  by: claude-fable-5-2
  at: 2026-11-10
status: stable
decision_status: accepted
sources:
  - docs/VISION.md
  - docs/adr/0001-local-only-app-with-no-backend.md
---

# 0002. Formatting from text shape, without AI

## Context and Problem

Notes should look organized in view mode, with headings and lists, but the owner does not want to type Markdown symbols. The first plan had a server-side model rewrite each note into Markdown. With no backend ([ADR 0001](0001-local-only-app-with-no-backend.md)) and a buy-once price, that is no longer possible.

## Considered Options

- **Server-side AI rewrite.** Needs a server and a paid model for every note, which a one-time price can't fund.
- **A small model on the phone.** Research on 2026-11-09 found that 1B to 3B models run on iPhones, but found no evidence that they reformat a note without dropping or changing words. Apple's built-in model is not available on the owner's iPhone 14 Pro Max. A bundled model adds a download of about 700 MB and a few gigabytes of memory use.
- **Markdown typed by the user.** Predictable and well understood, but it makes the user type symbols, which the owner rejects.
- **Fixed rules that read the shape of the text.** A short line standing alone is a heading. A line ending in a colon labels what follows. Several short lines in a row are a list. Longer lines are a paragraph. No symbols and no model.

## Decision

View mode formats a note with fixed rules that read the shape of the text. No model is used anywhere in the app.

- When a rule is unsure, the line is shown as plain text.
- The user corrects a wrong guess by holding the line and choosing heading, list item, checkbox or plain text. The app remembers the correction.
- Dates, links, phone numbers and addresses are recognized with the detector built into iOS.
- The target is at least 90% of lines guessed correctly on real notes.

## Consequences

- Formatting is instant, works offline and costs nothing to run.
- The same text always produces the same result, so the rules can be tested with a large set of real notes.
- The rules will guess wrong sometimes. The correction gesture and the 90% target exist because of that.
- A correction has to stay attached to its line while the text is edited. That tracking is the hardest part of the feature and needs thorough tests.
- The rules are tuned for short notes, and long prose may format poorly.
- The app cannot tidy a messy note or suggest a title. A model on the phone can be reconsidered later, once tests on a real phone show it keeps every word.
