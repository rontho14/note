import NoteCore
import NoteUI
import XCTest

nonisolated final class SavingTests: XCTestCase {
    private let storeWait = Autosave.delay / .seconds(1) + 1

    @MainActor func testASwipeFromBlankWriteOnlyMoves() {
        let app = XCUIApplication()
        app.launchWithNoNotes()

        app.swipeAlongTheStrip(.towardTheLeftEnd)

        assertShown(AccessibilityID.notes, in: app)
        XCTAssertFalse(app.saveSheet.exists)
    }

    @MainActor func testASwipeFromADraftAsksFirstAndDismissingTheSheetGoesBackToTheText() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        text.typeText("Draft")

        dragTowardNotes(in: app, from: 0.5, to: 0.6, slowly: true)
        assertShown(AccessibilityID.write, in: app)
        XCTAssertFalse(app.saveSheet.exists, "a drag that paging springs back doesn't ask to save")

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
        assertShown(AccessibilityID.write, in: app)
        XCTAssertTrue(hasKeyboardFocus(app.textFields[AccessibilityID.saveTitle]), "the title field has the caret")
        XCTAssertEqual(app.buttons[AccessibilityID.saveDelete].label, "Delete")
        attachScreenshot(of: app, named: AccessibilityID.save)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        assertBackOnTheDraft(text, typing: "!", in: app)

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
        app.saveSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
        assertBackOnTheDraft(text, typing: "?", in: app)

        dragTowardNotes(in: app, from: 0.1, to: 0.9, slowly: true)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5), "a slow swipe asks too")
    }

    @MainActor func testDeleteInTheSheetSendsTheDraftToTheTrashAndBlanksWrite() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        text.typeText("Doomed")

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
        app.buttons[AccessibilityID.saveDelete].tap()

        assertShown(AccessibilityID.notes, in: app)
        XCTAssertTrue(app.staticTexts[AccessibilityID.notesEmpty].waitForExistence(timeout: 5))
        app.swipeAlongTheStrip(.towardTheRightEnd)
        app.waitForWriteScreen()
        XCTAssertEqual(text.value as? String, "")
    }

    @MainActor func testASavedNoteEmptiedOfItsTextGoesToTheTrash() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        saveANote("Saved", in: app)

        rows(in: app).firstMatch.tap()
        app.waitForWriteScreen()
        text.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Saved".count))
        sleep(UInt32(storeWait))
        app.swipeAlongTheStrip(.towardTheLeftEnd)

        XCTAssertTrue(app.staticTexts[AccessibilityID.notesEmpty].waitForExistence(timeout: 5))
    }

    @MainActor func testANoteJustSavedLeavesWriteBlankAtLaunchAndOneEditedSinceReopens() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        saveANote("Saved", in: app)

        app.relaunch()
        XCTAssertEqual(text.value as? String, "", "a note just saved doesn't reopen")

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        rows(in: app).firstMatch.tap()
        app.waitForWriteScreen()
        text.typeText(" again")
        sleep(UInt32(storeWait))
        app.relaunch()

        XCTAssertEqual(text.value as? String, "Saved again", "a saved note edited since its save reopens")
    }

    @MainActor func testSavedNotesAreListedTitledOrUntitledBesideDraftsAndUnsortedCountsThem() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(1)
        saveANote("Untitled note", in: app)
        backToWrite(app)
        saveANote("Body under a title", titled: "A title", in: app)
        backToWrite(app)
        saveANote("Spaces only", titled: "   ", in: app)
        app.swipeAlongTheStrip(.towardTheRightEnd)
        app.waitForWriteScreen()
        XCTAssertEqual(app.textViews[AccessibilityID.writeText].value as? String, "", "write is blank after a save")
        app.textViews[AccessibilityID.writeText].typeText("Doomed")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
        app.buttons[AccessibilityID.saveDelete].tap()

        let labels = waitForRows(4, in: app)
        XCTAssertTrue(labels[0].contains("Spaces only") && labels[0].contains("UNSORTED"), labels[0])
        XCTAssertTrue(labels[1].contains("A title") && !labels[1].contains("Body"), labels[1])
        XCTAssertTrue(labels[2].contains("Untitled note") && labels[2].contains("UNSORTED"), labels[2])
        XCTAssertTrue(labels[3].contains("Seeded 0") && labels[3].contains("DRAFT"), labels[3])
        let heights = Set(rows(in: app).allElementsBoundByIndex.map(\.frame.height))
        XCTAssertEqual(heights.count, 1, "every kind of row is the same height: \(heights)")
        attachScreenshot(of: app, named: "\(AccessibilityID.notes).saved")

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)
        let count = app.staticTexts[AccessibilityID.drawersUnsortedCount]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "3", "three saved notes, not the draft or the note in the trash")
    }

    @MainActor func testAnEditedSavedNoteSavesStraightToTheTopAndAnUnchangedOneKeepsItsPlace() {
        let app = XCUIApplication()
        let text = app.textViews[AccessibilityID.writeText]
        app.launchWithNoNotes()
        saveANote("First", in: app)
        backToWrite(app)
        saveANote("Second", in: app)
        XCTAssertTrue(waitForRows(2, in: app)[0].contains("Second"))

        rows(in: app).element(boundBy: 1).tap()
        app.waitForWriteScreen()
        text.typeText(" edited")
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        XCTAssertFalse(app.saveSheet.exists, "a saved note saves with no sheet")
        XCTAssertTrue(waitForRows(2, in: app, firstContaining: "First edited")[1].contains("Second"))

        rows(in: app).element(boundBy: 1).tap()
        app.waitForWriteScreen()
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        XCTAssertFalse(app.saveSheet.exists)
        XCTAssertTrue(
            waitForRows(2, in: app, firstContaining: "First edited")[1].contains("Second"), "the order is unchanged")
    }

    /// From write, types `note`, swipes toward notes and saves it through the sheet, typing `title` and Return when
    /// given, or tapping save to leave it untitled. Ends on notes.
    @MainActor private func saveANote(_ note: String, titled title: String? = nil, in app: XCUIApplication) {
        app.textViews[AccessibilityID.writeText].typeText(note)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        if let title {
            XCTAssertTrue(app.saveSheet.waitForExistence(timeout: 5))
            app.textFields[AccessibilityID.saveTitle].typeText(title + "\n")
        } else {
            app.saveThroughTheSheet()
        }
        assertShown(AccessibilityID.notes, in: app)
    }

    @MainActor private func backToWrite(_ app: XCUIApplication) {
        app.swipeAlongTheStrip(.towardTheRightEnd)
        app.waitForWriteScreen()
    }

    /// Drags from `from` to `to` of the screen's width, toward notes, high enough to stay clear of the keyboard.
    @MainActor private func dragTowardNotes(
        in app: XCUIApplication, from: CGFloat, to: CGFloat, slowly: Bool = false
    ) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.3))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.3))
        if slowly {
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
        } else {
            start.press(forDuration: 0, thenDragTo: end)
        }
    }

    /// Fails unless the sheet is gone, write shows the draft with the keyboard up, and typing lands at its end.
    @MainActor private func assertBackOnTheDraft(
        _ text: XCUIElement, typing typed: String, in app: XCUIApplication, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.saveSheet.waitForNonExistence(timeout: 5), "the sheet went down", file: file, line: line)
        app.waitForWriteScreen(file: file, line: line)
        let before = text.value as? String ?? ""
        text.typeText(typed)
        XCTAssertEqual(text.value as? String, before + typed, "the caret is where it was", file: file, line: line)
    }

    @MainActor private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        element.waitForExistence(timeout: 5) && (element.value(forKey: "hasKeyboardFocus") as? Bool ?? false)
    }
}
