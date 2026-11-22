#!/usr/bin/env bash
#
# Builds the app for a simulator.
#
# Usage: bash scripts/ios/build.sh [platform] [configuration]
#   platform:      iOS (default), iPadOS, tvOS, visionOS or watchOS
#   configuration: Debug (default) or Release
#
# Building iOS also builds the watch app, which ships inside it.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

platform="${1:-iOS}"
configuration="${2:-Debug}"
resolve_platform "$platform"
require_project

echo "Building $SCHEME ($configuration) for $SIMULATOR_PLATFORM"
run_xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$configuration" \
  -destination "generic/platform=$SIMULATOR_PLATFORM" \
  "${XCODEBUILD_FLAGS[@]}"
