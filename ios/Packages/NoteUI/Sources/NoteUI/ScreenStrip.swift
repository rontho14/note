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
        _drawersModel = State(initialValue: DrawersModel(storage: storage, changes: changes))
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
        .overlay { renameSheet }
    }

    /// The save sheet over the draft on write: its title field, then delete and save.
    @ViewBuilder private var saveSheet: some View {
        if writeModel.isAskingToSave {
            TitleSheet(
                title: writeModel.titleToOffer, purpose: .save(onDelete: { answerAndLeave(.delete) }),
                onSave: { title in answerAndLeave(.save(title: title)) },
                onDismiss: writeModel.dismissSaveSheet)
        }
    }

    /// The rename sheet for the note held on notes.
    @ViewBuilder private var renameSheet: some View {
        if case .up(let renaming) = notesModel.renameSheet {
            TitleSheet(
                title: renaming.title, purpose: .rename,
                onSave: { title in startNotesChange { try await notesModel.finishRenaming(renaming, typed: title) } },
                onDismiss: notesModel.stopRenaming)
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
