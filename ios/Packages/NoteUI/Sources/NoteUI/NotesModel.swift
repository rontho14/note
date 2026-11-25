import Foundation
import NoteCore
import Observation

/// Every note as the notes list shows it, newest first, kept up to date with the store; the note just saved, which the
/// list tints for a moment; the note just deleted, which Undo can bring back for a moment; and the note the rename
/// sheet is up for.
@Observable
final class NotesModel {
    /// How long the note just saved stays tinted before the tint fades.
    static let tintDuration: Duration = .milliseconds(1_500)
    /// How long Undo is offered after a delete.
    static let undoDuration: Duration = .seconds(4)

    private(set) var summaries = StoreRead<[NoteSummary]>.reading
    /// The rename sheet: down, or up with the note's title as it rose.
    var renameSheet: TitleSheetState {
        if case .up(_, let title) = renaming { .up(title: title) } else { .down }
    }
    /// The note just saved, tinted and scrolled to.
    var justSaved: Showing<NoteID> { saved.showing }
    /// The note just moved to the trash, which the Undo pill offers to bring back.
    var undoable: Showing<NoteID> { trashed.showing }

    /// The note just saved once the summaries hold its row, so the list scrolls to it only when there is a row to
    /// scroll to.
    var justSavedRow: Showing<NoteID> {
        guard case .shown(let id) = justSaved, case .read(let summaries) = summaries,
            summaries.contains(where: { $0.id == id })
        else {
            return .hidden
        }
        return .shown(id)
    }

    /// Every change the list makes, and the read the rename sheet starts from, waits in it for the store leaving write
    /// started, which writes the whole note, so it can't bring a deleted note back or put an old title back.
    private let changes: NoteChanges
    /// The rename sheet, and the note it is up for.
    private var renaming = Renaming.down
    private let saved = FadingValue<NoteID>(lasting: NotesModel.tintDuration)
    private let trashed = FadingValue<NoteID>(lasting: NotesModel.undoDuration)

    init(changes: NoteChanges) {
        self.changes = changes
    }

    /// Shows the store's notes, and again after every change, for as long as the calling task runs.
    func follow() async throws {
        for try await summaries in changes.noteSummaries() {
            self.summaries = .read(summaries)
        }
    }

    /// Tints the note `id` and scrolls to it, for `tintDuration`. A later save takes over.
    func showSaved(_ id: NoteID) {
        saved.show(id)
    }

    /// Sends the note `id` to the trash, and offers Undo for it for `undoDuration`.
    func moveToTrash(_ id: NoteID, now: Date) async throws {
        try await changes.run { try await $0.moveToTrash(id: id, now: now) }
        trashed.show(id)
    }

    /// Raises the rename sheet for the note `id`, with its title as stored in the field, once every earlier change has
    /// finished. The list draws a title on one line, so the field never starts from that copy. A note gone by then
    /// raises nothing.
    func startRenaming(_ id: NoteID) async throws {
        if let stored = try await changes.run({ try await $0.note(id: id) }) {
            renaming = .up(id: id, title: stored.titleInTheField)
        }
    }

    /// Lowers the rename sheet with nothing stored.
    func stopRenaming() {
        renaming = .down
    }

    /// Lowers the rename sheet and gives the note it was up for the title `Note.title(typed:)` keeps of `typed`, once
    /// every earlier change has finished, so a store still on its way, such as leaving write's, can't put the old title
    /// back. Only the first answer of a sheet counts, so a second tap stores nothing.
    func finishRenaming(typed: String) async throws {
        guard case .up(let id, _) = renaming else {
            return
        }
        renaming = .down
        let title = Note.title(typed: typed)
        try await changes.run { try await $0.rename(id: id, title: title) }
    }

    /// Lowers the Undo pill and takes the note it offered out of the trash, back to its place in the list. Once the
    /// offer has faded, Undo does nothing.
    func undo() async throws {
        guard case .shown(let id) = trashed.showing else {
            return
        }
        trashed.clear()
        try await changes.run { try await $0.restoreFromTrash(id: id) }
    }

    /// Keeps the Undo pill up while VoiceOver reads it.
    func holdUndo() {
        trashed.pause()
    }

    /// Gives the Undo pill a full `undoDuration` once VoiceOver moves on from it.
    func releaseUndo() {
        trashed.resume()
    }

    /// Lowers the Undo pill, leaving its note in the trash.
    func dismissUndo() {
        trashed.clear()
    }
}

/// The rename sheet over the notes list: down, or up for the note `id` with `title` in its field as it rose.
private enum Renaming {
    case down
    case up(id: NoteID, title: String)
}
