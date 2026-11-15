public import SwiftUI

public struct RootScreen: View {
    public init() {}

    public var body: some View {
        Text("Note")
            .accessibilityIdentifier(AccessibilityID.root)
    }
}

#Preview {
    RootScreen()
}
