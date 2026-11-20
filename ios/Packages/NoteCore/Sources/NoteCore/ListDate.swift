public import Foundation

/// The date column of the notes list.
public enum ListDate {
    /// `now` under a minute before `now`, or after it. `today` earlier the same day. `9 Nov` before that, in any year,
    /// so the date fits its column. Days are those of `calendar`, in its time zone.
    public static func text(for date: Date, now: Date, calendar: Calendar) -> String {
        if now.timeIntervalSince(date) < 60 {
            return "now"
        }
        if calendar.isDate(date, inSameDayAs: now) {
            return "today"
        }
        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(day: .defaultDigits) \(month: .abbreviated)", locale: Locale(identifier: "en_US_POSIX"),
                timeZone: calendar.timeZone, calendar: calendar))
    }
}
