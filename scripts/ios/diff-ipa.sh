#!/usr/bin/env bash
#
# Usage: diff-ipa.sh <base-ipa> <current-ipa> [output.md]
#
# Compares two IPA files and writes a markdown report.
# Covers: compressed size, payload size, binary size, asset catalog,
# file count, added/removed files, and framework changes.

BASE_IPA="${1:?Usage: diff-ipa.sh <base-ipa> <current-ipa> [output.md]}"
CURRENT_IPA="${2:?Usage: diff-ipa.sh <base-ipa> <current-ipa> [output.md]}"
OUTPUT_FILE="${3:-build/ipa-diff.md}"

if [[ ! -f "$BASE_IPA" ]]; then
  echo "Base IPA not found: $BASE_IPA" >&2
  exit 1
fi

if [[ ! -f "$CURRENT_IPA" ]]; then
  echo "Current IPA not found: $CURRENT_IPA" >&2
  exit 1
fi

base_dir=$(mktemp -d)
current_dir=$(mktemp -d)

unzip -q "$BASE_IPA" -d "$base_dir"
unzip -q "$CURRENT_IPA" -d "$current_dir"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Total bytes for a file.
file_bytes() {
  wc -c < "$1" 2>/dev/null | tr -d ' ' || echo 0
}

# Total uncompressed bytes for a directory (portable: no du -b reliance).
dir_bytes() {
  find "$1" -type f | while IFS= read -r f; do
    wc -c < "$f"
  done | awk '{s+=$1} END {print s+0}'
}

# Human-readable size.
format_bytes() {
  local b=$1
  if [[ $b -ge 1048576 ]]; then
    awk "BEGIN {printf \"%.1f MB\", $b/1048576}"
  elif [[ $b -ge 1024 ]]; then
    awk "BEGIN {printf \"%.1f KB\", $b/1024}"
  else
    echo "${b} B"
  fi
}

# Delta string for byte values.
delta_bytes() {
  local delta=$(( $2 - $1 ))
  if [[ $delta -gt 0 ]]; then
    echo "+$(format_bytes "$delta")"
  elif [[ $delta -lt 0 ]]; then
    echo "-$(format_bytes "$(( -delta ))")"
  else
    echo "±0"
  fi
}

# Delta string for plain counts.
delta_count() {
  local delta=$(( $2 - $1 ))
  if [[ $delta -gt 0 ]]; then echo "+${delta}"
  elif [[ $delta -lt 0 ]]; then echo "${delta}"
  else echo "±0"
  fi
}

# ---------------------------------------------------------------------------
# Measurements
# ---------------------------------------------------------------------------

base_ipa_bytes=$(file_bytes "$BASE_IPA")
current_ipa_bytes=$(file_bytes "$CURRENT_IPA")

base_payload_bytes=$(dir_bytes "$base_dir/Payload")
current_payload_bytes=$(dir_bytes "$current_dir/Payload")

base_app=$(find "$base_dir/Payload" -maxdepth 1 -name "*.app" | head -1)
current_app=$(find "$current_dir/Payload" -maxdepth 1 -name "*.app" | head -1)
app_name=$(basename "$current_app" .app)

base_binary_bytes=$(file_bytes "$base_app/$app_name")
current_binary_bytes=$(file_bytes "$current_app/$app_name")

base_assets_bytes=$(file_bytes "$base_app/Assets.car")
current_assets_bytes=$(file_bytes "$current_app/Assets.car")

base_file_count=$(find "$base_app" -type f | wc -l | tr -d ' ')
current_file_count=$(find "$current_app" -type f | wc -l | tr -d ' ')

# Frameworks
base_frameworks=""
if [[ -d "$base_app/Frameworks" ]]; then
  base_frameworks=$(find "$base_app/Frameworks" -maxdepth 1 -name "*.framework" \
    | while IFS= read -r fw; do basename "$fw" .framework; done | sort)
fi

current_frameworks=""
if [[ -d "$current_app/Frameworks" ]]; then
  current_frameworks=$(find "$current_app/Frameworks" -maxdepth 1 -name "*.framework" \
    | while IFS= read -r fw; do basename "$fw" .framework; done | sort)
fi

added_frameworks=$(comm -13 <(echo "$base_frameworks") <(echo "$current_frameworks") | grep -v '^$' || true)
removed_frameworks=$(comm -23 <(echo "$base_frameworks") <(echo "$current_frameworks") | grep -v '^$' || true)

# File lists
base_files=$(find "$base_app" -type f | sed "s|${base_app}/||" | sort)
current_files=$(find "$current_app" -type f | sed "s|${current_app}/||" | sort)
added_files=$(comm -13 <(echo "$base_files") <(echo "$current_files") | grep -v '^$' || true)
removed_files=$(comm -23 <(echo "$base_files") <(echo "$current_files") | grep -v '^$' || true)

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

mkdir -p "$(dirname "$OUTPUT_FILE")"
{
  echo "## IPA Diff"
  echo ""
  echo "> Simulator binaries (arm64 + x86_64). Sizes reflect relative changes, not App Store download size."
  echo ""
  echo "| | Base | Current | Delta |"
  echo "|---|---|---|---|"
  echo "| IPA (compressed) | $(format_bytes "$base_ipa_bytes") | $(format_bytes "$current_ipa_bytes") | $(delta_bytes "$base_ipa_bytes" "$current_ipa_bytes") |"
  echo "| Payload (uncompressed) | $(format_bytes "$base_payload_bytes") | $(format_bytes "$current_payload_bytes") | $(delta_bytes "$base_payload_bytes" "$current_payload_bytes") |"
  echo "| Binary | $(format_bytes "$base_binary_bytes") | $(format_bytes "$current_binary_bytes") | $(delta_bytes "$base_binary_bytes" "$current_binary_bytes") |"
  echo "| Assets.car | $(format_bytes "$base_assets_bytes") | $(format_bytes "$current_assets_bytes") | $(delta_bytes "$base_assets_bytes" "$current_assets_bytes") |"
  echo "| File count | $base_file_count | $current_file_count | $(delta_count "$base_file_count" "$current_file_count") |"

  if [[ -n "$added_frameworks" ]]; then
    echo ""
    echo "**Added frameworks:** $(echo "$added_frameworks" | tr '\n' ',' | sed 's/,$//')"
  fi

  if [[ -n "$removed_frameworks" ]]; then
    echo ""
    echo "**Removed frameworks:** $(echo "$removed_frameworks" | tr '\n' ',' | sed 's/,$//')"
  fi

  if [[ -n "$added_files" ]]; then
    echo ""
    echo "<details><summary>Added files ($(echo "$added_files" | wc -l | tr -d ' '))</summary>"
    echo ""
    echo '```'
    echo "$added_files"
    echo '```'
    echo "</details>"
  fi

  if [[ -n "$removed_files" ]]; then
    echo ""
    echo "<details><summary>Removed files ($(echo "$removed_files" | wc -l | tr -d ' '))</summary>"
    echo ""
    echo '```'
    echo "$removed_files"
    echo '```'
    echo "</details>"
  fi
} > "$OUTPUT_FILE"

rm -rf "$base_dir" "$current_dir"

echo "Diff written to: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
