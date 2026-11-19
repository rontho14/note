#!/usr/bin/env bash
set -euo pipefail

project="$1"
derived_data="$2"
devices="$3"
only="${4:-}"

prefix="Note "

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

runtimes="$(xcrun simctl list runtimes -j)"
device_types="$(xcrun simctl list devicetypes -j)"

newest_runtime() {
    local wanted="$1" type_id="$2"
    jq -r --arg wanted "$wanted" --arg type_id "$type_id" '
        [.runtimes[]
            | select(.platform == "iOS" and .isAvailable)
            | select(any(.supportedDeviceTypes[]; .identifier == $type_id))
            | select($wanted == "latest" or (.version | startswith($wanted + ".")))]
        | sort_by(.version | split(".") | map(tonumber))
        | last
        | if . == null then empty else "\(.identifier) \(.version)" end
    ' <<<"$runtimes"
}

simulator_named() {
    local name="$1"
    xcrun simctl list devices -j | jq -r --arg name "$name" '
        [.devices[][] | select(.name == $name and .isAvailable) | .udid] | first // empty
    '
}

udids=()
names=()
IFS=',' read -r -a requested <<<"$devices"
for device in "${requested[@]}"; do
    if [[ "$device" != *@* ]]; then
        echo "run-ui-tests: $device has no @<iOS>. Write each device as <device type>@<iOS>, such as iPhone 15@latest or iPhone 15@26." >&2
        exit 2
    fi
    type_name="${device%@*}"
    ios="${device##*@}"

    type_id="$(jq -r --arg name "$type_name" '[.devicetypes[] | select(.name == $name) | .identifier] | first // empty' <<<"$device_types")"
    if [[ -z "$type_id" ]]; then
        echo "run-ui-tests: Xcode has no device type named $type_name" >&2
        exit 1
    fi

    runtime="$(newest_runtime "$ios" "$type_id")"
    if [[ -z "$runtime" ]]; then
        echo "run-ui-tests: no iOS $ios simulator runtime for $type_name. Install it in Xcode > Settings > Components." >&2
        exit 1
    fi
    runtime_id="${runtime%% *}"
    runtime_version="${runtime##* }"

    name="$prefix$type_name $runtime_version"
    udid="$(simulator_named "$name")"
    if [[ -z "$udid" ]]; then
        udid="$(xcrun simctl create "$name" "$type_id" "$runtime_id")"
        echo "run-ui-tests: created simulator $name"
    fi
    udids+=("$udid")
    names+=("$type_name $runtime_version")
done

results="build/ui-tests"
rm -rf "$results"
mkdir -p "$results"
bundle="$results/tests.xcresult"

arguments=(
    test
    -project "$project"
    -scheme Note
    -derivedDataPath "$derived_data"
    -resultBundlePath "$bundle"
    -quiet
)
for udid in "${udids[@]}"; do
    arguments+=(-destination "id=$udid")
done
if [[ -n "$only" ]]; then
    arguments+=("-only-testing:$only")
fi

xcodebuild "${arguments[@]}"

xcrun xcresulttool get test-results summary --path "$bundle" | jq -r '
    .devicesAndConfigurations[]
    | "run-ui-tests: \(.passedTests) passed on \(.device.deviceName) (iOS \(.device.osVersion))"
'

exported="$results/attachments"
xcrun xcresulttool export attachments --path "$bundle" --output-path "$exported" >/dev/null
jq -r --arg prefix "$prefix" '
    .[] | (.testIdentifier | rtrimstr("()") | gsub("/"; ".")) as $test
    | .attachments[]
    | select(.exportedFileName | endswith(".png"))
    | [.exportedFileName, (.deviceName | ltrimstr($prefix)), $test, .suggestedHumanReadableName]
    | @tsv
' "$exported/manifest.json" | while IFS=$'\t' read -r file device test suggested; do
    # Xcode treats the part of a name after its last dot as an extension: write.reopened becomes write_0_<UUID>.reopened.
    if [[ ! "$suggested" =~ ^(.+)_[0-9]+_[0-9A-F-]{36}\.(.+)$ ]]; then
        echo "run-ui-tests: can't read the screenshot name from $suggested. Xcode used to suggest <name>_<index>_<UUID>.png, or <name>_<index>_<UUID>.<state> for <name>.<state>." >&2
        exit 1
    fi
    name="${BASH_REMATCH[1]}"
    if [[ "${BASH_REMATCH[2]}" != png ]]; then
        name="$name.${BASH_REMATCH[2]}"
    fi
    target="$results/$device/$test-$name.png"
    if [[ -e "$target" ]]; then
        echo "run-ui-tests: $test attached two screenshots named $name on $device. Add .<state> to one name." >&2
        exit 1
    fi
    mkdir -p "$results/$device"
    mv "$exported/$file" "$target"
done
rm -rf "$exported"
echo "run-ui-tests: screenshots in $results"

bundle_id="$(plutil -extract CFBundleIdentifier raw "$derived_data/Build/Products/DebugE2E-iphonesimulator/Note.app/Info.plist")"
swift build --package-path ios/Packages/NoteStore --product NoteInvariants --quiet
invariants="$(swift build --package-path ios/Packages/NoteStore --show-bin-path)/NoteInvariants"
for index in "${!udids[@]}"; do
    udid="${udids[$index]}"
    # xcodebuild shuts down a simulator it booted, and simctl finds an app's container only on a booted one.
    state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" '.devices[][] | select(.udid == $udid) | .state')"
    if [[ "$state" != Booted ]]; then
        xcrun simctl bootstatus "$udid" -b >/dev/null
    fi
    container="$(xcrun simctl get_app_container "$udid" "$bundle_id" data)"
    status=0
    "$invariants" "$container" || status=$?
    if [[ "$state" != Booted ]]; then
        xcrun simctl shutdown "$udid"
    fi
    if [[ "$status" != 0 ]]; then
        echo "run-ui-tests: the database on ${names[$index]} breaks an invariant" >&2
        exit 1
    fi
done
echo "run-ui-tests: no database breaks an invariant"
