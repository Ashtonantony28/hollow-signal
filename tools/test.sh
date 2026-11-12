#!/usr/bin/env bash
# Runs the headless test suite. Usage: tools/test.sh [filter]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
ARGS=()
[[ $# -gt 0 ]] && ARGS=(-- "--filter=$1")
"$GODOT" --headless --path . -s tests/run_tests.gd "${ARGS[@]}"
