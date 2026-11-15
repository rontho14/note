import Foundation
import GRDB
import NoteCore

struct NoteRecord: Decodable, FetchableRecord, TableRecord {
    static let databaseTableName = "note"

    let id: UUID
    let text: String
    let createdAt: Date
    let modifiedAt: Date

    var note: Note {
        Note(id: NoteID(rawValue: id), text: text, createdAt: createdAt, modifiedAt: modifiedAt)
    }
}
