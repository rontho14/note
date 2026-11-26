import NoteUI
import XCTest

nonisolated final class RenameTests: XCTestCase {
    @MainActor func testRenamingANoteChangesItsTitleInPlaceAndOnlyWhitespaceRemovesIt() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        text.typeText("First")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        app.saveThroughTheSheet()
        app.swipeAlongTheStrip(.towardTheRightEnd)
        app.waitForWriteScreen()
        text.typeText("Second body")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
        app.textFields[AccessibilityID.save.title].typeText("Old\n")
        XCTAssertTrue(waitForRows(2, in: app)[0].contains("Old"))

        rename(row: 0, in: app)
        XCTAssertEqual(
            app.textFields[AccessibilityID.rename.title].value as? String, "Old", "the field holds the title")
        attachScreenshot(of: app, named: AccessibilityID.rename.sheet)
        app.textFields[AccessibilityID.rename.title].clearAndType("New")
        app.buttons[AccessibilityID.rename.confirm].tap()
        _ = waitForRows(2, in: app, firstContaining: "New")

        rename(row: 0, in: app)
        app.textFields[AccessibilityID.rename.title].clearAndType("   \n")
        _ = waitForRows(2, in: app, firstContaining: "Second body")

        rename(row: 1, in: app)
        app.textFields[AccessibilityID.rename.title].typeText(" ignored")
        app.descendants(matching: .any)[AccessibilityID.rename.scrim].tap()
        XCTAssertTrue(app.renameSheet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            waitForRows(2, in: app)[1].contains("First") && !rows(in: app).element(boundBy: 1).label.contains("ignored")
        )
    }

    @MainActor func testARenamedDraftShowsItsTitleAndItsFirstSaveOffersIt() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(2)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(waitForRows(2, in: app)[0].contains("Seeded 0"))

        rename(row: 0, in: app)
        app.textFields[AccessibilityID.rename.title].typeText("Plan\n")
        let labels = waitForRows(2, in: app, firstContaining: "Plan")
        XCTAssertTrue(labels[0].contains("DRAFT"), labels[0])
        let heights = Set(rows(in: app).allElementsBoundByIndex.map(\.frame.height))
        XCTAssertEqual(heights.count, 1, "a titled draft's row is as tall as an untitled one's: \(heights)")
        attachScreenshot(of: app, named: "\(AccessibilityID.notes).titledDraft")

        rows(in: app).element(boundBy: 0).tap()
        app.waitForWriteScreen()
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields[AccessibilityID.save.title].value as? String, "Plan", "the field holds the title")
        app.saveThroughTheSheet()

        let saved = waitForRows(2, in: app, firstContaining: "Plan")[0]
        XCTAssertTrue(saved.contains("UNSORTED"), saved)
    }

    /// Holds the row at `index` until its menu shows, taps Rename, and waits for the rename sheet.
    @MainActor private func rename(row index: Int, in app: XCUIApplication) {
        rows(in: app).element(boundBy: index).press(forDuration: 1)
        let rename = app.buttons[AccessibilityID.notesRename]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "the held row shows its menu")
        rename.tap()
        XCTAssertTrue(app.renameSheet.waitForExistence(timeout: 5))
    }
}

extension XCUIApplication {
    /// The rename sheet, which exists only while it is up.
    @MainActor fileprivate var renameSheet: XCUIElement {
        descendants(matching: .any)[AccessibilityID.rename.sheet]
    }
}

extension XCUIElement {
    /// Deletes the field's text and types `text`.
    @MainActor fileprivate func clearAndType(_ text: String) {
        let current = value as? String ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
