import Foundation
import NoteCore
import Testing

struct DraftReopeningTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func theCutoffIsFiveMinutesBeforeNow() {
        #expect(DraftReopening.cutoff(now: now) == Date(timeIntervalSince1970: 1_000_000 - 300))
    }

    @Test func aDraftModifiedJustInsideTheWindowReopens() {
        #expect(DraftReopening.reopens(modifiedAt: now.addingTimeInterval(-299), now: now))
    }

    @Test func aDraftModifiedAtTheWindowsEdgeDoesNotReopen() {
        #expect(!DraftReopening.reopens(modifiedAt: now.addingTimeInterval(-300), now: now))
    }
}
