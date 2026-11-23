import SwiftUI

/// The sheet a note's first save shows over the dimmed note: a title field, focused as it rises, then delete and save.
/// Return in the field saves, like the save button. It sits on the keyboard, and a drag down past half its height
/// dismisses it.
struct SaveSheet: View {
    let onSave: (String) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    @State private var title = ""
    @State private var dragDown: CGFloat = 0
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: Layout.rowTop) {
            titleField
            HStack(spacing: Layout.buttonGap) {
                deleteButton
                saveButton
            }
        }
        .padding(.horizontal, Layout.side)
        .padding(.top, Layout.side)
        .padding(.bottom, Layout.bottom)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: Layout.corner, topTrailingRadius: Layout.corner)
                .fill(Palette.surface)
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .offset(y: dragDown)
        .gesture(dragToDismiss)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.save)
        .accessibilityAction(.escape, onDismiss)
        .onAppear { isTitleFocused = true }
    }

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { drag in dragDown = max(drag.translation.height, 0) }
            .onEnded { drag in
                if drag.predictedEndTranslation.height > Layout.height / 2 {
                    onDismiss()
                } else {
                    withAnimation { dragDown = 0 }
                }
            }
    }

    private var titleField: some View {
        TextField(
            "", text: $title, prompt: Text("Title").font(Typeface.titlePlaceholder).foregroundStyle(Palette.second)
        )
        .font(Typeface.titleField)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .submitLabel(.done)
        .onSubmit { onSave(title) }
        .focused($isTitleFocused)
        .frame(height: Layout.fieldHeight)
        .overlay(alignment: .bottom) { Palette.hairline.frame(height: 1) }
        .accessibilityIdentifier(AccessibilityID.saveTitle)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            TrashIcon()
                .stroke(Palette.second, style: TrashIcon.style)
                .frame(width: Layout.icon, height: Layout.icon)
                .frame(width: Layout.button, height: Layout.button)
                .overlay { Circle().stroke(Palette.second, lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
        .accessibilityIdentifier(AccessibilityID.saveDelete)
    }

    private var saveButton: some View {
        Button {
            onSave(title)
        } label: {
            Text("Save")
                .font(Typeface.saveButton)
                .foregroundStyle(Palette.surface)
                .frame(maxWidth: .infinity, minHeight: Layout.button)
                .background(Capsule().fill(Palette.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.saveConfirm)
    }
}

/// DESIGN.md's Save sheet and Sheet numbers.
private enum Layout {
    static let side: CGFloat = 26
    static let bottom: CGFloat = 34
    static let corner: CGFloat = 8
    static let fieldHeight: CGFloat = 54
    /// From the title field to the row under it.
    static let rowTop: CGFloat = 6
    static let button: CGFloat = 52
    static let buttonGap: CGFloat = 10
    static let icon: CGFloat = 24
    static let height = side + fieldHeight + rowTop + button + bottom
}
