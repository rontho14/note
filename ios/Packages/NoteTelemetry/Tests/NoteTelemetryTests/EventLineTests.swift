import Testing

@testable import NoteTelemetry

struct EventLineTests {
    @Test(arguments: [
        (Event.appLaunched, "app.launched note.op.duration_ms=412"),
        (Event.noteSaved, "note.saved note.op.duration_ms=412"),
    ])
    func aLineIsTheEventFollowedByItsFields(event: Event, line: String) {
        #expect(Telemetry.line(event, [.durationMs(412)]) == line)
    }

    @Test func anEventWithoutFieldsIsItsNameAlone() {
        #expect(Telemetry.line(.appLaunched, []) == "app.launched")
    }
}
