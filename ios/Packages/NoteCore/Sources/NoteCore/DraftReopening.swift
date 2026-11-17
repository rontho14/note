public import Foundation

/// How recent a note must be for launch and return to reopen it instead of starting a blank one.
public enum DraftReopening {
    public static let window: Duration = .seconds(300)

    /// A note reopens when it was modified after this moment.
    public static func cutoff(now: Date) -> Date {
        now.addingTimeInterval(-(window / .seconds(1)))
    }
}
