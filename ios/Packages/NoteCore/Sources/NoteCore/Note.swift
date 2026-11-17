public import Foundation

public struct NoteID: Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

public struct Note: Sendable {
    public let id: NoteID
    public var text: String
    /// The caret as a UTF-8 offset into `text`, which points at the same place on reopen because the text is stored byte for byte.
    public var cursor: Int
    public let createdAt: Date
    public var modifiedAt: Date

    public init(id: NoteID, text: String, cursor: Int, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.text = text
        self.cursor = cursor
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public var isEmpty: Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// `cursor` as a position in `text`. Setting it stores the position's UTF-8 offset. Reading it accepts any offset, so
    /// `text` and `cursor` can change apart: one outside the text becomes its nearer end, and one inside a character moves
    /// back to that character's start.
    public var cursorIndex: String.Index {
        get {
            var index = text.utf8.index(text.startIndex, offsetBy: min(max(cursor, 0), text.utf8.count))
            while String.Index(index, within: text) == nil {
                index = text.utf8.index(before: index)
            }
            return index
        }
        set {
            cursor = text.utf8.distance(from: text.startIndex, to: newValue)
        }
    }
}
