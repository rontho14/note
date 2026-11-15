import NoteTelemetry
import Testing

struct LaunchMeasurementTests {
    @Test @MainActor func onlyTheFirstRecordReturnsADuration() {
        let launch = LaunchMeasurement.begin()

        #expect(launch.recordLaunched() != nil)
        #expect(launch.recordLaunched() == nil)
    }
}
