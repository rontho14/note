import Foundation
import NoteCore
import Testing

struct TrashExpiryTests {
    private let now = Date(timeIntervalSince1970: 100 * day)

    @Test func aNoteTrashedMoreThanThirtyDaysAgoIsExpiredAndOneTrashedLessIsKept() {
        #expect(TrashExpiry.isExpired(trashedAt: now - 31 * day, now: now))
        #expect(!TrashExpiry.isExpired(trashedAt: now - 29 * day, now: now))
        #expect(!TrashExpiry.isExpired(trashedAt: now - 30 * day, now: now))
        #expect(TrashExpiry.isExpired(trashedAt: now - 30 * day - 1, now: now))
    }

    @Test(arguments: [
        (0, 30),
        (1, 29),
        (29.5, 1),
        (29.999, 1),
        (31, 1),
        (-2, 30),
    ])
    func daysLeftRoundUpAndStayBetweenOneAndThirty(daysAgo: Double, left: Int) {
        #expect(TrashExpiry.daysLeft(trashedAt: now - daysAgo * day, now: now) == left)
    }
}

private let day: TimeInterval = 24 * 60 * 60
