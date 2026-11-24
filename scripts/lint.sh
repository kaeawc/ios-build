#!/usr/bin/env bash
#
# Runs every check the CI "Lint" job runs. Install the tools first with `mise install`
# (versions are pinned in mise.toml), plus `brew install yamllint` on macOS.
#
# Usage: bash scripts/lint.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

failed=()
check() {
  local name="$1"
  shift
  echo "→ $name"
  if ! "$@"; then
    failed+=("$name")
  fi
}

# On Linux, mise installs a static SwiftLint that needs no Swift toolchain at runtime.
swiftlint=swiftlint
if command -v swiftlint-static >/dev/null 2>&1; then
  swiftlint="swiftlint-static"
fi

swiftformat_reporter=()
swiftlint_reporter=()
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  swiftformat_reporter=(--reporter github-actions-log)
  swiftlint_reporter=(--reporter github-actions-logging)
fi

check "ShellCheck" env ONLY_TOUCHED_FILES=false bash scripts/shellcheck/validate_shell_scripts.sh
check "SwiftFormat" swiftformat --lint ${swiftformat_reporter[@]+"${swiftformat_reporter[@]}"} .
check "SwiftLint" "$swiftlint" lint --strict --quiet ${swiftlint_reporter[@]+"${swiftlint_reporter[@]}"}
check "buildifier" bash scripts/bazel/buildifier.sh
check "actionlint" actionlint
check "YAML" bash scripts/yaml/validate_yaml.sh
check "XML and property lists" bash scripts/xml/validate_xml.sh
check "App icons" bash scripts/icons/validate_app_icons.sh

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "✗ Failed: ${failed[*]}"
  echo "  Fix formatting with: bash scripts/format.sh"
  exit 1
fi
echo "✓ All checks passed"
