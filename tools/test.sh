#!/usr/bin/env bash
# Runs the headless test suite. Usage: tools/test.sh [filter]
# Fails on any test failure OR any GDScript runtime error in the log.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
ARGS=()
[[ $# -gt 0 ]] && ARGS=(-- "--filter=$1")
LOG=$(mktemp)
"$GODOT" --headless --path . -s tests/run_tests.gd "${ARGS[@]}" 2>&1 | tee "$LOG" | grep -E "^(PASS|FAIL)|passed|SCRIPT ERROR" -A1 | grep -v '^--'
code=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$LOG"; then
  echo "Script errors found in log"; code=1
fi
rm -f "$LOG"
exit $code
