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

- The app opens to a blank note with the keyboard already up. If the user left the app in the middle of a note within the last few minutes (default 5, adjustable from off up to an hour), it reopens that draft with the cursor where it was.
- A note is plain UTF-8 text. The write screen has no title field, and the first line is never treated as a title.
- Empty notes are never saved.
- Leaving the app without saving keeps the text as a **draft**. Drafts appear in the notes list, faintly marked.

## Saving

A quick flick from left to right saves the note and goes to the notes list.

- The first time a note is saved, a modal appears first. It has a title field, the list of drawers, a delete button and a save button. Title and drawer are both optional.
- The modal shows the drawers as chips in the user's order. A plus chip at the end adds a new drawer.
- Saving with nothing filled in leaves the note untitled in `Unsorted`.
- Delete in the modal sends the note to the trash. There is no separate gesture for discarding a note.
- After its first save, a note saves straight to the list, with no modal. A title can still be added later by renaming the note.
- After a save, the write screen is blank again. To return to a saved note, tap it in the list.

## View mode

A flick from right to left on the write screen shows the note formatted.

- The typeface changes with the mode. Writing is set in italic and view mode in roman, so the flick turns a draft into a page.
- A saved note opened from the list starts in view mode. Moving to write mode keeps the same place in the text.
- The app works out the formatting from the shape of the text, so the user types no symbols. A short line standing alone is a heading. A line ending in a colon labels what follows. Several short lines in a row are a list. Longer lines are a paragraph.
- Dates, links, phone numbers and addresses are recognized and become tappable.
- When the app is unsure, it shows plain text. A missed heading goes unnoticed, and a wrong one is irritating.
- Holding a line lets the user correct a wrong guess by choosing heading, list item, checkbox or plain text. The app remembers the correction.
- The target is at least 90% of lines guessed correctly on real notes.
- View mode shows the title if the note has one. If not, it shows nothing in that place and never asks.

## Notes and drawers

- The notes screen lists every note, the most recently edited first. An untitled note shows its first few words, styled as a preview.
- A search bar sits at the top of the notes screen and stays in place while the list scrolls under it. The list has to stay smooth with thousands of notes.
- **Drawers** are the grouping, named after Napoleon's habit of keeping matters in mental drawers. Each note sits in exactly one drawer, chosen from a list the user defines. `Unsorted` holds notes with no drawer.
- Tapping a drawer opens it in place. Its notes drop down under its name, and tapping it again closes it.
- The user sets the order of the drawers. Holding a drawer lifts it, and dragging moves it. `Unsorted` always comes first.
- Filing is done by hand, in the save modal or later. A note started inside a drawer is filed there.
- Holding a note, in the notes list or in a drawer, opens a dropdown with delete, move to drawer and rename. Moving the finger while holding turns the hold into a drag. Rows have no swipe actions, so nothing collides with swiping between screens.
- Deleting a note from the list offers Undo for a few seconds.
- The trash is a button at the bottom right of the drawers screen. Tapping it opens a sheet that lists the deleted notes, each with the days it has left and a restore button. Dragging a note onto the button deletes it. A restored note goes back to its old drawer.

## Search

- The search field is always at the top of the notes screen. Tapping it brings up the keyboard.
- Results update on every keystroke. There is no search button.
- Search covers titles and note text in every drawer. Partial words match, and accents are ignored.
- Typos are tolerated. Exact and partial matches rank first, and typo-corrected matches follow.
- Each result shows the matching line with the word highlighted. Tapping it opens the note in write mode with the cursor at that spot. Nothing is highlighted in the note itself.

## Themes

- The look is specified in [DESIGN.md](DESIGN.md).
- The app ships with five built-in themes, chosen in settings. Note Rome is the default. The others are Note Napoleon, Note Peking, Note Byzantium and a green theme that has no name yet.
- The built-in themes share the paper, the ink and the typefaces. Each one changes two colors, the secondary text color and the accent.
- A theme may change colors, fonts and the background, and nothing else.
- A theme is a data file, so imported themes are possible later.
- Every theme comes with its own app icon, and a new theme must have one. Choosing a theme switches the icon. iOS only allows icons that are built into the app, so an imported theme would have to reuse one of them.

## Settings

