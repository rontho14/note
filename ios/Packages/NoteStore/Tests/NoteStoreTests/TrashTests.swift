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

    @Test func theTrashListsOnlyTrashedNotesTheMostRecentlyTrashedFirstAndFollowsChanges() async throws {
        let older = Note.sample("older", savedAt: .minutes(1), trashedAt: .minutes(2))
        let newer = Note.sample("newer", title: "Titled", trashedAt: .minutes(3))
        try await storage.save(contentsOf: [older, newer, Note.sample("outside")])
        var trash = storage.trashSummaries().makeAsyncIterator()

        let first = try #require(try await trash.next(isolation: #isolation))
        #expect(first.map(\.summary.preview) == ["newer", "older"])
        #expect(first.map(\.trashedAt) == [.minutes(3), .minutes(2)])
        #expect(first.map(\.summary.kind) == [.draft, .saved(title: nil)])

        try await storage.restoreFromTrash(id: newer.id)
        let after = try await trash.next(isolation: #isolation)
        #expect(after?.map(\.summary.preview) == ["older"])
    }

    @Test func purgingDeletesOnlyNotesTrashedBeforeTheCutoff() async throws {
        let expired = Note.sample("expired", trashedAt: .minutes(1))
        let kept = Note.sample("kept", trashedAt: .minutes(5))
        let outside = Note.sample("outside", modifiedAt: .minutes(1))
        try await storage.save(contentsOf: [expired, kept, outside])

        try await storage.purgeTrash(trashedBefore: .minutes(3))

        #expect(try await storage.note(id: expired.id) == nil)
        #expect(try await storage.note(id: kept.id) != nil)
        #expect(try await storage.note(id: outside.id) != nil)
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
