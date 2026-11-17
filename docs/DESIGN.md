# Design

How the app looks. [VISION.md](VISION.md) says what the app does. This file gives the numbers an implementation needs.

The direction is called Empire. It was chosen on 2026-11-11 out of four explored on a design canvas. All sizes are in points on a 390 by 844 screen at the default text size.

## Rules

- **Italic is raw text. Roman is finished text.** The write screen is italic. View mode sets the same text in roman. In lists, an untitled note shows its first words in italic and a titled note shows its title in roman.
- **There is no sans-serif.** Every word is Source Serif 4 or Bodoni Moda.
- **Bodoni Moda is for names.** It sets view headings, drawer names, the title field and sheet headings. Everything else is Source Serif 4.
- **Ink is olive-black.** No neutral grey appears anywhere.
- **A theme has one accent.** It marks the caret, the active footer tab, drawer numerals, the draft ring, the selected chip, add buttons, the Restore word, checkboxes, switches, slider fills, checkmarks and the save button. Nothing else is colored.
- **Quiet things use the second color.** That covers dates, previews, labels, counts and inactive icons.
- **Screens have no titles.** The highlighted footer icon says where you are.
- **Every touch target is at least 44 points.**

## Color

These four are the same in every built-in theme.

| Token | Value | Use |
|---|---|---|
| paper | `#F8F4EC` | Screen background |
| surface | `#FFFDF8` | Sheets, lifted cards, the trash button |
| ink | `#1A1C12` | Text |
| hairline | `#E2DCCD` | Row dividers and quiet borders |

The scrim behind a sheet is ink at 36% opacity.

## Themes

A built-in theme changes two colors and nothing else. The data files are in [design/themes](design/themes). They move into the app bundle when themes are built, which is step 5 of the build order.

Note Rome is the default and comes first in the theme picker. The others follow in the order below.

| Theme | Second | Accent | Source of the colors |
|---|---|---|---|
| Note Rome | `#6B5E53` | `#66023C` | Stone, and Tyrian purple, which only emperors could wear |
| Green, name undecided | `#5E6050` | `#1F5A3D` | The original Empire palette |
| Note Napoleon | `#7A5C1E` | `#1B2A5C` | The imperial arms, a gold eagle on a blue shield |
| Note Peking | `#85591B` | `#C2281C` | The yellow roofs and red walls of the Forbidden City |
| Note Byzantium | `#5F5A4F` | `#C9A227` | Gold-ground mosaics |

Each theme file has these fields.

| Field | Meaning |
|---|---|
| `second` | Quiet text and inactive icons |
| `accent` | Fills, such as the active tab and the save button |
| `accentText` | The accent when it is small text or a thin icon on paper |
| `onAccent` | Text and icons drawn on an accent fill |

In four themes `accentText` equals `accent`, and `onAccent` is the surface color. Note Byzantium is the exception. Bright gold is unreadable as small text on paper, and cream is unreadable on gold. Its `accentText` is a deeper gold, `#8B6508`, and its `onAccent` is ink.

Each theme also has an app icon: a single N in Bodoni Moda 500, either in `onAccent` on the theme's accent or in `accentText` on paper. iOS switches icons with `setAlternateIconName` and shows its own short message each time. Each icon is an Icon Composer file built into the app.

Every second color and every `accentText` has a contrast of at least 4.5 to 1 against paper. I calculated these values. Nobody has measured them on a device.

## Type

Old-style figures are on everywhere. Source Serif 4 replaced Newsreader as the text face because Newsreader has no old-style figures.

