/// A value a screen follows from the store: still being read, so the screen shows nothing rather than an empty state
/// it hasn't read, or read.
enum StoreRead<Value> {
    case reading
    case read(Value)

    /// The value read, transformed by `transform`, or still being read.
    func map<Transformed>(_ transform: (Value) -> Transformed) -> StoreRead<Transformed> {
        switch self {
        case .reading: .reading
        case .read(let value): .read(transform(value))
        }
    }
}

extension StoreRead: Equatable where Value: Equatable {}
