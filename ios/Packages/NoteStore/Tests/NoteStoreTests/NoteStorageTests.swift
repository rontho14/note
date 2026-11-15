import Foundation
import NoteCore
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
        let note = Note(
            id: NoteID(rawValue: UUID()), text: text, createdAt: .milliseconds(1), modifiedAt: .milliseconds(2))

        try await storage.save(note)
        let stored = try #require(try await storage.note(id: note.id))

        #expect(Array(stored.text.utf8) == Array(text.utf8))
    }

    @Test func savingAgainChangesTextAndModifiedAtButKeepsTheFirstCreatedAt() async throws {
        let id = NoteID(rawValue: UUID())
        try await storage.save(
            Note(id: id, text: "first", createdAt: .milliseconds(1_000), modifiedAt: .milliseconds(1_000)))

        try await storage.save(
            Note(id: id, text: "second", createdAt: .milliseconds(9_000), modifiedAt: .milliseconds(5_000)))
        let stored = try #require(try await storage.note(id: id))

        #expect(stored.text == "second")
        #expect(stored.createdAt == .milliseconds(1_000))
        #expect(stored.modifiedAt == .milliseconds(5_000))
    }

    @Test func anUnknownIDHasNoNote() async throws {
        #expect(try await storage.note(id: NoteID(rawValue: UUID())) == nil)
    }
}

extension Date {
    static func milliseconds(_ count: Int64) -> Date {
        Date(timeIntervalSince1970: Double(count) / 1_000)
    }
}
