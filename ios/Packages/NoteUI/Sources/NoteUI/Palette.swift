import SwiftUI

/// The colors the screens draw. `paper` is also `LaunchBackground` in the app's asset catalog, and `check-owners.sh`
/// fails when the two differ.
enum Palette {
    static let paper = Color(red: 0xF8 / 255, green: 0xF4 / 255, blue: 0xEC / 255)
    static let ink = Color(red: 0x1A / 255, green: 0x1C / 255, blue: 0x12 / 255)
    /// Note Rome's accent.
    static let accent = Color(red: 0x66 / 255, green: 0x02 / 255, blue: 0x3C / 255)
}
