import NoteCore
import SwiftUI

/// A note on one line as every list draws it, with its drawer label under it: its title, or its first words when
/// untitled, after a ring for a draft labeled `DRAFT`, or alone for a saved note labeled `UNSORTED`.
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

    /// The note's title in roman ink, or its first words in italic in the second color when it has none, after an
    /// accent ring for a draft.
    private var mainLine: some View {
        HStack(spacing: Layout.ringGap) {
            if summary.kind == .draft {
                Circle()
                    .stroke(Palette.accent, lineWidth: Layout.ringStroke)
                    .frame(width: Layout.ring, height: Layout.ring)
            }
            if let title = summary.title {
                Text(title)
                    .font(Typeface.title)
                    .foregroundStyle(Palette.ink)
            } else {
                Text(summary.preview)
                    .font(Typeface.preview)
                    .foregroundStyle(Palette.second)
            }
        }
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
        title ?? preview
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
