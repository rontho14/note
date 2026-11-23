/// Measures a note's save as `note.save`. Only a save that completes logs `note.saved` with its duration.
public enum SaveMeasurement {
    public static func measure(_ save: () async throws -> Void) async rethrows {
        let interval = Telemetry.begin(.noteSave)
        do {
            try await save()
        } catch {
            interval.abandon()
            throw error
        }
        _ = interval.end()
    }
}
