import SwiftUI

/// The colors the screens draw. `paper` is also `LaunchBackground` in the app's asset catalog, and `check-owners.sh`
/// fails when the two differ.
enum Palette {
    static let paper = Color(red: 0xF8 / 255, green: 0xF4 / 255, blue: 0xEC / 255)
    static let ink = Color(red: 0x1A / 255, green: 0x1C / 255, blue: 0x12 / 255)
    /// Ink at 36%, behind a sheet.
    static let scrim = ink.opacity(0.36)
    /// Row dividers and quiet borders.
    static let hairline = Color(red: 0xE2 / 255, green: 0xDC / 255, blue: 0xCD / 255)
    /// Note Rome's second color, for quiet text.
    static let second = Color(red: 0x6B / 255, green: 0x5E / 255, blue: 0x53 / 255)
    /// Sheets and lifted cards.
    static let surface = Color(red: 0xFF / 255, green: 0xFD / 255, blue: 0xF8 / 255)
    /// Note Rome's accent.
    static let accent = Color(red: 0x66 / 255, green: 0x02 / 255, blue: 0x3C / 255)
    /// The accent as small text or a thin icon on paper. Note Rome's is the accent itself.
    static let accentText = accent
    /// The accent at 7%, behind the note just saved in a list.
    static let justSaved = accent.opacity(0.07)
}
