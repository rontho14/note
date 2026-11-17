import Foundation
import NoteCore
import NoteCoreTesting
import Testing

struct DraftChangeTests {
    let newID = NoteID(rawValue: UUID())

    @Test func newTextIsSavedByteForByteUnderTheNewIDWithItsCaret() throws {
        let text = "Emoji 👩🏽‍💻 and combining e\u{301}\r\nCRLF"
        let caret = text.utf8.index(text.startIndex, offsetBy: "Emoji 👩🏽‍💻".utf8.count)

        let saved = try #require(
            saved(DraftChange(saving: text, caret: caret, over: nil, now: .minutes(10), newID: newID)))

        #expect(Array(saved.text.utf8) == Array(text.utf8))
        #expect(saved.cursor == "Emoji 👩🏽‍💻".utf8.count)
        #expect(saved.id == newID)
        #expect(saved.createdAt == .minutes(10))
        #expect(saved.modifiedAt == .minutes(10))
    }

    @Test(arguments: ["", " \n\t"])
    func emptyTextWithNoDraftChangesNothing(text: String) {
        let change = DraftChange(saving: text, caret: text.endIndex, over: nil, now: .minutes(10), newID: newID)

        #expect(changesNothing(change))
    }

    @Test func emptyingADraftDeletesIt() {
        let draft = Note.sample("first", modifiedAt: .minutes(10))

        let change = DraftChange(saving: "  ", caret: "  ".endIndex, over: draft, now: .minutes(11), newID: newID)

        #expect(deleted(change) == draft.id)
    }

    @Test func editingTheTextMovesModifiedAtAndKeepsTheDraft() throws {
        let draft = Note.sample("one", createdAt: .minutes(10), modifiedAt: .minutes(10))

        let saved = try #require(
            saved(
                DraftChange(saving: "one two", caret: "one two".endIndex, over: draft, now: .minutes(11), newID: newID))
        )

        #expect(saved.id == draft.id)
        #expect(saved.text == "one two")
        #expect(saved.createdAt == .minutes(10))
        #expect(saved.modifiedAt == .minutes(11))
    }

    @Test func movingOnlyTheCaretSavesItAndKeepsModifiedAt() throws {
        let draft = Note.sample("caret", cursor: 5, modifiedAt: .minutes(10))

        let saved = try #require(
            saved(DraftChange(saving: "caret", caret: "caret".startIndex, over: draft, now: .minutes(11), newID: newID))
        )

        #expect(saved.cursor == 0)
        #expect(saved.modifiedAt == .minutes(10))
    }

    @Test func nothingChangedChangesNothing() {
        let draft = Note.sample("same", cursor: 4, modifiedAt: .minutes(10))

        let change = DraftChange(saving: "same", caret: "same".endIndex, over: draft, now: .minutes(11), newID: newID)

        #expect(changesNothing(change))
    }

    @Test func aChangeOfNormalizationIsAnEdit() throws {
        let draft = Note.sample("\u{E9}", cursor: 2, modifiedAt: .minutes(10))
        let decomposed = "e\u{301}"

        let saved = try #require(
            saved(
                DraftChange(
                    saving: decomposed, caret: decomposed.endIndex, over: draft, now: .minutes(11), newID: newID)))

        #expect(Array(saved.text.utf8) == Array(decomposed.utf8))
        #expect(saved.modifiedAt == .minutes(11))
    }

    private func changesNothing(_ change: DraftChange) -> Bool {
        if case .nothing = change {
            return true
        }
        return false
    }

    private func deleted(_ change: DraftChange) -> NoteID? {
        guard case .delete(let id) = change else {
            return nil
        }
        return id
    }

    private func saved(_ change: DraftChange) -> Note? {
        guard case .save(let note) = change else {
            return nil
        }
        return note
    }
}