Settings stay few. Apple's guidelines ask apps to offer as few as possible and not to repeat what the iPhone already controls.

- **Look:** theme; appearance (match iPhone, light or dark); text size (match iPhone, or a size the user picks); keyboard (match app, light or dark); and whether the footer shows.
- **Writing:** how long a note the user left reopens, from off up to an hour.
- **Your notes:** export and import.
- **Privacy:** the Face ID lock. The app builds no lock of its own. It uses the iPhone's lock, which the user turns on by holding the app icon and choosing Require Face ID. The settings row explains how.
- **At the bottom:** acknowledgements, which the font licenses require, and the version.

The app uses the iPhone's own keyboard. Match app gives a light keyboard in light mode and a dark one in dark mode. An app cannot change the keyboard's colors or font.

These are decided once and are not settings:

- Autocorrect and smart punctuation follow the iPhone's keyboard settings.
- The notes list is ordered by last edit.
- The trash keeps notes for 30 days.
- A saved note opens in view mode.

## Export and import

Export writes notes as Markdown files into a folder the user picks in Files. The user chooses whole drawers, single notes inside a drawer, or everything. Import reads such files back into the app. With no server, export is the way to take notes out of the app, for example to another kind of phone. Moving to a new iPhone does not need it (see [Architecture](#architecture)).

## Architecture

- **iOS app:** native Swift, with all data in SQLite on the phone (via GRDB). Search uses SQLite's FTS5 index (see [ADR 0004](adr/0004-sqlite-with-grdb-and-fts5-search.md)).
- **No network.** The app makes no requests (see [ADR 0001](adr/0001-local-only-app-with-no-backend.md)).
- **No AI.** Fixed rules format the note from the shape of its text (see [ADR 0002](adr/0002-formatting-from-text-shape-without-ai.md)).
- **Text is never modified.** Title, drawer and corrections are stored beside the text (see [ADR 0003](adr/0003-typed-text-is-never-modified.md)).
- **Notes move to a new iPhone through iOS.** iCloud Backup, computer backups and Quick Start all copy an app's data, so a person who restores or transfers to a new iPhone keeps their notes with no work from the app. This holds only while the database lives in Application Support. It must never sit in `Library/Caches` or `tmp`, which backups skip, and must never be marked as excluded from backup. A test checks both. With iCloud Backup on, iOS copies the notes to Apple's servers, and Apple can read that copy unless the person has turned on Advanced Data Protection. The app itself still makes no requests.
- **Free Apple account for now:** development uses a free Apple ID, so installs on the phone expire after 7 days and need reinstalling from Xcode. Selling the app needs the $99/year Apple Developer Program, which can wait until release.

## Engineering

- The app is split into small Swift packages with strict compiler settings and lint rules, so the build rejects bad code.
- One command, `make check`, lints, builds and tests. A pre-commit hook runs its fast part. GitHub Actions will run it on every change.
- UI tests drive the app in the Simulator.
- The shape formatting and search get large test suites built from real notes.
- Speed is tested. Launch to keyboard-up and search time have budgets that fail the build when exceeded.
- The author reviews look and feel on a real phone. Agents cannot judge that.

## Build order

The first version is all five steps. The author starts using the app once the fifth is done.

1. **Write, save, list, trash.**
2. **View mode** with shape formatting.
3. **Search.**
4. **Drawers and the footer.**
5. **Themes, settings, export and import, and corrections in view mode.**

## Later

None of this is in the first iteration.

- Sharing themes, and a free gallery of community themes.
- Ordering the drawers in the save modal by similarity to the note, using on-device text embeddings.
- A small on-device model for tidying notes. It must first prove on a real phone that it never drops or changes content.
- Closing a drawer to hide it and its notes without deleting anything.
- A backend, sync, encryption at rest on a server, and agent access over MCP.
- Siri, App Intents and widgets.

## Open questions

- Animation details for launch, the flicks and the save modal.
- How a correction in view mode stays attached to its line when the text is edited.
- What the green theme is called.
- Whether a whole drawer can be dragged to the trash, and where its notes go if it can.
- Whether an open drawer shows every note or only the latest few.
- What dark mode looks like. The appearance setting offers it, but it is not designed.
- Whether the trash can be emptied before the 30 days are up.
- How import decides which drawer an imported note goes into.
