import NoteCore
import Testing

/// Expects `stored` to hold `note`'s text byte for byte, its caret, its dates and its saved state.
func expectTextDatesAndSavedStateUnchanged(_ stored: Note, _ note: Note) {
    #expect(Array(stored.text.utf8) == Array(note.text.utf8))
    #expect(stored.cursor == note.cursor)
    #expect(stored.createdAt == note.createdAt)
    #expect(stored.modifiedAt == note.modifiedAt)
    #expect(stored.savedAt == note.savedAt)
}
