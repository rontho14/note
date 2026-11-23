/// The text on the write screen, as a store of it reads it.
public enum TextOnScreen: Sendable {
    /// Text that isn't empty, with the caret where typing would continue.
    case typed(String, caret: String.Index)
    /// Text erased to nothing but whitespace, after `lastText`, the last text on screen that wasn't.
    case erased(lastText: String)
}
