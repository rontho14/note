public import Foundation

/// A note as the notes list shows it: whether it is a draft or saved with its title, one line of preview, and when it
/// was last modified.
public struct NoteSummary: Sendable, Equatable, Identifiable {
    /// A draft, never saved and so never titled, or a saved note, titled or not.
    public enum Kind: Sendable, Equatable {
        case draft
        case saved(title: String?)
    }

    /// How many Unicode scalars from the start of a note are enough for its preview. One line never shows more. The cut
    /// may split a character made of several scalars, such as an emoji sequence, past anything one line shows.
    public static let textStartLength = 200

    public let id: NoteID
    /// The note's first words on one line, with each run of line breaks shown as one space. Only drawn, never stored.
    /// A saved note's title in `kind` is drawn on one line the same way, while the note keeps it as typed.
    public let preview: String
    public let modifiedAt: Date
    public let kind: Kind

    /// `textStart` is the note's text from its first scalar that isn't whitespace, up to `textStartLength` Unicode
    /// scalars.
    public init(id: NoteID, textStart: String, modifiedAt: Date, kind: Kind) {
        self.id = id
        self.preview = Self.oneLine(textStart)
        self.modifiedAt = modifiedAt
        self.kind = if case .saved(let title?) = kind { .saved(title: Self.oneLine(title)) } else { kind }
    }

    /// `text` with each run of line breaks shown as one space.
    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}
