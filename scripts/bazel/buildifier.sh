#!/usr/bin/env bash
#
# Runs buildifier on every tracked Starlark file (BUILD.bazel, *.bzl, MODULE.bazel).
#
# Usage: bash scripts/bazel/buildifier.sh [check|fix]
#   check (default)  fail on formatting or lint warnings
#   fix              rewrite the files and apply lint fixes

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

mode="${1:-check}"

if ! command -v buildifier >/dev/null 2>&1; then
  echo "buildifier missing. Run: mise install"
  exit 1
fi

# A read loop rather than mapfile, which macOS's bash 3.2 lacks.
files=()
while IFS= read -r file; do
  files+=("$file")
done < <(git ls-files --cached --others --exclude-standard -- \
  'BUILD' 'BUILD.bazel' '*/BUILD' '*/BUILD.bazel' '*.bzl' 'MODULE.bazel' 'WORKSPACE.bazel')

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No Starlark files found."
  exit 0
fi

case "$mode" in
  check) buildifier -mode=check -lint=warn "${files[@]}" ;;
  fix) buildifier -mode=fix -lint=fix "${files[@]}" ;;
  *)
    echo "Unknown mode '$mode'. Use check or fix." >&2
    exit 1
    ;;
esac
status=$?
if [[ $status -eq 0 && "$mode" == "check" ]]; then
  echo "${#files[@]} Starlark file(s) are formatted and lint-clean."
fi
exit $status
