#!/usr/bin/env bash

# Cross-platform XML validation using xmlstarlet or xml command (macOS alias)
XML_CMD="xmlstarlet"
if [[ "$OSTYPE" == "darwin"* ]]; then
  XML_CMD="xml"
fi

# Check for required XML tools
if ! command -v "$XML_CMD" &>/dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "xmlstarlet missing. Try: brew install xmlstarlet"
  else
    echo "xmlstarlet missing. Consult your OS package manager."
  fi
  exit 1
fi

# Start the timer
start_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")

# Determine parallel job count (cross-platform)
parallel_jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Collect XML and plist files tracked by git
mapfile -t xml_files < <(git ls-files --cached --others --exclude-standard | grep -E '\.(xml|plist)$' || true)

if [[ ${#xml_files[@]} -eq 0 ]]; then
  end_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")
  total_elapsed=$((end_time - start_time))
  echo "No XML files found in $total_elapsed ms."
  exit 0
fi

# Validate in parallel
errors=$(printf '%s\n' "${xml_files[@]}" \
  | xargs -n 1 -P "$parallel_jobs" "$XML_CMD" val -w -b -e 2>&1)

# Calculate total elapsed time
end_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")
total_elapsed=$((end_time - start_time))

# Check and report errors
if [[ -n $errors ]]; then
  echo "Errors in the following files:"
  echo "$errors"
  echo "Total time elapsed: $total_elapsed ms."
  exit 1
fi

echo "No XML errors found in $total_elapsed ms."
