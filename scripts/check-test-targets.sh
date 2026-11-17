#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

require_paths check-test-targets ios/project.yml ios/Packages

# SwiftPM names each test target after its folder in Tests.
failed=0
set_tested_packages
for package in ${ios_only_packages[@]+"${ios_only_packages[@]}"}; do
    name="$(basename "$package")"
    for folder in "$package"/Tests/*/; do
        target="$(basename "$folder")"
        if ! grep -q "package: $name/$target\$" ios/project.yml; then
            printf "an iOS-only package's test targets are in the Note scheme: %s:%d %s\n" "$package/Package.swift" 1 \
                "$target runs nowhere. Add package: $name/$target to the Note scheme's testTargets in ios/project.yml" >&2
            failed=1
        fi
    done
done
exit "$failed"
