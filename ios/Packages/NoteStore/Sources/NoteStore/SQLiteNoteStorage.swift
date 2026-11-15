import GRDB
public import NoteCore

public struct SQLiteNoteStorage: NoteStorage {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func save(_ note: Note) async throws {
        try await writer.write { db in
            try db.execute(
                literal: """
                    INSERT INTO note (id, text, createdAt, modifiedAt)
                    VALUES (\(note.id.rawValue), \(note.text), \(note.createdAt), \(note.modifiedAt))
                    ON CONFLICT (id) DO UPDATE SET text = excluded.text, modifiedAt = excluded.modifiedAt
                    """
            )
        }
    }

    public func note(id: NoteID) async throws -> Note? {
        try await writer.read { db in
            try NoteRecord.fetchOne(db, key: id.rawValue)?.note
        }
    }
}
