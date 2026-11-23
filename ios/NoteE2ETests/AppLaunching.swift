import NoteUI
import XCTest

extension XCUIApplication {
    /// Launches the app with its database deleted first, so it starts with no notes, and waits for the write screen.
    /// Later launches keep the notes, as a user's would.
    @MainActor func launchWithNoNotes(file: StaticString = #filePath, line: UInt = #line) {
        launchOnce(with: ["-reset-storage"], file: file, line: line)
    }

    /// Launches the app with its database holding only `count` seeded notes, all too old to reopen, and waits for the
    /// write screen. Later launches keep the notes.
    @MainActor func launchWithNotesSeeded(_ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        launchOnce(with: ["-reset-storage", "-seed-notes", String(count)], file: file, line: line)
    }

    /// Launches the app with `arguments` and waits for the write screen. Later launches go without them.
    @MainActor private func launchOnce(with arguments: [String], file: StaticString, line: UInt) {
        launchArguments = arguments
        launch()
        launchArguments = []
        waitForWriteScreen(file: file, line: line)
    }

    /// Kills the app and launches it again, keeping its notes, then waits for the write screen.
    @MainActor func relaunch(file: StaticString = #filePath, line: UInt = #line) {
        terminate()
        launch()
        waitForWriteScreen(file: file, line: line)
    }

    /// Waits for the write screen with the keyboard up, which must come without a tap.
    @MainActor func waitForWriteScreen(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(textViews[AccessibilityID.writeText].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(
            keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard came up without a tap", file: file,
            line: line)
    }
}

extension XCUIApplication {
    enum StripDirection {
        case towardTheLeftEnd, towardTheRightEnd
    }

    /// Drags across most of the screen's width, high enough to stay clear of the keyboard.
    @MainActor func swipeAlongTheStrip(_ direction: StripDirection) {
        let (from, to): (CGFloat, CGFloat) = direction == .towardTheLeftEnd ? (0.1, 0.9) : (0.9, 0.1)
        coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.3))
            .press(forDuration: 0, thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.3)))
    }

    /// The save sheet, which exists only while it is up.
    @MainActor var saveSheet: XCUIElement {
        descendants(matching: .any)[AccessibilityID.save]
    }

    /// Waits for the save sheet, taps its save button, leaving the title as it is, and waits for the sheet and its
    /// keyboard to go.
    @MainActor func saveThroughTheSheet(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(saveSheet.waitForExistence(timeout: 5), "the save sheet came up", file: file, line: line)
        buttons[AccessibilityID.saveConfirm].tap()
        XCTAssertTrue(saveSheet.waitForNonExistence(timeout: 5), "the save sheet went", file: file, line: line)
        XCTAssertTrue(keyboards.firstMatch.waitForNonExistence(timeout: 5), "its keyboard went", file: file, line: line)
    }
}

extension XCTestCase {
    /// The notes list's rows, top first.
    @MainActor func rows(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.notesRowPrefix))
    }

    /// Fails unless the screen identified by `screen` settles inside the window. The screens beside it lie outside.
    @MainActor func assertShown(
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

    @MainActor func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
