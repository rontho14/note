import SwiftUI

/// The drawers as they are before the user makes one: `Unsorted` alone.
struct DrawersScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Unsorted")
                .font(Typeface.unsorted)
                .foregroundStyle(Palette.second)
                .frame(height: Layout.rowLine)
                .padding(.vertical, Layout.rowPadding)
                .accessibilityIdentifier(AccessibilityID.drawersUnsorted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.side)
        .padding(.top, Layout.firstRowTop)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.drawers)
    }
}

/// DESIGN.md's Drawers and list numbers.
private enum Layout {
    static let side: CGFloat = 26
    static let firstRowTop: CGFloat = 58
    static let rowLine: CGFloat = 40
    static let rowPadding: CGFloat = 8
}
