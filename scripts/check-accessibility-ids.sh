#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

# ADR 0005: an identifier is <screen> or <screen>.<element>, lowercase words joined by dots, and a repeated element's
# constant is a prefix, <screen>.<element>., that the note or drawer ID completes. SheetID adds a sheet's parts.
ids=ios/Packages/NoteUI/Sources/NoteUI/AccessibilityID.swift
set_swift_source_folders check-accessibility-ids
set_swift_test_folders check-accessibility-ids
require_paths check-accessibility-ids "$ids"

failed=0

while IFS= read -r declaration; do
    if [[ "$declaration" =~ static\ let\ ([A-Za-z]+)\ =\ \"([^\"]*)\" ]]; then
        name="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        if [[ "$name" == *Prefix ]]; then
            pattern='^[a-z]+\.[a-z]+\.$'
        else
            pattern='^[a-z]+(\.[a-z]+)?$'
        fi
    elif [[ "$declaration" =~ static\ let\ ([A-Za-z]+)\ =\ SheetID\(\"([^\"]*)\"\) ]]; then
        name="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        pattern='^[a-z]+$'
    else
        continue
    fi
    if [[ ! "$value" =~ $pattern ]]; then
        printf "each identifier is a constant in AccessibilityID named by the convention in ADR 0005: %s:%d %s is \"%s\". Name it <screen> or <screen>.<element>, one lowercase word each\n" \
            "$ids" "$(grep -nF "$declaration" "$ids" | cut -d: -f1)" "$name" "$value" >&2
        failed=1
    fi
done < <(grep -E 'static let [A-Za-z]+ = ' "$ids")

while IFS=: read -r file line _; do
    printf "each identifier is a constant in AccessibilityID named by the convention in ADR 0005: %s:%d gives an identifier as a string. Add a constant to AccessibilityID and use it\n" \
        "$file" "$line" >&2
    failed=1
done < <(find "${swift_source_folders[@]}" "${swift_test_folders[@]}" -name '*.swift' \
    -exec grep -nE 'accessibilityIdentifier\("' {} +)

exit "$failed"
