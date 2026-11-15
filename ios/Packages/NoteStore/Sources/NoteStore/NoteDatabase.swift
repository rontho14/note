public import Foundation
import GRDB

public enum NoteDatabase {
    public static func openInMemory() throws -> SQLiteNoteStorage {
        try migrated(DatabaseQueue())
    }

    public static func openOnDisk(at url: URL) throws -> SQLiteNoteStorage {
        try migrated(DatabasePool(path: url.path))
    }

    private static func migrated(_ writer: some DatabaseWriter) throws -> SQLiteNoteStorage {
        try migrator.migrate(writer)
        return SQLiteNoteStorage(writer: writer)
    }
}
