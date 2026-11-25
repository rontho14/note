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

    /// Nil until the store first answers, so the list never shows itself empty before it has read.
    private(set) var summaries: [NoteSummary]?
    /// The rename sheet: down, or up for a note with its title as the sheet rose.
    private(set) var renameSheet = RenameSheet.down
    /// The note just saved, tinted and scrolled to.
    var justSaved: NoteID? { saved.value }
    /// The note just moved to the trash, which the Undo pill offers to bring back.
    var undoable: NoteID? { trashed.value }

    /// The note just saved once the summaries hold its row, so the list scrolls to it only when there is a row to
    /// scroll to.
    var justSavedRow: NoteID? {
        justSaved.flatMap { id in summaries?.contains { $0.id == id } == true ? id : nil }
    }

    private let storage: any NoteStorage
    /// Every read and change the list makes waits in it for the store leaving write started, which writes the whole
    /// note, so it can't bring a deleted note back or put an old title back.
    private let changes: NoteChanges
    private let saved = FadingValue<NoteID>(lasting: NotesModel.tintDuration)
    private let trashed = FadingValue<NoteID>(lasting: NotesModel.undoDuration)

    init(storage: any NoteStorage, changes: NoteChanges) {
        self.storage = storage
        self.changes = changes
    }

    /// Shows the store's notes, and again after every change, for as long as the calling task runs.
    func follow() async throws {
        for try await summaries in storage.noteSummaries() {
            self.summaries = summaries
        }
    }

    /// Tints the note `id` and scrolls to it, for `tintDuration`. A later save takes over.
    func showSaved(_ id: NoteID) {
        saved.show(id)
    }

    /// Sends the note `id` to the trash, and offers Undo for it for `undoDuration`.
    func moveToTrash(_ id: NoteID, now: Date) async throws {
        try await changes.run { try await self.storage.moveToTrash(id: id, now: now) }
        trashed.show(id)
    }

    /// Raises the rename sheet for the note `id`, with its title as stored in the field, once every earlier change has
    /// finished. The list draws a title on one line, so the field never starts from that copy. A note gone by then
    /// raises nothing.
    func startRenaming(_ id: NoteID) async throws {
        if let stored = try await changes.run({ try await self.storage.note(id: id) }) {
            renameSheet = .up(Renaming(id: id, title: stored.title ?? ""))
        }
    }

    /// Lowers the rename sheet with nothing stored.
    func stopRenaming() {
        renameSheet = .down
    }

    /// Lowers the rename sheet and gives the note it was up for the title `Note.title(typed:)` keeps of `typed`, once
    /// every earlier change has finished, so a store still on its way, such as leaving write's, can't put the old title
    /// back.
    func finishRenaming(_ renaming: Renaming, typed: String) async throws {
        renameSheet = .down
        let title = Note.title(typed: typed)
        try await changes.run { try await self.storage.rename(id: renaming.id, title: title) }
    }

    /// Lowers the Undo pill and takes the note it offered out of the trash, back to its place in the list. Once the
    /// offer has faded, Undo does nothing.
    func undo() async throws {
        guard let id = trashed.value else {
            return
        }
        trashed.clear()
        try await changes.run { try await self.storage.restoreFromTrash(id: id) }
    }

    /// Keeps the Undo pill up while VoiceOver reads it, and gives it a full `undoDuration` once VoiceOver moves on.
    func undoFocusChanged(isFocused: Bool) {
        isFocused ? trashed.pause() : trashed.resume()
    }

    /// Lowers the Undo pill, leaving its note in the trash.
    func dismissUndo() {
        trashed.clear()
    }
}

/// The rename sheet over the notes list.
enum RenameSheet {
    case down
    case up(Renaming)
}

/// The note the rename sheet is up for, and its title as the sheet rises.
struct Renaming {
    let id: NoteID
    let title: String
}
