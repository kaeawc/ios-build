#!/usr/bin/env bash

# Cross-platform XML validation using xmlstarlet or xml command (macOS alias)
validate_xml() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    xml "$@"
  else
    xmlstarlet "$@"
  fi
}

# Check for required XML tools
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v xml &>/dev/null; then
    echo "xmlstarlet missing. Try: brew install xmlstarlet"
    exit 1
  fi
else
  if ! command -v xmlstarlet &>/dev/null; then
    echo "xmlstarlet missing. Consult your OS package manager."
    exit 1
  fi
fi

# Start the timer
start_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")

# Determine parallel job count (cross-platform)
parallel_jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Export the function so xargs bash subshells can use it
export -f validate_xml
export OSTYPE

# Find XML files tracked by git and validate in parallel
# shellcheck disable=SC2016
errors=$(git ls-files --cached --others --exclude-standard -z |
  grep -z '\.xml$' |
  xargs -0 -n 1 -P "$parallel_jobs" bash -c 'validate_xml val -w -b -e "$0"' 2>&1)

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
