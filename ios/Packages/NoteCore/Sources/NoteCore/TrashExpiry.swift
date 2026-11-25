public import Foundation

/// How long the trash keeps a note: 30 days from when it went there, counted in days of 24 hours, so a daylight
/// saving change doesn't move a purge.
public enum TrashExpiry {
    /// A day of 24 hours.
    public static let day: TimeInterval = 24 * 60 * 60
    public static let keptForDays = 30
    private static let keptFor = Double(keptForDays) * day

    /// Notes trashed before this are past their 30 days at `now`.
    public static func cutoff(now: Date) -> Date {
        now - keptFor
    }

    public static func isExpired(trashedAt: Date, now: Date) -> Bool {
        trashedAt < cutoff(now: now)
    }

    /// The whole days a note has left in the trash, rounded up and between 1 and 30: a note trashed a moment ago has
    /// 30, one in its last day or past its 30 days but not yet purged has 1, and one whose trash date is after `now`,
    /// because the clock was moved back, has 30.
    public static func daysLeft(trashedAt: Date, now: Date) -> Int {
        let left = Int(((trashedAt + keptFor).timeIntervalSince(now) / day).rounded(.up))
        return min(max(left, 1), keptForDays)
    }
}
