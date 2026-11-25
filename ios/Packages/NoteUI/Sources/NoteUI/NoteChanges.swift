/// Runs changes to the stored notes one after another: each starts once every earlier one has finished, whether or not
/// that one failed. A store iOS suspended can't finish over a later change, and a change made from the list can't land
/// before the store leaving write started, which writes the whole note. The strip hands one to every model that
/// changes notes.
final class NoteChanges {
    private var last: Task<Void, any Error>?

    /// Runs `change` after every earlier change, and waits for it.
    func run(_ change: @escaping () async throws -> Void) async throws {
        let previous = last
        let next = Task {
            _ = await previous?.result
            try await change()
        }
        last = next
        try await next.value
    }
}
