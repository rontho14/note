require_paths() {
    local check="$1" path
    for path in "${@:2}"; do
        if [[ ! -e "$path" ]]; then
            echo "$check: $path is missing, so it can't be checked" >&2
            exit 2
        fi
    done
}

set_swift_source_folders() {
    swift_source_folders=(ios/Note ios/Packages/*/Sources)
    require_paths "$1" "${swift_source_folders[@]}"
}

set_swift_test_folders() {
    local folder
    swift_test_folders=(ios/NoteE2ETests)
    require_paths "$1" "${swift_test_folders[@]}"
    for folder in ios/Packages/*/Tests; do
        if [[ -d "$folder" ]]; then
            swift_test_folders+=("$folder")
        fi
    done
}

# Sorts every package that has tests by where they run. macos_packages test on the Mac through test-packages.sh.
# ios_only_packages test in the Simulator as test targets of the Note scheme, which check-test-targets.sh makes sure of.
set_tested_packages() {
    local tests package manifest
    macos_packages=()
    ios_only_packages=()
    for tests in ios/Packages/*/Tests; do
        package="$(dirname "$tests")"
        manifest="$(swift package --package-path "$package" dump-package)"
        if jq -e '.platforms | any(.platformName == "macos")' <<<"$manifest" >/dev/null; then
            macos_packages+=("$package")
        else
            ios_only_packages+=("$package")
        fi
    done
}
