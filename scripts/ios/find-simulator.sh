#!/usr/bin/env bash
#
# Prints the UDID of an available simulator for a platform, e.g. to boot it or stream its logs.
#
# Usage: bash scripts/ios/find-simulator.sh [platform]
#   platform: iOS (default), iPadOS, tvOS, visionOS or watchOS

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

resolve_platform "${1:-iOS}"
find_simulator
