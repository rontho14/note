import NoteCore
import Observation

/// Every note as the notes list shows it, newest first, kept up to date with the store.
@Observable
final class NotesModel {
    /// Nil until the store first answers, so the list never shows itself empty before it has read.
    private(set) var summaries: [NoteSummary]?

    private let storage: any NoteStorage

    init(storage: any NoteStorage) {
        self.storage = storage
    }

    /// Shows the store's notes, and again after every change, for as long as the calling task runs.
    func follow() async throws {
        for try await summaries in storage.noteSummaries() {
            self.summaries = summaries
        }
    }
}
