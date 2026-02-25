#!/usr/bin/env bash

# Check if yamllint is installed
if ! command -v yamllint &>/dev/null; then
  echo "yamllint missing"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Try 'brew install yamllint'"
  else
    echo "Consult your OS package manager"
  fi
  exit 1
fi

# Start the timer
start_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")

# Collect YAML files tracked by git
mapfile -t yaml_files < <(git ls-files --cached --others --exclude-standard | grep -E '\.(yml|yaml)$' || true)

if [[ ${#yaml_files[@]} -eq 0 ]]; then
  end_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")
  total_elapsed=$((end_time - start_time))
  echo "No YAML files found in $total_elapsed ms."
  exit 0
fi

# Validate all files in one yamllint invocation and capture output + exit code.
# yamllint exits 0 (pass, possibly with warnings), 1 (errors found), or 2 (config error).
output=$(yamllint -c .yamllint.yml "${yaml_files[@]}" 2>&1)
exit_code=$?

# Calculate total elapsed time
end_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")
total_elapsed=$((end_time - start_time))

if [[ $exit_code -ne 0 ]]; then
  echo "YAML errors found:"
  echo "$output"
  echo "Total time elapsed: $total_elapsed ms."
  exit "$exit_code"
fi

if [[ -n "$output" ]]; then
  echo "YAML warnings (not blocking):"
  echo "$output"
fi

echo "All YAML files are valid."
echo "Total time elapsed: $total_elapsed ms."
