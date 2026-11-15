@MainActor
public final class LaunchMeasurement {
    private var interval: Telemetry.Interval?

    private init(_ interval: consuming Telemetry.Interval) {
        self.interval = consume interval
    }

    public static func begin() -> LaunchMeasurement {
        LaunchMeasurement(Telemetry.begin(.appLaunch))
    }

    @discardableResult
    public func recordLaunched() -> Duration? {
        interval.take()?.end()
    }
}
