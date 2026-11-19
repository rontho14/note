import NoteUI
import XCTest

nonisolated final class NotesScrollTests: XCTestCase {
    /// Records how smoothly ten thousand notes scroll, as `notes.scroll`. The numbers stay in the result bundle; this
    /// test sets no budget for them.
    @MainActor func testScrollingTenThousandNotes() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(10_000)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        let list = app.collectionViews[AccessibilityID.notes]
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        attachScreenshot(of: app, named: "\(AccessibilityID.notes).seeded")

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            for _ in 0..<3 {
                list.swipeUp(velocity: .fast)
            }
        }
    }
}
