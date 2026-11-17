#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

scripts=(.githooks/* scripts/*.sh)
launch_background=ios/Note/Assets.xcassets/LaunchBackground.colorset/Contents.json
palette=ios/Packages/NoteUI/Sources/NoteUI/Palette.swift

require_paths check-owners ios/project.yml "${scripts[@]}" "$launch_background" "$palette"

failed=0
awk '
    function violate(rule, message) {
        printf "%s: %s:%d %s\n", rule, FILENAME, FNR, message > "/dev/stderr"
        failed = 1
    }

    FILENAME == "ios/project.yml" && match($0, /^[[:space:]]*(INFOPLIST_KEY_[A-Za-z0-9_~]*|GENERATE_INFOPLIST_FILE|INFOPLIST_FILE):/) {
        key = substr($0, RSTART, RLENGTH - 1)
        sub(/^[[:space:]]*/, "", key)
        violate("Info.plist keys live in the target\047s info: properties in ios/project.yml", \
            "sets " key ". Put the key under the target\047s info: properties")
    }

    FILENAME != "ios/project.yml" && /xcodegen[[:space:]]+generate/ {
        violate("only the Makefile runs xcodegen", "runs xcodegen. Run make ios-project instead")
    }

    END { exit failed }
' ios/project.yml "${scripts[@]}" || failed=1

launch_rgb="$(jq -r '.colors[0].color.components | "\(.red) \(.green) \(.blue)"' "$launch_background" | tr '[:lower:]' '[:upper:]')"
paper_line="$(awk '/static let paper = / { print FNR ":" $0 }' "$palette")"
paper_rgb="$(sed -n 's/.*Color(red: 0x\([0-9A-Fa-f]*\) \/ 255, green: 0x\([0-9A-Fa-f]*\) \/ 255, blue: 0x\([0-9A-Fa-f]*\) \/ 255).*/0X\1 0X\2 0X\3/p' <<<"$paper_line" | tr '[:lower:]' '[:upper:]')"
if [[ "$launch_rgb" != "$paper_rgb" ]]; then
    printf "LaunchBackground in the asset catalog is the same color as Palette.paper: %s:%d %s\n" \
        "$launch_background" 1 "is $launch_rgb, but $palette:${paper_line%%:*} sets paper to ${paper_rgb:-a color this check cannot read}" >&2
    failed=1
fi

exit "$failed"
