import Foundation
import NoteCore

public enum AccessibilityID {
    public static let write = "write"
    public static let writeText = "write.text"
    public static let notes = "notes"
    public static let notesEmpty = "notes.empty"
    public static let notesRowPrefix = "notes.row."
    public static let drawers = "drawers"
    public static let drawersUnsorted = "drawers.unsorted"
    public static let save = "save"
    public static let saveTitle = "save.title"
    public static let saveDelete = "save.delete"
    public static let saveConfirm = "save.confirm"
    public static let saveScrim = "save.scrim"

    static func notesRow(_ id: NoteID) -> String {
        notesRowPrefix + id.rawValue.uuidString
    }
}
