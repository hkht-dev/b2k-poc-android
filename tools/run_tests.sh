#!/usr/bin/env bash
# Run the GUT suite and fail if any test script was skipped.
#
# GUT prints a warning and carries on when a test script will not compile, and
# the run still exits 0. A broken test file would otherwise look exactly like a
# passing one. This counts the scripts GUT actually ran against the files on
# disk and fails when they disagree.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT"' EXIT

"$GODOT" --headless --path "$PROJECT_ROOT" \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs \
  -gprefix=test_ -gsuffix=.gd -gexit 2>&1 | tee "$OUTPUT"
status=${PIPESTATUS[0]}

expected=$(find "$PROJECT_ROOT/tests" -name 'test_*.gd' | wc -l | tr -d ' ')
actual=$(grep -cE '^Scripts +[0-9]+' "$OUTPUT" >/dev/null && \
         grep -oE '^Scripts +[0-9]+' "$OUTPUT" | grep -oE '[0-9]+' || echo 0)

echo
if [ "$actual" != "$expected" ]; then
  echo "run_tests: GUT ran $actual of $expected test scripts." >&2
  grep -iE 'Ignoring script|Parse Error|Failed to load script' "$OUTPUT" >&2 || true
  echo "run_tests: a skipped test script is a failing test script." >&2
  exit 1
fi

if [ "$status" -ne 0 ]; then
  echo "run_tests: GUT reported failures." >&2
  exit "$status"
fi

echo "run_tests: $actual/$expected test scripts ran, all passed."
