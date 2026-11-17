public import SwiftUI
import UIKit

/// The note being written and nothing else: the editor fills the paper, and the keyboard comes up at launch.
public struct WriteScreen: View {
    private let onKeyboardUp: () -> Void
    @State private var text = ""
    @FocusState private var isEditing: Bool

    /// `onKeyboardUp` runs each time the keyboard finishes appearing.
    public init(onKeyboardUp: @escaping () -> Void) {
        self.onKeyboardUp = onKeyboardUp
    }

    public var body: some View {
        ZStack {
            Palette.paper
                .ignoresSafeArea()
            TextEditor(text: $text)
                .font(Typeface.write)
                .lineSpacing(Typeface.writeLineSpacing)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accent)
                .scrollContentBackground(.hidden)
                .focused($isEditing)
                .accessibilityIdentifier(AccessibilityID.writeText)
                .padding(.horizontal, Layout.textSide - Layout.editorSideInset)
                .padding(.top, Layout.firstLineTop - Layout.editorTopInset)
                .ignoresSafeArea(.container, edges: .top)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.write)
        .onAppear { isEditing = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            onKeyboardUp()
        }
    }
}

#Preview {
    WriteScreen(onKeyboardUp: {})
}

/// DESIGN.md's Write numbers, and the insets `TextEditor` adds inside its frame, measured from the `write` screenshot.
private enum Layout {
    /// From the screen's edge to the text.
    static let textSide: CGFloat = 30
    /// From the screen's top to the first line.
    static let firstLineTop: CGFloat = 76
    /// UIKit's `lineFragmentPadding`.
    static let editorSideInset: CGFloat = 5
    /// UIKit's top `textContainerInset`.
    static let editorTopInset: CGFloat = 8
}
