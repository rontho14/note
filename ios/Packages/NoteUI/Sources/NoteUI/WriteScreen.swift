import NoteCore
import SwiftUI
import UIKit

/// The note being written and nothing else: the editor fills the paper, and the keyboard comes up at launch, on the
/// recent unsaved note or on a blank note, and whenever the screen is shown again. What is typed is stored
/// `Autosave.delay` after the last keystroke, and when the app goes to the background. Leaving the screen saves a saved
/// note straight.
struct WriteScreen: View {
    private let place: StripPlace
    private let onKeyboardUp: () -> Void
    private let onSwipeTowardNotes: () -> Void
    private let onLeftOnSaved: (NoteID) -> Void
    @Bindable private var model: WriteModel
    @FocusState private var isEditing: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// `place` is whether the strip rests on the screen. `onKeyboardUp` runs each time the keyboard finishes
    /// appearing. `onSwipeTowardNotes` runs for VoiceOver's scroll toward notes, which the strip's paging never sees.
    /// `onLeftOnSaved` gets the saved note write was left on, for the list to show.
    init(
        model: WriteModel, place: StripPlace, onKeyboardUp: @escaping () -> Void,
        onSwipeTowardNotes: @escaping () -> Void, onLeftOnSaved: @escaping (NoteID) -> Void
    ) {
        self.model = model
        self.place = place
        self.onKeyboardUp = onKeyboardUp
        self.onSwipeTowardNotes = onSwipeTowardNotes
        self.onLeftOnSaved = onLeftOnSaved
    }

    var body: some View {
        TextEditor(text: $model.text, selection: $model.selection)
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.write)
            .accessibilityScrollAction { edge in
                if edge == .leading {
                    onSwipeTowardNotes()
                }
            }
            .task {
                await stoppingTheAppOnFailure { try await model.loadRecentUnsavedNote(now: .now) }
                isEditing = place == .resting
            }
            .task(id: model.text) {
                do {
                    try await Task.sleep(for: Autosave.delay)
                } catch {
                    return  // A keystroke cancelled the wait and started a new one.
                }
                await stoppingTheAppOnFailure { try await model.storeText(now: .now) }
            }
            .onChange(of: model.saveSheet) { _, sheet in
                isEditing = sheet == .down && place == .resting
            }
            .onChange(of: place) { _, place in
                isEditing = place == .resting
                if place == .away {
                    startNotesChange {
                        if case .savedNote(let saved) = try await model.leave(now: .now) {
                            onLeftOnSaved(saved)
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    startNotesChange { try await model.storeText(now: .now) }
                case .active:
                    startNotesChange { try await model.returnToForeground(now: .now) }
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                onKeyboardUp()
            }
    }
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
