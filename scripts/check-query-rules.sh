#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

# NoteRecord names each column a query filters or orders by, and each rule on the dates, once. Migrations.swift
# creates the columns, and a shipped migration never changes, so it keeps its own strings.
store_sources=ios/Packages/NoteStore/Sources/NoteStore
require_paths check-query-rules "$store_sources/NoteRecord.swift" "$store_sources/Migrations.swift"

check='
    function violate(message) {
        printf "queries order and filter by NoteRecord rules: %s:%d %s\n", FILENAME, FNR, message > "/dev/stderr"
        failed = 1
    }

    {
        code = $0
        sub(/\/\/.*/, "", code)
        if (code ~ /(ORDER BY|WHERE)[[:space:]]+[^\\[:space:]]/) {
            violate("orders or filters by raw SQL. Interpolate a rule from NoteRecord, such as \\(NoteRecord.newestFirstOrder)")
        } else if (code ~ /(^|[^A-Za-z0-9_.(])(text|cursor|createdAt|modifiedAt|title|savedAt|trashedAt)[[:space:]]+(DESC|ASC|IS[[:space:]])/) {
            violate("names a column in raw SQL. Interpolate it from NoteRecord.Columns")
        } else if (FILENAME !~ /\/NoteRecord\.swift$/ && code ~ /Column\("/) {
            violate("names a column by its string. Use NoteRecord.Columns, adding the column there")
        }
    }

    END { exit failed }
'

find "$store_sources" -name '*.swift' ! -name Migrations.swift -exec awk "$check" {} +
