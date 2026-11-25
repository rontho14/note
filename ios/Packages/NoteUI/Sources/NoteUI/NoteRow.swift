import Foundation
import NoteCore
import SwiftUI

/// One note in the notes list: its date, then the note on one line with its drawer label. Every row is the same
/// height, so a long list doesn't jump as it scrolls.
struct NoteRow: View {
    let summary: NoteSummary
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: Layout.columnGap) {
            Text(ListDate.text(for: summary.modifiedAt, now: now, calendar: Self.calendar))
                .font(Typeface.date)
                .foregroundStyle(Palette.second)
                .frame(width: Layout.dateColumn, height: NoteLine.lineHeight, alignment: .leading)
            NoteLine(summary: summary)
        }
        .padding(.vertical, Layout.padding)
        .frame(height: Layout.padding + NoteLine.height + Layout.padding)
    }

    /// Days and years as the iPhone counts them where it is, with the Gregorian calendar the month names belong to.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}

/// DESIGN.md's Notes numbers.
private enum Layout {
    static let dateColumn: CGFloat = 54
    static let columnGap: CGFloat = 12
    static let padding: CGFloat = 13
}
