import Foundation
import GRDB
import NoteCore

struct NoteRecord: Decodable, FetchableRecord, TableRecord {
    static let databaseTableName = "note"
    /// Newest first, and in id order when two notes were modified at once, so every query agrees on which is newest.
    static let newestFirstOrder: SQL = "modifiedAt DESC, id"

    let id: UUID
    let text: String
    let cursor: Int
    let createdAt: Date
    let modifiedAt: Date

    var note: Note {
        Note(id: NoteID(rawValue: id), text: text, cursor: cursor, createdAt: createdAt, modifiedAt: modifiedAt)
    }
}
