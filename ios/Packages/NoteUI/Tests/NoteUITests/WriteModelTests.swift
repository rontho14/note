import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import SwiftUI
import Testing

@testable import NoteUI

@MainActor
struct WriteModelTests {
    let storage: SQLiteNoteStorage
    let model: WriteModel

    init() throws {
        storage = try NoteDatabase.openInMemory()
        model = WriteModel(storage: storage, changes: NoteChanges())
    }

    @Test func typedTextIsSavedByteForByteWithItsCursor() async throws {
        let text = "Emoji 👩🏽‍💻 and combining e\u{301}\r\nCRLF"
        type(text, caretAfter: "Emoji 👩🏽‍💻")

        try await model.storeText(now: .minutes(10))

        let saved = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))
        #expect(Array(saved.text.utf8) == Array(text.utf8))
        #expect(saved.cursor == "Emoji 👩🏽‍💻".utf8.count)
        #expect(saved.createdAt == .minutes(10))
    }

    @Test func erasingASavedDraftDeletesItAndTypingAgainStartsANewNote() async throws {
        type("first")
        try await model.storeText(now: .minutes(10))
        let first = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))

        type("  ")
        try await model.storeText(now: .minutes(11))
        #expect(try await storage.note(id: first.id) == nil)

        type("second")
        try await model.storeText(now: .minutes(12))
        let second = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))
        #expect(second.id != first.id)
        #expect(second.createdAt == .minutes(12))
    }

    @Test func emptyingASavedNoteTrashesItWithTheLastTextOnScreenAndTypingAgainStartsANewNote() async throws {
        let saved = Note.sample("abc", modifiedAt: .minutes(1), savedAt: .minutes(1))
        try await storage.save(saved)
        try await model.open(id: saved.id)

        type("abcdef")
        type("")
        try await model.storeText(now: .minutes(10))
        type("next")
        try await model.storeText(now: .minutes(11))

        let trashed = try #require(try await storage.note(id: saved.id))
        #expect(trashed.text == "abcdef")
        #expect(trashed.trashedAt == .minutes(10))
        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0))?.text == "next")
    }

    @Test func overlappingStoresStoreOneNote() async throws {
        type("once")

        async let debounced: Void = model.storeText(now: .minutes(10))
        async let backgrounded: Void = model.storeText(now: .minutes(10))
        _ = try await (debounced, backgrounded)
        type("")
        try await model.storeText(now: .minutes(11))

        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)) == nil)
    }

    @Test func aDraftFromInsideTheWindowReopensWithItsCaret() async throws {
        try await storage.save(Note.sample("older", modifiedAt: .minutes(7)))
        try await storage.save(Note.sample("newest e\u{301}", cursor: 6, modifiedAt: .minutes(8)))

        try await model.loadRecentUnsavedNote(now: .minutes(10))

        #expect(model.text == "newest e\u{301}")
        #expect(caret() == 6)
    }

    @Test func aReopenedDraftKeepsItsIDWhenEdited() async throws {
        let draft = Note.sample("kept", cursor: 4, modifiedAt: .minutes(8))
        try await storage.save(draft)
        try await model.loadRecentUnsavedNote(now: .minutes(10))

        type("kept going")
        try await model.storeText(now: .minutes(11))

        let saved = try #require(try await storage.note(id: draft.id))
        #expect(saved.text == "kept going")
        #expect(saved.createdAt == draft.createdAt)
    }

    @Test func returningOutsideTheWindowStartsABlankNoteAndKeepsTheDraftStored() async throws {
        type("put away")
        try await model.storeText(now: .minutes(10))
        let putAway = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))

        try await model.returnToForeground(now: .minutes(16))
        #expect(model.text.isEmpty)
        type("fresh")
        try await model.storeText(now: .minutes(16))

        #expect(try await storage.note(id: putAway.id)?.text == "put away")
        let fresh = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(10)))
        #expect(fresh.id != putAway.id)
    }

    @Test func aReturnWaitsForTheSaveInFlightSoTheDraftStaysStored() async throws {
        let held = HeldStorage(storage)
        let model = WriteModel(storage: held, changes: NoteChanges())
        model.text = "kept"
        try await model.storeText(now: .minutes(10))
        let draft = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))

        model.text = "kept more"
        await held.holdSaves()
        let backgroundSave = Task { try await model.storeText(now: .minutes(10)) }
        await held.waitForAHeldSave()
        let foregroundReturn = Task { try await model.returnToForeground(now: .minutes(16)) }
        await held.releaseSaves()
        try await backgroundSave.value
        try await foregroundReturn.value
        try await model.storeText(now: .minutes(16))

        #expect(model.text.isEmpty)
        #expect(try await storage.note(id: draft.id)?.text == "kept more")
    }

    @Test func openingANoteShowsItWithItsCaret() async throws {
        let listed = Note.sample("listed e\u{301}", cursor: 6, modifiedAt: .minutes(1))
        try await storage.save(listed)

        try await model.open(id: listed.id)

        #expect(model.text == "listed e\u{301}")
        #expect(caret() == 6)
    }

    @Test func anOpenedNoteIsTheOneEdited() async throws {
        let listed = Note.sample("listed", modifiedAt: .minutes(1))
        try await storage.save(listed)

        try await model.open(id: listed.id)
        type("listed, edited")
        try await model.storeText(now: .minutes(11))

        #expect(try await storage.note(id: listed.id)?.text == "listed, edited")
        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0))?.id == listed.id)
    }

    @Test func openingANoteThatIsGoneLeavesTheScreenAsItWas() async throws {
        type("on screen")

        try await model.open(id: NoteID(rawValue: UUID()))

        #expect(model.text == "on screen")
    }

    @Test func onlyTextThatWasNeverSavedHoldsWrite() async throws {
        #expect(!model.holdsLeaving)
        type("typed")
        #expect(model.holdsLeaving)
        try await model.storeText(now: .minutes(1))
        #expect(model.holdsLeaving)
        type(" ")
        #expect(!model.holdsLeaving)

        let saved = Note.sample("saved", savedAt: .minutes(1))
        try await storage.save(saved)
        try await model.open(id: saved.id)
        #expect(!model.holdsLeaving)
    }

    @Test func askingToSaveStoresTheTextTypedSinceThePauseBeforeRaisingTheSheet() async throws {
        type("typed just now")

        try await model.askToSave(now: .minutes(10))

        #expect(model.isAskingToSave)
        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0))?.text == "typed just now")
    }

    @Test func theSheetsSaveIsCarriedOutOnLeavingAndOnlyTheFirstAnswerCounts() async throws {
        type("to save")
        try await model.askToSave(now: .minutes(10))
        let draft = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))

        model.answerSaveSheet(.save(title: "A title"))
        model.answerSaveSheet(.delete)
        #expect(!model.isAskingToSave)
        let left = try await model.leave(now: .minutes(11))

        let saved = try #require(try await storage.note(id: draft.id))
        #expect(saved.title == "A title")
        #expect(saved.savedAt == .minutes(11))
        #expect(saved.trashedAt == nil)
        #expect(saved.modifiedAt == draft.modifiedAt)
        #expect(model.text.isEmpty)
        #expect(left == draft.id)
    }

    @Test func theSheetsDeleteTrashesTheNoteOnLeavingAndBlanksWrite() async throws {
        type("to delete")
        try await model.askToSave(now: .minutes(10))
        let draft = try #require(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)))

        model.answerSaveSheet(.delete)
        let left = try await model.leave(now: .minutes(11))

        #expect(try await storage.note(id: draft.id)?.trashedAt == .minutes(11))
        #expect(model.text.isEmpty)
        #expect(left == nil)
    }

    @Test func dismissingTheSheetLeavesTheNoteADraftOnWrite() async throws {
        type("kept")
        try await model.askToSave(now: .minutes(10))

        model.dismissSaveSheet()
        model.answerSaveSheet(.delete)
        _ = try await model.leave(now: .minutes(11))

        #expect(model.text == "kept")
        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0))?.isDraft == true)
    }

    @Test func leavingAnEditedSavedNoteSavesItStraightAndBlanksWrite() async throws {
        let saved = Note.sample("saved", modifiedAt: .minutes(1), savedAt: .minutes(1))
        try await storage.save(saved)
        try await model.open(id: saved.id)

        type("saved, edited")
        let left = try await model.leave(now: .minutes(10))

        let stored = try #require(try await storage.note(id: saved.id))
        #expect(stored.text == "saved, edited")
        #expect(stored.savedAt == .minutes(10))
        #expect(!stored.hasUnsavedEdits)
        #expect(model.text.isEmpty)
        #expect(left == saved.id)
    }

    @Test func leavingAnUnchangedSavedNoteStoresNothingAndBlanksWrite() async throws {
        let saved = Note.sample("saved", modifiedAt: .minutes(1), savedAt: .minutes(2))
        try await storage.save(saved)
        try await model.open(id: saved.id)

        let left = try await model.leave(now: .minutes(10))

        #expect(try await storage.note(id: saved.id)?.savedAt == .minutes(2))
        #expect(model.text.isEmpty)
        #expect(left == saved.id)
    }

    @Test func leavingWhileWriteHoldsUnsavedTextDoesNothing() async throws {
        type("held")

        _ = try await model.leave(now: .minutes(10))

        #expect(model.text == "held")
        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)) == nil)
    }

    @Test func leavingErasedTextStoresTheErasure() async throws {
        type("erased")
        try await model.storeText(now: .minutes(1))
        type("")

        _ = try await model.leave(now: .minutes(10))

        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .minutes(0)) == nil)
    }

    @Test func returningOutsideTheWindowWhileTheSheetIsUpLeavesWriteAsItIs() async throws {
        type("asked")
        try await model.askToSave(now: .minutes(10))

        try await model.returnToForeground(now: .minutes(16))

        #expect(model.text == "asked")
        #expect(model.isAskingToSave)
    }

    private func type(_ text: String, caretAfter prefix: String? = nil) {
        model.text = text
        let caret = prefix.map { text.utf8.index(text.startIndex, offsetBy: $0.utf8.count) } ?? text.endIndex
        model.selection = TextSelection(insertionPoint: caret)
    }

    private func caret() -> Int? {
        guard case .selection(let range)? = model.selection?.indices else {
            return nil
        }
        return model.text.utf8.distance(from: model.text.startIndex, to: range.upperBound)
    }
}
