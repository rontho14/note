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
    return migrator
}()
