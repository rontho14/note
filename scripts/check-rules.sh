#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"

root="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
cd "$root"

checks=(scripts/check-*.sh)
require_paths check-rules CLAUDE.md "${checks[@]}"

lowercase_without_backticks() {
    tr -d '`' | tr '[:upper:]' '[:lower:]'
}

failed=0
for check in "${checks[@]}"; do
    rules="$(sed -n \
        -e 's/.*violate("\([^"]*\)",.*/\1/p' \
        -e 's/.*printf "\([^"%]*\): %s:%d.*/\1/p' \
        "$check" | sed "s/\\\\047/'/g")"
    if [[ -z "$rules" ]]; then
        continue
    fi

    if ! row="$(grep -F "\`$check\`" CLAUDE.md)"; then
        echo "every rule a check names is stated in CLAUDE.md: $check has no row in CLAUDE.md's rules table" >&2
        failed=1
        continue
    fi
    row="$(lowercase_without_backticks <<<"$row")"
    while IFS= read -r rule; do
        if ! awk -v rule="$(lowercase_without_backticks <<<"$rule")" '
            {
                for (start = 1; (found = index(substr($0, start), rule)) > 0; start += found) {
                    at = start + found - 1
                    before = substr($0, at - 2, 2)
                    after = substr($0, at + length(rule), 1)
                    if ((before == "| " || before == ". ") && (after == "." || after == ":")) exit 0
                }
                exit 1
            }
        ' <<<"$row"; then
            echo "every rule a check names is stated in CLAUDE.md: $check names \"$rule\", which no sentence in its CLAUDE.md row states" >&2
            failed=1
        fi
    done <<<"$rules"
done

exit "$failed"
