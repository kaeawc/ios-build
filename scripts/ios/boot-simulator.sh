#!/usr/bin/env bash
#
# Find an available iPhone simulator, boot it, and wait until it is ready.
# Exits 0 on success, 1 on failure.

PROJECT_ROOT="$(pwd)"

device=$(bash "$PROJECT_ROOT/scripts/ios/find-available-iphone.sh")
if [[ -z "$device" ]]; then
  echo "No available iPhone simulator found"
  xcrun simctl list devices available
  exit 1
fi

echo "Booting simulator: ${device}"
xcrun simctl boot "${device}"
bash "$PROJECT_ROOT/scripts/ios/wait-for-simulator-boot.sh" "${device}"
