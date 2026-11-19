import Foundation
import NoteCore
import SwiftUI

/// One note in the notes list: its date, its first words, and its label. Every row is the same height, so a long list
/// doesn't jump as it scrolls. Every note is a draft until notes can be saved.
struct NoteRow: View {
    let summary: NoteSummary
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: Layout.columnGap) {
            Text(ListDate.text(for: summary.modifiedAt, now: now, calendar: Self.calendar))
                .font(Typeface.date)
                .foregroundStyle(Palette.second)
                .frame(width: Layout.dateColumn, height: Layout.line, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Layout.ringGap) {
                    Circle()
                        .stroke(Palette.accent, lineWidth: Layout.ringStroke)
                        .frame(width: Layout.ring, height: Layout.ring)
                    Text(summary.preview)
                        .font(Typeface.preview)
                        .foregroundStyle(Palette.second)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: Layout.line)
                Text("DRAFT")
                    .font(Typeface.label)
                    .tracking(Layout.labelTracking)
                    .foregroundStyle(Palette.second)
                    .frame(height: Layout.labelLine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Layout.padding)
        .frame(height: Layout.height)
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
    static let line: CGFloat = 24
    static let labelLine: CGFloat = 15
    static let height = padding + line + labelLine + padding
    static let ring: CGFloat = 7
    static let ringStroke: CGFloat = 1.4
    static let ringGap: CGFloat = 8
    /// 10% of the label's 10.5 points.
    static let labelTracking: CGFloat = 1.05
}
