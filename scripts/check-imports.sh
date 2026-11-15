#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/check-lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

set_swift_source_folders check-imports
set_swift_test_folders check-imports

find "${swift_source_folders[@]}" "${swift_test_folders[@]}" -name '*.swift' -exec awk '
    BEGIN {
        attributes = "(@[A-Za-z_]+(\\([^)]*\\))?[[:space:]]+)*"
        access = "((public|package|internal|fileprivate|private)[[:space:]]+)?"
        kind = "((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?"
        import_prefix = "^[[:space:]]*" attributes access "import[[:space:]]+" kind
    }

    function violate(rule, imported) {
        printf "%s: %s:%d imports %s\n", rule, FILENAME, FNR, imported > "/dev/stderr"
        failed = 1
    }

    FNR == 1 {
        split(FILENAME, path, "/")
        if (path[2] == "Packages") {
            package = path[3]
            target = path[5]
        } else {
            package = path[2]
            target = path[2]
        }
    }

    match($0, import_prefix) {
        imported = substr($0, RSTART + RLENGTH)
        sub(/[^A-Za-z0-9_].*/, "", imported)

        if (imported == "GRDB" && package != "NoteStore") violate("only NoteStore imports GRDB", imported)
        if (imported == "NoteStore" && target == "NoteUI") violate("NoteUI never imports NoteStore", imported)
        if (imported != "Foundation" && target == "NoteCore") violate("NoteCore imports only Foundation", imported)
        if ((imported == "os" || imported == "OSLog") && package != "NoteTelemetry") violate("only NoteTelemetry imports os or OSLog", imported)
    }

    END { exit failed }
' {} +
