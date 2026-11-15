import Testing

@testable import NoteTelemetry

struct EventLineTests {
    @Test func aLineIsTheEventFollowedByItsFields() {
        #expect(Telemetry.line(.appLaunched, [.durationMs(412)]) == "app.launched note.op.duration_ms=412")
    }

    @Test func anEventWithoutFieldsIsItsNameAlone() {
        #expect(Telemetry.line(.appLaunched, []) == "app.launched")
    }
}
