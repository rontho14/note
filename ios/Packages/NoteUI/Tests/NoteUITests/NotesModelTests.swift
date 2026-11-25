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
        let model = NotesModel(storage: storage, changes: NoteChanges())
        #expect(model.summaries == nil)
        let following = Task { try await model.follow() }
        defer { following.cancel() }

        try await waitUntil { model.summaries?.map(\.preview) == [] }
        let note = Note.sample("written", modifiedAt: .minutes(1))
        try await storage.save(note)
        try await waitUntil { model.summaries?.map(\.preview) == ["written"] }
        try await storage.deletePermanently(id: note.id)
        try await waitUntil { model.summaries?.map(\.preview) == [] }
    }

    @Test func aNoteDeletedWhileLeavingWriteStoresItGoesToTheTrashAfterThatStore() async throws {
        let storage = try NoteDatabase.openInMemory()
        let saved = Note.sample("saved", modifiedAt: .minutes(1), savedAt: .minutes(1))
        try await storage.save(saved)
        let held = HeldStorage(storage)
        let changes = NoteChanges()
        let write = WriteModel(storage: held, changes: changes)
        let notes = NotesModel(storage: held, changes: changes)
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
        #expect(notes.undoable == saved.id)
    }

    @Test func aNoteRenamedWhileLeavingWriteStoresItKeepsTheNewTitleAndTheTextFromWrite() async throws {
        let storage = try NoteDatabase.openInMemory()
        let saved = Note.sample("saved", modifiedAt: .minutes(1), title: "Old", savedAt: .minutes(1))
        try await storage.save(saved)
        let held = HeldStorage(storage)
        let changes = NoteChanges()
        let write = WriteModel(storage: held, changes: changes)
        let notes = NotesModel(storage: held, changes: changes)
        try await write.open(id: saved.id)
        write.text = "saved, edited"

        try await notes.startRenaming(saved.id)
        guard case .up(let sheet) = notes.renameSheet else {
            Issue.record("the rename sheet rose")
            return
        }

        await held.holdSaves()
        let leaving = Task { try await write.leave(now: .minutes(10)) }
        await held.waitForAHeldSave()
        let renaming = Task { try await notes.finishRenaming(sheet, typed: "New") }
        await held.releaseSaves()
        _ = try await leaving.value
        try await renaming.value

        let stored = try #require(try await storage.note(id: saved.id))
        #expect(stored.title == "New")
        #expect(stored.text == "saved, edited")
        guard case .down = notes.renameSheet else {
            Issue.record("the rename sheet went down")
            return
        }
    }

    @Test func theRenameSheetStartsFromTheTitleAsStoredNotAsTheListDrawsIt() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(storage: storage, changes: NoteChanges())
        let note = Note.sample("text", title: "Two\nlines e\u{301}", savedAt: .minutes(1))
        try await storage.save(note)

        try await model.startRenaming(note.id)

        guard case .up(let sheet) = model.renameSheet else {
            Issue.record("the rename sheet rose")
            return
        }
        #expect(sheet.id == note.id)
        #expect(Array(sheet.title.utf8) == Array("Two\nlines e\u{301}".utf8))
    }

    @Test func undoTakesTheNoteOutOfTheTrashAndLowersThePill() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(storage: storage, changes: NoteChanges())
        let note = Note.sample("deleted", modifiedAt: .minutes(1), savedAt: .minutes(1))
        try await storage.save(note)
        try await model.moveToTrash(note.id, now: .minutes(2))

        try await model.undo()

        #expect(model.undoable == nil)
        let restored = try #require(try await storage.note(id: note.id))
        #expect(restored.trashedAt == nil)
        #expect(restored.modifiedAt == .minutes(1))
    }
}
