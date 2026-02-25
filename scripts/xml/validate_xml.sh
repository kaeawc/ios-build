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

# Validate in parallel. DOCTYPE declarations are stripped via sed before
# passing to xmlstarlet so it never attempts to fetch external DTDs over the
# network (e.g. the Apple plist DTD in Info.plist). Since we only check
# well-formedness (-w), the DOCTYPE is irrelevant to the result.
# XML_CMD is exported so it is visible inside the xargs subshells.
export XML_CMD
# shellcheck disable=SC2016
errors=$(printf '%s\n' "${xml_files[@]}" \
  | xargs -n 1 -P "$parallel_jobs" bash -c \
    'out=$(sed "/<!DOCTYPE/d" "$0" | "$XML_CMD" val -w -q -e - 2>&1); rc=$?; [ $rc -ne 0 ] && echo "$0: $out"')

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
