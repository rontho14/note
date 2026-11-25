import NoteUI
import XCTest

nonisolated final class TrashTests: XCTestCase {
    @MainActor func testDeletingANoteFromTheListPutsItInTheTrashAndUndoBringsItBackInPlace() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(3)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        let labels = waitForRows(3, in: app)

        deleteRow(1, in: app)

        XCTAssertEqual(waitForRows(2, in: app), [labels[0], labels[2]])
        XCTAssertTrue(app.undoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["In the trash"].exists)
        attachScreenshot(of: app, named: AccessibilityID.notesUndo)

        app.undoButton.tap()

        XCTAssertEqual(waitForRows(3, in: app), labels, "the note is back in its place")
        XCTAssertTrue(app.undoButton.waitForNonExistence(timeout: 5))
    }

    @MainActor func testLeavingNotesTakesThePillAwayAndTheNoteStaysInTheTrash() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(2)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        let labels = waitForRows(2, in: app)
        deleteRow(0, in: app)
        XCTAssertTrue(app.undoButton.waitForExistence(timeout: 5))

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)
        app.swipeAlongTheStrip(.towardTheRightEnd)
        assertShown(AccessibilityID.notes, in: app)

        XCTAssertFalse(app.undoButton.exists)
        XCTAssertEqual(waitForRows(1, in: app), [labels[1]])
    }

    /// Holds the row at `index` until its menu shows, and taps Delete.
    @MainActor private func deleteRow(_ index: Int, in app: XCUIApplication) {
        rows(in: app).element(boundBy: index).press(forDuration: 1)
        let delete = app.buttons[AccessibilityID.notesDelete]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the held row shows its menu")
        attachScreenshot(of: app, named: "\(AccessibilityID.notes).menu")
        delete.tap()
    }
}

extension XCUIApplication {
    /// The Undo pill's button, which exists only while the pill is up.
    @MainActor fileprivate var undoButton: XCUIElement {
        buttons[AccessibilityID.notesUndo]
    }
}
