#!/usr/bin/env bash

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
  echo "shellcheck missing"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Try 'brew install shellcheck'"
  else
    echo "Consult your OS package manager"
  fi
  exit 1
fi

# Start the timer
start_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")

# Determine parallel job count (cross-platform)
parallel_jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# When ONLY_TOUCHED_FILES=true (e.g. pre-commit hook) only check staged files;
# otherwise check all tracked files. Hooks have no .sh extension so they need
# a separate match on the .githooks/ directory.
# Null bytes cannot survive in a bash variable, so pipe directly to xargs.
# shellcheck disable=SC2016
if [[ "${ONLY_TOUCHED_FILES:-false}" == "true" ]]; then
  errors=$(git diff --cached --name-only --diff-filter=d -z |
    grep -zE '(\.sh$|\.githooks/)' |
    xargs -0 -n 1 -P "$parallel_jobs" bash -c 'shellcheck --shell=bash "$0"' 2>&1)
else
  errors=$(git ls-files --cached --others --exclude-standard -z |
    grep -zE '(\.sh$|\.githooks/)' |
    xargs -0 -n 1 -P "$parallel_jobs" bash -c 'shellcheck --shell=bash "$0"' 2>&1)
fi

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

echo "All shell scripts are valid."
echo "Total time elapsed: $total_elapsed ms."
