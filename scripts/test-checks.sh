#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

rsync -a --exclude Note.xcodeproj --exclude .build "$repo/ios" "$scratch/"

failures=0

fail() {
    echo "test-checks: $1" >&2
    failures=$((failures + 1))
}

run_planted() {
    local case_root
    case_root="$(mktemp -d "$scratch/case.XXXXXX")"
    cp -R "$scratch/ios" "$case_root/ios"
    mkdir -p "$(dirname "$case_root/$1")"
    printf '%s\n' "$2" >"$case_root/$1"
    "$repo/scripts/check-imports.sh" "$case_root" 2>&1
}

expect_fail() {
    local rule="$1" path="$2" source="$3" output
    if output="$(run_planted "$path" "$source")"; then
        fail "'$source' in $path passed, expected \"$rule\""
    elif [[ "$output" != *"$rule"* ]]; then
        fail "'$source' in $path failed without naming \"$rule\": $output"
    fi
}

expect_pass() {
    local path="$1" source="$2" output
    if ! output="$(run_planted "$path" "$source")"; then
        fail "'$source' in $path failed: $output"
    fi
}

core=ios/Packages/NoteCore/Sources/NoteCore/Planted.swift
ui=ios/Packages/NoteUI/Sources/NoteUI/Planted.swift
store=ios/Packages/NoteStore/Sources/NoteStore/Planted.swift
app=ios/Note/Planted.swift

grdb="only NoteStore imports GRDB"
store_in_ui="NoteUI never imports NoteStore"
core_only_foundation="NoteCore imports only Foundation"

expect_fail "$grdb" "$core" "import GRDB"
expect_fail "$grdb" "$ui" "import GRDB"
expect_fail "$grdb" "$app" "import GRDB"
expect_fail "$store_in_ui" "$ui" "import NoteStore"
expect_fail "$core_only_foundation" "$core" "import SwiftUI"
expect_fail "$core_only_foundation" "$core" "import FoundationExtras"

for form in \
    "@testable import NoteStore" \
    "@preconcurrency import NoteStore" \
    "@_exported import NoteStore" \
    "public import NoteStore" \
    "package import NoteStore" \
    "internal import NoteStore" \
    "fileprivate import NoteStore" \
    "private import NoteStore" \
    "@preconcurrency public import NoteStore" \
    "import struct NoteStore.NoteDatabase" \
    "    import NoteStore"; do
    expect_fail "$store_in_ui" "$ui" "$form"
done

expect_pass "$store" "import GRDB"
expect_pass "$core" "import Foundation"
expect_pass "$app" "import NoteStore"
expect_pass "$ui" "import NoteStoreKit"
expect_pass ios/Packages/NoteUI/Tests/NoteUITests/Planted.swift "import NoteStore"
expect_pass "$ui" "// import NoteStore"

if "$repo/scripts/check-imports.sh" "$(mktemp -d "$scratch/empty.XXXXXX")" >/dev/null 2>&1; then
    fail "a tree without the scanned folders passed instead of failing"
fi

if ! output="$("$repo/scripts/check-imports.sh" "$scratch" 2>&1)"; then
    fail "the clean tree failed: $output"
fi

if ((failures > 0)); then
    echo "test-checks: $failures failed" >&2
    exit 1
fi
echo "test-checks: every check catches what it guards"
