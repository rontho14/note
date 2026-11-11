# Design

How the app looks. [VISION.md](VISION.md) says what the app does. This file gives the numbers an implementation needs.

The direction is called Empire. It was chosen on 2026-11-11 out of four explored on a design canvas. All sizes are in points on a 390 by 844 screen at the default text size.

## Rules

- **Italic is raw text. Roman is finished text.** The write screen is italic. View mode sets the same text in roman. In lists, an untitled note shows its first words in italic and a titled note shows its title in roman.
- **There is no sans-serif.** Every word is Newsreader or Bodoni Moda.
- **Bodoni Moda is for names.** It sets view headings, drawer names, the title field and sheet headings. Everything else is Newsreader.
- **Ink is olive-black.** No neutral grey appears anywhere.
- **A theme has one accent.** It marks the caret, the active footer tab, drawer numerals, the draft ring, the selected chip, add buttons, restore buttons and the save button. Nothing else is colored.
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

| Theme | Second | Accent | Source of the colors |
|---|---|---|---|
| Green, name undecided | `#5E6050` | `#1F5A3D` | The original Empire palette |
| Note Rome | `#6B5E53` | `#66023C` | Stone, and Tyrian purple, which only emperors could wear |
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

Every second color and every `accentText` has a contrast of at least 4.5 to 1 against paper. I calculated these values. Nobody has measured them on a device.

## Type

Old-style figures are on everywhere.

| Role | Face | Size / line | Notes |
|---|---|---|---|
| Write | Newsreader italic 400 | 17.5 / 28 | |
| View text | Newsreader 400 | 17.5 / 28 | |
| View heading | Bodoni Moda 500 | 30 / 34 | Tracking -1% |
| View label | Newsreader italic 400 | 16.5 / 26 | Second color. A line that ends in a colon |
| Note title in a list | Newsreader 500 | 17 / 24 | |
| Note preview in a list | Newsreader italic 400 | 17 / 24 | Second color, one line, cut with an ellipsis |
| Drawer label | Newsreader 600 | 10.5 / 15 | Uppercase, tracking 10%, second color |
| Date | Newsreader 400 | 13 / 24 | Second color |
| Drawer name | Bodoni Moda 500 | 28 / 40 | Tracking -1% |
| Unsorted | Bodoni Moda italic 400 | 28 / 40 | Second color |
| Drawer numeral | Newsreader italic 400 | 14 | `accentText`. Lowercase roman with a period |
| Count | Newsreader 400 | 14 | Second color |
| Note inside an open drawer | Newsreader 500, or italic 400 | 16 / 36 | Same italic rule as the notes list |
| Title field | Bodoni Moda 500 | 26 | Placeholder is Newsreader italic in the second color |
| Chip | Newsreader 400 | 16 | |
| Save button | Newsreader 500 | 17.5 | |
| Sheet heading | Bodoni Moda italic 500 | 26 / 34 | |
| Search field | Newsreader 400 | 20 / 28 | |

Dynamic Type is undecided. These sizes are for the default text size only.

### Fonts and licenses

Newsreader and Bodoni Moda are both under the SIL Open Font License 1.1. I read each license file in the Google Fonts repository on 2026-11-11. The license allows bundling the fonts in an app that is sold. It forbids selling the fonts by themselves. The app must ship each font's copyright notice and the license text, for example on an acknowledgements screen. Neither copyright line declares a reserved font name.

- Newsreader: Copyright 2020 The Newsreader Project Authors
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

The screen shows the note and nothing else. There is no title field, no footer and no button. The text is italic. The caret is the only color.

### View

The same text in roman. A heading is set in Bodoni Moda with 18 points below it. A paragraph has 26 points below it. A label line is italic in the second color, with its list directly under it. List items carry a 5 point diamond in the second color, 14 points before the text. Dates, phone numbers and links get a 1 point underline in the second color, 4 points below the baseline. There is no footer.

### Notes

Each row has a 54 point date column on the left and the note on the right, with 12 points between them and 13 points of padding above and below. The note is one line of title or preview, with its drawer label under it. A draft has a 7 point ring in the accent before its preview, and its label reads Draft. The date column says `now`, `today` or a short date such as `9 Nov`.

### Search

Pulling down on the notes screen reveals the search field above the list. The field is 52 points tall, with a 1 point ink line under it and a magnifier in the second color. Each result is laid out like a notes row, but its main line is the matching line of the note in roman. The match is tinted with the accent at 18% opacity. Under it sit the drawer label and the note's title, if it has one. Results found only by typo tolerance come last, under the words `close match` in italic.

### Drawers

Each row has a 36 point numeral column, the drawer name, and the count on the right, with 8 points of padding above and below. `Unsorted` comes first, is italic, and has no numeral. The other drawers are numbered i., ii., iii. and so on, in the user's order. A plus button sits under the list and adds a drawer.

Tapping a drawer opens it in place. Its notes hang under its name, indented by the numeral column, in rows 36 points tall with the date on the right. Tapping the drawer again closes it.

Holding a drawer lifts it as a card. Dragging moves it, and the numerals renumber as it passes other drawers. `Unsorted` cannot move.

### Trash

The trash is a round button, 52 points across, at the bottom right of the drawers screen. It sits 20 points from the edge and 16 above the footer. It has the surface color, a hairline border, an icon in the second color and a small count.

Tapping it opens a sheet. The sheet lists the deleted notes. Each row has the title or preview, the drawer label, the days it has left and a round restore button with the icon in `accentText`.

A note can be dragged onto the button to delete it. As the note approaches, the button grows to 72 points, fills with the accent and opens its lid.

### Save sheet

The sheet slides up over the dimmed note. From the top it has the title field, the drawer chips, and a row with delete and save.

- The title field is 54 points tall with a hairline under it.
- Chips are 44 points tall with 13 points of side padding, fully rounded, 6 points apart. They wrap onto a new line only when the next chip does not fit. They follow the user's drawer order. The selected chip is filled with the accent. The others have a 1 point border in the second color. The last chip is a round plus with a dashed border, and it adds a drawer.
- Delete is a 52 point circle with a 1 point border in the second color.
- Save is 52 points tall, fully rounded, filled with the accent, and takes the remaining width.

### Footer

The footer shows on settings, drawers and notes. It has the paper color and a hairline on top, with 8 points of padding above the icons and 14 at the sides. The four icons are settings, drawers, notes and write, in that order, each 48 points tall. Inactive icons use the second color. The active one is 1.7 times as wide, fully rounded and filled with the accent.

## Not designed yet

- Settings, including the theme picker and the acknowledgements screen.
- The blank write screen at launch, and how the keyboard shares the screen.
- The hold menus for a note and for a drawer.
- Correcting a line in view mode.
- Dark mode.
- All animation.

## Open questions

- What the green theme is called, and whether it is the default. One proposal is Note Babylon.
- Whether a whole drawer can be dragged to the trash, and where its notes go if it can.
- Whether an open drawer shows every note or only the latest few.
- Whether Note Byzantium keeps two golds or drops to one deeper gold.
- How the sizes respond to Dynamic Type.

## Source

The mockups are on a design canvas that is private to the author: <https://claude.ai/artifact/6f66K26z3RchzrsRbwuHef>. The author reviewed them there. Nothing has been reviewed on a phone yet.
