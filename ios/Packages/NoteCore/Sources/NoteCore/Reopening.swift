public import Foundation

/// How recent a note must be for launch and return to reopen it instead of starting a blank one.
public enum Reopening {
    public static let window: Duration = .seconds(300)

    /// A note reopens when it was modified after this moment. The store takes it to find the recent note.
    public static func cutoff(now: Date) -> Date {
        now.addingTimeInterval(-(window / .seconds(1)))
    }

    /// Whether a note modified at `modifiedAt` is still inside the window at `now`.
    public static func reopens(modifiedAt: Date, now: Date) -> Bool {
        modifiedAt > cutoff(now: now)
    }
}
