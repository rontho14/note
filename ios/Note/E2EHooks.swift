#if E2E
    import Foundation
    import NoteCore
    import NoteStore

    /// Launch arguments the UI tests start the app with, to put it in a known state. Only the E2E configuration builds
    /// this file, so no other build can be put in such a state.
    enum E2EHooks {
        /// Opens the database at `location` the way the launch arguments ask: emptied first for `-reset-storage`, and
        /// filled afterwards for `-seed-notes <count>` and `-seed-trash <kind>:<days>,…`.
        static func openStorage(at location: URL) throws(NoteDatabaseError) -> SQLiteNoteStorage {
            emptyDatabaseFolderIfAsked(holding: location)
            let storage = try NoteDatabase.openOnDisk(at: location)
            seedNotesIfAsked(into: storage)
            seedTrashIfAsked(into: storage)
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
        /// next, all `longAgo`.
        private static func seedNotesIfAsked(into storage: any NoteStorage) {
            guard let argument = argument(after: "-seed-notes") else {
                return
            }
            guard let count = Int(argument), count > 0 else {
                fatalError("-seed-notes needs a positive count")
            }
            let notes = (0..<count).map { index in
                let modified = longAgo.addingTimeInterval(-60 * Double(index))
                return Note(
                    id: NoteID(rawValue: UUID()), text: seededText(index), cursor: 0, createdAt: modified,
                    modifiedAt: modified)
            }
            startSaving(notes, into: storage, for: "-seed-notes")
        }

        /// Starts saving notes already in the trash into `storage` when the app was launched with
        /// `-seed-trash <kind>:<days>,…`, such as `saved:1,draft:29`: one note per entry, saved or a draft, trashed that
        /// many days before launch, its text naming both. A note trashed days ago is the one state the screens can't
        /// reach.
        private static func seedTrashIfAsked(into storage: any NoteStorage) {
            guard let argument = argument(after: "-seed-trash") else {
                return
            }
            let launch = Date.now
            let notes = argument.split(separator: ",").map { entry in
                let parts = entry.split(separator: ":")
                guard parts.count == 2, let kind = SeededKind(rawValue: String(parts[0])), let days = Int(parts[1])
                else {
                    fatalError("-seed-trash entries are saved:<days> or draft:<days>, not \(entry)")
                }
                return Note(
                    id: NoteID(rawValue: UUID()), text: "Trashed \(kind.rawValue) \(days)", cursor: 0,
                    createdAt: longAgo, modifiedAt: longAgo, savedAt: kind == .saved ? longAgo : nil,
                    trashedAt: launch - Double(days) * TrashExpiry.day)
            }
            startSaving(notes, into: storage, for: "-seed-trash")
        }

        /// When the seeded notes were modified: long ago, so none reopens on write.
        private static let longAgo = Date(timeIntervalSince1970: 1_767_225_600)

        /// The launch argument after `flag`, or nil when the app was launched without `flag`. A `flag` with nothing
        /// after it stops the app, since a test asked for it.
        private static func argument(after flag: String) -> String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: flag) else {
                return nil
            }
            guard arguments.indices.contains(index + 1) else {
                fatalError("\(flag) needs a value after it")
            }
            return arguments[index + 1]
        }

        /// Whether a seeded note in the trash was saved or a draft.
        private enum SeededKind: String {
            case saved, draft
        }

        /// Starts saving `notes` into `storage`, stopping the app if they can't be saved, since `flag` asked for them.
        private static func startSaving(_ notes: [Note], into storage: any NoteStorage, for flag: String) {
            Task {
                do {
                    try await storage.save(contentsOf: notes)
                } catch {
                    fatalError("\(flag) couldn't save the notes: \(error)")
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
