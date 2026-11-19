public import Foundation

/// A note as the notes list shows it: one line of preview and when it was last modified.
public struct NoteSummary: Sendable, Equatable, Identifiable {
    /// How many Unicode scalars from the start of a note are enough for its preview. One line never shows more. The cut
    /// may split a character made of several scalars, such as an emoji sequence, past anything one line shows.
    public static let textStartLength = 200

    public let id: NoteID
    /// The note's first words on one line: leading whitespace dropped, and each run of line breaks shown as one space.
    /// Only drawn, never stored.
    public let preview: String
    public let modifiedAt: Date

    /// `textStart` is the start of the note's text, up to `textStartLength` Unicode scalars.
    public init(id: NoteID, textStart: String, modifiedAt: Date) {
        self.id = id
        self.preview = textStart.drop(while: \.isWhitespace).split(whereSeparator: \.isNewline).joined(separator: " ")
        self.modifiedAt = modifiedAt
    }
}
