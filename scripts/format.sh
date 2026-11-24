#!/usr/bin/env bash
#
# Formats all Swift code with SwiftFormat, applies SwiftLint's automatic fixes, then formats the
# Bazel files with buildifier.
#
# Usage: bash scripts/format.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

swiftlint=swiftlint
if command -v swiftlint-static >/dev/null 2>&1; then
  swiftlint="swiftlint-static"
fi

swiftformat .
"$swiftlint" lint --fix --quiet
bash scripts/bazel/buildifier.sh fix
