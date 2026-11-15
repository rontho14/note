import os

enum Telemetry {
    struct Interval: ~Copyable {
        let op: Op
        fileprivate let state: OSSignpostIntervalState
        fileprivate let start: ContinuousClock.Instant

        consuming func end() -> Duration {
            let duration = ContinuousClock.now - start
            signposter.endInterval(op.name, state)
            Telemetry.event(op.completed, .durationMs(Int(duration / .milliseconds(1))))
            return duration
        }
    }

    private static let subsystem = "com.rontho14.note"
    private static let logger = Logger(subsystem: subsystem, category: "event")
    private static let signposter = OSSignposter(subsystem: subsystem, category: "perf")

    static func begin(_ op: Op) -> Interval {
        Interval(op: op, state: signposter.beginInterval(op.name, id: signposter.makeSignpostID()), start: .now)
    }

    static func event(_ event: Event, _ fields: Field...) {
        logger.log("\(line(event, fields), privacy: .public)")
    }

    static func line(_ event: Event, _ fields: [Field]) -> String {
        ([event.rawValue] + fields.map(\.pair)).joined(separator: " ")
    }
}
