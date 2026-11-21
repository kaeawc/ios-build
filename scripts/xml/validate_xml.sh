#!/usr/bin/env bash
#
# Checks that every tracked XML and property list file is well-formed.
# Uses xmllint, which ships with macOS (libxml2-utils on Linux). --nonet keeps it from fetching
# external DTDs such as Apple's plist DTD.

if ! command -v xmllint >/dev/null 2>&1; then
  echo "xmllint missing. On Linux: sudo apt-get install libxml2-utils"
  exit 1
fi

start_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")

# A read loop rather than mapfile, which macOS's bash 3.2 lacks.
xml_files=()
while IFS= read -r file; do
  xml_files+=("$file")
done < <(git ls-files --cached --others --exclude-standard | grep -E '\.(xml|plist)$' || true)

if [[ ${#xml_files[@]} -eq 0 ]]; then
  echo "No XML files found."
  exit 0
fi

errors=$(xmllint --noout --nonet "${xml_files[@]}" 2>&1)
status=$?

end_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")
total_elapsed=$((end_time - start_time))

if [[ $status -ne 0 ]]; then
  echo "Errors in the following files:"
  echo "$errors"
  echo "Total time elapsed: $total_elapsed ms."
  exit 1
fi

echo "${#xml_files[@]} XML file(s) are well-formed ($total_elapsed ms)."
