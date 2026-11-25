import SwiftUI

/// The dark pill a delete from the list shows: `In the trash`, and an underlined `Undo`. VoiceOver announces it as it
/// appears, and `onFocusChange` reports VoiceOver's focus coming to it and leaving, so it can stay while it is read.
struct UndoPill: View {
    let onUndo: () -> Void
    let onFocusChange: (Bool) -> Void
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text("In the trash")
            Spacer(minLength: Layout.gap)
            Button(action: onUndo) {
                Text("Undo").underline()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.notesUndo)
        }
        .font(Typeface.message)
        .foregroundStyle(Palette.surface)
        .padding(.horizontal, Layout.side)
        .frame(height: Layout.height)
        .background(Capsule().fill(Palette.ink))
        .padding(.horizontal, ListLayout.side)
        .padding(.bottom, Layout.bottom)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($isFocused)
        .onChange(of: isFocused) { _, focused in onFocusChange(focused) }
        .onAppear { AccessibilityNotification.Announcement("In the trash").post() }
    }
}

/// DESIGN.md's message pill numbers.
private enum Layout {
    static let height: CGFloat = 52
    static let side: CGFloat = 22
    static let gap: CGFloat = 12
    /// From the bottom of the screen, until the footer it will sit above exists.
    static let bottom: CGFloat = 16
}
