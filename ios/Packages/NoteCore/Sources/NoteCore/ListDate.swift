public import Foundation

/// The date column of the notes list.
public enum ListDate {
    /// `now` under a minute before `now`, or after it. `today` earlier the same day. `9 Nov` earlier the same year, and
    /// `9 Nov 2025` before that. Days and years are those of `calendar`, in its time zone.
    public static func text(for date: Date, now: Date, calendar: Calendar) -> String {
        if now.timeIntervalSince(date) < 60 {
            return "now"
        }
        if calendar.isDate(date, inSameDayAs: now) {
            return "today"
        }
        let format: Date.FormatString =
            calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? "\(day: .defaultDigits) \(month: .abbreviated)"
            : "\(day: .defaultDigits) \(month: .abbreviated) \(year: .defaultDigits)"
        return date.formatted(
            Date.VerbatimFormatStyle(
                format: format, locale: Locale(identifier: "en_US_POSIX"), timeZone: calendar.timeZone,
                calendar: calendar))
    }
}
