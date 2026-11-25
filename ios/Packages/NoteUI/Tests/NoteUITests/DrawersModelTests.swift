import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

@testable import NoteUI

@MainActor
struct DrawersModelTests {
    let storage: SQLiteNoteStorage
    let changes = NoteChanges()
    let model: DrawersModel

    init() throws {
        storage = try NoteDatabase.openInMemory()
        model = DrawersModel(storage: storage, changes: changes)
    }

    @Test func theUnsortedCountIsNothingUntilTheStoreAnswersThenFollowsIt() async throws {
        #expect(model.unsortedCount == nil)
        let following = Task { try await model.followUnsortedCount() }
        defer { following.cancel() }

        try await waitUntil { model.unsortedCount == 0 }
        try await storage.save(Note.sample("saved", savedAt: .minutes(1)))
        try await waitUntil { model.unsortedCount == 1 }
    }

    @Test func theTrashHidesANoteTheMomentItsThirtyDaysAreUp() async throws {
        let trashedAt = Date.minutes(0)
        try await storage.save(Note.sample("trashed", trashedAt: trashedAt))
        let following = Task { try await model.followTrash() }
        defer { following.cancel() }
        try await waitUntil { model.trash(listedAt: trashedAt) != nil }

        #expect(model.trash(listedAt: trashedAt + thirtyDays)?.map(\.summary.preview) == ["trashed"])
        #expect(model.trash(listedAt: trashedAt + thirtyDays + 60)?.isEmpty == true)
    }

    @Test(arguments: [
        (Note.sample("saved", savedAt: .minutes(1), trashedAt: .minutes(2)), NoteSummary.Kind.saved),
        (Note.sample("draft", trashedAt: .minutes(2)), NoteSummary.Kind.draft),
    ])
    func restoringTakesTheNoteOutOfTheTrashAndTheBubbleNamesWhereItWentOnceTheSheetIsDown(
        note: Note, kind: NoteSummary.Kind
    )
        async throws
    {
        try await storage.save(note)
        let following = Task { try await model.followTrash() }
        defer { following.cancel() }
        try await waitUntil { model.trash(listedAt: .minutes(2))?.count == 1 }
        let listed = try #require(model.trash(listedAt: .minutes(2))?.first)

        try await model.restore(listed)
        #expect(model.restoredBubble == nil, "no bubble while the sheet is up")
        model.showRestoredBubble()

        #expect(model.restoredBubble == kind)
        #expect(try await storage.note(id: note.id)?.trashedAt == nil)
    }

    @Test func aSheetClosedWhileTheRestoreWaitsItsTurnStillNamesTheNote() async throws {
        let note = Note.sample("saved", savedAt: .minutes(1), trashedAt: .minutes(2))
        try await storage.save(note)
        let following = Task { try await model.followTrash() }
        defer { following.cancel() }
        try await waitUntil { model.trash(listedAt: .minutes(2))?.count == 1 }
        let listed = try #require(model.trash(listedAt: .minutes(2))?.first)
        let held = HeldStorage(storage)
        await held.holdSaves()
        let earlierStore = Task { try await changes.run { try await held.save(Note.sample("earlier")) } }
        await held.waitForAHeldSave()

        let restoring = Task { try await model.restore(listed) }
        await Task.yield()  // The restore starts, and waits behind the held store.
        model.showRestoredBubble()
        await held.releaseSaves()
        try await earlierStore.value
        try await restoring.value

        #expect(model.restoredBubble == .saved)
    }

    @Test func closingTheSheetWithNothingRestoredShowsNoBubble() {
        model.showRestoredBubble()

        #expect(model.restoredBubble == nil)
    }

    @Test func purgingDeletesOnlyNotesPastTheirThirtyDays() async throws {
        let now = Date.minutes(0) + 40 * day
        let expired = Note.sample("expired", trashedAt: now - 31 * day)
        let kept = Note.sample("kept", trashedAt: now - 29 * day)
        try await storage.save(contentsOf: [expired, kept])

        try await model.purgeExpired(now: now)

        #expect(try await storage.note(id: expired.id) == nil)
        #expect(try await storage.note(id: kept.id) != nil)
    }
}

private let day: TimeInterval = 24 * 60 * 60
private let thirtyDays = 30 * day
