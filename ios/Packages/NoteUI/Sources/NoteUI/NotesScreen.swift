import SwiftUI

/// Every note, newest first. Empty until the notes are listed.
struct NotesScreen: View {
    var body: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityIdentifier(AccessibilityID.notes)
    }
}
