#!/usr/bin/env bash

INSTALL_SHFMT_WHEN_MISSING=${INSTALL_SHFMT_WHEN_MISSING:-false}
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

echo -e "${YELLOW}Checking for required commands...${NC}"

if ! command_exists shfmt; then
  echo -e "${RED}shfmt is not installed${NC}"
  if [[ "${INSTALL_SHFMT_WHEN_MISSING}" == "true" ]]; then
    echo -e "${YELLOW}Installing shfmt...${NC}"
    if [[ -f "$PROJECT_ROOT/scripts/shellcheck/install_shfmt.sh" ]]; then
      if ! bash "$PROJECT_ROOT/scripts/shellcheck/install_shfmt.sh"; then
        echo -e "${RED}Failed to install shfmt${NC}"
        exit 1
      fi
    else
      echo -e "${RED}shfmt installation script not found${NC}"
      exit 1
    fi
  else
    echo -e "${RED}shfmt is required. Set INSTALL_SHFMT_WHEN_MISSING=true to auto-install.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}shfmt is available${NC}"

for cmd in find xargs git; do
  if ! command_exists "$cmd"; then
    echo -e "${RED}Required command '$cmd' is not available${NC}"
    exit 1
  fi
done

start_time=$(bash "$PROJECT_ROOT/scripts/utils/get_timestamp.sh")

echo -e "${YELLOW}Starting shfmt formatting...${NC}"

find_all_shell_files() {
  git ls-files --cached --others --exclude-standard -z \
    | grep -z '\.sh$' \
    | xargs -0 -I {} echo "$PROJECT_ROOT/{}" \
    | sort \
    | uniq
}

get_touched_files() {
  {
    git diff --cached --name-only --diff-filter=ACMR | while read -r file; do
      if [[ "$file" =~ ^.*\.sh$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo "$PROJECT_ROOT/$file"
      fi
    done

    git diff --name-only --diff-filter=ACMR | while read -r file; do
      if [[ "$file" =~ ^.*\.sh$ ]] && [[ -f "$PROJECT_ROOT/$file" ]]; then
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
  echo -e "${YELLOW}Processing all shell script files in the project${NC}"
  while IFS= read -r file; do
    [[ -n "$file" ]] && files_to_process+=("$file")
  done < <(find_all_shell_files)
fi

if [[ ${#files_to_process[@]} -eq 0 ]]; then
  echo -e "${GREEN}No shell script files to process${NC}"
  end_time=$(bash "$PROJECT_ROOT/scripts/utils/get_timestamp.sh")
  echo "Total time elapsed: $((end_time - start_time)) ms."
  exit 0
fi

echo -e "${YELLOW}Found ${#files_to_process[@]} shell script file(s) to process${NC}"

temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT
printf '%s\n' "${files_to_process[@]}" >"$temp_file"

# Apply shfmt: 2-space indent, binary ops may start a line, switch cases indented, space after redirects
echo -e "${YELLOW}Applying shfmt formatting...${NC}"
errors=""

if [[ -s "$temp_file" ]]; then
  shfmt_output=$(xargs shfmt -i 2 -bn -ci -sr -w 2>&1 <"$temp_file")
  if echo "$shfmt_output" | grep -Ei "(error|failed)" >/dev/null 2>&1; then
    errors="$shfmt_output"
  fi
fi

end_time=$(bash "$PROJECT_ROOT/scripts/utils/get_timestamp.sh")
total_elapsed=$((end_time - start_time))

if [[ -n "$errors" ]]; then
  echo -e "${RED}Errors encountered during formatting:${NC}"
  echo -e "$errors"
  echo -e "${RED}Total time elapsed: $total_elapsed ms.${NC}"
  exit 1
fi

printf '%s\n' "${files_to_process[@]}" | xargs git add

echo -e "${GREEN}Shell scripts have been formatted successfully.${NC}"
echo "Total time elapsed: $total_elapsed ms."
exit 0
