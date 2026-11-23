import Foundation
import NoteCore

/// A store whose saves can be held until the test releases them, to replay a save that iOS suspended mid-write.
actor HeldStorage: NoteStorage {
    private let wrapped: any NoteStorage
    private var holding = false
    private var held: [CheckedContinuation<Void, Never>] = []
    private let (arrivals, arrived) = AsyncStream.makeStream(of: Void.self)

    init(_ wrapped: any NoteStorage) {
        self.wrapped = wrapped
    }

    func holdSaves() {
        holding = true
    }

    /// Returns once a save has reached the store and is being held.
    func waitForAHeldSave() async {
        var iterator = arrivals.makeAsyncIterator()
        _ = await iterator.next()
    }

    func releaseSaves() {
        holding = false
        for save in held {
            save.resume()
        }
        held.removeAll()
    }

    func save(contentsOf notes: [Note]) async throws {
        if holding {
            await withCheckedContinuation { continuation in
                held.append(continuation)
                arrived.yield()
            }
        }
        try await wrapped.save(contentsOf: notes)
    }

    func note(id: NoteID) async throws -> Note? {
        try await wrapped.note(id: id)
    }

    func deletePermanently(id: NoteID) async throws {
        try await wrapped.deletePermanently(id: id)
    }

    func mostRecentUnsavedNote(modifiedAfter cutoff: Date) async throws -> Note? {
        try await wrapped.mostRecentUnsavedNote(modifiedAfter: cutoff)
    }

    nonisolated func noteSummaries() -> any AsyncSequence<[NoteSummary], any Error> {
        wrapped.noteSummaries()
    }
}
