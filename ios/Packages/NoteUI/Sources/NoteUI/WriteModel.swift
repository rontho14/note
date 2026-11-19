import Foundation
import NoteCore
import Observation
import SwiftUI

/// The note on the write screen and its draft in storage. `DraftChange` decides what each save does; this model
/// carries it out, one change at a time.
@Observable
final class WriteModel {
    var text = ""
    var selection: TextSelection?

    private let storage: any NoteStorage
    /// The stored note the text on screen belongs to, as last saved. Nil when the text belongs to no stored note, so
    /// the next save of text that isn't empty creates one.
    private var draft: Note?
    /// The last change to the draft. Every load, save and return waits for the one before it, so a save that iOS
    /// suspended can't finish over a later change.
    private var lastChange: Task<Void, any Error>?

    init(storage: any NoteStorage) {
        self.storage = storage
    }

    /// Shows the most recent note modified inside the reopen window, with its caret, if there is one.
    func loadRecentDraft(now: Date) async throws {
        try await showIfFound { try await self.storage.mostRecentNote(modifiedAfter: DraftReopening.cutoff(now: now)) }
    }

    /// Stores the text and caret as the draft, or deletes the draft once its text is empty, as `DraftChange` decides.
    func saveDraft(now: Date) async throws {
        try await enqueue { try await self.writeDraft(now: now) }.value
    }

    /// Shows the note `id` with its caret. A note that is gone leaves the screen as it was.
    func open(id: NoteID) async throws {
        try await showIfFound { try await self.storage.note(id: id) }
    }

    /// Keeps the draft when it was modified inside the reopen window, and otherwise starts a blank note. The draft
    /// stays stored either way.
    func returnToForeground(now: Date) async throws {
        try await enqueue {
            guard let draft = self.draft, !DraftReopening.reopens(modifiedAt: draft.modifiedAt, now: now) else {
                return
            }
            self.show(nil)
        }.value
    }

    /// Shows the note `fetch` finds with its caret, after every earlier change. Finding none leaves the screen as it
    /// was.
    private func showIfFound(_ fetch: @escaping () async throws -> Note?) async throws {
        try await enqueue {
            guard let note = try await fetch() else {
                return
            }
            self.show(note)
        }.value
    }

    /// Puts `note` on screen with its caret, or a blank note when it is nil.
    private func show(_ note: Note?) {
        draft = note
        text = note?.text ?? ""
        selection = note.map { TextSelection(insertionPoint: $0.cursorIndex) }
    }

    /// Starts `change` once every earlier change has finished, whether or not that one failed, and returns its task.
    private func enqueue(_ change: @escaping () async throws -> Void) -> Task<Void, any Error> {
        let previous = lastChange
        let next = Task {
            _ = await previous?.result
            try await change()
        }
        lastChange = next
        return next
    }

    private func writeDraft(now: Date) async throws {
        switch DraftChange(saving: text, caret: caret, over: draft, now: now, newID: NoteID(rawValue: UUID())) {
        case .nothing:
            return
        case .save(let note):
            try await storage.save(note)
            draft = note
        case .delete(let id):
            try await storage.deletePermanently(id: id)
            draft = nil
        }
    }

    /// Where typing would continue: the end of the selection, or the end of the text when nothing is selected.
    private var caret: String.Index {
        switch selection?.indices {
        case .selection(let range):
            range.upperBound
        case .multiSelection(let ranges):
            ranges.ranges.last?.upperBound ?? text.endIndex
        case nil:
            text.endIndex
        @unknown default:
            text.endIndex
        }
    }
}
