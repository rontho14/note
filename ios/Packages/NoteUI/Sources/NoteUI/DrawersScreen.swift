import SwiftUI

/// The drawers as they are before the user makes one: `Unsorted` alone, with how many notes it holds once the store
/// has answered, and the trash button at the bottom right, which opens the trash. Each time the app becomes active, the
/// notes in the trash past their 30 days are deleted for good.
struct DrawersScreen: View {
    let model: DrawersModel
    @State private var isShowingTrash = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Unsorted")
                    .font(Typeface.unsorted)
                    .foregroundStyle(Palette.second)
                    .accessibilityIdentifier(AccessibilityID.drawersUnsorted)
                Spacer(minLength: 0)
                if case .read(let count) = model.unsortedCount {
                    Text(count, format: .number)
                        .font(Typeface.count)
                        .foregroundStyle(Palette.second)
                        .accessibilityIdentifier(AccessibilityID.drawersCount)
                }
            }
            .frame(height: Layout.rowLine)
            .padding(.vertical, Layout.rowPadding)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ListLayout.side)
        .padding(.top, ListLayout.firstRowTop)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ignoresSafeArea(.container, edges: .top)
        .overlay(alignment: .bottomTrailing) { trash }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.drawers)
        .task { await stoppingTheAppOnFailure { try await model.followUnsortedCount() } }
        .task { await stoppingTheAppOnFailure { try await model.followTrash() } }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                startNotesChange { try await model.purgeExpired(now: .now) }
            }
        }
        .sheet(isPresented: $isShowingTrash, onDismiss: model.showRestoredBubble) {
            TrashSheet(model: model)
        }
    }

    /// The trash button, with the bubble over it once a note is restored.
    private var trash: some View {
        VStack(alignment: .trailing, spacing: Layout.bubbleGap) {
            if case .shown(let restored) = model.restoredBubble {
                RestoredBubble(kind: restored)
            }
            TimelineView(.everyMinuteFromNow) { context in
                if case .read(let trash) = model.trash(listedAt: context.date) {
                    TrashButton(count: trash.count) { isShowingTrash = true }
                }
            }
            .fixedSize()
        }
        .animation(.easeOut, value: model.restoredBubble)
        .padding(.trailing, Layout.trashSide)
        .padding(.bottom, Layout.trashBottom)
    }
}

/// DESIGN.md's Drawers and Trash numbers.
private enum Layout {
    static let rowLine: CGFloat = 40
    static let rowPadding: CGFloat = 8
    /// From the screen's edge to the trash button.
    static let trashSide: CGFloat = 20
    /// From the bottom to the trash button, until the footer it will sit above exists.
    static let trashBottom: CGFloat = 16
    static let bubbleGap: CGFloat = 6
}
