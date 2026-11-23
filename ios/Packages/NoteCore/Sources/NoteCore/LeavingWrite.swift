public import Foundation

/// What leaving the write screen for the notes list does.
public enum LeavingWrite {
    /// The change leaving stores, or nil when text never saved is on write and the save sheet hasn't been answered, so
    /// it comes first. An answered sheet saves the draft with its title or trashes it, erased text is stored as
    /// `TextChange` decides, and a saved note is saved with the text on screen when it has edits since its save.
    /// Reads `screen` as well as `stored`, the note it belongs to as last stored, because the typing of the last pause
    /// may not be stored yet. `answer` is the save sheet's, if it was answered for `stored`. A save or trash happens at
    /// `now`.
    public static func change(
        _ screen: TextOnScreen, over stored: Note?, answer: SaveSheetAnswer?, now: Date
    ) -> TextChange? {
        if let stored, let answer {
            switch answer {
            case .save(let title):
                return .save(stored.saved(title: title, now: now))
            case .delete:
                return .trash(stored.trashed(now: now))
            }
        }
        if asksFirst(screen, over: stored) {
            return nil
        }
        switch screen {
        case .erased(let lastText):
            return TextChange(erasing: lastText, over: stored, now: now)
        case .typed(let text, let caret):
            guard let current = stored?.edited(text: text, caret: caret, now: now), current.hasUnsavedEdits else {
                return .nothing
            }
            return .save(current.saved(now: now))
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
