import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

@testable import NoteUI

@MainActor
struct NotesModelTests {
    @Test func theModelShowsNothingUntilTheStoreAnswersThenFollowsEveryChange() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = NotesModel(storage: storage)
        #expect(model.summaries == nil)
        let following = Task { try await model.follow() }
        defer { following.cancel() }

        try await waitUntil { model.summaries?.map(\.preview) == [] }
        let note = Note.sample("written", modifiedAt: .minutes(1))
        try await storage.save(note)
        try await waitUntil { model.summaries?.map(\.preview) == ["written"] }
        try await storage.deletePermanently(id: note.id)
        try await waitUntil { model.summaries?.map(\.preview) == [] }
    }

    /// Waits for `condition`, failing after two seconds.
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            try #require(ContinuousClock.now < deadline, "the model never showed the store's notes")
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
