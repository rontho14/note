public import Foundation
import GRDB

public enum NoteDatabaseError: Error, Equatable, CustomStringConvertible {
    case sqlite(resultCode: Int32)
    case system(domain: String, code: Int)

    public var description: String {
        switch self {
        case .sqlite(let resultCode): "SQLite result code \(resultCode)"
        case .system(let domain, let code): "\(domain) error code \(code)"
        }
    }
}

public enum NoteDatabase {
    private static let pauseBeforeRetry: TimeInterval = 0.2

    public static func defaultLocation(fileManager: FileManager) throws(NoteDatabaseError) -> URL {
        try reportingFailures {
            let folder = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
            ).appending(path: "Note", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder.appending(path: "notes.sqlite")
        }
    }

    public static func openInMemory() throws(NoteDatabaseError) -> SQLiteNoteStorage {
        try reportingFailures { try migrated(DatabaseQueue(), by: migrator) }
    }

    public static func openOnDisk(at url: URL) throws(NoteDatabaseError) -> SQLiteNoteStorage {
        try openOnDisk(migrator: migrator) { try DatabasePool(path: url.path) }
    }

    static func openOnDisk(
        migrator: DatabaseMigrator, connect: () throws -> DatabasePool
    ) throws(NoteDatabaseError) -> SQLiteNoteStorage {
        try reportingFailures {
            let pool = try connectRetryingOnce(connect)
            try PreMigrationCopy.makeIfMigrationsArePending(of: pool, migrator: migrator)
            return try migrated(pool, by: migrator)
        }
    }

    private static func migrated(
        _ writer: some DatabaseWriter, by migrator: DatabaseMigrator
    ) throws -> SQLiteNoteStorage {
        try migrator.migrate(writer)
        return SQLiteNoteStorage(writer: writer)
    }

    private static func connectRetryingOnce(_ connect: () throws -> DatabasePool) throws -> DatabasePool {
        do {
            return try connect()
        } catch {
            Thread.sleep(forTimeInterval: pauseBeforeRetry)
            return try connect()
        }
    }

    private static func reportingFailures<Result>(
        _ body: () throws -> Result
    ) throws(NoteDatabaseError) -> Result {
        do {
            return try body()
        } catch let error as DatabaseError {
            throw .sqlite(resultCode: error.extendedResultCode.rawValue)
        } catch {
            let error = error as NSError
            throw .system(domain: error.domain, code: error.code)
        }
    }
}
