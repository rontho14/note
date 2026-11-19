/// Runs a read or change of the notes, such as a draft's save or the notes list's read loop, and stops the app if it
/// fails. A store that fails is lost or unreadable notes with no screen to say so, so the app stops, as it does for a
/// database that won't open. The typing since the last successful save is lost.
func stoppingTheAppOnFailure(_ change: () async throws -> Void) async {
    do {
        try await change()
    } catch {
        fatalError("The notes couldn't be loaded or stored: \(error)")
    }
}

/// Starts `change` in a task of its own, without waiting for it to finish. A change that fails stops the app, as in
/// `stoppingTheAppOnFailure`.
func startNotesChange(_ change: @escaping () async throws -> Void) {
    Task { await stoppingTheAppOnFailure(change) }
}
