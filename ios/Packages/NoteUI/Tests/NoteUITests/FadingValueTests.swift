import Testing

@testable import NoteUI

@MainActor
struct FadingValueTests {
    private let duration = Duration.milliseconds(200)

    @Test func aValueShowsForItsDurationThenClears() async throws {
        let fading = FadingValue<Int>(lasting: duration)

        fading.show(1)

        #expect(fading.showing == .shown(1))
        try await Task.sleep(for: duration * 1.5)
        #expect(fading.showing == .hidden)
    }

    @Test func aLaterValueTakesOverForAFullDuration() async throws {
        let fading = FadingValue<Int>(lasting: duration)
        fading.show(1)
        try await Task.sleep(for: duration * 0.6)

        fading.show(2)
        try await Task.sleep(for: duration * 0.6)

        #expect(fading.showing == .shown(2))
        try await Task.sleep(for: duration)
        #expect(fading.showing == .hidden)
    }

    @Test func aPausedValueStaysUntilResumedThenFadesAfterAFullDuration() async throws {
        let fading = FadingValue<Int>(lasting: duration)
        fading.show(1)

        fading.pause()
        try await Task.sleep(for: duration * 1.5)
        #expect(fading.showing == .shown(1))

        fading.resume()
        try await Task.sleep(for: duration * 0.6)
        #expect(fading.showing == .shown(1))
        try await Task.sleep(for: duration)
        #expect(fading.showing == .hidden)
    }

    @Test func clearingLowersTheValueAtOnce() {
        let fading = FadingValue<Int>(lasting: duration)
        fading.show(1)

        fading.clear()

        #expect(fading.showing == .hidden)
    }
}
