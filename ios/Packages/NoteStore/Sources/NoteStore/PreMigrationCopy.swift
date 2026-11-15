import Foundation
import GRDB

enum PreMigrationCopy {
    static func makeIfMigrationsArePending(of pool: DatabasePool, migrator: DatabaseMigrator) throws {
        guard let firstPending = try pool.read({ try firstPendingMigration(in: $0, migrator: migrator) }) else {
            return
        }
        let fileManager = FileManager.default
        let names = CopyNames(database: URL(filePath: pool.path), firstPendingMigration: firstPending)

        if fileManager.fileExists(atPath: names.unfinishedCopy.path) {
            try fileManager.removeItem(at: names.unfinishedCopy)
        }
        try pool.backup(to: DatabaseQueue(path: names.unfinishedCopy.path))
        if fileManager.fileExists(atPath: names.copy.path) {
            _ = try fileManager.replaceItemAt(names.copy, withItemAt: names.unfinishedCopy)
        } else {
            try fileManager.moveItem(at: names.unfinishedCopy, to: names.copy)
        }
        for name in try fileManager.contentsOfDirectory(atPath: names.folder.path) where names.isOlderCopy(name) {
            try fileManager.removeItem(at: names.folder.appending(path: name))
        }
    }

    private static func firstPendingMigration(in db: Database, migrator: DatabaseMigrator) throws -> String? {
        let applied = try migrator.appliedIdentifiers(db)
        guard !applied.isEmpty else {
            return nil
        }
        return migrator.migrations.first { !applied.contains($0) }
    }
}

private struct CopyNames {
    let folder: URL
    let copy: URL
    let unfinishedCopy: URL
    private let prefix: String
    private let suffix: String

    init(database: URL, firstPendingMigration: String) {
        folder = database.deletingLastPathComponent()
        prefix = "\(database.deletingPathExtension().lastPathComponent).before-"
        suffix = ".\(database.pathExtension)"
        copy = folder.appending(path: "\(prefix)\(firstPendingMigration)\(suffix)")
        unfinishedCopy = copy.appendingPathExtension("unfinished")
    }

    func isOlderCopy(_ name: String) -> Bool {
        name.hasPrefix(prefix) && name.hasSuffix(suffix) && name != copy.lastPathComponent
    }
}
