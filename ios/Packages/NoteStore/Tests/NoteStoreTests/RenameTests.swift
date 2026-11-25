import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

struct RenameTests {
    let storage: SQLiteNoteStorage

    init() throws {
        storage = try NoteDatabase.openInMemory()
    }

    @Test func renamingChangesOnlyTheTitle() async throws {
        let note = Note.sample(
            "Emoji 👩🏽‍💻 and combining e\u{301}\r\n", cursor: 4, modifiedAt: .minutes(2), title: "Old",
            savedAt: .minutes(3))
        try await storage.save(note)

        try await storage.rename(id: note.id, title: "New")

        let renamed = try #require(try await storage.note(id: note.id))
        #expect(renamed.title == "New")
        #expect(renamed.trashedAt == nil)
        expectTextDatesAndSavedStateUnchanged(renamed, note)
    }

    @Test func renamingToNoTitleRemovesTheTitle() async throws {
        let note = Note.sample("text", title: "Old", savedAt: .minutes(3))
        try await storage.save(note)

        try await storage.rename(id: note.id, title: nil)

        #expect(try await storage.note(id: note.id)?.title == nil)
    }
}
