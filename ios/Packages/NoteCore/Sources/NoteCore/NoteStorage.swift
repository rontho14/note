public import Foundation

public enum NoteStorageError: Error, Equatable {
    case emptyNote
}

public protocol NoteStorage: Sendable {
    func save(_ note: Note) async throws
    func note(id: NoteID) async throws -> Note?
    func deletePermanently(id: NoteID) async throws
    func mostRecentNote(modifiedAfter cutoff: Date) async throws -> Note?
}
