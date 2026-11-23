import Foundation
import NoteCore
import NoteTelemetry
import Observation
import SwiftUI

/// The note on the write screen and its stored copy. `TextChange` decides what each store does, and `LeavingWrite`
/// what a swipe toward notes does; this model carries them out, one change at a time.
@Observable
final class WriteModel {
    var text = "" {
        didSet {
            if !Note.isEmpty(text) {
                lastText = text
            }
            refreshHoldsLeaving()
        }
    }
    var selection: TextSelection?
    /// Whether write holds text never saved, so a swipe toward notes must ask first. It changes only when the text
    /// turns empty or not, or the note on screen changes, so a view that reads it isn't redrawn on every keystroke.
    private(set) var holdsLeaving = false
    /// Whether the save sheet is up: raised and not yet answered.
    var isAskingToSave: Bool {
        sheet == .asking
    }

    private let storage: any NoteStorage
    /// The stored note the text on screen belongs to, as last stored. Nil when the text belongs to no stored note, so
    /// the next store of text that isn't empty creates one.
    private var stored: Note? {
        didSet { refreshHoldsLeaving() }
    }
    /// The last value of `text` that wasn't empty, kept as it is typed, so a saved note erased before the pause that
    /// stores it goes to the trash with all of its text. A stored note's text was on screen, so this is always its
    /// latest text.
    private var lastText = ""
    /// The save sheet over the stored draft: hidden, asking, or answered and waiting for leaving write to carry the
    /// answer out. The text can't change while it is up, so the stored draft is the one it was raised for.
    private var sheet = SaveSheetState.hidden
    /// The last change to the stored note. Every load, store and return waits for the one before it, so a store that
    /// iOS suspended can't finish over a later change.
    private var lastChange: Task<Void, any Error>?

    init(storage: any NoteStorage) {
        self.storage = storage
    }

    /// Shows the most recent note with unsaved edits modified inside the reopen window, with its caret, if there is
    /// one.
    func loadRecentUnsavedNote(now: Date) async throws {
        try await showIfFound {
            try await self.storage.mostRecentUnsavedNote(modifiedAfter: Reopening.cutoff(now: now))
        }
    }

    /// Stores the text and caret, or deletes a draft or trashes a saved note once its text is empty, as `TextChange`
    /// decides.
    func storeText(now: Date) async throws {
        try await enqueue { try await self.writeText(now: now) }.value
    }

    /// Shows the note `id` with its caret. A note that is gone leaves the screen as it was.
    func open(id: NoteID) async throws {
        try await showIfFound { try await self.storage.note(id: id) }
    }

    /// Keeps the note on screen when it was modified inside the reopen window or the save sheet is up for it, and
    /// otherwise starts a blank note. The note stays stored either way.
    func returnToForeground(now: Date) async throws {
        try await enqueue {
            guard self.sheet == .hidden, let stored = self.stored,
                !Reopening.reopens(modifiedAt: stored.modifiedAt, now: now)
            else {
                return
            }
            self.show(nil)
        }.value
    }

    /// Stores the text typed since the last pause, so the sheet always has a stored draft under it, then raises the
    /// save sheet.
    func askToSave(now: Date) async throws {
        try await enqueue {
            try await self.writeText(now: now)
            if self.stored != nil {
                self.sheet = .asking
            }
        }.value
    }

    /// Lowers the sheet with its Save or Delete, which leaving write then carries out. Only the first answer of a sheet
    /// counts, so a second tap can't act on a blank write.
    func answerSaveSheet(_ answer: SaveSheetAnswer) {
        if sheet == .asking {
            sheet = .answered(answer)
        }
    }

    /// Lowers the save sheet with nothing saved, so the note stays a draft on write.
    func dismissSaveSheet() {
        sheet = .hidden
    }

    /// Leaving write for notes: stores the change `LeavingWrite` decides, then blanks write. Text never saved is held on
    /// write until the sheet is answered, so it stays as it is.
    func leave(now: Date) async throws {
        try await enqueue {
            let answer: SaveSheetAnswer? = if case .answered(let answer) = self.sheet { answer } else { nil }
            guard let change = LeavingWrite.change(self.screen, over: self.stored, answer: answer, now: now) else {
                return
            }
            try await self.apply(change)
            self.show(nil)
            self.sheet = .hidden
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
        stored = note
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

    private func writeText(now: Date) async throws {
        try await apply(TextChange(storing: screen, over: stored, now: now, newID: NoteID(rawValue: UUID())))
    }

    /// Carries `change` out against the store and keeps `stored` in step with it.
    private func apply(_ change: TextChange) async throws {
        switch change {
        case .nothing:
            return
        case .store(let note):
            try await storage.save(note)
            stored = note
        case .save(let note):
            try await SaveMeasurement.measure { try await storage.save(note) }
            stored = note
        case .delete(let id):
            try await storage.deletePermanently(id: id)
            stored = nil
        case .trash(let note):
            try await storage.save(note)
            stored = nil
        }
    }

    private func refreshHoldsLeaving() {
        let holds = LeavingWrite.asksFirst(screen, over: stored)
        if holds != holdsLeaving {
            holdsLeaving = holds
        }
    }

    private var screen: TextOnScreen {
        Note.isEmpty(text) ? .erased(lastText: lastText) : .typed(text, caret: caret)
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

/// The save sheet's state over the draft on write.
private enum SaveSheetState: Equatable {
    case hidden
    case asking
    case answered(SaveSheetAnswer)
}
