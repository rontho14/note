import Foundation
import NoteCore

public enum AccessibilityID {
    public static let write = "write"
    public static let writeText = "write.text"
    public static let notes = "notes"
    public static let notesEmpty = "notes.empty"
    public static let notesRowPrefix = "notes.row."
    public static let notesDelete = "notes.delete"
    public static let notesUndo = "notes.undo"
    public static let drawers = "drawers"
    public static let drawersUnsorted = "drawers.unsorted"
    public static let drawersUnsortedCount = "drawers.unsorted.count"
    public static let drawersTrash = "drawers.trash"
    public static let trash = "trash"
    public static let trashEmpty = "trash.empty"
    public static let trashRowPrefix = "trash.row."
    public static let trashRestorePrefix = "trash.restore."
    public static let save = "save"
    public static let saveTitle = "save.title"
    public static let saveDelete = "save.delete"
    public static let saveConfirm = "save.confirm"
    public static let saveScrim = "save.scrim"

    static func notesRow(_ id: NoteID) -> String {
        notesRowPrefix + id.rawValue.uuidString
    }

    static func trashRow(_ id: NoteID) -> String {
        trashRowPrefix + id.rawValue.uuidString
    }

    static func trashRestore(_ id: NoteID) -> String {
        trashRestorePrefix + id.rawValue.uuidString
    }
}
