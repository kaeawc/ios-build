#!/usr/bin/env bash

ONLY_TOUCHED_FILES=${ONLY_TOUCHED_FILES:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

PROJECT_ROOT="$(pwd)"
echo "PROJECT_ROOT: $PROJECT_ROOT"

# Cross-platform XML formatting using xmlstarlet or xml command
format_xml() {
  local file="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    xml fo -s 2 "$file" >"$file.formatted" 2>&1
  else
    xmlstarlet fo -s 2 "$file" >"$file.formatted" 2>&1
  fi

  local exit_code=$?
  if [[ $exit_code -eq 0 && -f "$file.formatted" ]]; then
    mv "$file.formatted" "$file"
    return 0
  else
    rm -f "$file.formatted"
    return 1
  fi
}

echo -e "${YELLOW}Checking for required commands...${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command_exists xml; then
    echo -e "${RED}xmlstarlet (xml command) is not installed${NC}"
    echo "Try: brew install xmlstarlet"
    exit 1
  fi
else
  if ! command_exists xmlstarlet; then
    echo -e "${RED}xmlstarlet is not installed${NC}"
    echo "Consult your OS package manager"
    exit 1
  fi
fi

echo -e "${GREEN}XML tools are available${NC}"

for cmd in find xargs git; do
  if ! command_exists "$cmd"; then
    echo -e "${RED}Required command '$cmd' is not available${NC}"
    exit 1
  fi
done

start_time=$(bash "$PROJECT_ROOT/scripts/utils/get_timestamp.sh")
echo -e "${YELLOW}Starting XML formatting...${NC}"

find_all_xml_files() {
  git ls-files --cached --others --exclude-standard -z |
    grep -z '\.xml$' |
    xargs -0 -I {} echo "$PROJECT_ROOT/{}"
}

get_touched_files() {
  {
    git diff --cached --name-only --diff-filter=ACMR | while read -r file; do
      if [[ "$file" =~ ^.*\.xml$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo "$PROJECT_ROOT/$file"
      fi
    done

    git diff --name-only --diff-filter=ACMR | while read -r file; do
      if [[ "$file" =~ ^.*\.xml$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo "$PROJECT_ROOT/$file"
      fi
    done
  } | sort | uniq
}

declare -a files_to_process

if [[ "${ONLY_TOUCHED_FILES}" == "true" ]]; then
  echo -e "${YELLOW}Processing only touched/staged files${NC}"
  while IFS= read -r file; do
    [[ -n "$file" ]] && files_to_process+=("$file")
  done < <(get_touched_files)
else
  echo -e "${YELLOW}Processing all XML files in the project${NC}"
  while IFS= read -r file; do
    [[ -n "$file" ]] && files_to_process+=("$file")
  done < <(find_all_xml_files)
fi

if [[ ${#files_to_process[@]} -eq 0 ]]; then
  echo -e "${GREEN}No XML files to process${NC}"
  end_time=$(bash "$PROJECT_ROOT/scripts/utils/get_timestamp.sh")
  echo "Total time elapsed: $((end_time - start_time)) ms."
  exit 0
fi

echo -e "${YELLOW}Found ${#files_to_process[@]} XML file(s) to process${NC}"
echo -e "${YELLOW}Applying XML formatting...${NC}"

declare -a failed_files
processed_count=0

for file in "${files_to_process[@]}"; do
  if [[ -f "$file" ]]; then
    if format_xml "$file"; then
      ((processed_count++))
      echo -e "${GREEN}✓${NC} $file"
    else
      failed_files+=("$file")
      echo -e "${RED}✗${NC} $file"
    fi
  fi
done

echo -e "${GREEN}Processed $processed_count file(s)${NC}"

end_time=$(bash "$PROJECT_ROOT/scripts/utils/get_timestamp.sh")
total_elapsed=$((end_time - start_time))

if [[ ${#failed_files[@]} -gt 0 ]]; then
  echo -e "${RED}Failed to format ${#failed_files[@]} file(s):${NC}"
  printf '%s\n' "${failed_files[@]}"
  echo -e "${RED}Total time elapsed: $total_elapsed ms.${NC}"
  exit 1
fi

printf '%s\n' "${files_to_process[@]}" | xargs git add

echo -e "${GREEN}XML files have been formatted successfully.${NC}"
echo "Total time elapsed: $total_elapsed ms."
exit 0
