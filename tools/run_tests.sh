#!/usr/bin/env bash
# Underwars headless test runner — GDD §13.1 as amended (docs/decisions.md, 2026-08-04).
#
# Hardened against GUT 9.7.1 failure modes that all exit 0 (verified empirically):
#   - missing .godot/ import cache: gut_cmdln quits 0 without running anything
#   - -gdir does not recurse: tests/unit|sim|golden are ignored without -ginclude_subdirs
#   - "Nothing was run" / nonexistent -gdir path: exit 0
#
# Exit codes: 0 = tests ran and passed · 1 = failures or no tests collected · 2 = harness unavailable
#
# Loop agents: this script is the harness contract. Make it pass; do not weaken it.
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-/c/Users/aless/bin/godot47/Godot_v4.7-stable_win64_console.exe}"

if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "run_tests.sh: Godot binary not found: $GODOT (set GODOT_BIN)" >&2
  exit 2
fi

if [ ! -f "$ROOT/project.godot" ]; then
  echo "run_tests.sh: no project.godot yet (M0 incomplete) — harness unavailable" >&2
  exit 2
fi

# 1) Import pass: without .godot/, GUT's class_name cache is missing and gut_cmdln exits 0 doing nothing.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 \
  || { echo "run_tests.sh: godot --import failed" >&2; exit 1; }

# 2) Run GUT with subdirectory collection (tests/unit, tests/sim, tests/golden — GDD §11.2/§13.2).
OUT="$("$GODOT" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1)"
CODE=$?
printf '%s\n' "$OUT"

# 3) Refuse GUT's silent-success states: exit 0 with zero tests executed.
if printf '%s' "$OUT" | grep -qiE 'Nothing was run|does not exist|have not been imported'; then
  echo "run_tests.sh: GUT collected/ran no tests — failing (a green suite must actually run tests)" >&2
  exit 1
fi

exit "$CODE"
