public import Foundation

/// What storing the text on the write screen does to its note. One note at a time: the first store of text that isn't
/// empty creates it, and erasing the text deletes a draft or trashes a saved note, so the next typing starts a new
/// note.
public enum TextChange: Sendable {
    case nothing
    case store(Note)
    /// A save: stored like `store`, and measured as the save it is.
    case save(Note)
    case delete(NoteID)
    case trash(Note)

    /// Decides the change for `screen` over `stored`, the note as last stored or nil. Text that changed, byte for
    /// byte, moves `modifiedAt`. A caret that moved alone stores the caret and keeps `modifiedAt`, so it neither
    /// reorders notes nor extends the reopen window. A saved note erased goes to the trash with the last text on
    /// screen, which the pause before a store may have kept from the store. `newID` names the note if this store
    /// creates it; `NoteCore` takes random values as arguments.
    public init(storing screen: TextOnScreen, over stored: Note?, now: Date, newID: NoteID) {
        switch (screen, stored) {
        case (.erased(let lastText), _):
            self.init(erasing: lastText, over: stored, now: now)
        case (.typed(let text, let caret), nil):
            var note = Note(id: newID, text: text, cursor: 0, createdAt: now, modifiedAt: now)
            note.cursorIndex = caret
            self = .store(note)
        case (.typed(let text, let caret), let stored?):
            let note = stored.edited(text: text, caret: caret, now: now)
            self = note.hasSameText(as: stored) && note.cursor == stored.cursor ? .nothing : .store(note)
        }
    }

    /// Decides the change for text erased after `lastText` over `stored`: nothing over no stored note, a draft deleted,
    /// or a saved note in the trash with `lastText`.
    init(erasing lastText: String, over stored: Note?, now: Date) {
        guard let stored else {
            self = .nothing
            return
        }
        self =
            stored.isDraft
            ? .delete(stored.id)
            : .trash(stored.edited(text: lastText, caret: lastText.endIndex, now: now).trashed(now: now))
    }
}
