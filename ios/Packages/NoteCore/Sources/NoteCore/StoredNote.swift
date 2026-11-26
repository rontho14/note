/// The stored note the text on write belongs to, as last stored.
public enum StoredNote: Sendable {
    /// The text belongs to no stored note yet, so the next store of text that isn't empty creates one.
    case notYet
    case stored(Note)
}
