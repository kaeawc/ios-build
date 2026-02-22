#!/usr/bin/env bash

INSTALL_SWIFTFORMAT_WHEN_MISSING=${INSTALL_SWIFTFORMAT_WHEN_MISSING:-false}
ONLY_TOUCHED_FILES=${ONLY_TOUCHED_FILES:-false}
ONLY_CHANGED_SINCE_SHA=${ONLY_CHANGED_SINCE_SHA:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

PROJECT_ROOT="$(pwd)"

echo -e "${YELLOW}Checking for required commands...${NC}"

if ! command_exists swiftformat; then
  echo -e "${RED}swiftformat is not installed${NC}"
  if [[ "${INSTALL_SWIFTFORMAT_WHEN_MISSING}" == "true" ]]; then
    echo -e "${YELLOW}Installing swiftformat...${NC}"
    if [[ -f "$PROJECT_ROOT/scripts/swiftformat/install_swiftformat.sh" ]]; then
      if ! bash "$PROJECT_ROOT/scripts/swiftformat/install_swiftformat.sh"; then
        echo -e "${RED}Failed to install swiftformat${NC}"
        exit 1
      fi
    else
      echo -e "${RED}swiftformat installation script not found${NC}"
      exit 1
    fi
  else
    echo -e "${RED}swiftformat is required. Set INSTALL_SWIFTFORMAT_WHEN_MISSING=true to auto-install.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}swiftformat is available ($(swiftformat --version))${NC}"

start_time=$(date +%s)
echo -e "${YELLOW}Starting SwiftFormat validation...${NC}"

find_all_swift_files() {
  find "$PROJECT_ROOT/ios" -type f -name "*.swift" \
    -not -path "*/build/*" \
    -not -path "*/.build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Pods/*" \
    -not -path "*/Carthage/*" \
    -not -path "*/.swiftpm/*" \
    -not -path "*/xcuserdata/*" \
    2>/dev/null | sort | uniq
}

get_changed_files_since_sha() {
  local sha="$1"
  if ! git rev-parse --verify "$sha" >/dev/null 2>&1; then
    echo -e "${RED}SHA '$sha' does not exist in the repository${NC}" >&2
    exit 1
  fi
  git diff --name-only "$sha"...HEAD | while read -r file; do
    if [[ "$file" =~ ^ios/.*\.swift$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
      echo "$PROJECT_ROOT/$file"
    fi
  done | sort | uniq
}

get_touched_files() {
  {
    git diff --cached --name-only --diff-filter=ACMR | while read -r file; do
      if [[ "$file" =~ ^ios/.*\.swift$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo "$PROJECT_ROOT/$file"
      fi
    done

    git diff --name-only --diff-filter=ACMR | while read -r file; do
      if [[ "$file" =~ ^ios/.*\.swift$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo "$PROJECT_ROOT/$file"
      fi
    done
  } | sort | uniq
}

declare -a files_to_process

if [[ -n "$ONLY_CHANGED_SINCE_SHA" ]]; then
  echo -e "${YELLOW}Processing files changed since SHA: $ONLY_CHANGED_SINCE_SHA${NC}"
  while IFS= read -r file; do
    [[ -n "$file" ]] && files_to_process+=("$file")
  done < <(get_changed_files_since_sha "$ONLY_CHANGED_SINCE_SHA")
elif [[ "${ONLY_TOUCHED_FILES}" == "true" ]]; then
  echo -e "${YELLOW}Processing only touched/staged files${NC}"
  while IFS= read -r file; do
    [[ -n "$file" ]] && files_to_process+=("$file")
  done < <(get_touched_files)
else
  echo -e "${YELLOW}Processing all Swift files in ios/ directory${NC}"
  while IFS= read -r file; do
    [[ -n "$file" ]] && files_to_process+=("$file")
  done < <(find_all_swift_files)
fi

if [[ ${#files_to_process[@]} -eq 0 ]]; then
  echo -e "${GREEN}No Swift files to process${NC}"
  echo "Total time elapsed: $(($(date +%s) - start_time))s"
  exit 0
fi

echo -e "${YELLOW}Found ${#files_to_process[@]} Swift file(s) to check${NC}"

temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT
printf '%s\n' "${files_to_process[@]}" >"$temp_file"

echo -e "${YELLOW}Running swiftformat --lint...${NC}"

lint_output=""
lint_exit_code=0

while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    file_output=$(swiftformat --lint "$file" 2>&1)
    file_exit_code=$?
    if [[ $file_exit_code -ne 0 ]]; then
      lint_exit_code=1
      lint_output="${lint_output}${file_output}\n"
    fi
  fi
done <"$temp_file"

total_elapsed=$(($(date +%s) - start_time))

if [[ $lint_exit_code -ne 0 ]]; then
  echo -e "${RED}Formatting issues found:${NC}"
  echo -e "$lint_output"
  echo ""
  echo -e "${YELLOW}To fix these issues, run:${NC}"
  echo "  ./scripts/swiftformat/apply_swiftformat.sh"
  echo ""
  echo -e "${RED}Total time elapsed: ${total_elapsed}s${NC}"
  exit 1
fi

echo -e "${GREEN}All Swift source files are properly formatted.${NC}"
echo "Total time elapsed: ${total_elapsed}s"
exit 0
