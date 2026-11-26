import Foundation
import NoteCore
import NoteCoreTesting
import Testing

struct TextChangeTests {
    let newID = NoteID(rawValue: UUID())

    @Test func newTextIsStoredByteForByteUnderTheNewIDWithItsCaret() throws {
        let text = "Emoji 👩🏽‍💻 and combining e\u{301}\r\nCRLF"
        let caret = text.utf8.index(text.startIndex, offsetBy: "Emoji 👩🏽‍💻".utf8.count)

        let stored = try #require(stored(change(.typed(text, caret: caret), over: .notYet, now: .minutes(10))))

        #expect(Array(stored.text.utf8) == Array(text.utf8))
        #expect(stored.cursor == "Emoji 👩🏽‍💻".utf8.count)
        #expect(stored.id == newID)
        #expect(stored.createdAt == .minutes(10))
        #expect(stored.modifiedAt == .minutes(10))
    }

    @Test func erasedTextOverNoStoredNoteChangesNothing() {
        #expect(changesNothing(change(.erased(lastText: "gone"), over: .notYet, now: .minutes(10))))
    }

    @Test func erasingADraftDeletesIt() {
        let draft = Note.sample("first", modifiedAt: .minutes(10))

        #expect(deleted(change(.erased(lastText: "first"), over: .stored(draft), now: .minutes(11))) == draft.id)
    }

    @Test func erasingASavedNoteTrashesItWithItsStoredText() throws {
        let note = Note.sample("kept", modifiedAt: .minutes(10), savedAt: .minutes(10))

        let trashed = try #require(trashed(change(.erased(lastText: "kept"), over: .stored(note), now: .minutes(11))))

        #expect(trashed.id == note.id)
        #expect(trashed.text == "kept")
        #expect(trashed.modifiedAt == .minutes(10))
        #expect(trashed.trashedAt == .minutes(11))
    }

    @Test func erasingASavedNoteTrashesTheLastTextOnScreenEvenWhenItWasNeverStored() throws {
        let note = Note.sample("abc", modifiedAt: .minutes(10), savedAt: .minutes(10))
        let lastText = "abcdef 👩🏽‍💻"

        let trashed = try #require(trashed(change(.erased(lastText: lastText), over: .stored(note), now: .minutes(11))))

        #expect(Array(trashed.text.utf8) == Array(lastText.utf8))
        #expect(trashed.modifiedAt == .minutes(11))
        #expect(trashed.trashedAt == .minutes(11))
    }

    @Test func editingTheTextMovesModifiedAtAndKeepsTheNote() throws {
        let draft = Note.sample("one", createdAt: .minutes(10), modifiedAt: .minutes(10))

        let stored = try #require(
            stored(change(.typed("one two", caret: "one two".endIndex), over: .stored(draft), now: .minutes(11))))

        #expect(stored.id == draft.id)
        #expect(stored.text == "one two")
        #expect(stored.createdAt == .minutes(10))
        #expect(stored.modifiedAt == .minutes(11))
    }

    @Test func movingOnlyTheCaretStoresItAndKeepsModifiedAt() throws {
        let draft = Note.sample("caret", cursor: 5, modifiedAt: .minutes(10))

        let stored = try #require(
            stored(change(.typed("caret", caret: "caret".startIndex), over: .stored(draft), now: .minutes(11))))

        #expect(stored.cursor == 0)
        #expect(stored.modifiedAt == .minutes(10))
    }

    @Test func nothingChangedChangesNothing() {
        let draft = Note.sample("same", cursor: 4, modifiedAt: .minutes(10))

        #expect(changesNothing(change(.typed("same", caret: "same".endIndex), over: .stored(draft), now: .minutes(11))))
    }

    @Test func aChangeOfNormalizationIsAnEdit() throws {
        let draft = Note.sample("\u{E9}", cursor: 2, modifiedAt: .minutes(10))
        let decomposed = "e\u{301}"

        let stored = try #require(
            stored(change(.typed(decomposed, caret: decomposed.endIndex), over: .stored(draft), now: .minutes(11))))

        #expect(Array(stored.text.utf8) == Array(decomposed.utf8))
        #expect(stored.modifiedAt == .minutes(11))
    }

    private func change(_ screen: TextOnScreen, over note: StoredNote, now: Date) -> TextChange {
        TextChange(storing: screen, over: note, now: now, newID: newID)
    }

    private func changesNothing(_ change: TextChange) -> Bool {
        if case .nothing = change {
            return true
        }
        return false
    }

    private func deleted(_ change: TextChange) -> NoteID? {
        guard case .delete(let id) = change else {
            return nil
        }
        return id
    }

    private func trashed(_ change: TextChange) -> Note? {
        guard case .trash(let note) = change else {
            return nil
        }
        return note
    }

    private func stored(_ change: TextChange) -> Note? {
        guard case .store(let note) = change else {
            return nil
        }
        return note
    }
}
