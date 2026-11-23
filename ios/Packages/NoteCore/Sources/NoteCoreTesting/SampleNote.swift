public import Foundation
public import NoteCore

extension Note {
    /// A note for tests, with only the fields a test names set.
    public static func sample(
        _ text: String, id: NoteID = NoteID(rawValue: UUID()), cursor: Int = 0,
        createdAt: Date = Date(timeIntervalSince1970: 0.001), modifiedAt: Date = Date(timeIntervalSince1970: 0.001),
        title: String? = nil, savedAt: Date? = nil, trashedAt: Date? = nil
    ) -> Note {
        Note(
            id: id, text: text, cursor: cursor, createdAt: createdAt, modifiedAt: modifiedAt, title: title,
            savedAt: savedAt, trashedAt: trashedAt)
    }
}
