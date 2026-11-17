import NoteUI
import XCTest

nonisolated final class LaunchTests: XCTestCase {
    @MainActor func testLaunchOpensABlankNoteWithTheKeyboardUp() {
        let app = XCUIApplication()
        app.launch()

        let text = app.textViews[AccessibilityID.writeText]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard came up without a tap")
        XCTAssertEqual(text.value as? String, "")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.write].exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = AccessibilityID.write
        shot.lifetime = .keepAlways
        add(shot)
    }
}
