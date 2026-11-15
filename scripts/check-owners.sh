#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

scripts=(.githooks/* scripts/*.sh)

require_paths check-owners ios/project.yml "${scripts[@]}"

awk '
    function violate(rule, message) {
        printf "%s: %s:%d %s\n", rule, FILENAME, FNR, message > "/dev/stderr"
        failed = 1
    }

    FILENAME == "ios/project.yml" && match($0, /^[[:space:]]*(INFOPLIST_KEY_[A-Za-z0-9_~]*|GENERATE_INFOPLIST_FILE|INFOPLIST_FILE):/) {
        key = substr($0, RSTART, RLENGTH - 1)
        sub(/^[[:space:]]*/, "", key)
        violate("Info.plist keys live in the target'"'"'s info: properties", \
            "sets " key ". Put the key under the target'"'"'s info: properties in ios/project.yml")
    }

    FILENAME != "ios/project.yml" && /xcodegen[[:space:]]+generate/ {
        violate("only the Makefile runs xcodegen", "runs xcodegen. Run make ios-project instead")
    }

    END { exit failed }
' ios/project.yml "${scripts[@]}"
