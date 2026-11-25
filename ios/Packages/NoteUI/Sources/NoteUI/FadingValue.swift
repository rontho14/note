import Observation

/// A value shown for a while, such as the note just saved or the one Undo can bring back, cleared once its duration
/// has passed. A later value takes over with a full duration of its own.
@Observable
final class FadingValue<Value> {
    private(set) var value: Value?
    private let duration: Duration
    private var fading: Task<Void, Never>?

    init(lasting duration: Duration) {
        self.duration = duration
    }

    /// Shows `value`, and clears it after the duration.
    func show(_ value: Value) {
        self.value = value
        resume()
    }

    /// Keeps the value shown until `resume()`, as while VoiceOver reads it.
    func pause() {
        fading?.cancel()
    }

    /// Clears the value after a full duration from now.
    func resume() {
        fading?.cancel()
        fading = Task {
            do {
                try await Task.sleep(for: duration)
            } catch {
                return  // A later value, a pause or a clear took over.
            }
            value = nil
        }
    }

    func clear() {
        fading?.cancel()
        value = nil
    }
}
