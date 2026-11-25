public import Foundation

public enum NoteStorageError: Error, Equatable {
    case emptyNote
}

public protocol NoteStorage: Sendable {
    /// Saves every note or none, in one transaction. Seeding test data and import save thousands at once.
    func save(contentsOf notes: [Note]) async throws
    func note(id: NoteID) async throws -> Note?
    func deletePermanently(id: NoteID) async throws
    /// Sends the note `id` to the trash at `now`, changing nothing else.
    func moveToTrash(id: NoteID, now: Date) async throws
    /// Takes the note `id` out of the trash, changing nothing else.
    func restoreFromTrash(id: NoteID) async throws
    /// The newest note modified after `cutoff` that has unsaved edits and isn't in the trash: what write reopens.
    func mostRecentUnsavedNote(modifiedAfter cutoff: Date) async throws -> Note?
    /// Every note not in the trash, newest first, then again after every change to the notes.
    func noteSummaries() -> any AsyncSequence<[NoteSummary], any Error>
    /// How many saved notes are not in the trash, then again after every change.
    func savedNoteCounts() -> any AsyncSequence<Int, any Error>
}

extension NoteStorage {
    public func save(_ note: Note) async throws {
        try await save(contentsOf: [note])
    }
}
