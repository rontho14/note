import Foundation
import GRDB
import NoteCore

struct NoteRecord: Decodable, FetchableRecord, TableRecord {
    static let databaseTableName = "note"
    /// Newest first, and in id order when two notes were modified at once, so every query agrees on which is newest.
    static let newestFirstOrder: SQL = "modifiedAt DESC, id"
    /// The most recently trashed first, and in id order when two notes went to the trash at once.
    static let mostRecentlyTrashedFirstOrder: SQL = "\(Columns.trashedAt) DESC, id"
    /// The columns queries filter or change by name.
    enum Columns {
        static let modifiedAt = Column("modifiedAt")
        static let savedAt = Column("savedAt")
        static let trashedAt = Column("trashedAt")
    }

    static let isDraft: SQLExpression = Columns.savedAt == nil
    static let hasUnsavedEdits: SQLExpression = isDraft || Columns.modifiedAt > Columns.savedAt
    static let isOutsideTheTrash: SQLExpression = Columns.trashedAt == nil
    static let isInTheTrash: SQLExpression = Columns.trashedAt != nil

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
