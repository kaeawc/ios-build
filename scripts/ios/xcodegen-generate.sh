#!/usr/bin/env bash

# Check if xcodegen is installed
if ! command -v xcodegen &>/dev/null; then
  echo "xcodegen is not installed."
  echo "Install with: brew install xcodegen"
  exit 1
fi

PROJECT_ROOT="$(pwd)"
echo "PROJECT_ROOT: $PROJECT_ROOT"

start_time=$(date +%s)

# Find all project.yml files in the ios/ directory
project_files=()
while IFS= read -r f; do
  project_files+=("$f")
done < <(find "$PROJECT_ROOT/ios" -name "project.yml" \
  -not -path "*/.build/*" \
  -not -path "*/build/*" \
  -not -path "*/DerivedData/*" \
  2>/dev/null | sort)

if [[ ${#project_files[@]} -eq 0 ]]; then
  echo "No project.yml files found in ios/"
  exit 1
fi

echo "Found ${#project_files[@]} project.yml file(s)"

generated=0
failed=0

for project_file in "${project_files[@]}"; do
  project_dir=$(dirname "$project_file")
  echo ""
  echo "Generating Xcode project for: $project_file"

  if xcodegen generate --spec "$project_file" --project "$project_dir"; then
    ((generated++))
    echo "✓ Generated: $project_dir"
  else
    ((failed++))
    echo "✗ Failed: $project_dir"
  fi
done

elapsed=$(($(date +%s) - start_time))
echo ""
echo "Generated: $generated project(s) in ${elapsed}s"

if [[ $failed -gt 0 ]]; then
  echo "Failed: $failed project(s)"
  exit 1
fi
