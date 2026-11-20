import Foundation
import NoteCore
import Testing

struct ListDateTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))
            ?? .distantPast
    }

    @Test func aNoteModifiedUnderAMinuteAgoIsNow() {
        #expect(
            ListDate.text(for: date(2026, 11, 9, 15, 0, 1), now: date(2026, 11, 9, 15, 1, 0), calendar: calendar)
                == "now")
    }

    @Test func aNoteModifiedAMinuteAgoTheSameDayIsToday() {
        #expect(
            ListDate.text(for: date(2026, 11, 9, 15, 0, 0), now: date(2026, 11, 9, 15, 1, 0), calendar: calendar)
                == "today")
    }

    @Test func aNoteModifiedJustAfterMidnightIsToday() {
        #expect(
            ListDate.text(for: date(2026, 11, 9, 0, 0, 0), now: date(2026, 11, 9, 23, 59, 0), calendar: calendar)
                == "today")
    }

    @Test func aNoteModifiedJustBeforeMidnightIsYesterdaysDate() {
        #expect(
            ListDate.text(for: date(2026, 11, 8, 23, 59, 0), now: date(2026, 11, 9, 0, 1, 0), calendar: calendar)
                == "8 Nov")
    }

    @Test func midnightIsCountedInTheCalendarsTimeZone() {
        var utc = calendar
        utc.timeZone = .gmt
        let modified = date(2026, 11, 8, 20, 0, 0)
        let now = date(2026, 11, 8, 22, 0, 0)

        #expect(ListDate.text(for: modified, now: now, calendar: calendar) == "today")
        #expect(ListDate.text(for: modified, now: now, calendar: utc) == "8 Nov")
    }

    @Test func aNoteFromEarlierThisYearShowsDayAndMonth() {
        #expect(ListDate.text(for: date(2026, 9, 9), now: date(2026, 11, 9), calendar: calendar) == "9 Sep")
    }

    @Test func aNoteFromAnEarlierYearShowsOnlyDayAndMonth() {
        #expect(
            ListDate.text(for: date(2025, 12, 31, 23, 0), now: date(2026, 1, 1, 0, 30), calendar: calendar) == "31 Dec")
    }

    @Test func aNoteModifiedAfterNowIsNow() {
        #expect(ListDate.text(for: date(2026, 11, 10), now: date(2026, 11, 9), calendar: calendar) == "now")
    }
}
