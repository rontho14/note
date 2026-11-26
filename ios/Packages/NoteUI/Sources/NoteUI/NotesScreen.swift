import NoteCore
import SwiftUI

/// Every note, newest first, following the store as it changes. Tapping one opens it, and holding one offers to rename
/// or delete it. The note just saved is tinted for a moment, and the list scrolls to it once its row is there. After a
/// delete, a pill at the bottom offers Undo for a moment.
struct NotesScreen: View {
    let model: NotesModel
    /// Whether the strip rests on notes. Leaving takes the Undo pill away.
    let place: StripPlace
    let onOpen: (NoteID) -> Void

    var body: some View {
        list
            .ignoresSafeArea(.container, edges: .top)
            .overlay(alignment: .bottom) {
                if case .shown = model.undoable {
                    UndoPill(
                        onUndo: { startNotesChange { try await model.undo() } },
                        onReadStart: model.holdUndo, onReadEnd: model.releaseUndo)
                }
            }
            .animation(.easeOut, value: model.undoable)
            .onChange(of: place) { _, place in
                if place == .away {
                    model.dismissUndo()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.notes)
            .task { await stoppingTheAppOnFailure { try await model.follow() } }
    }

    @ViewBuilder private var list: some View {
        switch model.summaries {
        case .reading:
            Color.clear
        case .read(let summaries) where summaries.isEmpty:
            Text("No notes yet.")
                .font(Typeface.preview)
                .foregroundStyle(Palette.second)
                .padding(.horizontal, ListLayout.side)
                .padding(.top, ListLayout.firstRowTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityIdentifier(AccessibilityID.notesEmpty)
        case .read(let summaries):
            ScrollViewReader { list in
                TimelineView(.everyMinute) { context in
                    List(summaries) { summary in
                        Button {
                            onOpen(summary.id)
                        } label: {
                            NoteRow(summary: summary, now: context.date)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                startNotesChange { try await model.startRenaming(summary.id) }
                            }
                            .accessibilityIdentifier(AccessibilityID.notesRename)
                            Button("Delete", systemImage: "trash") {
                                startNotesChange { try await model.moveToTrash(summary.id, now: .now) }
                            }
                            .accessibilityIdentifier(AccessibilityID.notesDelete)
                        }
                        .accessibilityIdentifier(AccessibilityID.notesRow(summary.id))
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: ListLayout.side, bottom: 0, trailing: ListLayout.side)
                        )
                        .listRowBackground(model.justSaved == .shown(summary.id) ? Palette.justSaved : Color.clear)
                        .listRowSeparatorTint(Palette.hairline)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, ListLayout.firstRowTop, for: .scrollContent)
                    .animation(.easeOut, value: model.justSaved)
                }
                .onChange(of: model.justSavedRow) { _, saved in
                    if case .shown(let saved) = saved {
                        withAnimation { list.scrollTo(saved) }
                    }
                }
            }
        }
    }
}
