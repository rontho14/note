import Foundation
import GRDB
import NoteCore
import NoteStore
import Testing

struct DatabaseInspectionTests {
    let folder: TemporaryFolder
    let location: URL

    init() async throws {
        folder = try TemporaryFolder()
        location = folder.url.appending(path: "notes.sqlite")
        try await NoteDatabase.openOnDisk(at: location).save(
            Note(id: NoteID(rawValue: UUID()), text: "kept", createdAt: .milliseconds(1), modifiedAt: .milliseconds(1)))
    }

    @Test func emptyNotesWrittenPastTheStoreAreFound() async throws {
        let empty = UUID()
        try await write(
            """
            INSERT INTO note (id, text, createdAt, modifiedAt)
            VALUES (\(empty), \("\t\r\n"), \(Date.milliseconds(1)), \(Date.milliseconds(1)))
            """
        )

        #expect(try await NoteDatabase.emptyNoteIDs(inDatabaseAt: location) == [NoteID(rawValue: empty)])
    }

    @Test func aMigrationThisBuildDoesNotKnowIsNamed() async throws {
        try await write("INSERT INTO grdb_migrations (identifier) VALUES (\("from-a-newer-build"))")

        await #expect(throws: DatabaseInspectionError.unknownMigrations(["from-a-newer-build"])) {
            try await NoteDatabase.emptyNoteIDs(inDatabaseAt: location)
        }
    }

    @Test func aMissingDatabaseIsAnErrorAndIsNotCreated() async throws {
        let missing = folder.url.appending(path: "elsewhere.sqlite")

        await #expect(throws: DatabaseError.self) {
            try await NoteDatabase.emptyNoteIDs(inDatabaseAt: missing)
        }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    private func write(_ sql: SQL) async throws {
        try await DatabaseQueue(path: location.path).write { try $0.execute(literal: sql) }
    }
}
