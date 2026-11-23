import NoteTelemetry
import Testing

struct SaveMeasurementTests {
    struct SaveFailed: Error {}

    @Test func aSaveThatFailsPassesItsErrorOn() async {
        await #expect(throws: SaveFailed.self) {
            try await SaveMeasurement.measure { throw SaveFailed() }
        }
    }
}
