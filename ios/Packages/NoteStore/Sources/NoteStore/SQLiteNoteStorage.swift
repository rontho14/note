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
                        INSERT INTO note (id, text, cursor, createdAt, modifiedAt, title, savedAt, trashedAt)
                        VALUES (
                            \(note.id.rawValue), \(note.text), \(note.cursor), \(note.createdAt), \(note.modifiedAt),
                            \(note.title), \(note.savedAt), \(note.trashedAt))
                        ON CONFLICT (id) DO UPDATE
                        SET text = excluded.text, cursor = excluded.cursor, modifiedAt = excluded.modifiedAt,
                            title = excluded.title, savedAt = excluded.savedAt, trashedAt = excluded.trashedAt
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

    public func mostRecentUnsavedNote(modifiedAfter cutoff: Date) async throws -> Note? {
        try await writer.read { db in
            try NoteRecord
                .filter(NoteRecord.Columns.modifiedAt > cutoff)
                .filter(NoteRecord.isOutsideTheTrash && NoteRecord.hasUnsavedEdits)
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

    public func moveToTrash(id: NoteID, now: Date) async throws {
        try await update(id, NoteRecord.Columns.trashedAt, to: now)
    }

    public func restoreFromTrash(id: NoteID) async throws {
        try await update(id, NoteRecord.Columns.trashedAt, to: Date?.none)
    }

    public func noteSummaries() -> any AsyncSequence<[NoteSummary], any Error> {
        ValueObservation
            .tracking { db in try NoteSummaryRecord.newestFirst.fetchAll(db).map(\.summary) }
            .values(in: writer)
    }

    public func rename(id: NoteID, title: String?) async throws {
        try await update(id, NoteRecord.Columns.title, to: title)
    }

    public func trashSummaries() -> any AsyncSequence<[TrashedNoteSummary], any Error> {
        ValueObservation
            .tracking { db in try TrashedNoteSummaryRecord.mostRecentlyTrashedFirst.fetchAll(db).map(\.summary) }
            .values(in: writer)
    }

    public func purgeTrash(trashedBefore cutoff: Date) async throws {
        try await writer.write { db in
            _ = try NoteRecord.filter(NoteRecord.Columns.trashedAt < cutoff).deleteAll(db)
        }
    }

    public func savedNoteCounts() -> any AsyncSequence<Int, any Error> {
        ValueObservation
            .tracking { db in
                try NoteRecord.filter(!NoteRecord.isDraft && NoteRecord.isOutsideTheTrash).fetchCount(db)
            }
            .values(in: writer)
    }

    /// A change made from the list: one `UPDATE` of the note `id`'s `column` to `value`, which writes no text, so it can't lose
    /// a store of the whole note or be lost to one.
    private func update(
        _ id: NoteID, _ column: Column, to value: (some DatabaseValueConvertible & Sendable)?
    ) async throws {
        try await writer.write { db in
            _ = try NoteRecord.filter(key: id.rawValue).updateAll(db, column.set(to: value))
        }
    }
}
