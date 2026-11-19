public import NoteCore
public import SwiftUI

/// The screens side by side, drawers, notes and write, moved one at a time by a swipe. The app opens on write.
public struct ScreenStrip: View {
    enum Position: Hashable {
        case drawers, notes, write
    }

    private let onKeyboardUp: () -> Void
    @State private var writeModel: WriteModel
    @State private var notesModel: NotesModel
    @State private var position: Position? = .write

    /// `onKeyboardUp` runs each time the write screen's keyboard finishes appearing.
    public init(storage: any NoteStorage, onKeyboardUp: @escaping () -> Void) {
        _writeModel = State(initialValue: WriteModel(storage: storage))
        _notesModel = State(initialValue: NotesModel(storage: storage))
        self.onKeyboardUp = onKeyboardUp
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                DrawersScreen()
                    .containerRelativeFrame(.horizontal)
                    .id(Position.drawers)
                NotesScreen(model: notesModel, onOpen: open)
                    .containerRelativeFrame(.horizontal)
                    .id(Position.notes)
                WriteScreen(model: writeModel, isShown: position == .write, onKeyboardUp: onKeyboardUp)
                    .containerRelativeFrame(.horizontal)
                    .id(Position.write)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $position)
        .defaultScrollAnchor(.trailing)
        .background(Palette.paper)
    }

    /// Shows the note `id` on write, and moves there.
    private func open(_ id: NoteID) {
        Task {
            await stoppingTheAppOnFailure { try await writeModel.open(id: id) }
            withAnimation { position = .write }
        }
    }
}
