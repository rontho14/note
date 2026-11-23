import Foundation
import NoteCore
import NoteCoreTesting
import NoteStore
import Testing

@testable import NoteUI

@MainActor
struct DrawersModelTests {
    @Test func theUnsortedCountIsNothingUntilTheStoreAnswersThenFollowsIt() async throws {
        let storage = try NoteDatabase.openInMemory()
        let model = DrawersModel(storage: storage)
        #expect(model.unsortedCount == nil)
        let following = Task { try await model.follow() }
        defer { following.cancel() }

        try await waitUntil { model.unsortedCount == 0 }
        try await storage.save(Note.sample("saved", savedAt: .minutes(1)))
        try await waitUntil { model.unsortedCount == 1 }
    }
}
