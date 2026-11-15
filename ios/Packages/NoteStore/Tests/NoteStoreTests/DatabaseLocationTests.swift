import Foundation
import NoteStore
import Testing

struct DatabaseLocationTests {
    final class FolderCreationSkippingFileManager: FileManager {
        override func createDirectory(
            at url: URL, withIntermediateDirectories createIntermediates: Bool,
            attributes: [FileAttributeKey: Any]? = nil
        ) throws {}
    }

    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    @Test func theDefaultLocationIsInsideApplicationSupport() throws {
        let applicationSupport = try #require(
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)

        let location = try NoteDatabase.defaultLocation(fileManager: FolderCreationSkippingFileManager())

        #expect(location.path == applicationSupport.appending(components: "Note", "notes.sqlite").path)
        #expect(!location.pathComponents.contains("Caches"))
        #expect(!location.pathComponents.contains("tmp"))
    }

    @Test func aDatabaseOpenedOnDiskIsNotExcludedFromBackup() throws {
        let location = folder.url.appending(path: "notes.sqlite")

        _ = try NoteDatabase.openOnDisk(at: location)

        #expect(try location.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == false)
    }
}
