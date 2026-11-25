/// Runs changes to the stored notes one after another: each starts once every earlier one has finished, whether or not
/// that one failed. A store iOS suspended can't finish over a later change, and a change made from the list can't land
/// before the store leaving write started, which writes the whole note. The strip hands one to every model that
/// changes notes.
final class NoteChanges {
    private var last: Task<Void, Never>?

    /// Runs `change` after every earlier change, waits for it, and returns what it returns.
    func run<Result: Sendable>(_ change: @escaping () async throws -> Result) async throws -> Result {
        let previous = last
        let next = Task {
            await previous?.value
            return try await change()
        }
        last = Task { _ = await next.result }
        return try await next.value
    }
}
