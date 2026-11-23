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

    @Test func aSavedNoteIsTintedForTheTintDurationThenNotAtAll() async throws {
        let model = NotesModel(storage: try NoteDatabase.openInMemory())
        let id = NoteID(rawValue: UUID())

        model.showSaved(id)

        #expect(model.justSaved == id)
        try await Task.sleep(for: NotesModel.tintDuration + .milliseconds(200))
        #expect(model.justSaved == nil)
    }
}
