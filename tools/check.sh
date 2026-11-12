#!/usr/bin/env bash
# Parses every script via an editor import pass; prints unique script errors.
cd "$(dirname "$0")/.."
godot --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A1 | grep -v "^--" | paste - - | sort -u | grep -v "Compile Error: *at" | head -${1:-30}
