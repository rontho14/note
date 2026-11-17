import Foundation
import NoteCore
import Testing

struct CursorTests {
    @Test func anOffsetInsideAnEmojiMovesBackToItsStart() {
        let text = "a👩🏽‍💻b"

        #expect(Note.sample(text, cursor: 3).cursorIndex == text.index(after: text.startIndex))
    }

    @Test func anOffsetBetweenALetterAndItsCombiningMarkMovesBackToTheLetter() {
        let text = "xe\u{301}y"

        #expect(Note.sample(text, cursor: 2).cursorIndex == text.index(after: text.startIndex))
    }

    @Test func anOffsetOnACharacterBoundaryStaysPut() {
        let text = "é👍z"

        #expect(Note.sample(text, cursor: 6).cursorIndex == text.index(text.startIndex, offsetBy: 2))
    }

    @Test(arguments: [3, 4, 1_000])
    func anOffsetAtOrPastTheEndIsTheEnd(cursor: Int) {
        let text = "abc"

        #expect(Note.sample(text, cursor: cursor).cursorIndex == text.endIndex)
    }

    @Test func aPositionSetAsAnIndexIsStoredAsItsUTF8Offset() {
        let text = "é👍z"
        var note = Note.sample(text, cursor: 0)

        note.cursorIndex = text.index(text.startIndex, offsetBy: 2)

        #expect(note.cursor == 6)
    }

    @Test func aNegativeOffsetIsTheStart() {
        let text = "abc"

        #expect(Note.sample(text, cursor: -1).cursorIndex == text.startIndex)
    }
}
