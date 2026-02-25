#!/usr/bin/env bash

PROJECT_ROOT="$(pwd)"
SCHEME="${SCHEME:-StarterApp}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_ROOT/build/DerivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PROJECT_ROOT/build/test.xcresult}"

start_time=$(date +%s)

# Find the Xcode project
project_path=$(find "$PROJECT_ROOT/ios" -name "*.xcodeproj" -maxdepth 3 2>/dev/null | head -1)

if [[ -z "$project_path" ]]; then
  echo "No .xcodeproj found. Run scripts/ios/xcodegen-generate.sh first."
  exit 1
fi

echo "Running tests for scheme: $SCHEME"
echo "Project: $project_path"

# Prefer a booted simulator, fall back to iPhone 16
destination="platform=iOS Simulator,name=iPhone 16,OS=latest"

booted_udid=$(xcrun simctl list devices booted --json 2>/dev/null |
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted' and 'iPhone' in d.get('name', ''):
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null || echo "")

if [[ -n "$booted_udid" ]]; then
  destination="platform=iOS Simulator,id=$booted_udid"
  echo "Using booted simulator: $booted_udid"
else
  echo "Using destination: $destination"
fi

# Remove old result bundle
rm -rf "$RESULT_BUNDLE_PATH"

xcodebuild test \
  -project "$project_path" \
  -scheme "$SCHEME" \
  -destination "$destination" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  INDEX_ENABLE_DATA_STORE=NO \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO

test_exit_code=$?
elapsed=$(($(date +%s) - start_time))

if [[ $test_exit_code -ne 0 ]]; then
  echo "Tests failed in ${elapsed}s"
  exit $test_exit_code
fi

echo "Tests passed in ${elapsed}s"
