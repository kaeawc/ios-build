#!/usr/bin/env bash
#
# Prints the UDID of the first booted iPhone simulator.
# Exits 1 if no booted iPhone simulator is found.
#
# Example output: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

line=$(xcrun simctl list devices booted 2>/dev/null | grep 'iPhone' | head -1)

if [[ -z "$line" ]]; then
  exit 1
fi

# Extract the UUID from "    iPhone 16 Pro (UDID) (Booted)"
udid=$(echo "$line" | grep -oE '[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}')

if [[ -z "$udid" ]]; then
  exit 1
fi

echo "$udid"
