import SwiftUI

/// The drawers as they are before the user makes one: `Unsorted` alone, with how many notes it holds once the store
/// has answered.
struct DrawersScreen: View {
    let model: DrawersModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Unsorted")
                    .font(Typeface.unsorted)
                    .foregroundStyle(Palette.second)
                    .accessibilityIdentifier(AccessibilityID.drawersUnsorted)
                Spacer(minLength: 0)
                if let count = model.unsortedCount {
                    Text(count, format: .number)
                        .font(Typeface.count)
                        .foregroundStyle(Palette.second)
                        .accessibilityIdentifier(AccessibilityID.drawersUnsortedCount)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.drawers)
        .task { await stoppingTheAppOnFailure { try await model.follow() } }
    }
}

/// DESIGN.md's Drawers numbers.
private enum Layout {
    static let rowLine: CGFloat = 40
    static let rowPadding: CGFloat = 8
}
