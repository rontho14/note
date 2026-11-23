import NoteCore
import Observation

/// Every note as the notes list shows it, newest first, kept up to date with the store, and the note just saved, which
/// the list tints for a moment.
@Observable
final class NotesModel {
    /// How long the note just saved stays tinted before the tint fades.
    static let tintDuration: Duration = .milliseconds(1_500)

    /// Nil until the store first answers, so the list never shows itself empty before it has read.
    private(set) var summaries: [NoteSummary]?
    /// The note just saved, tinted and scrolled to, until `tintDuration` has passed.
    private(set) var justSaved: NoteID?
    private var tintFading: Task<Void, Never>?

    /// The note just saved once the summaries hold its row, so the list scrolls to it only when there is a row to
    /// scroll to.
    var justSavedRow: NoteID? {
        justSaved.flatMap { id in summaries?.contains { $0.id == id } == true ? id : nil }
    }

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

    /// Tints the note `id` and scrolls to it, and lets the tint go after `tintDuration`. A later save takes over.
    func showSaved(_ id: NoteID) {
        justSaved = id
        tintFading?.cancel()
        tintFading = Task {
            do {
                try await Task.sleep(for: Self.tintDuration)
            } catch {
                return  // A later save took over the tint.
            }
            justSaved = nil
        }
    }
}
