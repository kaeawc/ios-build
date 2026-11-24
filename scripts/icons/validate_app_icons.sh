#!/usr/bin/env bash
#
# Fails when an app icon has an empty slot or points at a missing file. App Store Connect rejects
# archives with missing icons, while simulator builds only warn, so catch it in lint.
# Checks every AppIcon*.appiconset, .brandassets (tvOS) and .solidimagestack (visionOS).
# Needs jq (preinstalled on macOS 15+ and GitHub's runners).

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

if ! command -v jq >/dev/null 2>&1; then
  echo "jq missing. macOS: brew install jq; Linux: apt-get install jq"
  exit 1
fi

errors=0
checked=0
while IFS= read -r contents; do
  dir=$(dirname "$contents")
  checked=$((checked + 1))
  # "images" entries (image sets) must all name an existing file; "layers" and "assets" entries
  # (stacks and brand assets) must name an existing directory.
  while IFS=$'\t' read -r kind name; do
    if [[ -z "$name" ]]; then
      echo "✗ $contents: an entry in \"${kind}s\" has no filename (empty icon slot)"
      errors=$((errors + 1))
    elif [[ ! -e "$dir/$name" ]]; then
      echo "✗ $contents: $kind '$name' does not exist"
      errors=$((errors + 1))
    fi
  done < <(jq -r '
    ((.images // [])[] | ["image", (.filename // "")]),
    ((.layers // [])[] | ["layer", (.filename // "")]),
    ((.assets // [])[] | ["asset", (.filename // "")])
    | @tsv' "$contents")
done < <(git ls-files --cached --others --exclude-standard -- '*Contents.json' |
  grep -E '\.(appiconset|brandassets|solidimagestack)/' || true)

if [[ $checked -eq 0 ]]; then
  echo "No app icon sets found."
  exit 0
fi
if [[ $errors -gt 0 ]]; then
  echo "Regenerate the placeholders with: bash scripts/icons/generate.sh"
  exit 1
fi
echo "All $checked app icon asset files are complete."
