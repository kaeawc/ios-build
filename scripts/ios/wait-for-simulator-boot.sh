#!/usr/bin/env bash
#
# Usage: wait-for-simulator-boot.sh <udid> [timeout_seconds]
#
# Polls xcrun simctl until the simulator reaches the Booted state.
# Exits 0 on success, 1 on timeout.

udid="${1:?Usage: wait-for-simulator-boot.sh <udid> [timeout_seconds]}"
timeout_secs="${2:-120}"

echo "Waiting for simulator ${udid} to boot (timeout: ${timeout_secs}s)..."

i=0
while [[ $i -lt $timeout_secs ]]; do
  if xcrun simctl list devices booted 2>/dev/null | grep -q "${udid}"; then
    echo "Simulator booted after ${i}s"
    exit 0
  fi
  sleep 1
  i=$((i + 1))
done

echo "Timed out after ${timeout_secs}s waiting for simulator to boot"
xcrun simctl list devices 2>/dev/null | grep "${udid}" || true
exit 1
