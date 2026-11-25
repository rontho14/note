public import NoteCore
public import SwiftUI

/// The screens side by side, drawers, notes and write, moved one at a time by a swipe. The app opens on write.
public struct ScreenStrip: View {
    /// The screens in the strip's order. Write is the last, which `StripPaging` holds.
    enum Position: Hashable {
        case drawers, notes, write
    }

    private let onKeyboardUp: () -> Void
    @State private var writeModel: WriteModel
    @State private var notesModel: NotesModel
    @State private var drawersModel: DrawersModel
    @State private var position: Position? = .write
    /// The screen the strip rests on. `position` follows the scroll as it moves, so a drag from write that springs
    /// back passes through notes; this changes only once the strip stops.
    @State private var restingPosition: Position = .write

    /// `onKeyboardUp` runs each time the write screen's keyboard finishes appearing.
    public init(storage: any NoteStorage, onKeyboardUp: @escaping () -> Void) {
        let changes = NoteChanges()
        _writeModel = State(initialValue: WriteModel(storage: storage, changes: changes))
        _notesModel = State(initialValue: NotesModel(storage: storage, changes: changes))
        _drawersModel = State(initialValue: DrawersModel(storage: storage))
        self.onKeyboardUp = onKeyboardUp
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                DrawersScreen(model: drawersModel)
                    .containerRelativeFrame(.horizontal)
                    .id(Position.drawers)
                NotesScreen(model: notesModel, isShown: restingPosition == .notes, onOpen: open)
                    .containerRelativeFrame(.horizontal)
                    .id(Position.notes)
                WriteScreen(
                    model: writeModel, isShown: restingPosition == .write, onKeyboardUp: onKeyboardUp,
                    onSwipeTowardNotes: swipeTowardNotes, onLeftOnSaved: notesModel.showSaved
                )
                .containerRelativeFrame(.horizontal)
                .id(Position.write)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(
            StripPaging(
                holdsLastPage: writeModel.holdsLeaving,
                onHeldSwipe: swipeTowardNotes)
        )
        .scrollIndicators(.hidden)
        .scrollPosition(id: $position)
        .onScrollPhaseChange { _, phase in
            if phase == .idle, let position {
                restingPosition = position
            }
        }
        .defaultScrollAnchor(.trailing)
        .background(Palette.paper)
        .overlay { saveSheet }
    }

    /// The save sheet over DESIGN.md's scrim, drawn above the strip rather than presented or placed inside it, so
    /// focusing its title field never scrolls the strip and no presentation hands focus back to the editor. A tap on
    /// the scrim or a drag down dismisses it.
    @ViewBuilder private var saveSheet: some View {
        if writeModel.isAskingToSave {
            ZStack(alignment: .bottom) {
                Palette.scrim
                    .ignoresSafeArea()
                    .onTapGesture { writeModel.dismissSaveSheet() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(AccessibilityID.saveScrim)
                SaveSheet(
                    onSave: { title in answerAndLeave(.save(title: title)) },
                    onDelete: { answerAndLeave(.delete) },
                    onDismiss: writeModel.dismissSaveSheet)
            }
        }
    }

    /// Lowers the sheet with `answer` and leaves write for notes in the same step, so the editor never takes focus on
    /// the way out. Leaving write carries the answer out.
    private func answerAndLeave(_ answer: SaveSheetAnswer) {
        writeModel.answerSaveSheet(answer)
        showNotes()
    }

    /// Leaves write for notes, or raises the save sheet first while write holds text never saved. Both a held drag and
    /// VoiceOver's scroll come here.
    private func swipeTowardNotes() {
        if writeModel.holdsLeaving {
            startNotesChange { try await writeModel.askToSave(now: .now) }
        } else {
            showNotes()
        }
    }

    /// Moves to notes, and counts write as left at once, so the editor doesn't take the keyboard back on the way out.
    private func showNotes() {
        restingPosition = .notes
        withAnimation { position = .notes }
    }

    /// Shows the note `id` on write, and moves there.
    private func open(_ id: NoteID) {
        startNotesChange {
            try await writeModel.open(id: id)
            withAnimation { position = .write }
        }
    }
}
