import NoteUI
import XCTest

nonisolated final class NotesTests: XCTestCase {
    @MainActor func testWhatIsTypedOnWriteIsListedAndFollowedWithoutAReload() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        XCTAssertTrue(app.staticTexts[AccessibilityID.notesEmpty].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "\(AccessibilityID.notes).empty")

        app.swipeAlongTheStrip(.towardTheRightEnd)
        app.waitForWriteScreen()
        text.typeText("First note")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        app.saveThroughTheSheet()
        assertRows(["First note"], in: app)
        attachScreenshot(of: app, named: AccessibilityID.notes)

        rows(in: app).firstMatch.tap()
        app.waitForWriteScreen()
        text.typeText(", and more")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertRows(["First note, and more"], in: app)
    }

    @MainActor func testTappingANoteOpensItOnWriteWhereEditingItChangesThatNote() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNotesSeeded(3)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertRows(["Seeded 0", "Seeded 1 on one long line", "Seeded 2, line 1"], in: app)

        rows(in: app).element(boundBy: 1).tap()
        assertShown(AccessibilityID.write, in: app)
        app.waitForWriteScreen()
        XCTAssertTrue((text.value as? String)?.hasPrefix("Seeded 1 on one long line") == true)

        text.typeText("Edited. ")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        app.saveThroughTheSheet()
        assertRows(["Edited. Seeded 1", "Seeded 0", "Seeded 2, line 1"], in: app)
    }

    /// Fails unless the list settles on one row per entry, in order, each row showing its entry's text.
    @MainActor private func assertRows(
        _ starts: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let rows = rows(in: app)
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                rows.count == starts.count
                    && zip(0..., starts).allSatisfy { rows.element(boundBy: $0).label.contains($1) }
            }, object: nil)
        if XCTWaiter.wait(for: [settled], timeout: 10) != .completed {
            XCTFail(
                "the list doesn't show \(starts): \(rows.allElementsBoundByIndex.map(\.label))", file: file, line: line)
        }
    }
}
