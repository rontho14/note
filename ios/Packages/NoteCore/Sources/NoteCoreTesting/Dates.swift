public import Foundation

extension Date {
    /// A fixed moment for tests, `count` milliseconds after 1970.
    public static func milliseconds(_ count: Int64) -> Date {
        Date(timeIntervalSince1970: Double(count) / 1_000)
    }

    /// A fixed moment for tests, `count` minutes after 1970.
    public static func minutes(_ count: Double) -> Date {
        Date(timeIntervalSince1970: count * 60)
    }
}
