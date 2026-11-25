import Foundation
import NoteCore
import Observation

/// Every note as the notes list shows it, newest first, kept up to date with the store; the note just saved, which the
/// list tints for a moment; and the note just deleted, which Undo can bring back for a moment.
@Observable
final class NotesModel {
    /// How long the note just saved stays tinted before the tint fades.
    static let tintDuration: Duration = .milliseconds(1_500)
    /// How long Undo is offered after a delete.
    static let undoDuration: Duration = .seconds(4)

    /// Nil until the store first answers, so the list never shows itself empty before it has read.
    private(set) var summaries: [NoteSummary]?
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
    /// Deletes and undos wait in it for the store leaving write started, so it can't bring a deleted note back.
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
