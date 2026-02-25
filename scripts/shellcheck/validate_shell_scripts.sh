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

# Find shell scripts (by extension) and git hooks (by path) tracked by git,
# then validate in parallel. Hooks have no .sh extension so they need a
# separate match on the .githooks/ directory.
# shellcheck disable=SC2016
errors=$(git ls-files --cached --others --exclude-standard -z |
  grep -zE '(\.sh$|\.githooks/)' |
  xargs -0 -n 1 -P "$parallel_jobs" bash -c 'shellcheck --shell=bash "$0"' 2>&1)

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
