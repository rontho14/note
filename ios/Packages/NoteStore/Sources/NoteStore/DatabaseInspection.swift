package import Foundation
import GRDB
package import NoteCore

package enum DatabaseInspectionError: Error, Equatable, CustomStringConvertible {
    case unknownMigrations([String])

    package var description: String {
        switch self {
        case .unknownMigrations(let names): "migrations this build doesn't know: \(names.joined(separator: ", "))"
        }
    }
}

extension NoteDatabase {
    package static func emptyNoteIDs(inDatabaseAt url: URL) async throws -> [NoteID] {
        var configuration = Configuration()
        configuration.readonly = true
        return try await DatabaseQueue(path: url.path, configuration: configuration).read { db in
            let unknownMigrations = try migrator.appliedIdentifiers(db).subtracting(migrator.migrations).sorted()
            guard unknownMigrations.isEmpty else {
                throw DatabaseInspectionError.unknownMigrations(unknownMigrations)
            }
            return try Array(NoteRecord.fetchCursor(db).map(\.note).filter(\.isEmpty).map(\.id))
        }
    }
}
