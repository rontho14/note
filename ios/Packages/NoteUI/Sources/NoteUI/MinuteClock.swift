import Foundation
import SwiftUI

extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    /// Once a minute, counted from now. The trash ticks with it rather than with `.everyMinute`, whose dates fall at
    /// the start of each minute, up to a minute before now, and would give a note one day more than it has left.
    static var everyMinuteFromNow: PeriodicTimelineSchedule {
        .periodic(from: .now, by: 60)
    }
}
