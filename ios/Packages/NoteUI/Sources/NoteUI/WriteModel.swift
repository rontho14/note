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
    // check-named-states: allowed until 2027-05-25 by rontho14: TextEditor's selection binding is optional.
    var selection: TextSelection?
    /// Whether a swipe toward notes leaves write or is held because write holds text never saved, so it asks first.
    /// It changes only when the text turns empty or not, or the note on screen changes, so a view that reads it isn't
    /// redrawn on every keystroke.
    private(set) var leaving = Leaving.free
    /// The save sheet: up while raised and not yet answered, with the title its field starts from, or down.
    var saveSheet: TitleSheetState {
        if case .asking(let title) = sheet { .up(title: title) } else { .down }
    }

    /// The stored note the text on screen belongs to, as last stored.
    private var stored = StoredNote.notYet {
        didSet { refreshHoldsLeaving() }
    }
    /// The last value of `text` that wasn't empty, kept as it is typed, so a saved note erased before the pause that
    /// stores it goes to the trash with all of its text. A stored note's text was on screen, so this is always its
    /// latest text.
    private var lastText = ""
    /// The save sheet over the stored draft: hidden, asking, or answered and waiting for leaving write to carry the
    /// answer out. The text can't change while it is up, so the stored draft is the one it was raised for.
    private var sheet = SaveSheetState.hidden
    /// Every load, store and return waits in it for the change before it.
    private let changes: NoteChanges

    init(changes: NoteChanges) {
        self.changes = changes
    }

    /// Shows the most recent note with unsaved edits modified inside the reopen window, with its caret, if there is
    /// one.
    func loadRecentUnsavedNote(now: Date) async throws {
        try await showIfFound {
            try await $0.mostRecentUnsavedNote(modifiedAfter: Reopening.cutoff(now: now))
        }
    }

    /// Stores the text and caret, or deletes a draft or trashes a saved note once its text is empty, as `TextChange`
    /// decides.
    func storeText(now: Date) async throws {
        try await changes.run { try await self.writeText(now: now, to: $0) }
    }

    /// Shows the note `id` with its caret. A note that is gone leaves the screen as it was.
    func open(id: NoteID) async throws {
        try await showIfFound { try await $0.note(id: id) }
    }

    /// Keeps the note on screen when it was modified inside the reopen window or the save sheet is up for it, and
    /// otherwise starts a blank note. The note stays stored either way.
    func returnToForeground(now: Date) async throws {
        try await changes.run { _ in
            guard self.sheet == .hidden, case .stored(let stored) = self.stored,
                !Reopening.reopens(modifiedAt: stored.modifiedAt, now: now)
            else {
                return
            }
            self.showBlank()
        }
    }

    /// Stores the text typed since the last pause, so the sheet always has a stored draft under it, then raises the
    /// save sheet.
    func askToSave(now: Date) async throws {
        try await changes.run {
            try await self.writeText(now: now, to: $0)
            if case .stored(let stored) = self.stored {
                self.sheet = .asking(title: stored.titleInTheField)
            }
        }
    }

    /// Lowers the sheet with its Save or Delete, which leaving write then carries out. Only the first answer of a sheet
    /// counts, so a second tap can't act on a blank write.
    func answerSaveSheet(_ answer: SaveSheetAnswer) {
        if case .asking = sheet {
            sheet = .answered(answer)
        }
    }

    /// Lowers the save sheet with nothing saved, so the note stays a draft on write.
    func dismissSaveSheet() {
        sheet = .hidden
    }

    /// Leaving write for notes: stores the change `LeavingWrite` decides, then blanks write, and returns what write was
    /// left on. A saved note, one just saved or one with nothing new to save, is what the list shows. Text never saved
    /// is held on write until the sheet is answered, so it stays as it is.
    func leave(now: Date) async throws -> LeftOn {
        try await changes.run { storage in
            guard
                case .apply(let change) = LeavingWrite(
                    self.screen, over: self.stored, answer: self.sheet.outcome, now: now)
            else {
                return .nothingToShow
            }
            try await self.apply(change, to: storage)
            let left: LeftOn =
                if case .stored(let note) = self.stored, !note.isDraft { .savedNote(note.id) } else { .nothingToShow }
            self.showBlank()
            self.sheet = .hidden
            return left
        }
    }

    /// Shows the note `fetch` finds with its caret, after every earlier change. Finding none leaves the screen as it
    /// was.
    private func showIfFound(_ fetch: @escaping (any NoteStorage) async throws -> Note?) async throws {
        try await changes.run { storage in
            guard let note = try await fetch(storage) else {
                return
            }
            self.show(note)
        }
    }

    /// Puts `note` on screen with its caret.
    private func show(_ note: Note) {
        stored = .stored(note)
        text = note.text
        selection = TextSelection(insertionPoint: note.cursorIndex)
    }

    /// Puts a blank note on screen, which the next store of text that isn't empty creates.
    private func showBlank() {
        stored = .notYet
        text = ""
        selection = nil
    }

    private func writeText(now: Date, to storage: any NoteStorage) async throws {
        try await apply(
            TextChange(storing: screen, over: stored, now: now, newID: NoteID(rawValue: UUID())), to: storage)
    }

    /// Carries `change` out against the store and keeps `stored` in step with it.
    private func apply(_ change: TextChange, to storage: any NoteStorage) async throws {
        switch change {
        case .nothing:
            return
        case .store(let note):
            try await storage.save(note)
            stored = .stored(note)
        case .save(let note):
            try await SaveMeasurement.measure { try await storage.save(note) }
            stored = .stored(note)
        case .delete(let id):
            try await storage.deletePermanently(id: id)
            stored = .notYet
        case .trash(let note):
            try await storage.save(note)
            stored = .notYet
        }
    }

    private func refreshHoldsLeaving() {
        let leaving: Leaving = LeavingWrite.asksFirst(screen, over: stored) ? .held : .free
        if leaving != self.leaving {
            self.leaving = leaving
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
    /// Raised over the stored draft, offering `title`: the draft's title as stored, given when it was renamed in the
    /// notes list, or nothing.
    case asking(title: String)
    case answered(SaveSheetAnswer)

    /// Whether the sheet was answered, for leaving write to carry out.
    var outcome: SaveSheetOutcome {
        if case .answered(let answer) = self { .answered(answer) } else { .unanswered }
    }
}

/// What leaving write was left on.
enum LeftOn: Equatable {
    /// A saved note, just saved or with nothing new to save, which the list shows.
    case savedNote(NoteID)
    /// A draft trashed, erased text or nothing stored: the list has no note to show.
    case nothingToShow
}

/// Whether a swipe off the last screen of the strip leaves it, or is held there so the screen can ask first.
enum Leaving: Equatable {
    case free
    case held
}
