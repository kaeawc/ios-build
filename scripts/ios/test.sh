#!/usr/bin/env bash
#
# Builds and runs the tests on a simulator: the Swift Testing suites of every module in
# ios/Modules, plus the XCTest UI tests (except on watchOS, which has none).
#
# Usage: bash scripts/ios/test.sh [platform]
#   platform: iOS (default), iPadOS, tvOS, visionOS or watchOS
#
# Environment:
#   UNIT_TESTS_ONLY=true   skip the UI tests
#   SIMULATOR_ID=<udid>    use this simulator instead of picking one
#   RESULT_BUNDLE_PATH     where to write the .xcresult (default: build/<platform>.xcresult)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

platform="${1:-iOS}"
resolve_platform "$platform"
require_project

simulator_id="${SIMULATOR_ID:-$(find_simulator)}"
result_bundle="${RESULT_BUNDLE_PATH:-$PROJECT_ROOT/build/$platform.xcresult}"
rm -rf "$result_bundle"

extra_flags=()
if [[ "${UNIT_TESTS_ONLY:-false}" == "true" && "$SCHEME" == "StarterApp" ]]; then
  extra_flags+=(-skip-testing:StarterAppUITests)
fi

echo "Testing $SCHEME on $SIMULATOR_PLATFORM ($simulator_id)"
run_xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "platform=$SIMULATOR_PLATFORM,id=$simulator_id" \
  -resultBundlePath "$result_bundle" \
  ${extra_flags[@]+"${extra_flags[@]}"} \
  "${XCODEBUILD_FLAGS[@]}"
