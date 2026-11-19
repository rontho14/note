public import Foundation
import GRDB
public import NoteCore

public struct SQLiteNoteStorage: NoteStorage {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func save(contentsOf notes: [Note]) async throws {
        guard !notes.contains(where: \.isEmpty) else {
            throw NoteStorageError.emptyNote
        }
        try await writer.write { db in
            for note in notes {
                try db.execute(
                    literal: """
                        INSERT INTO note (id, text, cursor, createdAt, modifiedAt)
                        VALUES (\(note.id.rawValue), \(note.text), \(note.cursor), \(note.createdAt), \(note.modifiedAt))
                        ON CONFLICT (id) DO UPDATE
                        SET text = excluded.text, cursor = excluded.cursor, modifiedAt = excluded.modifiedAt
                        """
                )
            }
        }
    }

    public func note(id: NoteID) async throws -> Note? {
        try await writer.read { db in
            try NoteRecord.fetchOne(db, key: id.rawValue)?.note
        }
    }

    public func mostRecentNote(modifiedAfter cutoff: Date) async throws -> Note? {
        try await writer.read { db in
            try NoteRecord
                .filter(Column("modifiedAt") > cutoff)
                .order(literal: NoteRecord.newestFirstOrder)
                .fetchOne(db)?
                .note
        }
    }

    public func deletePermanently(id: NoteID) async throws {
        try await writer.write { db in
            _ = try NoteRecord.deleteOne(db, key: id.rawValue)
        }
    }

    public func noteSummaries() -> any AsyncSequence<[NoteSummary], any Error> {
        ValueObservation
            .tracking { db in try NoteSummaryRecord.newestFirst.fetchAll(db).map(\.summary) }
            .values(in: writer)
    }
}
