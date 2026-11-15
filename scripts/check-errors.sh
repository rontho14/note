#!/usr/bin/env bash
set -euo pipefail

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

swift_folders=(ios/Note ios/Packages/*/Sources)
shell_files=(Makefile .githooks/* scripts/*.sh)

for path in "${swift_folders[@]}" "${shell_files[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "check-errors: $path is missing, so its error handling can't be checked" >&2
        exit 2
    fi
done

check='
    function violate(message) {
        printf "errors are never swallowed: %s:%d %s\n", FILENAME, FNR, message > "/dev/stderr"
        failed = 1
    }

    {
        hidden = ""
        if (FILENAME ~ /\.swift$/) {
            if ($0 ~ /try[?]/) hidden = "try?"
        } else if ($0 ~ /2>[[:space:]]*\/dev\/null/) {
            hidden = "2>" "/dev/null"
        } else if ($0 ~ /[|][|][[:space:]]*(true|:)([[:space:];)]|$)/) {
            hidden = "||" " true"
        }
        if (hidden == "") next

        if (match($0, /check-errors: allowed until [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] by [^:]+: [^ ]/)) {
            until = substr($0, RSTART + length("check-errors: allowed until "), 10)
            if (until >= today) next
            violate("has an exception that expired on " until)
            next
        }
        violate("uses " hidden ", which hides a failure. Handle the error, or end the line with a comment " \
            "\"check-errors: allowed until YYYY-MM-DD by NAME: reason\" that a person approved")
    }

    END { exit failed }
'

today="$(date +%F)"
failed=0
awk -v today="$today" "$check" "${shell_files[@]}" || failed=1
find "${swift_folders[@]}" -name '*.swift' -exec awk -v today="$today" "$check" {} + || failed=1
exit "$failed"
