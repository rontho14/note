import Foundation
import NoteCore
import Testing

struct NoteSummaryTests {
    @Test(arguments: [
        ("Plain words", "Plain words"),
        ("First line\nSecond line", "First line Second line"),
        ("Windows\r\nline\r\n\r\n\r\nends", "Windows line ends"),
        ("Tabs\tstay inside", "Tabs\tstay inside"),
        ("👩🏽‍💻 and e\u{301}\nnext", "👩🏽‍💻 and e\u{301} next"),
        ("Trailing breaks\n\n", "Trailing breaks"),
        ("Oneverylongwordwithnospaces", "Oneverylongwordwithnospaces"),
    ])
    func thePreviewIsTheFirstWordsOnOneLine(text: String, preview: String) {
        let summary = NoteSummary(
            id: NoteID(rawValue: UUID()), textStart: text, modifiedAt: .now, kind: .draft)

        #expect(summary.preview == preview)
    }

    @Test func aTitleIsDrawnOnOneLineLikeThePreview() {
        let summary = NoteSummary(
            id: NoteID(rawValue: UUID()), textStart: "text", modifiedAt: .now, kind: .saved(title: "\nTitle\r\nnext "))

        #expect(summary.kind == .saved(title: "Title next "))
    }
}
