#!/usr/bin/env bash
#
# Usage: create-ipa.sh <output_path>
#
# Packages the built Debug .app bundle into an IPA file.

PROJECT_ROOT="$(pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_ROOT/build/DerivedData}"

output_path="${1:?Usage: create-ipa.sh <output_path>}"
# Resolve to absolute path so it stays valid after cd-ing into the temp dir
[[ "$output_path" == /* ]] || output_path="$PROJECT_ROOT/$output_path"

# Debug builds land in Debug-iphonesimulator/
app_bundle=$(find "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator" \
  -maxdepth 1 -name "*.app" 2>/dev/null | head -1)

if [[ -z "$app_bundle" ]]; then
  echo "No .app bundle found in: $DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator"
  ls -la "$DERIVED_DATA_PATH/Build/Products/" 2>/dev/null || echo "(directory missing)"
  exit 1
fi

echo "Packaging: $app_bundle"
echo "Output:    $output_path"

tmp_dir=$(mktemp -d)
mkdir -p "$tmp_dir/Payload"
cp -r "$app_bundle" "$tmp_dir/Payload/"
mkdir -p "$(dirname "$output_path")"
(cd "$tmp_dir" && zip -qr "$output_path" Payload/)
rm -rf "$tmp_dir"

size=$(du -sh "$output_path" | cut -f1)
echo "IPA created: $output_path ($size)"
