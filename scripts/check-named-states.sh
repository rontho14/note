#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

# NoteUI holds the app's modes: screens, sheets, pills and what the store has answered. NoteCore and NoteStore keep
# optionals for stored columns, such as a note's title, which are data rather than modes.
ui_sources=ios/Packages/NoteUI/Sources
require_paths check-named-states "$ui_sources"

check='
    function violate(message) {
        printf "no optional, nil or Bool stands for a mode: %s:%d %s\n", FILENAME, FNR, message > "/dev/stderr"
        failed = 1
    }

    FNR == 1 { previous = "" }

    {
        line = previous "\n" $0
        previous = $0
        code = $0
        sub(/\/\/.*/, "", code)
        found = ""
        if (code ~ /(var|let)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[^=]*[?]([[:space:]]|=|[{]|$)/) {
            found = "declares an optional"
        } else if (code ~ /func[[:space:]][^{]*->[^{]*[?][[:space:]]*([{]|where|$)/) {
            found = "returns an optional"
        } else if (code ~ /[!=]=[[:space:]]*nil([^A-Za-z0-9_]|$)/) {
            found = "compares with nil"
        } else if (code !~ /@(Accessibility)?FocusState/ \
            && (code ~ /(var|let)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[[:space:]]*Bool[[:space:]]*(=|$)/ \
                || code ~ /[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[[:space:]]*Bool[[:space:]]*[,)]/)) {
            found = "holds a Bool"
        }
        if (found == "") next

        if (match(line, /check-named-states: allowed until [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] by [^:]+: [^ ]/)) {
            until = substr(line, RSTART + length("check-named-states: allowed until "), 10)
            if (until >= today) next
            violate("has an exception that expired on " until)
            next
        }
        violate(found ". Name each state as an enum case, such as StoreRead, Showing or TitleSheetState, or " \
            "put a comment \"check-named-states: allowed until YYYY-MM-DD by NAME: reason\" that a person " \
            "approved on the line or the one above it")
    }

    END { exit failed }
'

find "$ui_sources" -name '*.swift' -exec awk -v today="$(date +%F)" "$check" {} +
