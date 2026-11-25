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

    /// Launches the app with its database holding only the notes `-seed-trash` describes, such as `saved:1,draft:29`:
    /// each saved or a draft, trashed that many days before launch. Waits for the write screen.
    @MainActor func launchWithTrashSeeded(_ notes: String, file: StaticString = #filePath, line: UInt = #line) {
        launchOnce(with: ["-reset-storage", "-seed-trash", notes], file: file, line: line)
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

    /// Waits until the list shows `count` rows, and returns their labels.
    @MainActor func waitForRows(
        _ count: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) -> [String] {
        waitForRows(in: app, "\(count) rows", file: file, line: line) { $0.count == count }
    }

    /// Waits until the list shows `count` rows, the first holding `text`, and returns their labels.
    @MainActor func waitForRows(
        _ count: Int, in app: XCUIApplication, firstContaining text: String, file: StaticString = #filePath,
        line: UInt = #line
    ) -> [String] {
        waitForRows(in: app, "\(count) rows, the first holding \(text)", file: file, line: line) { rows in
            rows.count == count && rows.firstMatch.label.contains(text)
        }
    }

    /// Waits until the list's rows meet `settled`, failing with what was `expected`, and returns their labels.
    @MainActor private func waitForRows(
        in app: XCUIApplication, _ expected: String, file: StaticString, line: UInt,
        until settled: @escaping (XCUIElementQuery) -> Bool
    ) -> [String] {
        let rows = rows(in: app)
        let waiting = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in settled(rows) }, object: nil)
        if XCTWaiter.wait(for: [waiting], timeout: 10) != .completed {
            XCTFail(
                "the list never showed \(expected): \(rows.allElementsBoundByIndex.map(\.label))", file: file,
                line: line)
        }
        return rows.allElementsBoundByIndex.map(\.label)
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
