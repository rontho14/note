# Vision

A minimal note-taking app for iPhone. Opening it and typing should take no thought and no taps. Everything stays on the phone. There is no AI, no server and no account.

The app is built for one person first. It is meant to be sold later as a buy-once app, with no subscription.

## Principles

- **Almost no words on screen.** The write screen shows only the note. Moving between screens is done by swiping. Buttons are allowed where they are clearer than a gesture.
- **Never change what the user typed.** The app stores the text exactly as written. Formatting is only a way of displaying it.
- **Every delete can be undone.** Deleted notes go to a trash that empties after 30 days.
- **Excellence does not need to be justified.** Data integrity, migrations and performance get production-grade care even though the first user is the author.
- **Built so agents can do the work.** Strict build checks and thorough tests let AI agents write, test and speed up the code with little supervision. See [Engineering](#engineering).

## Screens

Five screens sit side by side. A swipe moves one screen at a time.

```
settings  |  drawers  |  notes  |  WRITE  |  VIEW
```

- A footer in the style of Clash Royale shows on the settings, drawers and notes screens. It has one icon per screen plus a write icon, with the current screen highlighted. Icons carry no text labels.
- The write and view screens have no footer.
- A setting hides the footer. The swipes work the same without it.

## Writing

- The app opens to a blank note with the keyboard already up. If the user left the app in the middle of a note within the last few minutes (default 5, configurable), it reopens that draft with the cursor where it was.
- A note is plain UTF-8 text. The write screen has no title field, and the first line is never treated as a title.
- Empty notes are never saved.
- Leaving the app without saving keeps the text as a **draft**. Drafts appear in the notes list, faintly marked.

## Saving

A quick flick from left to right saves the note and goes to the notes list.

- For a note that has no title and no drawer, a modal appears first. It has a title field, the list of drawers, a delete button and a save button. Title and drawer are both optional.
- The modal shows the drawers as chips in the user's order. A plus chip at the end adds a new drawer.
- Saving with nothing filled in leaves the note untitled in `Unsorted`.
- Delete in the modal sends the note to the trash. There is no separate gesture for discarding a note.
- A note that already has a title or a drawer saves straight to the list, with no modal.
- After a save, the write screen is blank again. To return to a saved note, tap it in the list.

## View mode

A flick from right to left on the write screen shows the note formatted.

- The typeface changes with the mode. Writing is set in italic and view mode in roman, so the flick turns a draft into a page.
- The app works out the formatting from the shape of the text, so the user types no symbols. A short line standing alone is a heading. A line ending in a colon labels what follows. Several short lines in a row are a list. Longer lines are a paragraph.
- Dates, links, phone numbers and addresses are recognized and become tappable.
- When the app is unsure, it shows plain text. A missed heading goes unnoticed, and a wrong one is irritating.
- Holding a line lets the user correct a wrong guess by choosing heading, list item, checkbox or plain text. The app remembers the correction.
- The target is at least 90% of lines guessed correctly on real notes.
- View mode shows the title if the note has one. If not, it shows nothing in that place and never asks.

## Notes and drawers

- The notes screen lists the latest notes. An untitled note shows its first few words, styled as a preview.
- **Drawers** are the grouping, named after Napoleon's habit of keeping matters in mental drawers. Each note sits in exactly one drawer, chosen from a list the user defines. `Unsorted` holds notes with no drawer.
- Tapping a drawer opens it in place. Its notes drop down under its name, and tapping it again closes it.
- The user sets the order of the drawers. Holding a drawer lifts it, and dragging moves it. `Unsorted` always comes first.
- Filing is done by hand, in the save modal or later. A note started inside a drawer is filed there.
- Holding a note, in the notes list or in a drawer, opens a dropdown with delete, move to drawer and rename. Moving the finger while holding turns the hold into a drag. Rows have no swipe actions, so nothing collides with swiping between screens.
- The trash is a button at the bottom right of the drawers screen. Tapping it opens a sheet that lists the deleted notes, each with the days it has left and a restore button. Dragging a note onto the button deletes it.

## Search

- Pulling down on the notes screen shows the search field with the keyboard up.
- Results update on every keystroke. There is no search button.
- Search covers titles and note text in every drawer. Partial words match, and accents are ignored.
- Typos are tolerated. Exact and partial matches rank first, and typo-corrected matches follow.
- Each result shows the matching line with the word highlighted. Tapping it opens the note at that spot.

## Themes

- The look is specified in [DESIGN.md](DESIGN.md).
- The app ships with five built-in themes, chosen in settings. Four are named Note Rome, Note Napoleon, Note Peking and Note Byzantium. The fifth is green and has no name yet.
- The built-in themes share the paper, the ink and the typefaces. Each one changes two colors, the secondary text color and the accent.
- A theme may change colors, fonts and the background, and nothing else.
- A theme is a data file, so imported themes are possible later.

## Export

One action writes every note as a Markdown file into a folder the user picks in Files. With no server, this is also the backup.

## Architecture

- **iOS app:** native Swift, with all data in SQLite on the phone (via GRDB). Search uses SQLite's FTS5 index (see [ADR 0004](adr/0004-sqlite-with-grdb-and-fts5-search.md)).
- **No network.** The app makes no requests (see [ADR 0001](adr/0001-local-only-app-with-no-backend.md)).
- **No AI.** Fixed rules format the note from the shape of its text (see [ADR 0002](adr/0002-formatting-from-text-shape-without-ai.md)).
- **Text is never modified.** Title, drawer and corrections are stored beside the text (see [ADR 0003](adr/0003-typed-text-is-never-modified.md)).
- **Free Apple account for now:** development uses a free Apple ID, so installs on the phone expire after 7 days and need reinstalling from Xcode. Selling the app needs the $99/year Apple Developer Program, which can wait until release.

## Engineering

- The app is split into small Swift packages with strict compiler settings and lint rules, so the build rejects bad code.
- One command, `make check`, formats, lints, builds and tests. GitHub Actions runs it on every change.
- UI tests drive the app in the Simulator.
- The shape formatting and search get large test suites built from real notes.
- Speed is tested. Launch to keyboard-up and search time have budgets that fail the build when exceeded.
- The author reviews look and feel on a real phone. Agents cannot judge that.

## Build order

Each step produces something used daily.

1. **Write, save, list, trash.**
2. **View mode** with shape formatting.
3. **Search.**
4. **Drawers and the footer.**
5. **Themes, export, and corrections in view mode.**

## Later

None of this is in the first iteration.

- Sharing themes, and a free gallery of community themes.
- Ordering the drawers in the save modal by similarity to the note, using on-device text embeddings.
- A small on-device model for tidying notes. It must first prove on a real phone that it never drops or changes content.
- Closing a drawer to hide it and its notes without deleting anything.
- A backend, sync, encryption at rest on a server, and agent access over MCP.
- Siri, App Intents and widgets.

## Open questions

- Whether a saved note opens from the list in write mode or view mode.
- Animation details for launch, the flicks and the save modal.
- How a correction in view mode stays attached to its line when the text is edited.
- What the green theme is called, and whether it is the default.
- Whether a whole drawer can be dragged to the trash, and where its notes go if it can.
- Whether an open drawer shows every note or only the latest few.
- Whether the first version has a dark mode.
