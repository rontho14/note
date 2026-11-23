enum Event: String {
    case appLaunched = "app.launched"
    case noteSaved = "note.saved"
}

struct Op {
    static let appLaunch = Op(name: "app.launch", completed: .appLaunched)
    static let noteSave = Op(name: "note.save", completed: .noteSaved)

    let name: StaticString
    let completed: Event
}

enum Field {
    case durationMs(Int)

    var pair: String {
        switch self {
        case .durationMs(let milliseconds): "note.op.duration_ms=\(milliseconds)"
        }
    }
}
