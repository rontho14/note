import Foundation
import GRDB
import NoteCore

struct NoteSummaryRecord: Decodable, FetchableRecord {
    let id: UUID
    let textStart: String
    let modifiedAt: Date
    let title: String?
    let isDraft: Bool

    /// Every Unicode scalar with the White_Space property: what the text start skips at the beginning of a note.
    private static let whitespace = String(
        String.UnicodeScalarView((0...0x10FFFF).compactMap(Unicode.Scalar.init).filter(\.properties.isWhitespace)))

    /// The columns a summary reads. The text start begins at the note's first character that isn't whitespace, so a
    /// note that opens with a long run of blank lines still reads its first words.
    static let columns: SQL = """
        id, substr(ltrim(text, \(whitespace)), 1, \(NoteSummary.textStartLength)) AS textStart, modifiedAt, title,
            \(NoteRecord.isDraft) AS isDraft
        """

    static let newestFirst: SQLRequest<NoteSummaryRecord> = """
        SELECT \(columns)
        FROM note
        WHERE \(NoteRecord.isOutsideTheTrash)
        ORDER BY \(NoteRecord.newestFirstOrder)
        """

    var summary: NoteSummary {
        NoteSummary(
            id: NoteID(rawValue: id), textStart: textStart, modifiedAt: modifiedAt,
            kind: isDraft ? .draft : .saved(title: title))
    }
}

/// A note in the trash: its summary, and when it went there.
struct TrashedNoteSummaryRecord: FetchableRecord {
    let summary: TrashedNoteSummary

    static let mostRecentlyTrashedFirst: SQLRequest<TrashedNoteSummaryRecord> = """
        SELECT \(NoteSummaryRecord.columns), \(NoteRecord.Columns.trashedAt)
        FROM note
        WHERE \(NoteRecord.isInTheTrash)
        ORDER BY \(NoteRecord.mostRecentlyTrashedFirstOrder)
        """

    init(row: Row) throws {
        summary = TrashedNoteSummary(
            summary: try NoteSummaryRecord(row: row).summary, trashedAt: row[NoteRecord.Columns.trashedAt])
    }
}
