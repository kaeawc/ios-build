#!/usr/bin/env bash

PROJECT_ROOT="$(pwd)"
SCHEME="${SCHEME:-StarterApp}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_ROOT/build/DerivedData}"

start_time=$(date +%s)

# Find the Xcode project
project_path=$(find "$PROJECT_ROOT/ios" -name "*.xcodeproj" -maxdepth 3 2>/dev/null | head -1)

if [[ -z "$project_path" ]]; then
  echo "No .xcodeproj found. Run scripts/ios/xcodegen-generate.sh first."
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION)"
echo "Project: $project_path"
echo "DerivedData: $DERIVED_DATA_PATH"

xcodebuild build \
  -project "$project_path" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  INDEX_ENABLE_DATA_STORE=NO

build_exit_code=$?
elapsed=$(($(date +%s) - start_time))

if [[ $build_exit_code -ne 0 ]]; then
  echo "Build failed in ${elapsed}s"
  exit $build_exit_code
fi

echo "Build succeeded in ${elapsed}s"
