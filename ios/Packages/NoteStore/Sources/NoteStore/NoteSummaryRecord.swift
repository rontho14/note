import Foundation
import GRDB
import NoteCore

struct NoteSummaryRecord: Decodable, FetchableRecord {
    let id: UUID
    let textStart: String
    let modifiedAt: Date

    /// Every scalar with Unicode's White_Space property, the one `Character.isWhitespace` tests. The last is U+3000.
    private static let whitespace = String(
        String.UnicodeScalarView((0...0x3000).compactMap(Unicode.Scalar.init).filter(\.properties.isWhitespace)))

    /// The text start begins at the note's first character that isn't whitespace, so a note that opens with a long run
    /// of blank lines still reads its first words.
    static let newestFirst: SQLRequest<NoteSummaryRecord> = """
        SELECT id, substr(ltrim(text, \(whitespace)), 1, \(NoteSummary.textStartLength)) AS textStart, modifiedAt
        FROM note
        ORDER BY \(NoteRecord.newestFirstOrder)
        """

    var summary: NoteSummary {
        NoteSummary(id: NoteID(rawValue: id), textStart: textStart, modifiedAt: modifiedAt)
    }
}
