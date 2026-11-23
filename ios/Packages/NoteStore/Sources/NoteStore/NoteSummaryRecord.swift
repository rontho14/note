import Foundation
import GRDB
import NoteCore

struct NoteSummaryRecord: Decodable, FetchableRecord {
    let id: UUID
    let textStart: String
    let modifiedAt: Date

    /// Every Unicode scalar with the White_Space property: what the text start skips at the beginning of a note.
    private static let whitespace = String(
        String.UnicodeScalarView((0...0x10FFFF).compactMap(Unicode.Scalar.init).filter(\.properties.isWhitespace)))

    /// The text start begins at the note's first character that isn't whitespace, so a note that opens with a long run
    /// of blank lines still reads its first words.
    static let newestFirst: SQLRequest<NoteSummaryRecord> = """
        SELECT id, substr(ltrim(text, \(whitespace)), 1, \(NoteSummary.textStartLength)) AS textStart, modifiedAt
        FROM note
        WHERE \(NoteRecord.isOutsideTheTrash)
        ORDER BY \(NoteRecord.newestFirstOrder)
        """

    var summary: NoteSummary {
        NoteSummary(id: NoteID(rawValue: id), textStart: textStart, modifiedAt: modifiedAt)
    }
}
