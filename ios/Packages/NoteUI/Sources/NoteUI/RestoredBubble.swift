import NoteCore
import SwiftUI

/// The small dark bubble above the trash button, pointing down at it, that says where a restored note went.
struct RestoredBubble: View {
    let kind: NoteSummary.Kind

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(words)
                .font(Typeface.message)
                .foregroundStyle(Palette.surface)
                .padding(.horizontal, Layout.side)
                .padding(.vertical, Layout.top)
                .background(RoundedRectangle(cornerRadius: Layout.corner).fill(Palette.ink))
            DownPointer()
                .fill(Palette.ink)
                .frame(width: Layout.pointer, height: Layout.pointer / 2)
                .padding(.trailing, Layout.pointerInset)
        }
        .transition(.opacity)
    }

    /// Every saved note is in `Unsorted` until drawers exist, and a draft has no drawer.
    private var words: String {
        switch kind {
        case .draft: "Back as a draft"
        case .saved: "Back in Unsorted"
        }
    }
}

/// A triangle pointing down, its base along the top.
private struct DownPointer: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// DESIGN.md's message bubble numbers.
private enum Layout {
    static let side: CGFloat = 14
    static let top: CGFloat = 8
    static let corner: CGFloat = 8
    static let pointer: CGFloat = 12
    /// Puts the pointer over the middle of the 52 point trash button.
    static let pointerInset: CGFloat = 20
}
