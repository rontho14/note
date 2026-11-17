public import Foundation

/// What saving the text on the write screen does to its draft. One draft at a time: the first save of text that isn't
/// empty creates it, and emptying the text deletes it, so the next typing starts a new note.
public enum DraftChange: Sendable {
    case nothing
    case save(Note)
    case delete(NoteID)

    /// Decides the change for `text` with the caret at `caret`, over `draft`, the draft as last stored or nil. Text
    /// that changed, byte for byte, moves `modifiedAt`. A caret that moved alone saves the caret and keeps
    /// `modifiedAt`, so it neither reorders notes nor extends the reopen window. `newID` names the draft if this
    /// save creates it; `NoteCore` takes random values as arguments.
    public init(saving text: String, caret: String.Index, over draft: Note?, now: Date, newID: NoteID) {
        guard let draft else {
            var note = Note(id: newID, text: text, cursor: 0, createdAt: now, modifiedAt: now)
            note.cursorIndex = caret
            self = note.isEmpty ? .nothing : .save(note)
            return
        }
        var note = draft
        note.text = text
        note.cursorIndex = caret
        if note.isEmpty {
            self = .delete(draft.id)
        } else if !draft.text.utf8.elementsEqual(text.utf8) {
            note.modifiedAt = now
            self = .save(note)
        } else if note.cursor != draft.cursor {
            self = .save(note)
        } else {
            self = .nothing
        }
    }
}
