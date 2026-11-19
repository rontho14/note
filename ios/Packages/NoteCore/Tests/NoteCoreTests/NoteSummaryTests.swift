import Foundation
import NoteCore
import Testing

struct NoteSummaryTests {
    @Test(arguments: [
        ("Plain words", "Plain words"),
        ("\n\n \t  After blank lines", "After blank lines"),
        ("First line\nSecond line", "First line Second line"),
        ("Windows\r\nline\r\n\r\n\r\nends", "Windows line ends"),
        ("Tabs\tstay inside", "Tabs\tstay inside"),
        ("👩🏽‍💻 and e\u{301}\nnext", "👩🏽‍💻 and e\u{301} next"),
        ("Trailing breaks\n\n", "Trailing breaks"),
        ("Oneverylongwordwithnospaces", "Oneverylongwordwithnospaces"),
    ])
    func thePreviewIsTheFirstWordsOnOneLine(text: String, preview: String) {
        let summary = NoteSummary(id: NoteID(rawValue: UUID()), textStart: text, modifiedAt: .now)

        #expect(summary.preview == preview)
    }
}
