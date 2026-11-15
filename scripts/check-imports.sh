#!/usr/bin/env bash
set -euo pipefail

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

scanned=(ios/Note ios/NoteE2ETests ios/Packages/*/Sources)

for folder in "${scanned[@]}"; do
    if [[ ! -d "$folder" ]]; then
        echo "check-imports: $folder is missing, so its imports can't be checked" >&2
        exit 2
    fi
done

find "${scanned[@]}" -name '*.swift' -exec awk '
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
        module = FILENAME
        if (!sub(/.*\/Sources\//, "", module)) sub(/^ios\//, "", module)
        sub(/\/.*/, "", module)
    }

    match($0, import_prefix) {
        imported = substr($0, RSTART + RLENGTH)
        sub(/[^A-Za-z0-9_].*/, "", imported)

        if (imported == "GRDB" && module != "NoteStore") violate("only NoteStore imports GRDB", imported)
        if (imported == "NoteStore" && module == "NoteUI") violate("NoteUI never imports NoteStore", imported)
        if (imported != "Foundation" && module == "NoteCore") violate("NoteCore imports only Foundation", imported)
    }

    END { exit failed }
' {} +
