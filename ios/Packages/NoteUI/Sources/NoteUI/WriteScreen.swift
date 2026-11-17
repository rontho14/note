public import NoteCore
public import SwiftUI
import UIKit

/// The note being written and nothing else: the editor fills the paper, and the keyboard comes up at launch, on the
/// recent draft or on a blank note. What is typed is saved `saveDelay` after the last keystroke, and at once when the
/// app goes to the background.
public struct WriteScreen: View {
    /// How long typing must pause before the draft is saved.
    nonisolated public static let saveDelay: Duration = .seconds(2)

    private let onKeyboardUp: () -> Void
    @State private var model: WriteModel
    @FocusState private var isEditing: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// `onKeyboardUp` runs each time the keyboard finishes appearing.
    public init(storage: any NoteStorage, onKeyboardUp: @escaping () -> Void) {
        _model = State(initialValue: WriteModel(storage: storage))
        self.onKeyboardUp = onKeyboardUp
    }

    public var body: some View {
        ZStack {
            Palette.paper
                .ignoresSafeArea()
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.write)
        .task {
            await stoppingTheAppOnFailure { try await model.loadRecentDraft(now: .now) }
            isEditing = true
        }
        .task(id: model.text) {
            do {
                try await Task.sleep(for: Self.saveDelay)
            } catch {
                return  // A keystroke cancelled the wait and started a new one.
            }
            await stoppingTheAppOnFailure { try await model.saveDraft(now: .now) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                Task { await stoppingTheAppOnFailure { try await model.saveDraft(now: .now) } }
            case .active:
                Task { await stoppingTheAppOnFailure { try await model.returnToForeground(now: .now) } }
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
    /// Runs a change to the draft, and stops the app if it fails. A store that fails is a lost draft with no screen to
    /// say so, so the app stops, as it does for a database that won't open. The typing since the last successful save
    /// is lost.
    private func stoppingTheAppOnFailure(_ change: () async throws -> Void) async {
        do {
            try await change()
        } catch {
            fatalError("The draft couldn't be loaded or stored: \(error)")
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
