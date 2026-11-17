#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

migrations=ios/Packages/NoteStore/Sources/NoteStore/Migrations.swift
require_paths check-migrations "$migrations"
if ! git rev-parse --verify --quiet refs/heads/main >/dev/null; then
    echo "check-migrations: $root has no main branch, so it can't be checked" >&2
    exit 2
fi

# Prints the registerMigration("<name>") block: its first line through the line where its braces balance again.
block_of() {
    awk -v call="registerMigration(\"$1\")" '
        !inside && index($0, call) { inside = 1 }
        inside {
            print
            line = $0
            depth += gsub(/{/, "", line) - gsub(/}/, "", line)
            if (depth == 0) exit
        }
    '
}

failed=0
while IFS=: read -r line name; do
    first="$(git log refs/heads/main --reverse --format=%H -S"registerMigration(\"$name\")" -- "$migrations")"
    first="${first%%$'\n'*}"
    if [[ -z "$first" ]]; then
        continue
    fi
    if [[ "$(block_of "$name" <"$migrations")" != "$(git show "$first:$migrations" | block_of "$name")" ]]; then
        printf "never edit a migration that has shipped: %s:%d %s differs from %s, the first commit on main to register it\n" \
            "$migrations" "$line" "$name" "${first:0:7}" >&2
        failed=1
    fi
done < <(grep -n 'registerMigration("' "$migrations" | sed 's/^\([0-9]*\):.*registerMigration("\([^"]*\)").*/\1:\2/')

exit "$failed"