| Role | Face | Size / line | Notes |
|---|---|---|---|
| Write | Source Serif 4 italic 400 | 17.5 / 28 | |
| View text | Source Serif 4 400 | 17.5 / 28 | |
| View heading | Bodoni Moda 500 | 30 / 34 | Tracking -1% |
| View label | Source Serif 4 italic 400 | 16.5 / 26 | Second color. A line that ends in a colon |
| Note title in a list | Source Serif 4 500 | 17 / 24 | |
| Note preview in a list | Source Serif 4 italic 400 | 17 / 24 | Second color, one line, cut with an ellipsis |
| Drawer label | Source Serif 4 600 | 10.5 / 15 | Uppercase, tracking 10%, second color |
| Date | Source Serif 4 400 | 13 / 24 | Second color |
| Drawer name | Bodoni Moda 500 | 28 / 40 | Tracking -1% |
| Unsorted | Bodoni Moda italic 400 | 28 / 40 | Second color |
| Drawer numeral | Source Serif 4 italic 400 | 14 | `accentText`. Lowercase roman with a period |
| Count | Source Serif 4 400 | 14 | Second color |
| Note inside an open drawer | Source Serif 4 500, or italic 400 | 16 / 36 | Same italic rule as the notes list |
| Title field | Bodoni Moda 500 | 26 | Placeholder is Source Serif 4 italic in the second color |
| Chip | Source Serif 4 400 | 16 | |
| Save button | Source Serif 4 500 | 17.5 | |
| Sheet heading | Bodoni Moda italic 500 | 26 / 34 | |
| Search field | Source Serif 4 400 | 18 / 24 | |
| Settings row | Source Serif 4 400 | 17.5 | |
| Settings value | Source Serif 4 italic 400 | 16 | Second color |
| Settings group label | Source Serif 4 600 | 12 / 28 | Uppercase, tracking 10%, second color |
| Message pill and bubble | Source Serif 4 italic 400 | 15 to 16 | Surface color on ink |

Text size follows the iPhone by default, and a setting can replace it with a size the user picks. These sizes are for the default size. How each one scales is undecided.

### Fonts and licenses

Source Serif 4 and Bodoni Moda are both under the SIL Open Font License 1.1. I read Bodoni Moda's license file in the Google Fonts repository on 2026-11-11 and Source Serif 4's on 2026-11-16. The license allows bundling the fonts in an app that is sold. It forbids selling the fonts by themselves. The app must ship each font's copyright notice and the license text, for example on an acknowledgements screen. Neither copyright line declares a reserved font name.

- Source Serif 4: Copyright 2014 The Source Serif 4 Project Authors
- Bodoni Moda: Copyright 2020 The Bodoni Moda Project Authors

## Shape and spacing

| Thing | Value |
|---|---|
| Side padding on write and view | 30 |
| Side padding on lists and sheets | 26 |
| First line of text on write and view | 76 from the top |
| First row of a list | 58 to 60 from the top |
| Row divider | 1 point, hairline color |
| Sheet | Surface color, top corners 8, padding 26, bottom padding 34 |
| Lifted card | Surface color, corners 8, shadow of ink at about 24% blurred 34 and offset 14 down, plus a 1 point hairline ring |
| Icons | 24, stroke 1.4, round caps |
| Caret | 2 points wide, accent |

## Screens

### Write

The screen shows the note and nothing else. There is no title field, no footer and no button. The text is italic. The caret is the only color. At launch the screen is blank, with the caret on the first line and the keyboard up.

### Keyboard

The app uses the iPhone's keyboard. It is light when the app is in light mode and dark in dark mode, unless the Keyboard setting says otherwise. Its colors and font cannot be changed. On iOS 26 it is made of Liquid Glass, so how it looks over the paper needs checking on a phone.

### View

The same text in roman. A heading is set in Bodoni Moda with 18 points below it. A paragraph has 26 points below it. A label line is italic in the second color, with its list directly under it. List items carry a 5 point diamond in the second color, 14 points before the text. Dates, phone numbers and links get a 1 point underline in the second color, 4 points below the baseline. There is no footer.

Holding a line lifts it as a card. A menu under it offers Heading, List item, Checkbox and Plain text. Each choice is drawn in its own style: Heading in Bodoni Moda, List item with its diamond, Checkbox with an empty box. The current one has a checkmark in the accent.

