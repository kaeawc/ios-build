#!/usr/bin/env bash
#
# Prints the UDID of the first available iPhone simulator.
# Exits 1 if no available iPhone simulator is found.
#
# Example output: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

line=$(xcrun simctl list devices available 2>/dev/null | grep 'iPhone' | head -1)

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
