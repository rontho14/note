public import Foundation

public enum NoteStorageError: Error, Equatable {
    case emptyNote
}

public protocol NoteStorage: Sendable {
    /// Saves every note or none, in one transaction. Seeding test data and import save thousands at once.
    func save(contentsOf notes: [Note]) async throws
    func note(id: NoteID) async throws -> Note?
    func deletePermanently(id: NoteID) async throws
    func mostRecentNote(modifiedAfter cutoff: Date) async throws -> Note?
    /// Every note, newest first, then again after every change to the notes.
    func noteSummaries() -> any AsyncSequence<[NoteSummary], any Error>
}

extension NoteStorage {
    public func save(_ note: Note) async throws {
        try await save(contentsOf: [note])
    }
}