A checkbox item has a 22 point box with corners of 5. A checked box is filled with the accent and its text is struck through in the second color.

### Notes

A search bar sits at the top, 58 points from the top of the screen. It is 44 points tall, fully rounded, in the surface color with a hairline border, and holds a magnifier in the second color. It has no placeholder word. The bar stays in place while the list scrolls under it, and a hairline under the bar marks the edge once the list has moved. A thin scroll indicator shows on the right while scrolling.

Each row has a 54 point date column on the left and the note on the right, with 12 points between them and 13 points of padding above and below. The note is one line of title or preview, with its drawer label under it. A draft has a 7 point ring in the accent before its preview, and its label reads Draft. The date column says `now`, `today` or a short date such as `9 Nov`. Every row is the same height, which keeps a long list from jumping as it scrolls.

On first launch the list area shows `No notes yet.` in italic in the second color.

After a save the list opens with the new note at the top, tinted with the accent at 7% for a moment.

Holding a note lifts its row as a card and shows a menu with Rename, Move to drawer and Delete, each with its icon. Move to drawer opens a sheet listing the drawers with the current one checked. Rename opens a sheet with the title field and a Save button above the keyboard.

Deleting a note shows a dark pill above the footer, 52 points tall and fully rounded, saying `In the trash` with an underlined `Undo`.

### Search

Tapping the search bar turns its border to ink and brings up the keyboard. Each result is laid out like a notes row, but its main line is the matching line of the note in roman. The match is tinted with the accent at 14% opacity. Under it sit the drawer label and the note's title, if it has one. Results found only by typo tolerance come last, under the words `close match` in italic. With no results the list area shows `No notes match.` in italic.

Tapping a result opens the note in Write with the caret at the match. Nothing is tinted there.

### Drawers

Each row has a 36 point numeral column, the drawer name, and the count on the right, with 8 points of padding above and below. `Unsorted` comes first, is italic, and has no numeral. The other drawers are numbered i., ii., iii. and so on, in the user's order. A plus button sits under the list and adds a drawer.

Tapping a drawer opens it in place. Its notes hang under its name, indented by the numeral column, in rows 36 points tall with the date on the right. Tapping the drawer again closes it.

Holding a drawer lifts it as a card and shows a menu with Rename and Delete. Moving the finger instead drags it, and the numerals renumber as it passes other drawers. `Unsorted` cannot move.

The plus button adds a new row at the end of the list, with the next numeral and the caret in the name, and the keyboard comes up.

Deleting a drawer asks first, in a sheet with Cancel and Delete. The drawn version says its notes move to `Unsorted`, which is an assumption.

On first launch the list holds only `Unsorted`.

### Trash

The trash is a round button, 52 points across, at the bottom right of the drawers screen. It sits 20 points from the edge and 16 above the footer. It has the surface color, a hairline border, an icon in the second color and a small count.

Tapping it opens a sheet headed `Trash`, with `kept for 30 days` on the right. Each row has the title or preview, the drawer label, the days it has left and the word `Restore` in italic `accentText`. An empty trash shows `Nothing in the trash.` in italic.

Restoring a note shows a small dark bubble just above the trash button, pointing down at it, naming the drawer the note went back to.

A note can be dragged onto the button to delete it. As the note approaches, the button grows to 72 points, fills with the accent and opens its lid.

### Save sheet

The sheet slides up over the dimmed note. From the top it has the title field, the drawer chips, and a row with delete and save.

- The title field is 54 points tall with a hairline under it.
- Chips are 44 points tall with 13 points of side padding, fully rounded, 6 points apart. They wrap onto a new line only when the next chip does not fit. They follow the user's drawer order. The selected chip is filled with the accent. The others have a 1 point border in the second color. The last chip is a round plus with a dashed border, and it adds a drawer.
- Delete is a 52 point circle with a 1 point border in the second color.
- Save is 52 points tall, fully rounded, filled with the accent, and takes the remaining width.

