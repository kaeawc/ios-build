#!/usr/bin/env bash
# Returns current time in milliseconds (cross-platform)
if [[ "$OSTYPE" == "darwin"* ]]; then
  python3 -c "import time; print(int(time.time() * 1000))"
else
  date +%s%3N
fi
