import Testing

@testable import NoteUI

/// Waits for `condition`, which a model meets once the store has answered, failing after two seconds.
@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(2)
    while !condition() {
        try #require(ContinuousClock.now < deadline, "the model never showed what the store holds")
        try await Task.sleep(for: .milliseconds(10))
    }
}

extension StoreRead {
    /// The value read, or nil while it is being read, for a test to require.
    var readValue: Value? {
        if case .read(let value) = self { value } else { nil }
    }
}
