public import Foundation

public struct NoteID: Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

public struct Note: Sendable {
    public let id: NoteID
    public var text: String
    public let createdAt: Date
    public var modifiedAt: Date

    public init(id: NoteID, text: String, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
