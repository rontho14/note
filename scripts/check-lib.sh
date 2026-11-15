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
