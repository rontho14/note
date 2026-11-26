import NoteCore

/// The models' only way to the store. Changes run one after another: each starts once every earlier one has finished,
/// whether or not that one failed. A store iOS suspended can't finish over a later change, and a change made from the
/// list can't land before the store leaving write started, which writes the whole note. The strip hands one to every
/// model, so no model can reach the store outside the queue except to follow it.
final class NoteChanges {
    private let storage: any NoteStorage
    /// The latest change, finished or not. It starts as one with nothing to do.
    private var last = Task<Void, Never> {}

    init(storage: any NoteStorage) {
        self.storage = storage
    }

    /// Runs `change` against the store after every earlier change, waits for it, and returns what it returns.
    func run<Result: Sendable>(_ change: @escaping (any NoteStorage) async throws -> Result) async throws -> Result {
        let previous = last
        let storage = storage
        let next = Task {
            await previous.value
            return try await change(storage)
        }
        last = Task { _ = await next.result }
        return try await next.value
    }

    /// The store's notes, outside the trash, newest first, sent again after every change. Following waits for nothing.
    func noteSummaries() -> any AsyncSequence<[NoteSummary], any Error> {
        storage.noteSummaries()
    }

    /// How many saved notes are outside the trash, sent again after every change. Following waits for nothing.
    func savedNoteCounts() -> any AsyncSequence<Int, any Error> {
        storage.savedNoteCounts()
    }

    /// The notes in the trash, the most recently trashed first, sent again after every change. Following waits for
    /// nothing.
    func trashSummaries() -> any AsyncSequence<[TrashedNoteSummary], any Error> {
        storage.trashSummaries()
    }
}
