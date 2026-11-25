import NoteCore
import SwiftUI

/// The sheet the trash button opens: every note in the trash, the most recently trashed first, each with the days it
/// has left and Restore, or a line saying the trash is empty.
struct TrashSheet: View {
    let model: DrawersModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trash")
                    .font(Typeface.title)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Layout.gap)
                Text("kept for \(TrashExpiry.keptForDays) days")
                    .font(Typeface.preview)
                    .foregroundStyle(Palette.second)
            }
            .padding(.bottom, Layout.headerBottom)
            TimelineView(.everyMinuteFromNow) { context in
                if case .read(let trash) = model.trash(listedAt: context.date) {
                    notes(trash, now: context.date)
                }
            }
        }
        .padding(.horizontal, ListLayout.side)
        .padding(.top, Layout.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.trash)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Layout.corner)
    }

    @ViewBuilder private func notes(_ trash: [TrashedNoteSummary], now: Date) -> some View {
        if trash.isEmpty {
            Text("Nothing in the trash.")
                .font(Typeface.preview)
                .foregroundStyle(Palette.second)
                .accessibilityIdentifier(AccessibilityID.trashEmpty)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(trash) { note in
                        row(note, now: now)
                        Palette.hairline.frame(height: 1)
                    }
                }
            }
        }
    }

    private func row(_ note: TrashedNoteSummary, now: Date) -> some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            NoteLine(summary: note.summary)
            VStack(alignment: .trailing, spacing: 0) {
                Text(daysLeft(note, now: now))
                    .font(Typeface.date)
                    .foregroundStyle(Palette.second)
                    .frame(height: NoteLine.lineHeight)
                Button {
                    startNotesChange { try await model.restore(note) }
                } label: {
                    Text("Restore")
                        .font(Typeface.preview)
                        .foregroundStyle(Palette.accentText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restore \(note.summary.titleOrPreview)")
                .accessibilityIdentifier(AccessibilityID.trashRestore(note.id))
            }
        }
        .padding(.vertical, Layout.rowPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.trashRow(note.id))
    }

    private func daysLeft(_ note: TrashedNoteSummary, now: Date) -> String {
        let days = TrashExpiry.daysLeft(trashedAt: note.trashedAt, now: now)
        return days == 1 ? "1 day" : "\(days) days"
    }
}

/// DESIGN.md's Trash and Sheet numbers.
private enum Layout {
    static let top: CGFloat = 26
    static let corner: CGFloat = 8
    static let gap: CGFloat = 12
    static let headerBottom: CGFloat = 12
    static let rowPadding: CGFloat = 13
}
