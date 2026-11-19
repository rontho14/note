import NoteCore
import SwiftUI
import UIKit

/// The note being written and nothing else: the editor fills the paper, and the keyboard comes up at launch, on the
/// recent draft or on a blank note, and whenever the screen is shown again. What is typed is saved `DraftSaving.delay`
/// after the last keystroke, and at once when the screen is left or the app goes to the background.
struct WriteScreen: View {
    private let isShown: Bool
    private let onKeyboardUp: () -> Void
    @Bindable private var model: WriteModel
    @FocusState private var isEditing: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// `isShown` is whether the screen is the one on screen. `onKeyboardUp` runs each time the keyboard finishes
    /// appearing.
    init(model: WriteModel, isShown: Bool, onKeyboardUp: @escaping () -> Void) {
        self.model = model
        self.isShown = isShown
        self.onKeyboardUp = onKeyboardUp
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
            .task {
                await stoppingTheAppOnFailure { try await model.loadRecentDraft(now: .now) }
                isEditing = isShown
            }
            .task(id: model.text) {
                do {
                    try await Task.sleep(for: DraftSaving.delay)
                } catch {
                    return  // A keystroke cancelled the wait and started a new one.
                }
                await stoppingTheAppOnFailure { try await model.saveDraft(now: .now) }
            }
            .onChange(of: isShown) { _, shown in
                isEditing = shown
                if !shown {
                    startDraftChange { try await model.saveDraft(now: .now) }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    startDraftChange { try await model.saveDraft(now: .now) }
                case .active:
                    startDraftChange { try await model.returnToForeground(now: .now) }
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                onKeyboardUp()
            }
    }
}

extension WriteScreen {
    /// Starts a change to the draft without waiting for it to finish. A change that fails stops the app.
    private func startDraftChange(_ change: @escaping () async throws -> Void) {
        Task { await stoppingTheAppOnFailure(change) }
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
