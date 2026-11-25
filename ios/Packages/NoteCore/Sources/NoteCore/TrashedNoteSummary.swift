public import Foundation

/// A note in the trash as the trash sheet shows it: as the notes list would show it, and when it went to the trash.
public struct TrashedNoteSummary: Sendable, Equatable, Identifiable {
    public let summary: NoteSummary
    public let trashedAt: Date

    public init(summary: NoteSummary, trashedAt: Date) {
        self.summary = summary
        self.trashedAt = trashedAt
    }

    public var id: NoteID {
        summary.id
    }
}
