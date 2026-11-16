import Foundation
import NoteCore
import Testing

struct EmptyNoteTests {
    @Test(arguments: ["", " ", "\t\n", "\r\n", "\u{00A0}"])
    func textOfOnlyWhitespaceIsEmpty(text: String) {
        #expect(note(text).isEmpty)
    }

    @Test(arguments: ["a", " a ", "\u{200B}"])
    func anyOtherCharacterMakesANote(text: String) {
        #expect(!note(text).isEmpty)
    }

    private func note(_ text: String) -> Note {
        Note(id: NoteID(rawValue: UUID()), text: text, createdAt: .now, modifiedAt: .now)
    }
}
