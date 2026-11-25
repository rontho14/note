public import Foundation

/// A note as the notes list shows it: whether it is a draft or saved, its title, one line of preview, and when it was
/// last modified.
public struct NoteSummary: Sendable, Equatable, Identifiable {
    /// A draft, never saved, or a saved note.
    public enum Kind: Sendable, Equatable {
        case draft
        case saved
    }

    /// How many Unicode scalars from the start of a note are enough for its preview. One line never shows more. The cut
    /// may split a character made of several scalars, such as an emoji sequence, past anything one line shows.
    public static let textStartLength = 200

    public let id: NoteID
    /// The note's first words on one line, with each run of line breaks shown as one space. Only drawn, never stored.
    public let preview: String
    /// The note's title on one line, drawn the same way as the preview, while the note keeps it as typed. A draft has
    /// one once it is renamed.
    public let title: String?
    public let modifiedAt: Date
    public let kind: Kind

    /// `textStart` is the note's text from its first scalar that isn't whitespace, up to `textStartLength` Unicode
    /// scalars.
    public init(id: NoteID, textStart: String, title: String?, modifiedAt: Date, kind: Kind) {
        self.id = id
        self.preview = Self.oneLine(textStart)
        self.title = title.map(Self.oneLine)
        self.modifiedAt = modifiedAt
        self.kind = kind
    }

    /// `text` with each run of line breaks shown as one space.
    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}
