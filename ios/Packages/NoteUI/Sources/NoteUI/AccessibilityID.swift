import Foundation
import NoteCore

public enum AccessibilityID {
    public static let write = "write"
    public static let writeText = "write.text"
    public static let notes = "notes"
    public static let notesEmpty = "notes.empty"
    public static let notesRowPrefix = "notes.row."
    public static let notesRename = "notes.rename"
    public static let notesDelete = "notes.delete"
    public static let notesUndo = "notes.undo"
    public static let drawers = "drawers"
    public static let drawersUnsorted = "drawers.unsorted"
    public static let drawersCount = "drawers.count"
    public static let drawersTrash = "drawers.trash"
    public static let trash = "trash"
    public static let trashEmpty = "trash.empty"
    public static let trashRowPrefix = "trash.row."
    public static let trashRestorePrefix = "trash.restore."
    public static let save = SheetID("save")
    public static let saveDelete = "save.delete"
    public static let rename = SheetID("rename")

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

/// A title sheet's identifiers, each built from the sheet's name, so every sheet names its parts alike.
public struct SheetID: Sendable {
    /// The sheet's outermost view.
    public let sheet: String

    init(_ sheet: String) {
        self.sheet = sheet
    }

    public var title: String { "\(sheet).title" }
    public var confirm: String { "\(sheet).confirm" }
    public var scrim: String { "\(sheet).scrim" }
}
