import Foundation
import NoteCore

extension Note {
    /// A note with only the fields a test names set. NoteCoreTests and NoteStoreTests each hold this same builder, so a
    /// new field changes both copies.
    static func sample(
        _ text: String, id: NoteID = NoteID(rawValue: UUID()), cursor: Int = 0,
        createdAt: Date = Date(timeIntervalSince1970: 0.001), modifiedAt: Date = Date(timeIntervalSince1970: 0.001)
    ) -> Note {
        Note(id: id, text: text, cursor: cursor, createdAt: createdAt, modifiedAt: modifiedAt)
    }
}
