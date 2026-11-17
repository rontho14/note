import Foundation
import NoteCore
import Testing

struct DraftReopeningTests {
    @Test func theCutoffIsFiveMinutesBeforeNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        #expect(DraftReopening.cutoff(now: now) == Date(timeIntervalSince1970: 1_000_000 - 300))
    }
}
