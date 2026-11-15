enum Event: String {
    case appLaunched = "app.launched"
}

struct Op {
    static let appLaunch = Op(name: "app.launch", completed: .appLaunched)

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
