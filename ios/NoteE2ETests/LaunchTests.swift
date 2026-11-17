import NoteUI
import XCTest

nonisolated final class LaunchTests: XCTestCase {
    /// Longer than the write screen waits after the last keystroke before it saves.
    private let saveWait = WriteScreen.saveDelay / .seconds(1) + 1

    @MainActor func testLaunchOpensABlankNoteThatKeepsWhatIsTyped() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        launch(app)

        if let leftover = text.value as? String, !leftover.isEmpty {
            erase(leftover, in: text)
            relaunchAfterSave(app)
        }
        XCTAssertEqual(text.value as? String, "")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.write].exists)
        attachScreenshot(of: app, named: AccessibilityID.write)

        text.typeText("Hello, note")
        relaunchAfterSave(app)
        XCTAssertEqual(text.value as? String, "Hello, note")
        attachScreenshot(of: app, named: "\(AccessibilityID.write).reopened")

        erase("Hello, note", in: text)
        relaunchAfterSave(app)
        XCTAssertEqual(text.value as? String, "")
    }

    /// Launches the app and waits for the write screen with the keyboard up, which must come without a tap.
    @MainActor private func launch(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.textViews[AccessibilityID.writeText].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard came up without a tap")
    }

    /// Waits for the typing to be saved, then kills the app and launches it again.
    @MainActor private func relaunchAfterSave(_ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: saveWait)
        app.terminate()
        launch(app)
    }

    /// Deletes `shown` from the end, where the reopened caret sits.
    @MainActor private func erase(_ shown: String, in text: XCUIElement) {
        text.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: shown.count))
    }

    @MainActor private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
