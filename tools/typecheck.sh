#!/usr/bin/env bash
# Underwars §11.3 static-typing gate — GDD §11.3, §13.6, §14 M0 "CI script" deliverable.
#
# Godot 4.7 ships NO `--warnings-as-errors` CLI flag (confirmed via `--help` on the pinned
# repo-local 4.7.stable.official.5b4e0cb0f binary). The gate is project-setting driven
# instead: project.godot's [debug] section pins 46 GDScript warnings at level 2 = error
# (docs/decisions.md M0-T4), with 3 documented exclusions at level 0. Under
# `--check-only --script <file>`, a level-2 warning makes the engine refuse to *load* the
# script: exit 1, "SCRIPT ERROR: Parse Error: ... (Warning treated as error.)". A clean file
# exits 0. (Level 1 prints nothing headless — measured — so only 0/2 are meaningful here.)
#
# This script enumerates every project .gd file outside addons/ and .godot/ and --check-only's
# each one INDIVIDUALLY, aggregating ALL failures rather than stopping at the first, then
# prints the engine's captured file:line: message block for every failure and exits 1 if any
# file failed.
#
# Usage:
#   bash tools/typecheck.sh              # check every project .gd file, aggregate failures
#   bash tools/typecheck.sh --self-test  # two-way proof (mirrors tools/verify_harness.sh):
#                                         # (a) require green on the tree as committed,
#                                         # (b) plant a typing-violating .gd and re-run the FULL
#                                         #     gate, requiring a non-zero exit that names it,
#                                         # (c) remove it via trap, (d) re-require green.
#
# Exit codes: 0 = every file clean · 1 = at least one file failed / zero files found ·
#             2 = harness unavailable (missing repo-local Godot or project.godot)
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Self-contained toolchain: ALWAYS the repo-local binary (decisions.md SETUP-3) — never the
# `godot` PATH shim, which is not pinned and can silently switch builds.
GODOT="$ROOT/godot/Godot_v4.7-stable_win64_console.exe"

if [ ! -x "$GODOT" ]; then
  echo "typecheck.sh: repo-local Godot missing: $GODOT" >&2
  echo "  Place Godot_v4.7-stable_win64_console.exe + Godot_v4.7-stable_win64.exe in godot/ (see README)." >&2
  exit 2
fi

if [ ! -f "$ROOT/project.godot" ]; then
  echo "typecheck.sh: no project.godot yet — harness unavailable" >&2
  exit 2
fi

# Import pass first — same reason as run_tests.sh (decisions.md SETUP-2): without the
# .godot/ cache, engine behavior against project scripts is not reliable.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
IMPORT_CODE=$?
if [ "$IMPORT_CODE" -ne 0 ]; then
  echo "typecheck.sh: godot --import failed (exit $IMPORT_CODE)" >&2
  exit 1
fi

# Runs the gate over every project .gd file. Prints a per-file failure block and a summary
# line to stderr. Returns 0 iff every file passed AND at least one file was found.
run_gate() {
  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$ROOT" -name '*.gd' -not -path '*/addons/*' -not -path '*/.godot/*' -print0)

  if [ "${#files[@]}" -eq 0 ]; then
    echo "typecheck.sh: found ZERO .gd files to check outside addons/ — refusing to report success" >&2
    return 1
  fi

  local fail_count=0
  local checked_count=0
  local f rel res_path out code
  for f in "${files[@]}"; do
    rel="${f#"$ROOT"/}"
    res_path="res://${rel//\\//}"
    checked_count=$((checked_count + 1))
    out="$("$GODOT" --headless --path "$ROOT" --check-only --script "$res_path" 2>&1)"
    code=$?
    if [ "$code" -ne 0 ]; then
      fail_count=$((fail_count + 1))
      echo "typecheck.sh: FAIL $res_path" >&2
      printf '%s\n' "$out" >&2
    fi
  done

  echo "typecheck.sh: checked $checked_count file(s) outside addons/, $fail_count failed" >&2
  [ "$fail_count" -eq 0 ]
}

# Two-way proof of the gate, mirroring tools/verify_harness.sh's Phase A / Phase B / cleanup
# / re-verify idiom exactly.
run_self_test() {
  local probe="$ROOT/tools/_typecheck_selftest_probe.gd"

  cleanup() {
    rm -f "$probe" "$probe.uid"
  }
  trap cleanup EXIT

  fail() {
    echo "typecheck.sh --self-test: $1" >&2
    exit 1
  }

  echo "typecheck.sh --self-test: Phase A (baseline green) ..." >&2
  run_gate || fail "Phase A (baseline green) expected the gate to pass on the committed tree"
  echo "typecheck.sh --self-test: Phase A OK — exit 0" >&2

  cat > "$probe" <<'EOF'
## Temporary typing-violating probe — written and removed by tools/typecheck.sh --self-test.
## Proves the §11.3 gate rejects an untyped declaration. Must never survive to a commit.
extends RefCounted


func probe_violation() -> void:
	var v = 1
	v = v + 1
EOF

  echo "typecheck.sh --self-test: Phase B (red canary present) ..." >&2
  local out code
  # Phase B drives the WHOLE tool (run_gate over the real file list), not a bare engine call on
  # the probe: the two-way proof must cover this script's own enumeration, aggregation and
  # exit-code plumbing — exactly as verify_harness.sh's Phase B re-invokes run_tests.sh rather
  # than godot. A run_gate that swallowed a failure (e.g. an $? read through a pipeline) would
  # otherwise still report a passing self-test — the false-green class SETUP-2 hardened against.
  out="$(run_gate 2>&1)"
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "Phase B expected a non-zero exit for a typing violation, got 0"
  fi
  if ! printf '%s' "$out" | grep -q "_typecheck_selftest_probe.gd"; then
    printf '%s\n' "$out" >&2
    fail "Phase B output did not name the probe file"
  fi
  if ! printf '%s' "$out" | grep -q "Warning treated as error"; then
    printf '%s\n' "$out" >&2
    fail "Phase B output did not contain 'Warning treated as error'"
  fi
  echo "typecheck.sh --self-test: Phase B OK — exit $code (non-zero), gate rejected the violation" >&2

  rm -f "$probe" "$probe.uid"

  echo "typecheck.sh --self-test: Phase A (post-cleanup green) ..." >&2
  run_gate || fail "Phase A (post-cleanup green) expected the gate to pass again after cleanup"
  echo "typecheck.sh --self-test: PASS — gate proven both ways, tree clean" >&2
  exit 0
}

if [ "${1:-}" = "--self-test" ]; then
  run_self_test
  # run_self_test always exits explicitly (fail() calls exit 1; the success path calls exit 0).
fi

run_gate
exit $?
