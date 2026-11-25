import Foundation
import NoteCore
import Observation

/// The drawers screen's state, kept up to date with the store: how many notes `Unsorted` holds, every saved note being
/// in `Unsorted` until drawers exist, and the notes in the trash, with the bubble that says where a restored note went.
@Observable
final class DrawersModel {
    /// How long the bubble naming where a restored note went stays up.
    static let restoredDuration: Duration = .seconds(3)

    private(set) var unsortedCount = StoreRead<Int>.reading
    /// What the last note restored was, a draft or saved, which the bubble names once the trash sheet goes down.
    var restoredBubble: Showing<NoteSummary.Kind> {
        bubble.showing
    }

    /// Restores and purges wait in it for every earlier change to the notes.
    private let changes: NoteChanges
    /// Every note in the trash, the most recently trashed first, including notes past their 30 days until the purge
    /// deletes them, so it is read only through `trash(listedAt:)`.
    private var trashed = StoreRead<[TrashedNoteSummary]>.reading
    private let bubble = FadingValue<NoteSummary.Kind>(lasting: DrawersModel.restoredDuration)
    /// The note restored last while the trash sheet is up, waiting for the sheet to go down.
    private var restoredWhileTheSheetIsUp = RestoredWhileTheSheetIsUp.nothing

    init(changes: NoteChanges) {
        self.changes = changes
    }

    /// Shows the store's count, and again after every change, for as long as the calling task runs.
    func followUnsortedCount() async throws {
        for try await count in changes.savedNoteCounts() {
            unsortedCount = .read(count)
        }
    }

    /// Shows the store's trash, and again after every change, for as long as the calling task runs.
    func followTrash() async throws {
        for try await trashed in changes.trashSummaries() {
            self.trashed = .read(trashed)
        }
    }

    /// The trash as listed at `now`: a note leaves the list the moment its 30 days are up, before the purge deletes it.
    func trash(listedAt now: Date) -> StoreRead<[TrashedNoteSummary]> {
        trashed.map { $0.filter { !TrashExpiry.isExpired(trashedAt: $0.trashedAt, now: now) } }
    }

    /// Takes `note` out of the trash, back to its place in the list, for the bubble to name once the sheet goes down.
    /// The bubble's note is kept at once, so a sheet that goes down while the restore waits its turn still names it.
    func restore(_ note: TrashedNoteSummary) async throws {
        restoredWhileTheSheetIsUp = .restored(note.summary.kind)
        try await changes.run { try await $0.restoreFromTrash(id: note.id) }
    }

    /// Shows the bubble for the note restored last while the trash sheet was up, if any. The sheet calls it as it goes
    /// down, since the bubble sits under the sheet.
    func showRestoredBubble() {
        if case .restored(let kind) = restoredWhileTheSheetIsUp {
            bubble.show(kind)
            restoredWhileTheSheetIsUp = .nothing
        }
    }

    /// Deletes for good every note in the trash past its 30 days at `now`.
    func purgeExpired(now: Date) async throws {
        try await changes.run { try await $0.purgeTrash(trashedBefore: TrashExpiry.cutoff(now: now)) }
    }
}

/// The note restored while the trash sheet is up, which the bubble names once the sheet goes down.
private enum RestoredWhileTheSheetIsUp {
    case nothing
    case restored(NoteSummary.Kind)
}
