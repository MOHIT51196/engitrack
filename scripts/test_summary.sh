#!/bin/sh
set -e

LOG_FILE="$1"
if [ -z "$LOG_FILE" ]; then
  echo "Usage: test_summary.sh <log_file>" >&2
  exit 1
fi

CLEAN=$(sed 's/\x1B\[[0-9;]*m//g' "$LOG_FILE")
PASSED=$(echo "$CLEAN" | grep -oE '\+[0-9]+' | tail -1 | tr -d '+')
FAILED=$(echo "$CLEAN" | grep -oE ' -[0-9]+' | tail -1 | tr -d ' -')
PASSED=${PASSED:-0}
FAILED=${FAILED:-0}
TOTAL=$((PASSED + FAILED))

echo ""
printf "Total: %s  |  \033[32mPassed: %s\033[0m  |  \033[31mFailed: %s\033[0m\n" "$TOTAL" "$PASSED" "$FAILED"
