import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

@testable import NoteUI

@MainActor
struct NotesModelTests {
    @Test func theModelShowsNothingUntilTheStoreAnswersThenFollowsEveryChange() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(changes: NoteChanges(storage: storage))
        #expect(model.summaries == .reading)
        let following = Task { try await model.follow() }
        defer { following.cancel() }

        try await waitUntil { model.summaries.map { $0.map(\.preview) } == .read([]) }
        let note = Note.sample("written", modifiedAt: .minutes(1))
        try await storage.save(note)
        try await waitUntil { model.summaries.map { $0.map(\.preview) } == .read(["written"]) }
        try await storage.deletePermanently(id: note.id)
        try await waitUntil { model.summaries.map { $0.map(\.preview) } == .read([]) }
    }

    @Test func aNoteDeletedWhileLeavingWriteStoresItGoesToTheTrashAfterThatStore() async throws {
        let storage = try NoteDatabase.openInMemory()
        let saved = Note.sample("saved", modifiedAt: .minutes(1), savedAt: .minutes(1))
        try await storage.save(saved)
        let held = HeldStorage(storage)
        let changes = NoteChanges(storage: held)
        let write = WriteModel(changes: changes)
        let notes = NotesModel(changes: changes)
        try await write.open(id: saved.id)
        write.text = "saved, edited"

        await held.holdSaves()
        let leaving = Task { try await write.leave(now: .minutes(10)) }
        await held.waitForAHeldSave()
        let deleting = Task { try await notes.moveToTrash(saved.id, now: .minutes(11)) }
        await held.releaseSaves()
        _ = try await leaving.value
        try await deleting.value

        let stored = try #require(try await storage.note(id: saved.id))
        #expect(stored.text == "saved, edited")
        #expect(stored.trashedAt == .minutes(11))
        #expect(notes.undoable == .shown(saved.id))
    }

    @Test func aNoteRenamedWhileLeavingWriteStoresItKeepsTheNewTitleAndTheTextFromWrite() async throws {
        let storage = try NoteDatabase.openInMemory()
        let saved = Note.sample("saved", modifiedAt: .minutes(1), title: "Old", savedAt: .minutes(1))
        try await storage.save(saved)
        let held = HeldStorage(storage)
        let changes = NoteChanges(storage: held)
        let write = WriteModel(changes: changes)
        let notes = NotesModel(changes: changes)
        try await write.open(id: saved.id)
        write.text = "saved, edited"

        try await notes.startRenaming(saved.id)

        await held.holdSaves()
        let leaving = Task { try await write.leave(now: .minutes(10)) }
        await held.waitForAHeldSave()
        let renaming = Task { try await notes.finishRenaming(typed: "New") }
        await held.releaseSaves()
        _ = try await leaving.value
        try await renaming.value

        let stored = try #require(try await storage.note(id: saved.id))
        #expect(stored.title == "New")
        #expect(stored.text == "saved, edited")
        #expect(notes.renameSheet == .down)
    }

    @Test func onlyTheRenameSheetsFirstAnswerCounts() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(changes: NoteChanges(storage: storage))
        let note = Note.sample("text", title: "Old", savedAt: .minutes(1))
        try await storage.save(note)

        try await model.startRenaming(note.id)
        try await model.finishRenaming(typed: "New")
        try await model.finishRenaming(typed: "Second tap")

        #expect(try await storage.note(id: note.id)?.title == "New")
    }

    @Test func theRenameSheetStartsFromTheTitleAsStoredNotAsTheListDrawsIt() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(changes: NoteChanges(storage: storage))
        let note = Note.sample("text", title: "Two\nlines e\u{301}", savedAt: .minutes(1))
        try await storage.save(note)

        try await model.startRenaming(note.id)

        guard case .up(let title) = model.renameSheet else {
            Issue.record("the rename sheet rose")
            return
        }
        #expect(Array(title.utf8) == Array("Two\nlines e\u{301}".utf8))
    }

    @Test func undoTakesTheNoteOutOfTheTrashAndLowersThePill() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(changes: NoteChanges(storage: storage))
        let note = Note.sample("deleted", modifiedAt: .minutes(1), savedAt: .minutes(1))
        try await storage.save(note)
        try await model.moveToTrash(note.id, now: .minutes(2))

        try await model.undo()

        #expect(model.undoable == .hidden)
        let restored = try #require(try await storage.note(id: note.id))
        #expect(restored.trashedAt == nil)
        #expect(restored.modifiedAt == .minutes(1))
    }
}
