import GRDB
import Testing

@testable import NoteStore

struct MigrationTests {
    struct Schema: Equatable {
        let tables: [String]
        let isStrict: Bool?
        let columns: [[String]]
    }

    @Test func anEmptyDatabaseEndsAtTheVersionOneSchema() throws {
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
                columns: try Row.fetchAll(db, sql: "SELECT name, type, \"notnull\", pk FROM pragma_table_info('note')")
                    .map { row in [row["name"], row["type"], String(row["notnull"] as Int), String(row["pk"] as Int)] }
            )
        }

        #expect(
            schema
                == Schema(
                    tables: ["note"],
                    isStrict: true,
                    columns: [
                        ["id", "BLOB", "1", "1"],
                        ["text", "TEXT", "1", "0"],
                        ["createdAt", "TEXT", "1", "0"],
                        ["modifiedAt", "TEXT", "1", "0"],
                    ]
                )
        )
    }
}
