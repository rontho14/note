public import Foundation

/// What leaving the write screen for the notes list does.
public enum LeavingWrite: Sendable {
    /// Text never saved is on write and the save sheet hasn't been answered, so it comes first.
    case askFirst
    /// This change is stored, then write turns blank.
    case apply(TextChange)

    /// Reads `screen` as well as `stored`, the note it belongs to as last stored, because the typing of the last pause
    /// may not be stored yet. `answer` is the save sheet's, answered for `stored`. An answered sheet saves the draft
    /// with its title or trashes it, erased text is stored as `TextChange` decides, and a saved note is saved with the
    /// text on screen when it has edits since its save. A save or trash happens at `now`.
    public init(_ screen: TextOnScreen, over stored: Note?, answer: SaveSheetAnswer?, now: Date) {
        switch (answer, screen, stored) {
        case (.save(let title)?, _, let stored?):
            self = .apply(.save(stored.saved(title: title, now: now)))
        case (.delete?, _, let stored?):
            self = .apply(.trash(stored.trashed(now: now)))
        case (_, .erased(let lastText), _):
            self = .apply(TextChange(erasing: lastText, over: stored, now: now))
        case (_, .typed(let text, let caret), let stored?) where !LeavingWrite.asksFirst(screen, over: stored):
            let current = stored.edited(text: text, caret: caret, now: now)
            self = .apply(current.hasUnsavedEdits ? .save(current.saved(now: now)) : .nothing)
        case (_, .typed, _):
            self = .askFirst
        }
    }

    /// Whether leaving with `screen` over `stored` asks first: text on screen that was never saved.
    public static func asksFirst(_ screen: TextOnScreen, over stored: Note?) -> Bool {
        guard case .typed = screen else {
            return false
        }
        return stored?.isDraft ?? true
    }
}
