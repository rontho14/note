import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

struct NoteSummariesTests {
    let storage: SQLiteNoteStorage

    init() throws {
        storage = try NoteDatabase.openInMemory()
    }

    @Test func notesComeNewestFirstWithTiesInIDOrder() async throws {
        let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        try await storage.save(Note.sample("oldest", modifiedAt: .milliseconds(1_000)))
        try await storage.save(
            Note.sample("tied second", id: NoteID(rawValue: second), modifiedAt: .milliseconds(3_000)))
        try await storage.save(Note.sample("middle", modifiedAt: .milliseconds(2_000)))
        try await storage.save(Note.sample("tied first", id: NoteID(rawValue: first), modifiedAt: .milliseconds(3_000)))

        let summaries = try await currentSummaries()

        #expect(summaries.map(\.preview) == ["tied first", "tied second", "middle", "oldest"])
        #expect(summaries.first?.modifiedAt == .milliseconds(3_000))
    }

    @Test func thePreviewIsTakenFromTheStartOfALongNote() async throws {
        try await storage.save(Note.sample("Start\nof the note " + String(repeating: "word ", count: 10_000)))

        let preview = try #require(try await currentSummaries().first?.preview)

        #expect(preview.hasPrefix("Start of the note word"))
        #expect(preview.count == NoteSummary.textStartLength)
    }

    @Test func aNoteThatOpensWithMoreWhitespaceThanThePreviewReadsStillHasAPreview() async throws {
        let opening = String(repeating: "\n", count: NoteSummary.textStartLength) + "\r\n\u{3000}\u{A0} \t"
        try await storage.save(Note.sample(opening + "First words"))

        let preview = try await currentSummaries().first?.preview

        #expect(preview == "First words")
    }

    @Test func aSaveAnEditAndADeleteEachSendFreshSummaries() async throws {
        let id = NoteID(rawValue: UUID())
        var updates = storage.noteSummaries().makeAsyncIterator()
        var previews: [[String]?] = []
        previews.append(try await updates.next(isolation: #isolation)?.map(\.preview))

        try await storage.save(Note.sample("written", id: id, modifiedAt: .milliseconds(1)))
        previews.append(try await updates.next(isolation: #isolation)?.map(\.preview))
        try await storage.save(Note.sample("edited", id: id, modifiedAt: .milliseconds(2)))
        previews.append(try await updates.next(isolation: #isolation)?.map(\.preview))
        try await storage.deletePermanently(id: id)
        previews.append(try await updates.next(isolation: #isolation)?.map(\.preview))

        #expect(previews == [[], ["written"], ["edited"], []])
    }

    private func currentSummaries() async throws -> [NoteSummary] {
        var updates = storage.noteSummaries().makeAsyncIterator()
        let current = try await updates.next(isolation: #isolation)
        return try #require(current)
    }
}
