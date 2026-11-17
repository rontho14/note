import Foundation
import NoteCore
import Testing

struct EmptyNoteTests {
    @Test(arguments: ["", " ", "\t\n", "\r\n", "\u{00A0}"])
    func textOfOnlyWhitespaceIsEmpty(text: String) {
        #expect(Note.sample(text).isEmpty)
    }

    @Test(arguments: ["a", " a ", "\u{200B}"])
    func anyOtherCharacterMakesANote(text: String) {
        #expect(!Note.sample(text).isEmpty)
    }
}
