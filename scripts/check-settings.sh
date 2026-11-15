#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

package_settings=(
    enableUpcomingFeature:ExistentialAny
    enableUpcomingFeature:MemberImportVisibility
    enableUpcomingFeature:InternalImportsByDefault
    enableUpcomingFeature:NonisolatedNonsendingByDefault
    enableUpcomingFeature:InferIsolatedConformances
    strictMemorySafety
    treatAllWarnings:error
)

app_settings=(
    SWIFT_VERSION=6.0
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
    SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY=YES
    SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY=YES
    SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT=YES
    SWIFT_APPROACHABLE_CONCURRENCY=YES
    SWIFT_STRICT_MEMORY_SAFETY=YES
    SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor
)

manifests=(ios/Packages/*/Package.swift)

require_paths check-settings ios/project.yml "${manifests[@]}"

failed=0

report() {
    if [[ -n "$1" ]]; then
        sed 's/^/check-settings: /' <<<"$1" >&2
        failed=1
    fi
}

for manifest in "${manifests[@]}"; do
    package="$(dirname "$manifest")"
    required=("${package_settings[@]}")
    [[ "$(basename "$package")" == NoteUI ]] && required+=(defaultIsolation:MainActor)

    dump="$(swift package --package-path "$package" dump-package)"
    report "$(jq -r --args '
            .targets[]
            | .name as $target
            | [.settings[]?.kind | to_entries[0] | .key + (.value._0 // null | if . then ":\(.)" else "" end)] as $set
            | $ARGS.positional[]
            | select(. as $required | $set | index($required) | not)
            | "\($target) target lacks \(.)"
        ' "${required[@]}" <<<"$dump")"
done

make -s -C "$root" ios-project
build_settings="$(xcodebuild -showBuildSettings -json -project ios/Note.xcodeproj -target Note)"

for pair in "${app_settings[@]}"; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(jq -r --arg key "$key" '.[0].buildSettings[$key] // "unset"' <<<"$build_settings")"
    [[ "$actual" == "$expected" ]] || report "Note app target has $key = $actual, needs $expected"
done

exit "$failed"
