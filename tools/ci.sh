#!/usr/bin/env bash
# Underwars CI script — GDD §14 M0 row's "CI script" deliverable (M0-T4).
#
# Runs every §13.1 command that CLAUDE.md's applicability rule says currently applies:
#   1. tools/typecheck.sh — §11.3 static-typing gate.
#   2. tools/run_tests.sh — the GUT suite (always applies from M0; harness contract, never
#      edited from here).
#
# Mechanizes the applicability rule itself for the remaining §13.1 commands, each of which is
# gated behind a later milestone/phase and is NOT YET BUILT in this tree:
#   - tools/sim_smoke.gd    — fully meaningful from M7 (needs M6 factions + M7 AI)
#   - tools/content_cli.gd  — delivered in E4 (Phase 2)
#   - tools/balance_lab.gd  — delivered in E5 (Phase 2)
# A tool that does not exist yet is skipped NON-FATALLY with a printed notice — per CLAUDE.md,
# "a command whose tool is not yet due — or not yet built — is not a blocker and must not be
# reported as a failure." If a future milestone adds one of these files, ci.sh will stop
# skipping it (this existence check is the mechanism) and it becomes an applicable stage.
#
# Exit codes: 0 = every applicable stage passed · 1 = at least one applicable stage failed ·
# non-fatal skips never affect the exit code.
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STATUS=0

# Runs one applicable stage. Never stops the script on failure — records it in STATUS so every
# applicable stage still gets a chance to run (mirrors typecheck.sh's "aggregate, don't stop at
# the first failure" discipline, applied here at the stage level instead of the file level).
run_stage() {
  local name="$1"
  shift
  echo "== ci.sh: $name ==" >&2
  "$@"
  local code=$?
  if [ "$code" -ne 0 ]; then
    echo "ci.sh: STAGE FAILED: $name (exit $code)" >&2
    STATUS=1
  else
    echo "ci.sh: stage OK: $name" >&2
  fi
}

# Prints the CLAUDE.md applicability-rule notice for a §13.1 tool that is not yet built.
skip_stage() {
  local name="$1"
  local reason="$2"
  echo "ci.sh: SKIP (not yet built, not a failure per CLAUDE.md applicability rule): $name — $reason" >&2
}

# --- Applicable from M0 (GDD §14 M0 row) ----------------------------------------------------
run_stage "tools/typecheck.sh (§11.3 static-typing gate)" bash "$ROOT/tools/typecheck.sh"
run_stage "tools/run_tests.sh (§13.1 GUT suite)" bash "$ROOT/tools/run_tests.sh"

# --- §13.1 commands not yet due / not yet built ---------------------------------------------
if [ -f "$ROOT/tools/sim_smoke.gd" ]; then
  echo "ci.sh: NOTE: tools/sim_smoke.gd now exists — ci.sh does not yet know how to invoke it; a later task must add that stage." >&2
else
  skip_stage "sim_smoke" "fully meaningful from M7 (needs M6 factions + M7 AI)"
fi

if [ -f "$ROOT/tools/content_cli.gd" ]; then
  echo "ci.sh: NOTE: tools/content_cli.gd now exists — ci.sh does not yet know how to invoke it; a later task must add that stage." >&2
else
  skip_stage "content_cli" "delivered in E4 (Phase 2)"
fi

if [ -f "$ROOT/tools/balance_lab.gd" ]; then
  echo "ci.sh: NOTE: tools/balance_lab.gd now exists — ci.sh does not yet know how to invoke it; a later task must add that stage." >&2
else
  skip_stage "balance_lab" "delivered in E5 (Phase 2)"
fi

if [ "$STATUS" -ne 0 ]; then
  echo "ci.sh: FAILED — one or more applicable stages failed" >&2
else
  echo "ci.sh: PASS — all applicable stages green" >&2
fi
exit "$STATUS"
