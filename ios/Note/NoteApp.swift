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
            let location = try NoteDatabase.defaultLocation(fileManager: .default)
            #if E2E
                storage = try E2EHooks.openStorage(at: location)
            #else
                storage = try NoteDatabase.openOnDisk(at: location)
            #endif
        } catch {
            fatalError(error.description)
        }
    }

    var body: some Scene {
        WindowGroup {
            ScreenStrip(storage: storage, onKeyboardUp: { launch.recordLaunched() })
        }
    }
}
