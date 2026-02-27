#!/usr/bin/env bash

PROJECT_ROOT="$(pwd)"
PRODUCTS_PATH="${PRODUCTS_PATH:-$PROJECT_ROOT/build/DerivedData/Build/Products}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PROJECT_ROOT/build/automobile-tests.xcresult}"

start_time=$(date +%s)

# Find the .xctestrun file produced by build-for-testing
xctestrun_file=$(find "$PRODUCTS_PATH" -name "*.xctestrun" 2>/dev/null | head -1)
if [[ -z "$xctestrun_file" ]]; then
  echo "No .xctestrun file found in: $PRODUCTS_PATH"
  echo "Contents:"
  ls -la "$PRODUCTS_PATH" 2>/dev/null || echo "(directory missing or empty)"
  exit 1
fi

echo "Using xctestrun: $xctestrun_file"

# Find a booted iPhone simulator
booted_udid=$(bash "$PROJECT_ROOT/scripts/ios/find-booted-iphone-udid.sh" 2>/dev/null || echo "")

if [[ -z "$booted_udid" ]]; then
  echo "No booted iPhone simulator found"
  echo "Booted devices:"
  xcrun simctl list devices booted
  exit 1
fi

echo "Testing on simulator: $booted_udid"

rm -rf "$RESULT_BUNDLE_PATH"

xcodebuild test-without-building \
  -xctestrun "$xctestrun_file" \
  -destination "platform=iOS Simulator,id=$booted_udid" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -only-testing:StarterAppAutoMobileTests \
  -enableCodeCoverage NO \
  -skipMacroValidation

test_exit_code=$?
elapsed=$(($(date +%s) - start_time))

if [[ $test_exit_code -ne 0 ]]; then
  echo "AutoMobile tests failed in ${elapsed}s"
  exit $test_exit_code
fi

echo "AutoMobile tests passed in ${elapsed}s"