### Footer

The footer shows on settings, drawers and notes. It has the paper color and a hairline on top, with 8 points of padding above the icons and 14 at the sides. The four icons are settings, drawers, notes and write, in that order, each 48 points tall. Inactive icons use the second color. The active one is 1.7 times as wide, fully rounded and filled with the accent.

### Settings

There is no title. Rows sit in four groups, each under an uppercase label at 12 points:

| Group | Rows | Value shown |
|---|---|---|
| Look | Theme, Appearance, Text size, Keyboard, Footer | The theme name, `Match iPhone`, `Match iPhone`, `Match app`, and a switch for the footer |
| Writing | Reopen a draft | `5 minutes` |
| Your notes | Export, Import | None |
| Privacy | Lock with Face ID | None |

Rows are 52 points tall with a hairline between them. The label is on the left. The value is on the right in italic in the second color, followed by a chevron. The switch is the iPhone's size, 51 by 31, filled with the accent when on. Under the groups, centered, sit an underlined `Acknowledgements` link and the version number at 13 points in the second color.

Each row opens a sheet:

- **Theme** lists the five themes. Each has two overlapping 26 point circles in its second and accent colors and its name in Bodoni Moda at 22. The current one has a checkmark.
- **Appearance** offers Match iPhone, Light and Dark.
- **Keyboard** offers Match app, Light and Dark. Option sheets carry no explanation lines.
- **Text size** has a Match iPhone switch, a slider between a small and a large `A`, and a sample sentence in the write style at the chosen size.
- **Reopen a draft** has one sentence explaining it, the number of minutes in Bodoni Moda at 34, and a slider from `Off` to `1 hour`. The number can also be typed: tapping it brings up the number pad with the caret after the number, and the slider follows what is typed. Nothing changes in how the number looks until it is tapped. Anything above 60 becomes 60, and 0 means off.
- **Export** lists the drawers, each with a 22 point checkbox, its name in Bodoni Moda at 22, its note count, and a chevron for picking single notes inside it. A drawer with only some notes picked shows a dash in its box and `3 of 9` in the accent. `Select all` sits in the heading row. The button at the bottom counts what will go out, as in `Export 40 notes`.
- **Export done** shows a 56 point circle in the accent with a check, and how many notes went out. The circle grows in, slightly overshooting, then the check draws itself. Nothing moves when Reduce Motion is on.
- **Lock with Face ID** shows a small picture of the app icon beside the Home Screen menu with `Require Face ID`, and one sentence with the steps.
- **Acknowledgements** is a page, not a sheet. It has each font's name in Bodoni Moda, its copyright line, and a link to the license.

Sliders have a 3 point track in the hairline color, filled with the accent up to a white 28 point thumb.

## Not designed yet

- Dark mode.
- Picking single notes inside a drawer for export.
- Import.
- Animation for everything except Export done.
- How the keyboard looks over the paper on a real phone.

## Open questions

- What the green theme is called. The canvas shows Note Aztec as a proposal; Note Mughal and Note Babylon are the alternatives.
- Whether a whole drawer can be dragged to the trash, and where its notes go if it can.
- Whether an open drawer shows every note or only the latest few.
- Whether Note Byzantium keeps two golds or drops to one deeper gold.
- How each size scales when the user picks a text size.
- Whether a deleted drawer's notes move to `Unsorted`.
- Whether the trash can be emptied before the 30 days are up.
- Whether the notes list gets date headers or a quick way back to the top.

## Source

The mockups are on a design canvas that is private to the author: <https://claude.ai/artifact/6f66K26z3RchzrsRbwuHef>. Its page `Note Rome · every screen` shows every screen and state and is the reference. The Explorations page holds the earlier directions. The author reviewed the screens there. Nothing has been reviewed on a phone yet.
