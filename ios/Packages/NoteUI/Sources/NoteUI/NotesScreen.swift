import NoteCore
import SwiftUI

/// Every note, newest first, following the store as it changes. Tapping one opens it. The note just saved is tinted
/// for a moment, and the list scrolls to it once its row is there.
struct NotesScreen: View {
    let model: NotesModel
    let onOpen: (NoteID) -> Void

    var body: some View {
        list
            .ignoresSafeArea(.container, edges: .top)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.notes)
            .task { await stoppingTheAppOnFailure { try await model.follow() } }
    }

    @ViewBuilder private var list: some View {
        switch model.summaries {
        case nil:
            Color.clear
        case let summaries? where summaries.isEmpty:
            Text("No notes yet.")
                .font(Typeface.preview)
                .foregroundStyle(Palette.second)
                .padding(.horizontal, ListLayout.side)
                .padding(.top, ListLayout.firstRowTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityIdentifier(AccessibilityID.notesEmpty)
        case let summaries?:
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
                        .accessibilityIdentifier(AccessibilityID.notesRow(summary.id))
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: ListLayout.side, bottom: 0, trailing: ListLayout.side)
                        )
                        .listRowBackground(summary.id == model.justSaved ? Palette.justSaved : Color.clear)
                        .listRowSeparatorTint(Palette.hairline)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, ListLayout.firstRowTop, for: .scrollContent)
                    .animation(.easeOut, value: model.justSaved)
                }
                .onChange(of: model.justSavedRow) { _, saved in
                    if let saved {
                        withAnimation { list.scrollTo(saved) }
                    }
                }
            }
        }
    }
}
