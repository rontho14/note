import NoteUI
import XCTest

nonisolated final class TrashTests: XCTestCase {
    @MainActor func testDeletingANoteFromTheListPutsItInTheTrashAndUndoBringsItBackInPlace() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(3)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        let labels = waitForRows(3, in: app)

        deleteRow(1, in: app)

        XCTAssertEqual(waitForRows(2, in: app), [labels[0], labels[2]])
        XCTAssertTrue(app.undoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["In the trash"].exists)
        attachScreenshot(of: app, named: AccessibilityID.notesUndo)

        app.undoButton.tap()

        XCTAssertEqual(waitForRows(3, in: app), labels, "the note is back in its place")
        XCTAssertTrue(app.undoButton.waitForNonExistence(timeout: 5))
    }

    @MainActor func testLeavingNotesTakesThePillAwayAndTheNoteStaysInTheTrash() {
        let app = XCUIApplication()
        app.launchWithNotesSeeded(2)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        let labels = waitForRows(2, in: app)
        deleteRow(0, in: app)
        XCTAssertTrue(app.undoButton.waitForExistence(timeout: 5))

        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)
        app.swipeAlongTheStrip(.towardTheRightEnd)
        assertShown(AccessibilityID.notes, in: app)

        XCTAssertFalse(app.undoButton.exists)
        XCTAssertEqual(waitForRows(1, in: app), [labels[1]])
    }

    @MainActor func testAnEmptyTrashShowsNoCountAndSaysSo() {
        let app = XCUIApplication()
        app.launchWithNoNotes()
        showDrawers(app)

        XCTAssertEqual(app.trashButton.value as? String ?? "", "")
        app.trashButton.tap()

        XCTAssertTrue(app.staticTexts[AccessibilityID.trashEmpty].waitForExistence(timeout: 5))
    }

    @MainActor func testTheTrashListsItsNotesWithTheDaysLeftAndRestoreBringsEachBackWithABubble() {
        let app = XCUIApplication()
        app.launchWithTrashSeeded("saved:1,draft:29")
        showDrawers(app)
        XCTAssertEqual(app.trashButton.value as? String, "2")
        XCTAssertEqual(app.staticTexts[AccessibilityID.drawersCount].label, "0")
        attachScreenshot(of: app, named: AccessibilityID.drawersTrash)

        app.trashButton.tap()
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.trashRowPrefix))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        let labels = rows.allElementsBoundByIndex.map {
            $0.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        }
        XCTAssertEqual(labels.count, 2)
        XCTAssertTrue(labels[0].contains("Trashed saved 1") && labels[0].contains("UNSORTED"), labels[0])
        XCTAssertTrue(labels[0].contains("29 days"), labels[0])
        XCTAssertTrue(labels[1].contains("Trashed draft 29") && labels[1].contains("DRAFT"), labels[1])
        XCTAssertTrue(labels[1].contains("1 day"), labels[1])
        attachScreenshot(of: app, named: AccessibilityID.trash)

        restoreFirstRowAndCloseTheSheet(app)
        XCTAssertTrue(app.staticTexts["Back in Unsorted"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts[AccessibilityID.drawersCount].label, "1")
        XCTAssertEqual(app.trashButton.value as? String, "1")

        app.trashButton.tap()
        restoreFirstRowAndCloseTheSheet(app)
        XCTAssertTrue(app.staticTexts["Back as a draft"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.trashButton.value as? String ?? "", "")

        app.swipeAlongTheStrip(.towardTheRightEnd)
        XCTAssertEqual(waitForRows(2, in: app).count, 2, "both notes are back in the list")
    }

    @MainActor func testANotePastItsThirtyDaysIsGoneOnceTheAppComesBack() {
        let app = XCUIApplication()
        app.launchWithTrashSeeded("saved:31")

        XCUIDevice.shared.press(.home)
        app.activate()
        app.waitForWriteScreen()
        showDrawers(app)

        XCTAssertEqual(app.trashButton.value as? String ?? "", "")
    }

    /// Swipes from write past notes to drawers.
    @MainActor private func showDrawers(_ app: XCUIApplication) {
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.notes, in: app)
        app.swipeAlongTheStrip(.towardTheLeftEnd)
        assertShown(AccessibilityID.drawers, in: app)
    }

    /// Taps the trash sheet's first Restore, then drags the sheet down.
    @MainActor private func restoreFirstRowAndCloseTheSheet(_ app: XCUIApplication) {
        let restore = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.trashRestorePrefix)
        ).firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        let sheet = app.descendants(matching: .any)[AccessibilityID.trash]
        sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "the sheet went down")
    }

    /// Holds the row at `index` until its menu shows, and taps Delete.
    @MainActor private func deleteRow(_ index: Int, in app: XCUIApplication) {
        rows(in: app).element(boundBy: index).press(forDuration: 1)
        let delete = app.buttons[AccessibilityID.notesDelete]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the held row shows its menu")
        attachScreenshot(of: app, named: "\(AccessibilityID.notes).menu")
        delete.tap()
    }
}

extension XCUIApplication {
    /// The trash button on drawers, whose value is its count.
    @MainActor fileprivate var trashButton: XCUIElement {
        buttons[AccessibilityID.drawersTrash]
    }

    /// The Undo pill's button, which exists only while the pill is up.
    @MainActor fileprivate var undoButton: XCUIElement {
        buttons[AccessibilityID.notesUndo]
    }
}
