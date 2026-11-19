import NoteUI
import XCTest

nonisolated final class ScreensTests: XCTestCase {
    @MainActor func testOneSwipeMovesOneScreenAndTheStripStopsAtItsEnds() {
        let app = XCUIApplication()
        app.launchWithNoNotes()
        assertShown(AccessibilityID.write, in: app)

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "leaving write lowers the keyboard")

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.drawersUnsorted].exists)
        attachScreenshot(of: app, named: AccessibilityID.drawers)

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)

        app.swipeAlongTheStrip(.towardTheRightEnd)
        assertShown(AccessibilityID.notes, in: app)
        app.swipeAlongTheStrip(.towardTheRightEnd)
        assertShown(AccessibilityID.write, in: app)
        app.waitForWriteScreen()

        app.swipeAlongTheStrip(.towardTheRightEnd)
        assertShown(AccessibilityID.write, in: app)
    }

    @MainActor func testScrollingALongNoteThatDriftsSidewaysStaysOnWrite() {
        let app = XCUIApplication()
        app.launchWithNoNotes()
        app.textViews[AccessibilityID.writeText].typeText(String(repeating: "A line of the note\n", count: 40))

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        start.press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.1)))
        start.press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.1)))

        assertShown(AccessibilityID.write, in: app)
    }

    @MainActor func testTextLeftOnWriteIsSavedAtOnceAndWaitsThereWithItsCaret() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()

        text.typeText("Kept")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        app.swipeAlongTheStrip(.towardTheRightEnd)
        app.waitForWriteScreen()
        text.typeText("!")
        XCTAssertEqual(text.value as? String, "Kept!", "the text waits on write with the caret at its end")

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        app.relaunch()

        XCTAssertEqual(text.value as? String, "Kept!", "leaving write saved the text without waiting for a pause")
    }
}
