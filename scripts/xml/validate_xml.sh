#!/usr/bin/env bash

# xmllint is built-in on macOS and available via libxml2-utils on Linux.
if ! command -v xmllint &>/dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "xmllint missing (expected to be built-in on macOS)"
  else
    echo "xmllint missing. Try: sudo apt-get install libxml2-utils"
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

# Validate in parallel. --nonet prevents fetching external DTDs over the
# network (e.g. the Apple plist DTD declared in Info.plist's DOCTYPE).
# --noout suppresses document output; only errors are printed.
# shellcheck disable=SC2016
errors=$(printf '%s\n' "${xml_files[@]}" \
  | xargs -n 1 -P "$parallel_jobs" bash -c 'xmllint --nonet --noout "$0" 2>&1')

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
