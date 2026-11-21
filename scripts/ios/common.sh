#!/usr/bin/env bash
#
# Shared helpers for the xcodebuild scripts in this directory. Source it; don't run it.
#
# Platforms: iOS (iPhone), iPadOS (iPad), tvOS, visionOS, watchOS.

# Variables set here are used by the scripts that source this file.
# shellcheck disable=SC2034

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_PATH="$PROJECT_ROOT/ios/StarterApp/StarterApp.xcodeproj"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_ROOT/build/DerivedData}"

# Flags for every xcodebuild invocation: no signing (simulator only), no index store (smaller,
# faster DerivedData), and no interactive trust prompts for package plugins and macros.
XCODEBUILD_FLAGS=(
  -derivedDataPath "$DERIVED_DATA_PATH"
  -skipPackagePluginValidation
  -skipMacroValidation
  CODE_SIGNING_ALLOWED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)

require_project() {
  if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "No Xcode project at $PROJECT_PATH. Run: bash scripts/ios/xcodegen-generate.sh" >&2
    exit 1
  fi
}

# Sets SCHEME, SIMULATOR_PLATFORM (for -destination), SIMULATOR_SDK and DEVICE_PREFIX for "$1".
resolve_platform() {
  case "$1" in
    iOS) SCHEME=StarterApp SIMULATOR_PLATFORM="iOS Simulator" SIMULATOR_SDK=iphonesimulator DEVICE_PREFIX="iPhone" ;;
    iPadOS) SCHEME=StarterApp SIMULATOR_PLATFORM="iOS Simulator" SIMULATOR_SDK=iphonesimulator DEVICE_PREFIX="iPad" ;;
    tvOS) SCHEME=StarterApp SIMULATOR_PLATFORM="tvOS Simulator" SIMULATOR_SDK=appletvsimulator DEVICE_PREFIX="Apple TV" ;;
    visionOS) SCHEME=StarterApp SIMULATOR_PLATFORM="visionOS Simulator" SIMULATOR_SDK=xrsimulator DEVICE_PREFIX="Apple Vision" ;;
    watchOS) SCHEME=StarterAppWatch SIMULATOR_PLATFORM="watchOS Simulator" SIMULATOR_SDK=watchsimulator DEVICE_PREFIX="Apple Watch" ;;
    *)
      echo "Unknown platform '$1'. Use one of: iOS, iPadOS, tvOS, visionOS, watchOS." >&2
      exit 1
      ;;
  esac
}

# Prints the UDID of an available simulator for the resolved platform, preferring a runtime that
# matches the active Xcode's SDK (avoids "no matching destination" errors on runners that have
# several Xcode versions installed), otherwise the newest runtime.
find_simulator() {
  local sdk_version
  sdk_version=$(xcrun --sdk "$SIMULATOR_SDK" --show-sdk-version 2>/dev/null || true)
  xcrun simctl list devices available --json | python3 -c '
import json, re, sys

prefix, sdk_version = sys.argv[1], sys.argv[2]
runtimes = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"SimRuntime\.(iOS|tvOS|xrOS|watchOS)-(\d+(?:-\d+)*)$", runtime)
    candidates = [d for d in devices if d["name"].startswith(prefix)]
    if match and candidates:
        version = tuple(int(part) for part in match.group(2).split("-"))
        runtimes.append((version, candidates[0]["udid"]))

wanted = tuple(int(part) for part in sdk_version.split(".")) if sdk_version else None
exact = [udid for version, udid in runtimes if version == wanted]
newest = [udid for version, udid in sorted(runtimes, reverse=True)]
if not (exact or newest):
    sys.exit("No available simulator named " + prefix + "*")
print((exact or newest)[0])
' "$DEVICE_PREFIX" "$sdk_version"
}

# Runs xcodebuild, piping through xcbeautify when it is installed.
run_xcodebuild() {
  if command -v xcbeautify >/dev/null 2>&1; then
    local renderer=terminal
    [[ -n "${GITHUB_ACTIONS:-}" ]] && renderer=github-actions
    set -o pipefail
    xcodebuild "$@" 2>&1 | xcbeautify --renderer "$renderer"
  else
    xcodebuild "$@"
  fi
}
