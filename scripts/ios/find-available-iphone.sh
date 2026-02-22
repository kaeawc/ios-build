#!/usr/bin/env bash
#
# Prints the name of the first available iPhone simulator.
# Exits 1 if no available iPhone simulator is found.
#
# Example output: "iPhone 16 Pro"

line=$(xcrun simctl list devices available 2>/dev/null | grep 'iPhone' | head -1)

if [[ -z "$line" ]]; then
  echo "No available iPhone simulator found" >&2
  exit 1
fi

# Input:  "    iPhone 16 Pro (UDID) (Shutdown)"
# Strip leading whitespace, then remove the " (UDID) (State)" suffix.
echo "$line" | sed -E 's/^[[:space:]]*//' | sed -E 's/ \([0-9A-Fa-f-]+\) \([^)]*\)$//'
