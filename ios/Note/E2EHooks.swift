#if E2E
    import Foundation

    /// Launch arguments the UI tests start the app with, to put it in a known state. Only the E2E configuration builds
    /// this file, so no other build can be put in such a state.
    enum E2EHooks {
        /// Deletes every file in the folder that holds the database at `location`, the database's own folder, when the
        /// app was launched with `-reset-storage`, so it starts with no notes. Runs before the database opens.
        static func emptyDatabaseFolderIfAsked(holding location: URL) {
            guard ProcessInfo.processInfo.arguments.contains("-reset-storage") else {
                return
            }
            let fileManager = FileManager.default
            let folder = location.deletingLastPathComponent()
            do {
                for file in try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                    try fileManager.removeItem(at: file)
                }
            } catch {
                fatalError("-reset-storage couldn't empty \(folder.path): \(error)")
            }
        }
    }
#endif
