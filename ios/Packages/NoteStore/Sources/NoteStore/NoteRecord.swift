import Foundation
import GRDB
import NoteCore

struct NoteRecord: Decodable, FetchableRecord, TableRecord {
    static let databaseTableName = "note"
    /// Newest first, and in id order when two notes were modified at once, so every query agrees on which is newest.
    static let newestFirstOrder: SQL = "modifiedAt DESC, id"
    static let isDraft: SQLExpression = Column("savedAt") == nil
    static let hasUnsavedEdits: SQLExpression = isDraft || Column("modifiedAt") > Column("savedAt")
    static let isOutsideTheTrash: SQLExpression = Column("trashedAt") == nil

    let id: UUID
    let text: String
    let cursor: Int
    let createdAt: Date
    let modifiedAt: Date
    let title: String?
    let savedAt: Date?
    let trashedAt: Date?

    var note: Note {
        Note(
            id: NoteID(rawValue: id), text: text, cursor: cursor, createdAt: createdAt, modifiedAt: modifiedAt,
            title: title, savedAt: savedAt, trashedAt: trashedAt)
    }
}
