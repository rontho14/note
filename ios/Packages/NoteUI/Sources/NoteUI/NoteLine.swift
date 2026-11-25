import NoteCore
import SwiftUI

/// A note on one line as every list draws it, with its drawer label under it: a draft's ring and first words labeled
/// `DRAFT`, or a saved note's title, or its first words when untitled, labeled `UNSORTED`.
struct NoteLine: View {
    let summary: NoteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainLine
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: Layout.line)
            Text(label)
                .font(Typeface.label)
                .tracking(Layout.labelTracking)
                .foregroundStyle(Palette.second)
                .frame(height: Layout.labelLine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The height of the note's main line, which a row's other columns align with.
    static let lineHeight = Layout.line
    /// The note's height, its main line and label.
    static let height = Layout.line + Layout.labelLine

    /// A draft's accent ring and first words, a saved note's title in roman ink, or an untitled one's first words, both
    /// in italic in the second color.
    @ViewBuilder private var mainLine: some View {
        switch summary.kind {
        case .draft:
            HStack(spacing: Layout.ringGap) {
                Circle()
                    .stroke(Palette.accent, lineWidth: Layout.ringStroke)
                    .frame(width: Layout.ring, height: Layout.ring)
                preview
            }
        case .saved(let title?):
            Text(title)
                .font(Typeface.title)
                .foregroundStyle(Palette.ink)
        case .saved(nil):
            preview
        }
    }

    private var preview: some View {
        Text(summary.preview)
            .font(Typeface.preview)
            .foregroundStyle(Palette.second)
    }

    private var label: String {
        switch summary.kind {
        case .draft: "DRAFT"
        case .saved: "UNSORTED"
        }
    }
}

extension NoteSummary {
    /// What a note's main line reads, as `NoteLine` draws it: its title, or its first words when it has none.
    var titleOrPreview: String {
        switch kind {
        case .saved(let title?): title
        case .draft, .saved(nil): preview
        }
    }
}

/// DESIGN.md's Notes numbers for a note's line and label.
private enum Layout {
    static let line: CGFloat = 24
    static let labelLine: CGFloat = 15
    static let ring: CGFloat = 7
    static let ringStroke: CGFloat = 1.4
    static let ringGap: CGFloat = 8
    /// 10% of the label's 10.5 points.
    static let labelTracking: CGFloat = 1.05
}
