import NoteUI
import XCTest

nonisolated final class LaunchTests: XCTestCase {
    @MainActor func testLaunchShowsRootScreen() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.root].waitForExistence(timeout: 5))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = AccessibilityID.root
        shot.lifetime = .keepAlways
        add(shot)
    }
}
