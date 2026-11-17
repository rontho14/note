import Foundation
import GRDB
import NoteCore
import NoteCoreTesting
import Testing

@testable import NoteStore

struct DatabaseOpeningTests {
    let temporaryFolder: TemporaryFolder
    let folder: URL
    let location: URL

    init() throws {
        temporaryFolder = try TemporaryFolder()
        folder = temporaryFolder.url
        location = folder.appending(path: "notes.sqlite")
    }

    @Test func oneFailedAttemptIsFollowedByASuccessfulOne() async throws {
        var attempts = 0

        let storage = try NoteDatabase.openOnDisk(migrator: migrator) {
            attempts += 1
            if attempts == 1 {
                throw DatabaseError(resultCode: .SQLITE_BUSY)
            }
            return try DatabasePool(path: location.path)
        }

        let unknownNote = try await storage.note(id: NoteID(rawValue: UUID()))
        #expect(attempts == 2)
        #expect(unknownNote == nil)
    }

    @Test func twoFailedAttemptsThrowTheSQLiteCodeAndLeaveTheFileAsItWas() async throws {
        _ = try await savedNote()
        let bytesBefore = try Data(contentsOf: location)
        var attempts = 0

        #expect(throws: NoteDatabaseError.sqlite(resultCode: ResultCode.SQLITE_CANTOPEN.rawValue)) {
            try NoteDatabase.openOnDisk(migrator: migrator) {
                attempts += 1
                throw DatabaseError(resultCode: .SQLITE_CANTOPEN)
            }
        }

        #expect(attempts == 2)
        #expect(try Data(contentsOf: location) == bytesBefore)
    }

    @Test func aPendingMigrationLeavesOneCopyOfTheDatabaseAsItWasBefore() async throws {
        let note = try await savedNote()
        try Data("older copy".utf8).write(to: folder.appending(path: "notes.before-v0.sqlite"))
        try Data("interrupted copy".utf8).write(to: folder.appending(path: "notes.before-extra.sqlite.unfinished"))
        var migratorWithAnExtraMigration = migrator
        migratorWithAnExtraMigration.registerMigration("extra") { db in
            try db.execute(sql: "DELETE FROM note")
        }

        _ = try NoteDatabase.openOnDisk(migrator: migratorWithAnExtraMigration) {
            try DatabasePool(path: location.path)
        }

        #expect(try copies() == ["notes.before-extra.sqlite"])
        let copy = try DatabaseQueue(path: folder.appending(path: "notes.before-extra.sqlite").path)
        let copiedMigrations = try await copy.read(migrator.appliedIdentifiers)
        let copiedNote = try await SQLiteNoteStorage(writer: copy).note(id: note.id)
        #expect(copiedMigrations == Set(migrator.migrations))
        #expect(copiedNote?.text == "kept")
    }

    @Test func neitherANewNorAnUpToDateDatabaseIsCopied() throws {
        _ = try NoteDatabase.openOnDisk(at: location)
        _ = try NoteDatabase.openOnDisk(at: location)

        #expect(try copies().isEmpty)
    }

    private func savedNote() async throws -> Note {
        let note = Note.sample("kept")
        try await NoteDatabase.openOnDisk(at: location).save(note)
        return note
    }

    private func copies() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix("notes.before-") }
            .sorted()
    }
}
