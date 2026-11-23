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
    /// Stored beside the text, never in it, and as typed.
    public var title: String?
    /// When the note was last saved, or nil for a draft, a note never saved.
    public var savedAt: Date?
    public var trashedAt: Date?

    public init(
        id: NoteID, text: String, cursor: Int, createdAt: Date, modifiedAt: Date, title: String? = nil,
        savedAt: Date? = nil, trashedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.cursor = cursor
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.title = title
        self.savedAt = savedAt
        self.trashedAt = trashedAt
    }

    /// Whether `text` holds nothing but whitespace, which no note is stored with and no title is kept as.
    public static func isEmpty(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }

    public var isEmpty: Bool {
        Note.isEmpty(text)
    }

    public var isDraft: Bool {
        savedAt == nil
    }

    /// A draft, or a saved note whose text changed after its last save: what write reopens.
    public var hasUnsavedEdits: Bool {
        savedAt.map { modifiedAt > $0 } ?? true
    }

    /// The note saved at `now`, keeping its title. Saving is not an edit: text, caret and `modifiedAt` stay as they are.
    public func saved(now: Date) -> Note {
        var note = self
        note.savedAt = now
        return note
    }

    /// The note saved at `now` with `title`, kept as typed, or with no title when `title` is only whitespace.
    public func saved(title: String, now: Date) -> Note {
        var note = saved(now: now)
        note.title = Note.isEmpty(title) ? nil : title
        return note
    }

    /// The note with `text` and the caret at `caret`. Text that changed moves `modifiedAt` to `now`.
    func edited(text: String, caret: String.Index, now: Date) -> Note {
        var note = self
        note.text = text
        note.cursorIndex = caret
        if !note.hasSameText(as: self) {
            note.modifiedAt = now
        }
        return note
    }

    /// Whether the two texts are the same byte for byte, so a change of normalization counts as an edit.
    func hasSameText(as other: Note) -> Bool {
        text.utf8.elementsEqual(other.text.utf8)
    }

    public func trashed(now: Date) -> Note {
        var note = self
        note.trashedAt = now
        return note
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
