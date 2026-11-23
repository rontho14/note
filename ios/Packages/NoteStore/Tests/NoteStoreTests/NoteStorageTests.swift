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

    @Test func theTitleAndWhenTheNoteWasSavedAndTrashedReadBackExactly() async throws {
        let title = "  Title 👩🏽‍💻 e\u{301}\r\n"
        let note = Note.sample(
            "text", title: title, savedAt: .milliseconds(1_234_567), trashedAt: .milliseconds(2_345_678))

        try await storage.save(note)
        let stored = try #require(try await storage.note(id: note.id))

        #expect(stored.title.map { Array($0.utf8) } == Array(title.utf8))
        #expect(stored.savedAt == .milliseconds(1_234_567))
        #expect(stored.trashedAt == .milliseconds(2_345_678))
    }

    @Test func savingAgainReplacesTheTitleAndWhenTheNoteWasSavedAndTrashed() async throws {
        let id = NoteID(rawValue: UUID())
        try await storage.save(
            Note.sample("text", id: id, title: "Old", savedAt: .milliseconds(1), trashedAt: .milliseconds(2)))

        try await storage.save(Note.sample("text", id: id, savedAt: .milliseconds(3)))
        let stored = try #require(try await storage.note(id: id))

        #expect(stored.title == nil)
        #expect(stored.savedAt == .milliseconds(3))
        #expect(stored.trashedAt == nil)
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

        let recent = try await storage.mostRecentUnsavedNote(modifiedAfter: .milliseconds(1_000))

        #expect(recent?.text == "newest")
    }

    @Test func aNoteModifiedAtOrBeforeTheCutoffIsNotRecent() async throws {
        try await storage.save(Note.sample("at the cutoff", modifiedAt: .milliseconds(1_000)))
        try await storage.save(Note.sample("before the cutoff", modifiedAt: .milliseconds(999)))

        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .milliseconds(1_000)) == nil)
    }

    @Test(arguments: [nil, Date.milliseconds(4_999), Date.milliseconds(5_000), Date.milliseconds(5_001)])
    func aNoteReopensExactlyWhenItHasUnsavedEdits(savedAt: Date?) async throws {
        let note = Note.sample("note", modifiedAt: .milliseconds(5_000), savedAt: savedAt)
        try await storage.save(note)

        let reopened = try await storage.mostRecentUnsavedNote(modifiedAfter: .milliseconds(1_000))

        #expect((reopened?.id == note.id) == note.hasUnsavedEdits)
    }

    @Test func aNoteInTheTrashNeverReopens() async throws {
        try await storage.save(
            Note.sample("trashed", modifiedAt: .milliseconds(5_000), trashedAt: .milliseconds(5_000)))

        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .milliseconds(1_000)) == nil)
    }

    @Test func theNewestNoteWithUnsavedEditsReopensOverANewerSavedOne() async throws {
        try await storage.save(
            Note.sample("just saved", modifiedAt: .milliseconds(6_000), savedAt: .milliseconds(6_000)))
        let edited = Note.sample("edited", modifiedAt: .milliseconds(5_000), savedAt: .milliseconds(4_000))
        try await storage.save(edited)

        #expect(try await storage.mostRecentUnsavedNote(modifiedAfter: .milliseconds(1_000))?.id == edited.id)
    }

    @Test func ofTwoNotesModifiedAtOnceTheMostRecentIsTheOneTheListShowsFirst() async throws {
        let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        try await storage.save(Note.sample("first", id: NoteID(rawValue: first), modifiedAt: .milliseconds(2_000)))
        try await storage.save(Note.sample("second", id: NoteID(rawValue: second), modifiedAt: .milliseconds(2_000)))

        let recent = try await storage.mostRecentUnsavedNote(modifiedAfter: .milliseconds(1_000))
        var summaries = storage.noteSummaries().makeAsyncIterator()
        let listed = try await summaries.next(isolation: #isolation)

        #expect(recent?.id == listed?.first?.id)
    }
}
