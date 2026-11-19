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

    static func notesRow(_ id: NoteID) -> String {
        notesRowPrefix + id.rawValue.uuidString
    }
}
