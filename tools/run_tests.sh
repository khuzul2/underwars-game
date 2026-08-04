#!/usr/bin/env bash
# Underwars headless test runner — GDD §13.1 as amended (docs/decisions.md, 2026-08-04; hardened
# further by M0-T5, 2026-08-04).
#
# Hardened against GUT 9.7.1 failure modes that all exit 0 (verified empirically):
#   - missing .godot/ import cache: gut_cmdln quits 0 without running anything
#   - -gdir does not recurse: tests/unit|sim|golden are ignored without -ginclude_subdirs
#   - "Nothing was run" / nonexistent -gdir path: exit 0
#   - a test_*.gd file that fails to PARSE is silently un-collected while every OTHER script still
#     runs: GUT exits 0 and the Scripts/Tests/Asserts totals stay byte-identical to a healthy run
#     (docs/decisions.md M0-T4 item (i), corrected by M0-T5). A magic-number count cannot catch
#     that at all, and a diagnostic grep only catches it for as long as GUT chooses to log the
#     file it failed to open; only "every test_*.gd on disk was actually collected" is evasion-
#     proof, which is why the script-coverage guard below exists in addition to the grep.
#
# Exit codes: 0 = tests ran and passed · 1 = failures or no tests collected · 2 = harness unavailable
#
# Loop agents: this script is the harness contract. Make it pass; do not weaken it.
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Self-contained toolchain: ALWAYS the repo-local binary (godot/ is gitignored — 178 MB exceeds
# GitHub's file limit; a fresh clone must drop the official 4.7-stable win64 build into godot/).
GODOT="$ROOT/godot/Godot_v4.7-stable_win64_console.exe"

if [ ! -x "$GODOT" ]; then
  echo "run_tests.sh: repo-local Godot missing: $GODOT" >&2
  echo "  Place Godot_v4.7-stable_win64_console.exe + Godot_v4.7-stable_win64.exe in godot/ (see README)." >&2
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

# 3) Refuse GUT's silent-success states: exit 0 with zero tests executed, OR exit 0 while a
#    test_*.gd script failed to load/parse (M0-T5 — strengthening only; the three original
#    alternatives from docs/decisions.md SETUP-2 item 2 stay in the list forever).
# NEVER pipe "$OUT" into `grep -q` (M1-T4, measured live): `grep -q` exits the instant it
# matches, the upstream writer dies of SIGPIPE, and `-o pipefail` then makes the WHOLE pipeline
# report 141 even though the pattern DID match. Below ~64 KB of output the writer finishes first
# and the bug is invisible; above it the refusal here silently stops firing (a FALSE GREEN) and
# the coverage guard below reports every file as missing (a false red). Both greps therefore read
# from a here-string, which has no writer process to kill. Reproduced and re-verified at M1-T4
# with an 89 KB run.
if grep -qiE 'Nothing was run|does not exist|have not been imported|Failed to load script|Ignoring script' <<< "$OUT"; then
  echo "run_tests.sh: GUT reported a diagnostic meaning a test script did not run as written — failing (a green suite must actually run every collected test)" >&2
  exit 1
fi

# 4) Script-coverage guard (M0-T5) — the half that cannot be evaded. Both measured parse-error
#    variants leave GUT's Scripts/Tests/Asserts totals byte-identical to a healthy run while the
#    process exits 0. The refusal grep above happens to fire FIRST today (a test_-prefixed broken
#    file does print both diagnostics — measured this iteration, correcting docs/decisions.md
#    M0-T4 item (i)), but that depends on GUT choosing to log a file it never opened; this guard
#    depends on nothing but the filesystem. Proven load-bearing by negative control at Verify:
#    with the grep neutered, both variants still exit 1 HERE ("Scripts=7 but 8 on disk") and a
#    healthy tree still exits 0. Enumerate every tests/**/test_*.gd on disk using EXACTLY GUT
#    9.7.1's own prefix/suffix collection rule (test_*.gd, recursive — the reason
#    -ginclude_subdirs exists) and require (a) every one of them named somewhere in GUT's output
#    and (b) GUT's own "Scripts" total to equal that count.
DISK_SCRIPTS=()
while IFS= read -r -d '' f; do
  DISK_SCRIPTS+=("$f")
done < <(find "$ROOT/tests" -type f -name 'test_*.gd' -print0)

if [ "${#DISK_SCRIPTS[@]}" -eq 0 ]; then
  echo "run_tests.sh: found ZERO test_*.gd files under tests/ — enumeration is broken, refusing to call that a pass" >&2
  exit 1
fi

MISSING=()
for f in "${DISK_SCRIPTS[@]}"; do
  REL="${f#"$ROOT"/}"
  REL="${REL//\\//}"
  RES_PATH="res://$REL"
  # Here-string, not `printf | grep -q` — see the SIGPIPE/pipefail note above.
  if ! grep -qF -- "$RES_PATH" <<< "$OUT"; then
    MISSING+=("$RES_PATH")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "run_tests.sh: the following test_*.gd files are on disk but GUT's output never mentions them — a parse error may have silently un-collected the whole file:" >&2
  for m in "${MISSING[@]}"; do
    echo "  $m" >&2
  done
  exit 1
fi

CLEAN_OUT="$(printf '%s\n' "$OUT" | sed 's/\x1b\[[0-9;]*m//g')"
SCRIPTS_LINE="$(printf '%s\n' "$CLEAN_OUT" | grep -E '^Scripts[[:space:]]+[0-9]+' | head -n1)"
SCRIPTS_COUNT=""
if [ -n "$SCRIPTS_LINE" ]; then
  SCRIPTS_COUNT="$(printf '%s' "$SCRIPTS_LINE" | grep -oE '[0-9]+' | head -n1)"
fi

if [ -z "$SCRIPTS_COUNT" ]; then
  echo "run_tests.sh: could not find GUT's numeric 'Scripts' total in its output — an absent or non-numeric Totals block must never read as success" >&2
  exit 1
fi

if [ "$SCRIPTS_COUNT" -ne "${#DISK_SCRIPTS[@]}" ]; then
  echo "run_tests.sh: GUT reported Scripts=$SCRIPTS_COUNT but ${#DISK_SCRIPTS[@]} test_*.gd files exist on disk under tests/ — a script was silently skipped" >&2
  exit 1
fi

exit "$CODE"
