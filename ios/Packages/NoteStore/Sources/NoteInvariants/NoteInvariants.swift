import Foundation
import NoteCore
import NoteStore

@main
enum NoteInvariants {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()
        guard arguments.count == 1, let container = arguments.first else {
            report("usage: NoteInvariants <app data container>")
            exit(1)
        }
        let database = NoteDatabase.location(
            inApplicationSupport: URL(filePath: container).appending(components: "Library", "Application Support"))
        do {
            let emptyNotes = try await NoteDatabase.emptyNoteIDs(inDatabaseAt: database)
            for id in emptyNotes {
                report("an empty note is never stored: \(database.path) \(id.rawValue.uuidString)")
            }
            exit(emptyNotes.isEmpty ? 0 : 1)
        } catch {
            report("NoteInvariants: \(database.path): \(error)")
            exit(1)
        }
    }

    private static func report(_ line: String) {
        FileHandle.standardError.write(Data("\(line)\n".utf8))
    }
}
