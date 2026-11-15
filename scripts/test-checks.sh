#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

mkdir "$scratch/repo"
(cd "$repo" && git ls-files -co --exclude-standard -z) | rsync -a --from0 --files-from=- "$repo/" "$scratch/repo/"
failures="$scratch/failures"
touch "$failures"

fail() {
    echo "test-checks: $1" >>"$failures"
}

expect_fail() {
    local rule="$1" change="$2"
    shift 2
    {
        local output
        if output="$("$@" 2>&1)"; then
            fail "$change passed, expected \"$rule\""
        elif [[ "$output" != *"$rule"* ]]; then
            fail "$change failed without naming \"$rule\": $output"
        fi
    } &
}

expect_pass() {
    local change="$1"
    shift
    {
        local output
        if ! output="$("$@" 2>&1)"; then
            fail "$change failed: $output"
        fi
    } &
}

run_check() {
    "$repo/scripts/$1" "$2"
}

plant() {
    mkdir -p "$(dirname "$1/$2")"
    printf '%s\n' "$3" >"$1/$2"
}

fresh_case() {
    local case_root
    case_root="$(mktemp -d "$scratch/case.XXXXXX")"
    cp -R "$scratch/repo/." "$case_root"
    echo "$case_root"
}

planted() {
    local case_root
    case_root="$(fresh_case)"
    plant "$case_root" "$1" "$2"
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

commit_in() {
    if [[ "$1" != "$scratch"/* || ! -d "$1/.git" ]]; then
        echo "test-checks: refusing to commit outside a scratch repository: '$1'" >&2
        return 2
    fi
    git -C "$1" -c user.name=test-checks -c user.email=test-checks@example.invalid commit -q "${@:2}"
}

hooked_case_with() {
    local case_root
    case_root="$(fresh_case)"
    git -C "$case_root" init -q
    git -C "$case_root" add -A
    commit_in "$case_root" --no-verify -m baseline
    make -C "$case_root" setup >/dev/null
    plant "$case_root" "$1" "$2"
    git -C "$case_root" add -A
    echo "$case_root"
}

formatted_then_linted() {
    make -C "$1" fmt && make -C "$1" lint
}

expect_import_fail() {
    expect_fail "$1" "'$3' in $2" run_check check-imports.sh "$(planted "$2" "$3")"
}

expect_import_pass() {
    expect_pass "'$2' in $1" run_check check-imports.sh "$(planted "$1" "$2")"
}

expect_settings_fail() {
    expect_fail "$1" "$2" run_check check-settings.sh "$3"
}

core=ios/Packages/NoteCore/Sources/NoteCore/Planted.swift
ui=ios/Packages/NoteUI/Sources/NoteUI/Planted.swift
store=ios/Packages/NoteStore/Sources/NoteStore/Planted.swift
telemetry=ios/Packages/NoteTelemetry/Sources/NoteTelemetry/Planted.swift
app=ios/Note/Planted.swift
ui_test=ios/NoteE2ETests/Planted.swift
core_test=ios/Packages/NoteCore/Tests/NoteCoreTests/Planted.swift

grdb="only NoteStore imports GRDB"
store_in_ui="NoteUI never imports NoteStore"
core_only_foundation="NoteCore imports only Foundation"
os_in_telemetry="only NoteTelemetry imports os or OSLog"

expect_import_fail "$grdb" "$core" "import GRDB"
expect_import_fail "$grdb" "$ui" "import GRDB"
expect_import_fail "$grdb" "$app" "import GRDB"
expect_import_fail "$grdb" "$ui_test" "import GRDB"
expect_import_fail "$grdb" "$core_test" "import GRDB"
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

for file in "$ui" "$store" "$app" "$ui_test" "$core_test"; do
    for form in "import os" "import OSLog" "import os.log"; do
        expect_import_fail "$os_in_telemetry" "$file" "$form"
    done
done

expect_import_pass "$store" "import GRDB"
expect_import_pass "$telemetry" "import os"
expect_import_pass ios/Packages/NoteTelemetry/Tests/NoteTelemetryTests/Planted.swift "import os"
expect_import_pass ios/Packages/NoteStore/Tests/NoteStoreTests/Planted.swift "import GRDB"
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
        expect_settings_fail "target lacks $reported" "$manifest without $written" "$(without "$manifest" "$written")"
    done
done

expect_settings_fail "NoteUI target lacks defaultIsolation:MainActor" "NoteUI without default MainActor isolation" \
    "$(replaced ios/Packages/NoteUI/Package.swift ' + [.defaultIsolation(MainActor.self)]' '')"

expect_settings_fail "NoteCore target lacks strictMemorySafety" "NoteCore's target without the strict settings" \
    "$(replaced ios/Packages/NoteCore/Package.swift ', swiftSettings: strictSettings' '')"

expect_settings_fail "NoteCoreTests target lacks strictMemorySafety" \
    "NoteCore with a test target that has no strict settings" \
    "$(replaced ios/Packages/NoteCore/Package.swift 'targets: [.target(' \
        'targets: [.testTarget(name: "NoteCoreTests", dependencies: ["NoteCore"]), .target(')"

for setting in \
    SWIFT_VERSION \
    SWIFT_TREAT_WARNINGS_AS_ERRORS \
    SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY \
    SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY \
    SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT \
    SWIFT_APPROACHABLE_CONCURRENCY \
    SWIFT_STRICT_MEMORY_SAFETY \
    SWIFT_DEFAULT_ACTOR_ISOLATION; do
    expect_settings_fail "Note app target has $setting" "project.yml without $setting" \
        "$(without ios/project.yml "$setting:")"
done

expect_settings_fail "Note app target has SWIFT_STRICT_MEMORY_SAFETY = NO" \
    "the app target overriding strict memory safety" \
    "$(replaced ios/project.yml '        PRODUCT_BUNDLE_IDENTIFIER' \
        "        SWIFT_STRICT_MEMORY_SAFETY: NO
        PRODUCT_BUNDLE_IDENTIFIER")"

expect_settings_fail "Invalid manifest" "a NoteUI manifest that doesn't parse" \
    "$(replaced ios/Packages/NoteUI/Package.swift 'let package' 'let package = ')"

swallowed="errors are never swallowed"
hidden_grep_errors='matches="$(grep -rn import ios 2>/dev/''null |''| true)"'
hidden_removal_error='try? FileManager.default.removeItem(at: unfinishedCopy)'

expect_fail "$swallowed" "a script that hides grep's errors" \
    run_check check-errors.sh "$(planted scripts/planted.sh "$hidden_grep_errors")"
expect_fail "$swallowed" "a try? in production code" \
    run_check check-errors.sh "$(planted "$core" "import Foundation
$hidden_removal_error")"
expect_pass "a try? in a test file" run_check check-errors.sh "$(planted "$core_test" "$hidden_removal_error")"
expect_pass "an exception that has not expired" \
    run_check check-errors.sh "$(planted scripts/planted.sh \
        'x=1 |''| true # check-errors: allowed until 2099-01-01 by test-checks: planted')"
expect_fail "expired on 2020-01-01" "an exception that has expired" \
    run_check check-errors.sh "$(planted scripts/planted.sh \
        'x=1 |''| true # check-errors: allowed until 2020-01-01 by test-checks: planted')"

expect_fail "only the Makefile runs xcodegen" "a script that runs xcodegen itself" \
    run_check check-owners.sh "$(replaced scripts/check-settings.sh 'make -s -C "$root" ios-project' \
        '(cd ios && xcodegen gen''erate --quiet)')"
expect_fail "Info.plist keys live in the target's info: properties" "project.yml generating Info.plist keys" \
    run_check check-owners.sh "$(replaced ios/project.yml '        TARGETED_DEVICE_FAMILY: "1"' \
        '        TARGETED_DEVICE_FAMILY: "1"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES')"

no_print="no print, debugPrint, dump or NSLog"

for file in "$app" "$store" "$core_test"; do
    for call in 'print("planted")' 'debugPrint("planted")' 'dump(1)' 'NSLog("planted")'; do
        expect_fail "$no_print" "'$call' in $file" run_check check-logging.sh "$(planted "$file" "$call")"
    done
done
expect_pass "a commented-out print" run_check check-logging.sh "$(planted "$app" '// print("planted")')"
expect_pass "a call to printer(" run_check check-logging.sh "$(planted "$app" 'printer("planted")')"

for script in check-imports.sh check-settings.sh check-errors.sh check-owners.sh check-logging.sh; do
    expect_fail "can't be checked" "$script on a tree without the checked files" \
        run_check "$script" "$(mktemp -d "$scratch/empty.XXXXXX")"
    expect_pass "$script on the clean tree" run_check "$script" "$(fresh_case)"
done

badly_formatted='struct  Spaced{let value=1}'
force_unwrapped='let forced = Int("1")!'

expect_fail "[Spacing]" "a badly formatted file" make -C "$(planted "$core" "$badly_formatted")" lint
expect_pass "make fmt then make lint on a badly formatted file" \
    formatted_then_linted "$(planted "$core" "$badly_formatted")"
expect_fail "[NeverForceUnwrap]" "a force unwrap in production code" \
    make -C "$(planted "$core" "$force_unwrapped")" lint
expect_pass "a force unwrap in a test file" \
    make -C "$(planted "$core_test" "import Testing
$force_unwrapped")" lint

expect_fail "[Spacing]" "committing a badly formatted file" \
    commit_in "$(hooked_case_with "$core" "$badly_formatted")" -m planted
expect_fail "$store_in_ui" "committing a broken import rule" \
    commit_in "$(hooked_case_with "$ui" "import NoteStore")" -m planted
expect_pass "committing a clean file" commit_in "$(hooked_case_with "$core" "let planted = 1")" -m planted

wait

if [[ -s "$failures" ]]; then
    cat "$failures" >&2
    echo "test-checks: $(grep -c '^test-checks: ' "$failures") failed" >&2
    exit 1
fi
echo "test-checks: every check catches what it guards"
