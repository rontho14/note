#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/check-lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

set_swift_source_folders check-logging
set_swift_test_folders check-logging

find "${swift_source_folders[@]}" "${swift_test_folders[@]}" -name '*.swift' -exec awk '
    {
        code = $0
        sub(/\/\/.*/, "", code)
        if (!match(code, /(^|[^A-Za-z0-9_.])(print|debugPrint|dump|NSLog)\(/)) next

        called = substr(code, RSTART, RLENGTH - 1)
        sub(/^[^A-Za-z]/, "", called)
        printf "no print, debugPrint, dump or NSLog: %s:%d calls %s\n", FILENAME, FNR, called > "/dev/stderr"
        failed = 1
    }

    END { exit failed }
' {} +
