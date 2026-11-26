#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

# The docs that describe the app as it is. The ADR log and the research notes record the past, so they keep old names.
docs=(docs/VISION.md docs/DESIGN.md docs/adr/[0-9]*.md)
require_paths check-doc-names "${docs[@]}"
set_swift_source_folders check-doc-names
set_swift_test_folders check-doc-names

# Types the docs name that come from Apple's frameworks, not from this repository.
framework_types="UIResponder"
# File names the docs give in backticks, which read like a type and a member.
file_extensions="swift|md|yml|yaml|json|sh|plist|xcspec"

swift_files=()
while IFS= read -r -d '' file; do
    swift_files+=("$file")
done < <(find "${swift_source_folders[@]}" "${swift_test_folders[@]}" -name '*.swift' -print0)

failed=0
while IFS=: read -r doc line name; do
    type="${name%%.*}"
    member="${name#*.}"
    if [[ "$member" =~ ^($file_extensions)$ || " $framework_types " == *" $type "* ]]; then
        continue
    fi

    declaring=()
    while IFS= read -r file; do
        declaring+=("$file")
    done < <(grep -lE "(struct|class|enum|protocol|actor|extension)[[:space:]]+$type([^A-Za-z0-9_]|$)" "${swift_files[@]}")
    if ((${#declaring[@]} == 0)); then
        printf "a doc names only code that exists: %s:%d names %s, but no Swift file declares %s\n" \
            "$doc" "$line" "$name" "$type" >&2
        failed=1
    elif ! grep -qE "(func|var|let)[[:space:]]+$member([^A-Za-z0-9_]|$)|case[[:space:]]+([A-Za-z0-9_]+,[[:space:]]*)*$member([^A-Za-z0-9_]|$)" \
        "${declaring[@]}"; then
        printf "a doc names only code that exists: %s:%d names %s, but %s declares no %s\n" \
            "$doc" "$line" "$name" "$type" "$member" >&2
        failed=1
    fi
done < <(grep -onE '`[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*' "${docs[@]}" | tr -d '`')

exit "$failed"
