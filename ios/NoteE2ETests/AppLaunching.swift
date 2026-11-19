import NoteUI
import XCTest

extension XCUIApplication {
    /// Launches the app with its database deleted first, so it starts with no notes, and waits for the write screen.
    /// Later launches keep the notes, as a user's would.
    @MainActor func launchWithNoNotes(file: StaticString = #filePath, line: UInt = #line) {
        launchArguments = ["-reset-storage"]
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

extension XCTestCase {
    @MainActor func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
