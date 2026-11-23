import GRDB

let migrator: DatabaseMigrator = {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1") { db in
        try db.create(table: "note", options: .strict) { table in
            table.primaryKey("id", .blob)
            table.column("text", .text).notNull()
            table.column("createdAt", .text).notNull()
            table.column("modifiedAt", .text).notNull()
        }
    }
    migrator.registerMigration("v2") { db in
        try db.alter(table: "note") { table in
            table.add(column: "cursor", .integer).notNull().defaults(to: 0)
        }
        try db.create(indexOn: "note", columns: ["modifiedAt"])
    }
    migrator.registerMigration("v3") { db in
        try db.alter(table: "note") { table in
            table.add(column: "title", .text)
            table.add(column: "savedAt", .text)
            table.add(column: "trashedAt", .text)
        }
    }
    return migrator
}()
