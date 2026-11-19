import NoteCore
import NoteUI
import XCTest

nonisolated final class LaunchTests: XCTestCase {
    /// Longer than the write screen waits after the last keystroke before it saves.
    private let saveWait = DraftSaving.delay / .seconds(1) + 1

    @MainActor func testLaunchOpensABlankNoteThatKeepsWhatIsTyped() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()

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

    /// Waits for the typing to be saved, then kills the app and launches it again.
    @MainActor private func relaunchAfterSave(_ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: saveWait)
        app.relaunch()
    }

    /// Deletes `shown` from the end, where the reopened caret sits.
    @MainActor private func erase(_ shown: String, in text: XCUIElement) {
        text.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: shown.count))
    }
}
