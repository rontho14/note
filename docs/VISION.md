# Vision

A minimal note-taking app for iPhone. Opening it and typing should take no thought and no taps. Organization happens afterwards, done by an AI, and the notes stay available to the owner's AI agents.

The app is built for one person, but engineered as if other people's data depended on it.

## Principles

- **Few visible features, plenty of hidden ones.** The screen shows a note, a list of recent notes, and drawers. Siri, widgets, sync, tagging and linking are welcome as long as they stay out of sight.
- **Never lose what the user typed.** Every AI or agent change is saved as a revision, and nothing is destroyed by anyone but the user.
- **Excellence does not need to be justified.** Security, data integrity and migrations get production-grade care even though the first user is the author.

## Writing

- The app opens to a blank note with the keyboard already up. If a draft was left within the last few minutes (default 5, configurable), it reopens that draft with the cursor where it was. Empty notes are never saved. Launch is animated, not a static cut; details are open.
- A note is plain UTF-8 text. There is no title field.
- Leaving a note only saves it. An unfinished note is a **draft** and appears only under Latest, faintly marked.
- **Write mode** shows the note as plain text (for a formatted note, its Markdown source). **View mode** renders the Markdown. A horizontal swipe switches between them.

## Finishing

Swiping into view mode marks the note **finished**, and the AI then:

1. formats the text as Markdown,
2. gives it a short title, only on the first finish,
3. files it into a drawer,
4. assigns hidden tags,
5. adds links to related notes.

Rules for the rewrite:

- The formatted version becomes the note. The text from before the rewrite is kept as a revision, and the user can revert with one tap.
- A rewrite that drops content (words, numbers, links present in the input but missing from the output) is rejected, and the note stays as it was.
- Re-finishing an edited note is a minimal update: nothing happens if the text is unchanged, otherwise only what changed gets formatted. The title stays the same. Tags are re-evaluated, and tags set by hand are never removed.
- If the AI is unavailable or offline, the note renders as typed and the rewrite is queued.

## Organization

- **Drawers** are the visible grouping, named after Napoleon's habit of keeping matters in mental drawers and closing them when done. Each note sits in exactly one drawer, chosen from a list the user defines. The AI files notes; `Unsorted` catches notes that fit nowhere; the user can move notes.
- A drawer can be **closed**. A closed drawer and its notes leave the main views, nothing is deleted, the AI stops filing into it, agents can still read it, and the user can reopen it.
- **Tags** come from a fixed list the user defines in settings. The AI picks one to three per note, or none. Tags are never shown in the app; they exist for the background agent and for MCP clients. Adding a tag lets the AI backfill it onto older notes.
- **Links** are visible at the end of a note in view mode. The background agent adds them when it judges two notes related. They are stored alongside the note, not inside its text.

## Agents

The owner's AI agents can use the notes from anywhere through a remote MCP server (see [ADR 0003](adr/0003-remote-mcp-with-non-destructive-agent-access.md)):

- Agents can read, create and edit notes.
- Every agent edit is saved as a revision attributed to that agent.
- An agent "delete" moves a note to a trash that empties after 30 days.
- Agents cannot change drawers, tags or settings.
- Each agent connects with its own OAuth grant, revocable individually.

## Architecture

- **iOS app:** native Swift. Local-first: a full copy of the notes in SQLite (via GRDB), so the app is fast and works offline.
- **Backend:** Go, with SQLite as the database (see [ADR 0001](adr/0001-go-backend-with-sqlite.md)). It holds the master copy of the notes, runs the background AI jobs, and serves sync and MCP.
- **AI:** runs on the server behind a provider interface. OpenAI first, with the model name in configuration and the API key stored on the server. On a device with Apple Intelligence, the on-device model can be offered as well. The owner's current iPhone 14 Pro Max doesn't have it.
- **Encryption:** per-user envelope encryption with a master key in a key management service (see [ADR 0002](adr/0002-per-user-envelope-encryption.md)).
- **Multi-user ready:** every record carries a `user_id` from day one.
- **Revisions:** every saved version records the revision it was based on, so any conflict-resolution strategy remains possible.
- **Free Apple account for now:** development uses a free Apple ID, so installs on the phone expire after 7 days and need reinstalling from Xcode. Nothing in the design may depend on paid-program features: sync works without push notifications (the app syncs when opened), and login doesn't use Sign in with Apple. Joining the $99/year Apple Developer Program later would add push-based sync, TestFlight and longer installs.

## Build order

Each milestone produces something used daily.

1. **Capture.** The iOS app on its own: local storage, write and view modes, Latest, the open-or-resume launch. No server, no AI.
2. **Backend.** Go server, SQLite with Litestream, auth, envelope encryption, sync.
3. **AI finishing.** Rewrite, title, drawer filing, tags, the content check, revisions.
4. **MCP.** Remote MCP with OAuth for each agent, under the non-destructive rules.
5. **Links and extras.** Agent-created links, Siri and App Intents, widgets, closing drawers.

## Deferred

- How sync resolves conflicting edits between the phone and an agent.
- Animation and gesture details.
- How the Swift app and the Go server share one definition of the API.
- Search inside the app. Agents get search through MCP regardless.
- Hosting: Railway, Fly.io, or a VPS.
