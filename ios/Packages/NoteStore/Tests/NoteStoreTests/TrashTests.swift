import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

struct TrashTests {
    let storage: SQLiteNoteStorage

    init() throws {
        storage = try NoteDatabase.openInMemory()
    }

    @Test func movingToTheTrashSetsOnlyWhenTheNoteWentThere() async throws {
        let note = Note.sample(
            "Emoji 👩🏽‍💻 and combining e\u{301}\r\n", cursor: 4, modifiedAt: .minutes(2), title: "Kept",
            savedAt: .minutes(3))
        try await storage.save(note)

        try await storage.moveToTrash(id: note.id, now: .minutes(9))

        let trashed = try #require(try await storage.note(id: note.id))
        #expect(trashed.trashedAt == .minutes(9))
        expectUnchangedApartFromTheTrash(trashed, note)
    }

    @Test func restoringTakesTheNoteOutOfTheTrashAndChangesNothingElse() async throws {
        let note = Note.sample(
            "Emoji 👩🏽‍💻 and combining e\u{301}\r\n", cursor: 4, modifiedAt: .minutes(2), title: "Kept",
            savedAt: .minutes(3), trashedAt: .minutes(4))
        try await storage.save(note)

        try await storage.restoreFromTrash(id: note.id)

        let restored = try #require(try await storage.note(id: note.id))
        #expect(restored.trashedAt == nil)
        expectUnchangedApartFromTheTrash(restored, note)
    }

    private func expectUnchangedApartFromTheTrash(_ stored: Note, _ note: Note) {
        #expect(Array(stored.text.utf8) == Array(note.text.utf8))
        #expect(stored.cursor == note.cursor)
        #expect(stored.createdAt == note.createdAt)
        #expect(stored.modifiedAt == note.modifiedAt)
        #expect(stored.title == note.title)
        #expect(stored.savedAt == note.savedAt)
    }
}
