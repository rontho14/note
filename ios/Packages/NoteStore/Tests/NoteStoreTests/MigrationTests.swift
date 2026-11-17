import Foundation
import GRDB
import NoteCore
import NoteCoreTesting
import Testing

@testable import NoteStore

struct MigrationTests {
    struct Schema: Equatable {
        let tables: [String]
        let isStrict: Bool?
        let columns: [[String]]
        let indexedColumns: [String]
    }

    let folder: TemporaryFolder

    init() throws {
        folder = try TemporaryFolder()
    }

    @Test func anEmptyDatabaseEndsAtTheLatestSchema() throws {
        let database = try DatabaseQueue()
        try migrator.migrate(database)

        let schema = try database.read { db in
            Schema(
                tables: try String.fetchAll(
                    db,
                    sql:
                        "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT GLOB 'sqlite_*' AND name NOT GLOB 'grdb_*'"
                ),
                isStrict: try Bool.fetchOne(db, sql: "SELECT strict FROM pragma_table_list WHERE name = 'note'"),
                columns: try Row.fetchAll(
                    db, sql: "SELECT name, type, \"notnull\", dflt_value, pk FROM pragma_table_info('note')"
                )
                .map { row in
                    [
                        row["name"], row["type"], String(row["notnull"] as Int), row["dflt_value"] ?? "",
                        String(row["pk"] as Int),
                    ]
                },
                indexedColumns: try db.indexes(on: "note").filter { !$0.isUnique }.flatMap(\.columns)
            )
        }

        #expect(
            schema
                == Schema(
                    tables: ["note"],
                    isStrict: true,
                    columns: [
                        ["id", "BLOB", "1", "", "1"],
                        ["text", "TEXT", "1", "", "0"],
                        ["createdAt", "TEXT", "1", "", "0"],
                        ["modifiedAt", "TEXT", "1", "", "0"],
                        ["cursor", "INTEGER", "1", "0", "0"],
                    ],
                    indexedColumns: ["modifiedAt"]
                )
        )
    }

    @Test func aNoteWrittenAtVersionOneReadsBackByteForByteWithTheCursorAtTheStart() async throws {
        let location = folder.url.appending(path: "notes.sqlite")
        let id = UUID()
        let text = "Emoji 👩🏽‍💻🇧🇷 and combining e\u{301}\r\nCRLF\r\n"
        let versionOne = try DatabaseQueue(path: location.path)
        try migrator.migrate(versionOne, upTo: "v1")
        try await versionOne.write { db in
            try db.execute(
                literal: """
                    INSERT INTO note (id, text, createdAt, modifiedAt)
                    VALUES (\(id), \(text), \(Date.milliseconds(1)), \(Date.milliseconds(2)))
                    """
            )
        }
        try versionOne.close()

        let stored = try #require(try await NoteDatabase.openOnDisk(at: location).note(id: NoteID(rawValue: id)))

        #expect(Array(stored.text.utf8) == Array(text.utf8))
        #expect(stored.cursor == 0)
        #expect(stored.modifiedAt == .milliseconds(2))
    }
}
