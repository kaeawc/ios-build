#!/usr/bin/env bash
#
# Usage: count-simulator-runtimes.sh <major_version>
#
# Prints the number of installed iOS simulator runtimes whose version starts
# with <major_version>.  Exits 0 in all normal cases (including 0 matches).

major_version="${1:?Usage: count-simulator-runtimes.sh <major_version>}"

xcrun simctl list runtimes iOS 2>/dev/null \
  | grep -c "iOS ${major_version}\." \
  || true
