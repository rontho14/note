/// The save sheet's Save, with the title typed, or its Delete.
public enum SaveSheetAnswer: Sendable, Equatable {
    case save(title: String)
    case delete
}

/// Whether the save sheet over the draft on write was answered, and how.
public enum SaveSheetOutcome: Sendable, Equatable {
    case unanswered
    case answered(SaveSheetAnswer)
}
