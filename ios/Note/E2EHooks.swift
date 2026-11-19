#if E2E
    import Foundation
    import NoteCore
    import NoteStore

    /// Launch arguments the UI tests start the app with, to put it in a known state. Only the E2E configuration builds
    /// this file, so no other build can be put in such a state.
    enum E2EHooks {
        /// Opens the database at `location` the way the launch arguments ask: emptied first for `-reset-storage`, and
        /// filled afterwards for `-seed-notes <count>`.
        static func openStorage(at location: URL) throws(NoteDatabaseError) -> SQLiteNoteStorage {
            emptyDatabaseFolderIfAsked(holding: location)
            let storage = try NoteDatabase.openOnDisk(at: location)
            seedNotesIfAsked(into: storage)
            return storage
        }

        /// Deletes every file in the folder that holds the database at `location`, the database's own folder, when the
        /// app was launched with `-reset-storage`, so it starts with no notes.
        private static func emptyDatabaseFolderIfAsked(holding location: URL) {
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

        /// Starts saving `count` fixed notes into `storage` when the app was launched with `-seed-notes <count>`. Their
        /// lengths cycle through one word, one long line and many lines, and each was modified a minute before the
        /// next, all long ago, so none reopens on write.
        private static func seedNotesIfAsked(into storage: any NoteStorage) {
            let arguments = ProcessInfo.processInfo.arguments
            guard let flag = arguments.firstIndex(of: "-seed-notes") else {
                return
            }
            guard arguments.indices.contains(flag + 1), let count = Int(arguments[flag + 1]), count > 0 else {
                fatalError("-seed-notes needs a positive count")
            }
            let newest = Date(timeIntervalSince1970: 1_767_225_600)
            let notes = (0..<count).map { index in
                let modified = newest.addingTimeInterval(-60 * Double(index))
                return Note(
                    id: NoteID(rawValue: UUID()), text: seededText(index), cursor: 0, createdAt: modified,
                    modifiedAt: modified)
            }
            Task {
                do {
                    try await storage.save(contentsOf: notes)
                } catch {
                    fatalError("-seed-notes couldn't save the notes: \(error)")
                }
            }
        }

        private static func seededText(_ index: Int) -> String {
            switch index % 3 {
            case 0: "Seeded \(index)"
            case 1: "Seeded \(index) " + String(repeating: "on one long line that runs past the screen ", count: 4)
            default: (1...12).map { "Seeded \(index), line \($0)" }.joined(separator: "\n")
            }
        }
    }
#endif
