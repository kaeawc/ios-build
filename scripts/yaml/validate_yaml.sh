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

# Validate (yamllint is fast enough that parallel adds overhead for small repos)
errors=$(printf '%s\n' "${yaml_files[@]}" | xargs yamllint -c .yamllint.yml 2>&1)

# Calculate total elapsed time
end_time=$(bash "$(pwd)/scripts/utils/get_timestamp.sh")
total_elapsed=$((end_time - start_time))

# Check and report errors
if [[ -n $errors ]]; then
  echo "Errors in the following files:"
  echo "$errors"
  echo "Total time elapsed: $total_elapsed ms."
  exit 1
fi

echo "All YAML files are valid."
echo "Total time elapsed: $total_elapsed ms."
