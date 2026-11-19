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
                E2EHooks.emptyDatabaseFolderIfAsked(holding: location)
            #endif
            storage = try NoteDatabase.openOnDisk(at: location)
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
