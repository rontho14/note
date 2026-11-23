import Foundation
import NoteCore
import NoteCoreTesting
import Testing

struct SavingTests {
    @Test func savingKeepsTextCaretModifiedAtAndTitleAndMarksTheNoteSaved() {
        let text = "Emoji 👩🏽‍💻 and combining e\u{301}\r\n"
        let note = Note.sample(text, cursor: 4, modifiedAt: .minutes(3), title: "Kept")

        let saved = note.saved(now: .minutes(9))

        #expect(Array(saved.text.utf8) == Array(text.utf8))
        #expect(saved.cursor == 4)
        #expect(saved.modifiedAt == .minutes(3))
        #expect(saved.title == "Kept")
        #expect(saved.savedAt == .minutes(9))
        #expect(!saved.isDraft)
    }

    @Test(arguments: [
        ("A title", "A title"),
        ("  spaced\n", "  spaced\n"),
        ("e\u{301}", "e\u{301}"),
        ("", nil),
        (" \t\n", nil),
    ])
    func aTitleIsKeptAsTypedUnlessItIsOnlyWhitespace(typed: String, title: String?) {
        let saved = Note.sample("text", title: "Earlier").saved(title: typed, now: .minutes(1))

        #expect(saved.title.map { Array($0.utf8) } == title.map { Array($0.utf8) })
        #expect(saved.savedAt == .minutes(1))
    }

    @Test(arguments: [
        (nil, true),
        (Date.minutes(5), false),
        (Date.minutes(6), false),
        (Date.minutes(4), true),
    ])
    func aNoteHasUnsavedEditsWhenItIsADraftOrWasEditedAfterItsSave(savedAt: Date?, hasUnsavedEdits: Bool) {
        #expect(Note.sample("text", modifiedAt: .minutes(5), savedAt: savedAt).hasUnsavedEdits == hasUnsavedEdits)
    }

    @Test func leavingErasedTextStoresItAsTextChangeDecides() {
        let saved = Note.sample("stored", savedAt: .minutes(1))

        #expect(
            trashed(LeavingWrite.change(.erased(lastText: "stored"), over: saved, answer: nil, now: .minutes(9))) != nil
        )
        #expect(isNothing(LeavingWrite.change(.erased(lastText: ""), over: nil, answer: nil, now: .minutes(9))))
    }

    @Test(arguments: [nil, Note.sample("draft")])
    func leavingTextThatWasNeverSavedAsksFirst(stored: Note?) {
        #expect(
            LeavingWrite.change(.typed("typed", caret: "typed".endIndex), over: stored, answer: nil, now: .minutes(9))
                == nil)
    }

    @Test func leavingASavedNoteEditedSinceItsSaveSavesItWithTheTextOnScreen() throws {
        let saved = Note.sample("saved", modifiedAt: .minutes(1), savedAt: .minutes(1))

        let note = try #require(
            self.saved(
                LeavingWrite.change(
                    .typed("saved, edited", caret: "saved, edited".endIndex), over: saved, answer: nil,
                    now: .minutes(9))))

        #expect(note.id == saved.id)
        #expect(note.text == "saved, edited")
        #expect(note.modifiedAt == .minutes(9))
        #expect(note.savedAt == .minutes(9))
    }

    @Test func leavingASavedNoteWithNothingNewStoresNothing() {
        let saved = Note.sample("saved", modifiedAt: .minutes(1), savedAt: .minutes(2))

        #expect(
            isNothing(
                LeavingWrite.change(
                    .typed("saved", caret: "saved".endIndex), over: saved, answer: nil, now: .minutes(9))))
    }

    @Test func leavingAfterTheSheetsSaveSavesTheDraftWithItsTitle() throws {
        let draft = Note.sample("draft", modifiedAt: .minutes(1))

        let note = try #require(
            saved(
                LeavingWrite.change(
                    .typed("draft", caret: "draft".endIndex), over: draft, answer: .save(title: "Title"),
                    now: .minutes(9))))

        #expect(note.id == draft.id)
        #expect(note.title == "Title")
        #expect(note.savedAt == .minutes(9))
        #expect(note.modifiedAt == .minutes(1))
    }

    @Test func leavingAfterTheSheetsDeleteTrashesTheDraft() throws {
        let draft = Note.sample("draft")

        let note = try #require(
            trashed(
                LeavingWrite.change(
                    .typed("draft", caret: "draft".endIndex), over: draft, answer: .delete, now: .minutes(9))))

        #expect(note.id == draft.id)
        #expect(note.trashedAt == .minutes(9))
    }

    private func saved(_ change: TextChange?) -> Note? {
        guard case .save(let note)? = change else {
            return nil
        }
        return note
    }

    private func trashed(_ change: TextChange?) -> Note? {
        guard case .trash(let note)? = change else {
            return nil
        }
        return note
    }

    private func isNothing(_ change: TextChange?) -> Bool {
        if case .nothing? = change {
            return true
        }
        return false
    }
}
