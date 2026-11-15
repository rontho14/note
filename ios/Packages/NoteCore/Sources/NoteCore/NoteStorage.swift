public protocol NoteStorage: Sendable {
    func save(_ note: Note) async throws
    func note(id: NoteID) async throws -> Note?
}
