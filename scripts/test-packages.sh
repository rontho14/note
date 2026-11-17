#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

set_tested_packages
for package in ${macos_packages[@]+"${macos_packages[@]}"}; do
    swift test --package-path "$package"
done
