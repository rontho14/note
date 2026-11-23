import NoteCore
import Observation

/// How many notes `Unsorted` holds, kept up to date with the store. Every saved note is in `Unsorted` until drawers
/// exist.
@Observable
final class DrawersModel {
    /// Nil until the store first answers, so the count never shows `0` before it has read.
    private(set) var unsortedCount: Int?

    private let storage: any NoteStorage

    init(storage: any NoteStorage) {
        self.storage = storage
    }

    /// Shows the store's count, and again after every change, for as long as the calling task runs.
    func follow() async throws {
        for try await count in storage.savedNoteCounts() {
            unsortedCount = count
        }
    }
}
