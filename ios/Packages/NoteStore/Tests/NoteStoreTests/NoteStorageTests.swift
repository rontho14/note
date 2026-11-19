import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

struct NoteStorageTests {
    let storage: SQLiteNoteStorage

    init() throws {
        storage = try NoteDatabase.openInMemory()
    }

    @Test func textComesBackByteForByte() async throws {
        let text =
            "Emoji 👩🏽‍💻🇧🇷, composed é and combining e\u{301}\r\nCRLF\rlone CR\ntrailing spaces   \ttab\t\n"
            + "NUL\u{0}inside" + String(repeating: "x", count: 100_000)
        let cursor = "Emoji 👩🏽‍💻".utf8.count
        let note = Note.sample(text, cursor: cursor)

        try await storage.save(note)
        let stored = try #require(try await storage.note(id: note.id))

        #expect(Array(stored.text.utf8) == Array(text.utf8))
        #expect(stored.cursor == cursor)
    }

    @Test func savingAgainChangesTextCursorAndModifiedAtButKeepsTheFirstCreatedAt() async throws {
        let id = NoteID(rawValue: UUID())
        try await storage.save(
            Note.sample("first", id: id, cursor: 5, createdAt: .milliseconds(1_000), modifiedAt: .milliseconds(1_000)))

        try await storage.save(
            Note.sample("second", id: id, cursor: 2, createdAt: .milliseconds(9_000), modifiedAt: .milliseconds(5_000)))
        let stored = try #require(try await storage.note(id: id))

        #expect(stored.text == "second")
        #expect(stored.cursor == 2)
        #expect(stored.createdAt == .milliseconds(1_000))
        #expect(stored.modifiedAt == .milliseconds(5_000))
    }

    @Test func anUnknownIDHasNoNote() async throws {
        #expect(try await storage.note(id: NoteID(rawValue: UUID())) == nil)
    }

    @Test func anEmptyNoteIsRefusedAndTheStoredNoteIsKept() async throws {
        let id = NoteID(rawValue: UUID())
        try await storage.save(Note.sample("kept", id: id))

        await #expect(throws: NoteStorageError.emptyNote) {
            try await storage.save(Note.sample(" \n", id: id, modifiedAt: .milliseconds(2)))
        }
        let stored = try #require(try await storage.note(id: id))

        #expect(stored.text == "kept")
        #expect(stored.modifiedAt == .milliseconds(1))
    }

    @Test func aBatchIsSavedTogether() async throws {
        let notes = ["one", "two", "three"].enumerated().map { index, text in
            Note.sample(text, modifiedAt: .milliseconds(Int64(index)))
        }

        try await storage.save(contentsOf: notes)

        for note in notes {
            #expect(try await storage.note(id: note.id)?.text == note.text)
        }
    }

    @Test func aBatchWithAnEmptyNoteIsRefusedWhole() async throws {
        let kept = Note.sample("would be kept")

        await #expect(throws: NoteStorageError.emptyNote) {
            try await storage.save(contentsOf: [kept, Note.sample(" \n")])
        }

        #expect(try await storage.note(id: kept.id) == nil)
    }

    @Test func deletingPermanentlyRemovesTheNote() async throws {
        let id = NoteID(rawValue: UUID())
        try await storage.save(Note.sample("gone", id: id))

        try await storage.deletePermanently(id: id)

        #expect(try await storage.note(id: id) == nil)
    }

    @Test func deletingAnUnknownIDPermanentlySucceeds() async throws {
        try await storage.deletePermanently(id: NoteID(rawValue: UUID()))
    }

    @Test func theMostRecentNoteIsTheNewestModifiedAfterTheCutoff() async throws {
        for (text, modified) in [("older", 2_000), ("newest", 3_000), ("before the cutoff", 500)] {
            try await storage.save(Note.sample(text, modifiedAt: .milliseconds(Int64(modified))))
        }

        let recent = try await storage.mostRecentNote(modifiedAfter: .milliseconds(1_000))

        #expect(recent?.text == "newest")
    }

    @Test func aNoteModifiedAtOrBeforeTheCutoffIsNotRecent() async throws {
        try await storage.save(Note.sample("at the cutoff", modifiedAt: .milliseconds(1_000)))
        try await storage.save(Note.sample("before the cutoff", modifiedAt: .milliseconds(999)))

        #expect(try await storage.mostRecentNote(modifiedAfter: .milliseconds(1_000)) == nil)
    }
}
