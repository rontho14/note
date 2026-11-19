import NoteUI
import XCTest

nonisolated final class ScreensTests: XCTestCase {
    @MainActor func testOneSwipeMovesOneScreenAndTheStripStopsAtItsEnds() {
        let app = XCUIApplication()
        app.launchWithNoNotes()
        assertShown(AccessibilityID.write, in: app)

        swipe(app, .towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "leaving write lowers the keyboard")

        swipe(app, .towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.drawersUnsorted].exists)
        attachScreenshot(of: app, named: AccessibilityID.drawers)

        swipe(app, .towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)

        swipe(app, .towardTheRightEnd)
        assertShown(AccessibilityID.notes, in: app)
        swipe(app, .towardTheRightEnd)
        assertShown(AccessibilityID.write, in: app)
        app.waitForWriteScreen()

        swipe(app, .towardTheRightEnd)
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
        swipe(app, .towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        swipe(app, .towardTheRightEnd)
        app.waitForWriteScreen()
        text.typeText("!")
        XCTAssertEqual(text.value as? String, "Kept!", "the text waits on write with the caret at its end")

        swipe(app, .towardTheLeftEnd)
        app.relaunch()

        XCTAssertEqual(text.value as? String, "Kept!", "leaving write saved the text without waiting for a pause")
    }

    private enum Direction {
        case towardTheLeftEnd, towardTheRightEnd
    }

    /// Drags across most of the screen's width, high enough to stay clear of the keyboard.
    @MainActor private func swipe(_ app: XCUIApplication, _ direction: Direction) {
        let (from, to): (CGFloat, CGFloat) = direction == .towardTheLeftEnd ? (0.1, 0.9) : (0.9, 0.1)
        app.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.3))
            .press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.3)))
    }

    /// Fails unless the screen identified by `screen` settles inside the window. The screens beside it lie outside.
    @MainActor private func assertShown(
        _ screen: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[screen]
        let window = app.windows.firstMatch
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in window.frame.contains(element.frame) }, object: nil)
        if XCTWaiter.wait(for: [settled], timeout: 5) != .completed {
            XCTFail("\(screen) is not on screen", file: file, line: line)
        }
    }
}
