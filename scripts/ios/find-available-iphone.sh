#!/usr/bin/env bash
#
# Prints the UDID of the first available iPhone simulator.
# Prefers a simulator whose runtime matches the current Xcode SDK version
# (e.g. iOS 26.2 when Xcode 26.2 is active) to avoid xctestrun mismatches.
# Falls back to the first available iPhone if no version-matched simulator exists.
# Exits 1 if no available iPhone simulator is found.
#
# Example output: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || echo "")

# Prefer a simulator whose runtime matches the current SDK version.
# simctl list groups devices under "-- iOS <version> --" headers sorted ascending,
# so head -1 would otherwise pick the lowest available version (e.g. 26.0 on a
# runner that also has 26.1 and 26.2), causing xctestrun mismatches.
line=""
if [[ -n "$sdk_version" ]]; then
  line=$(xcrun simctl list devices available 2>/dev/null | awk -v ver="$sdk_version" '
    index($0, "-- iOS " ver " --") { found=1; next }
    /^-- /                         { found=0 }
    found && /iPhone/              { print; exit }
  ')
fi

# Fall back to first available iPhone if no version-matched simulator was found
if [[ -z "$line" ]]; then
  line=$(xcrun simctl list devices available 2>/dev/null | grep 'iPhone' | head -1)
fi

if [[ -z "$line" ]]; then
  echo "No available iPhone simulator found" >&2
  exit 1
fi

# Extract the UUID from "    iPhone 16 Pro (UDID) (Shutdown)"
udid=$(echo "$line" | grep -oE '[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}')

if [[ -z "$udid" ]]; then
  echo "No UDID found in line: $line" >&2
  exit 1
fi

echo "$udid"
