import NoteStore
import NoteTelemetry
import NoteUI
import SwiftUI

@main
struct NoteApp: App {
    private let launch = LaunchMeasurement.begin()
    private let storage: SQLiteNoteStorage

    init() {
        do throws(NoteDatabaseError) {
            storage = try NoteDatabase.openOnDisk(at: NoteDatabase.defaultLocation(fileManager: .default))
        } catch {
            fatalError(error.description)
        }
    }

    var body: some Scene {
        WindowGroup {
            WriteScreen(onKeyboardUp: { launch.recordLaunched() })
        }
    }
}
