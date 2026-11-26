import NoteCore
import SwiftUI

/// A sheet over DESIGN.md's scrim with a title field, focused as it rises, and a row with Save taking the width Delete
/// leaves on the save sheet. Return in the field saves, like Save. It sits on the keyboard, and a tap on the scrim or a drag
/// down past half its height dismisses it. The save sheet and the rename sheet are both one, drawn above the strip
/// rather than presented or placed inside a page, so focusing the field never scrolls the strip.
struct TitleSheet: View {
    /// Which sheet it is: the save sheet, with Delete, or the rename sheet.
    enum Purpose {
        case save(onDelete: () -> Void)
        case rename
    }

    let purpose: Purpose
    let onSave: (String) -> Void
    let onDismiss: () -> Void
    @State private var title: String
    @State private var dragDown: CGFloat = 0
    @FocusState private var isTitleFocused: Bool

    /// `title` is the field's text as the sheet rises.
    init(title: String, purpose: Purpose, onSave: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        _title = State(initialValue: title)
        self.purpose = purpose
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(purpose.identifiers.scrim)
            sheet
        }
    }

    private var sheet: some View {
        VStack(spacing: Layout.rowTop) {
            titleField
            HStack(spacing: Layout.buttonGap) {
                if case .save(let onDelete) = purpose {
                    DeleteButton(action: onDelete)
                }
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
        .accessibilityIdentifier(purpose.identifiers.sheet)
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
        .accessibilityIdentifier(purpose.identifiers.title)
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
        .accessibilityIdentifier(purpose.identifiers.confirm)
    }
}

extension TitleSheet.Purpose {
    /// The identifiers of the sheet's outermost view, its field, its Save and its scrim.
    fileprivate var identifiers: SheetID {
        switch self {
        case .save: AccessibilityID.save
        case .rename: AccessibilityID.rename
        }
    }
}

/// The save sheet's delete: a circle around the trash icon, beside Save.
private struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
}

/// DESIGN.md's Save sheet and Sheet numbers.
private enum Layout {
    static let side: CGFloat = 26
    static let bottom: CGFloat = 34
    static let corner: CGFloat = 8
    static let fieldHeight: CGFloat = 54
    /// From the title field to the row under it.
    static let rowTop: CGFloat = 6
    static let buttonGap: CGFloat = 10
    /// The height of Save and of Delete, which is a circle.
    static let button: CGFloat = 52
    static let icon: CGFloat = 24
    static let height = side + fieldHeight + rowTop + button + bottom
}

/// A title sheet as a model hands it to the strip: down, or up with the text its field starts from.
enum TitleSheetState: Equatable {
    case down
    case up(title: String)
}

extension Note {
    /// The text a title sheet's field starts from for the note: its title as stored, or nothing when it has none.
    var titleInTheField: String {
        title ?? ""
    }
}
