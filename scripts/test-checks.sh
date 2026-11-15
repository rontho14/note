#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

rsync -a --exclude Note.xcodeproj --exclude .build "$repo/ios" "$scratch/"
failures="$scratch/failures"
touch "$failures"

fail() {
    echo "test-checks: $1" >>"$failures"
}

fresh_case() {
    local case_root
    case_root="$(mktemp -d "$scratch/case.XXXXXX")"
    cp -R "$scratch/ios" "$case_root/ios"
    echo "$case_root"
}

expect_fail() {
    local check="$1" rule="$2" case_root="$3" change="$4"
    {
        local output
        if output="$("$repo/scripts/$check" "$case_root" 2>&1)"; then
            fail "$change passed $check, expected \"$rule\""
        elif [[ "$output" != *"$rule"* ]]; then
            fail "$change failed $check without naming \"$rule\": $output"
        fi
    } &
}

expect_pass() {
    local check="$1" case_root="$2" change="$3"
    {
        local output
        if ! output="$("$repo/scripts/$check" "$case_root" 2>&1)"; then
            fail "$change failed $check: $output"
        fi
    } &
}

planted() {
    local case_root
    case_root="$(fresh_case)"
    mkdir -p "$(dirname "$case_root/$1")"
    printf '%s\n' "$2" >"$case_root/$1"
    echo "$case_root"
}

without() {
    local case_root
    case_root="$(fresh_case)"
    grep -vF -- "$2" "$repo/$1" >"$case_root/$1"
    echo "$case_root"
}

replaced() {
    local case_root content replacement="$3"
    case_root="$(fresh_case)"
    content="$(<"$repo/$1")"
    printf '%s\n' "${content//"$2"/$replacement}" >"$case_root/$1"
    echo "$case_root"
}

expect_import_fail() {
    expect_fail check-imports.sh "$1" "$(planted "$2" "$3")" "'$3' in $2"
}

expect_import_pass() {
    expect_pass check-imports.sh "$(planted "$1" "$2")" "'$2' in $1"
}

core=ios/Packages/NoteCore/Sources/NoteCore/Planted.swift
ui=ios/Packages/NoteUI/Sources/NoteUI/Planted.swift
store=ios/Packages/NoteStore/Sources/NoteStore/Planted.swift
app=ios/Note/Planted.swift

grdb="only NoteStore imports GRDB"
store_in_ui="NoteUI never imports NoteStore"
core_only_foundation="NoteCore imports only Foundation"

expect_import_fail "$grdb" "$core" "import GRDB"
expect_import_fail "$grdb" "$ui" "import GRDB"
expect_import_fail "$grdb" "$app" "import GRDB"
expect_import_fail "$store_in_ui" "$ui" "import NoteStore"
expect_import_fail "$core_only_foundation" "$core" "import SwiftUI"
expect_import_fail "$core_only_foundation" "$core" "import FoundationExtras"

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
    expect_import_fail "$store_in_ui" "$ui" "$form"
done

expect_import_pass "$store" "import GRDB"
expect_import_pass "$core" "import Foundation"
expect_import_pass "$app" "import NoteStore"
expect_import_pass "$ui" "import NoteStoreKit"
expect_import_pass ios/Packages/NoteUI/Tests/NoteUITests/Planted.swift "import NoteStore"
expect_import_pass "$ui" "// import NoteStore"

for manifest in "$repo"/ios/Packages/*/Package.swift; do
    manifest="${manifest#"$repo/"}"
    for setting in \
        '.enableUpcomingFeature("ExistentialAny")|enableUpcomingFeature:ExistentialAny' \
        '.enableUpcomingFeature("MemberImportVisibility")|enableUpcomingFeature:MemberImportVisibility' \
        '.enableUpcomingFeature("InternalImportsByDefault")|enableUpcomingFeature:InternalImportsByDefault' \
        '.enableUpcomingFeature("NonisolatedNonsendingByDefault")|enableUpcomingFeature:NonisolatedNonsendingByDefault' \
        '.enableUpcomingFeature("InferIsolatedConformances")|enableUpcomingFeature:InferIsolatedConformances' \
        '.strictMemorySafety()|strictMemorySafety' \
        '.treatAllWarnings(as: .error)|treatAllWarnings:error'; do
        written="${setting%%|*}"
        reported="${setting#*|}"
        expect_fail check-settings.sh "target lacks $reported" "$(without "$manifest" "$written")" \
            "$manifest without $written"
    done
done

expect_fail check-settings.sh "NoteUI target lacks defaultIsolation:MainActor" \
    "$(replaced ios/Packages/NoteUI/Package.swift ' + [.defaultIsolation(MainActor.self)]' '')" \
    "NoteUI without default MainActor isolation"

expect_fail check-settings.sh "NoteCore target lacks strictMemorySafety" \
    "$(replaced ios/Packages/NoteCore/Package.swift ', swiftSettings: strictSettings' '')" \
    "NoteCore's target without the strict settings"

expect_fail check-settings.sh "NoteCoreTests target lacks strictMemorySafety" \
    "$(replaced ios/Packages/NoteCore/Package.swift 'targets: [.target(' \
        'targets: [.testTarget(name: "NoteCoreTests", dependencies: ["NoteCore"]), .target(')" \
    "NoteCore with a test target that has no strict settings"

for setting in \
    SWIFT_VERSION \
    SWIFT_TREAT_WARNINGS_AS_ERRORS \
    SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY \
    SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY \
    SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT \
    SWIFT_APPROACHABLE_CONCURRENCY \
    SWIFT_STRICT_MEMORY_SAFETY \
    SWIFT_DEFAULT_ACTOR_ISOLATION; do
    expect_fail check-settings.sh "Note app target has $setting" "$(without ios/project.yml "$setting:")" \
        "project.yml without $setting"
done

expect_fail check-settings.sh "Note app target has SWIFT_STRICT_MEMORY_SAFETY = NO" \
    "$(replaced ios/project.yml '        PRODUCT_BUNDLE_IDENTIFIER' \
        "        SWIFT_STRICT_MEMORY_SAFETY: NO
        PRODUCT_BUNDLE_IDENTIFIER")" \
    "the app target overriding strict memory safety"

expect_fail check-settings.sh "Invalid manifest" \
    "$(replaced ios/Packages/NoteUI/Package.swift 'let package' 'let package = ')" \
    "a NoteUI manifest that doesn't parse"

for check in check-imports.sh check-settings.sh; do
    expect_fail "$check" "can't be checked" "$(mktemp -d "$scratch/empty.XXXXXX")" "a tree without the checked files"
    expect_pass "$check" "$(fresh_case)" "the clean tree"
done

wait

if [[ -s "$failures" ]]; then
    cat "$failures" >&2
    echo "test-checks: $(grep -c '^test-checks: ' "$failures") failed" >&2
    exit 1
fi
echo "test-checks: every check catches what it guards"
