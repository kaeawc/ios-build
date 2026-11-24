#!/usr/bin/env bash
#
# Turns this template into your project: renames "StarterApp" everywhere (file contents, file and
# directory names, targets, schemes) and sets the bundle identifier prefix and display name.
#
# Usage: bash scripts/rename.sh <AppName> <bundle-id-prefix> ["Display Name"]
#   bash scripts/rename.sh Weather com.acme "Acme Weather"
#
#   AppName           Swift identifier for targets, schemes and the product (e.g. Weather)
#   bundle-id-prefix  reverse-DNS prefix; the app becomes <prefix>.<AppName> (e.g. com.acme)
#   Display Name      name under the icon on the Home Screen (defaults to AppName)
#
# Run it once on a clean checkout, review `git status`, then regenerate the Xcode project.

set -euo pipefail

old_name="StarterApp"
old_prefix="com.example"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

new_name="$1"
new_prefix="$2"
display_name="${3:-$1}"

if [[ ! "$new_name" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "AppName must start with a letter and contain only letters and digits: '$new_name'" >&2
  exit 1
fi
if [[ ! "$new_prefix" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "bundle-id-prefix must be reverse-DNS, like com.acme: '$new_prefix'" >&2
  exit 1
fi
if [[ "$display_name" == *[\\\$\"]* ]]; then
  echo "Display Name can't contain \\, \$ or \"" >&2
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first, so the rename is easy to review." >&2
  exit 1
fi
if ! git grep -q "$old_name" -- ':!scripts/rename.sh'; then
  echo "Nothing to rename: '$old_name' no longer appears in the repository." >&2
  exit 1
fi

# 1. File contents. perl -pi works the same with macOS and GNU tools.
git grep -lz "$old_name" -- ':!scripts/rename.sh' ':!LICENSE' |
  xargs -0 perl -pi -e "s/\Q$old_name\E/$new_name/g"

shared=ios/$old_name/Configurations/Shared.xcconfig
perl -pi -e "s/^BUNDLE_ID_PREFIX = \Q$old_prefix\E\$/BUNDLE_ID_PREFIX = $new_prefix/" "$shared"
perl -pi -e "s/^APP_DISPLAY_NAME = .*\$/APP_DISPLAY_NAME = $display_name/" "$shared"

# The same identity for Bazel.
config=ios/$old_name/config.bzl
perl -pi -e "s/^BUNDLE_ID_PREFIX = \"\Q$old_prefix\E\"\$/BUNDLE_ID_PREFIX = \"$new_prefix\"/" "$config"
perl -pi -e "s/^APP_DISPLAY_NAME = \".*\"\$/APP_DISPLAY_NAME = \"$display_name\"/" "$config"

# 2. File and directory names, deepest first so parents are renamed last.
git ls-files | grep "$old_name" | awk -F/ '{ print NF "\t" $0 }' | sort -rn | cut -f2- |
  while IFS= read -r path; do
    dir=$(dirname "$path")
    base=$(basename "$path")
    if [[ "$base" == *"$old_name"* ]]; then
      git mv "$path" "$dir/${base//$old_name/$new_name}"
    fi
  done
git ls-files | grep "/$old_name/" | sed "s|/$old_name/.*|/$old_name|" | sort -u |
  while IFS= read -r dir; do
    git mv "$dir" "${dir%"$old_name"}$new_name"
  done

# 3. Placeholder app icons with the new initial and Top Shelf name.
icons_step="Regenerate the app icons:    bash scripts/icons/generate.sh (needs rsvg-convert)"
if command -v rsvg-convert >/dev/null 2>&1; then
  bash scripts/icons/generate.sh
  icons_step="Replace the placeholder icons in ios/$new_name/{App,Watch}/Assets.xcassets"
fi

echo "Renamed $old_name → $new_name ($new_prefix.$new_name, \"$display_name\")."
echo
echo "Next:"
echo "  1. Review the changes:          git status && git diff --stat"
echo "  2. Regenerate the project:      bash scripts/ios/xcodegen-generate.sh"
echo "  3. Set DEVELOPMENT_TEAM in      ios/$new_name/Configurations/Shared.xcconfig (or Local.xcconfig)"
echo "  4. $icons_step"
echo "  5. Update the copyright holder in LICENSE, and README.md"
