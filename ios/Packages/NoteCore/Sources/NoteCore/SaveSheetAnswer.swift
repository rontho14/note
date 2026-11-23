/// The save sheet's Save, with the title typed, or its Delete.
public enum SaveSheetAnswer: Sendable, Equatable {
    case save(title: String)
    case delete
}
