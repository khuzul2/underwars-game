#!/usr/bin/env bash
# Underwars M0 harness verifier — mechanical two-way proof of the amended §14 M0 acceptance
# criterion (docs/decisions.md 2026-08-04 SETUP-2 item 3, extended by M0-T5):
#   a passing sentinel suite makes tools/run_tests.sh exit 0, AND a deliberately failing
#   sentinel makes the SAME script exit non-zero (Phases A/B). M0-T5 adds two more red phases,
#   one per measured silent-skip variant (docs/decisions.md M0-T4 item (i), corrected by M0-T5):
#   Phase C plants a SYNTACTIC parse error, Phase D a STATICALLY-IMPOSSIBLE construct — they fail
#   in different engine phases, so proving one proves nothing about the other. This script
#   performs all four halves itself and self-cleans via trap so no canary ever survives a failure
#   or interruption.
#
# tools/run_tests.sh is the harness contract (do not edit it or this script from other stages).
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANARY="$ROOT/tests/unit/test_harness_redcanary.gd"
SYNTAX_PROBE="$ROOT/tests/unit/test_harness_syntaxcanary.gd"
IMPOSSIBLE_PROBE="$ROOT/tests/unit/test_harness_typecanary.gd"

cleanup() {
  rm -f "$CANARY" "$CANARY.uid"
  rm -f "$SYNTAX_PROBE" "$SYNTAX_PROBE.uid"
  rm -f "$IMPOSSIBLE_PROBE" "$IMPOSSIBLE_PROBE.uid"
}
trap cleanup EXIT

fail() {
  echo "verify_harness.sh: $1" >&2
  exit 1
}

# --- Phase A (green): the sentinel suite as committed must pass. ---------------------------
bash "$ROOT/tools/run_tests.sh" >/dev/null 2>&1
CODE_A1=$?
if [ "$CODE_A1" -ne 0 ]; then
  fail "Phase A (baseline green) expected exit 0, got $CODE_A1"
fi
echo "verify_harness.sh: Phase A (baseline green) OK — exit 0"

# --- Phase B (red): a deliberately failing sentinel must flip the exit code. ----------------
cat > "$CANARY" <<'EOF'
## Temporary deliberately-failing sentinel — written and removed by tools/verify_harness.sh.
## Proves tools/run_tests.sh exits non-zero on a real failure (GDD §14 M0 acceptance, as
## amended by docs/decisions.md 2026-08-04 SETUP-2 item 3). Must never survive to a commit.
extends GutTest


func test_deliberately_fails() -> void:
	assert_eq(1, 2, "canary: this must fail so run_tests.sh is proven to catch failures")
EOF

bash "$ROOT/tools/run_tests.sh" >/dev/null 2>&1
CODE_B=$?
if [ "$CODE_B" -eq 0 ]; then
  fail "Phase B (red canary present) expected non-zero exit, got 0"
fi
echo "verify_harness.sh: Phase B (red canary present) OK — exit $CODE_B (non-zero)"
rm -f "$CANARY" "$CANARY.uid"

# --- Phase C (red, SYNTACTIC parse error): measured (docs/decisions.md M0-T4 item (i), corrected
# by M0-T5) to leave GUT's Scripts/Tests/Passing totals byte-identical to a healthy run while the
# process exits 0 — the false green M0-T5 closes. BOTH of run_tests.sh's new guards catch it
# (the refusal grep fires first, the disk-vs-collected coverage guard would catch it anyway —
# verified by negative control at M0-T5's Verify stage); this phase pins that the runner refuses
# the variant, not which guard got there first. ----------------------------------------------
cat > "$SYNTAX_PROBE" <<'EOF'
## Temporary SYNTACTIC-parse-error canary — written and removed by tools/verify_harness.sh.
## Proves run_tests.sh refuses a test_*.gd that fails to PARSE (GDD §14 M0 acceptance, amended
## by docs/decisions.md M0-T5). Must never survive to a commit.
extends GutTest


func test_probe() -> void:
	var x: int = (
EOF

OUT_C="$(bash "$ROOT/tools/run_tests.sh" 2>&1)"
CODE_C=$?
if [ "$CODE_C" -eq 0 ]; then
  fail "Phase C (syntactic parse-error canary) expected non-zero exit, got 0"
fi
if ! printf '%s' "$OUT_C" | grep -qF "test_harness_syntaxcanary.gd"; then
  fail "Phase C (syntactic parse-error canary) exited non-zero but never named the probe file — wrong reason"
fi
echo "verify_harness.sh: Phase C (syntactic parse-error canary) OK — exit $CODE_C (non-zero), probe named"
rm -f "$SYNTAX_PROBE" "$SYNTAX_PROBE.uid"

# --- Phase D (red, STATICALLY-IMPOSSIBLE construct): the M0-T2 live case, reproduced
# dependency-free (`r is Node` against a RefCounted) — fails in a different engine phase than
# Phase C, so it exercises a distinct path through GUT and through the runner's guards. --------
cat > "$IMPOSSIBLE_PROBE" <<'EOF'
## Temporary STATICALLY-IMPOSSIBLE-construct canary — written and removed by
## tools/verify_harness.sh. Proves run_tests.sh refuses a test_*.gd GDScript rejects at parse
## time as impossible (the M0-T2 live case, reproduced dependency-free). Must never survive to a
## commit.
extends GutTest


func test_probe() -> void:
	var r: RefCounted = RefCounted.new()
	assert_true(r is Node, "impossible")
EOF

OUT_D="$(bash "$ROOT/tools/run_tests.sh" 2>&1)"
CODE_D=$?
if [ "$CODE_D" -eq 0 ]; then
  fail "Phase D (statically-impossible-construct canary) expected non-zero exit, got 0"
fi
if ! printf '%s' "$OUT_D" | grep -qF "test_harness_typecanary.gd"; then
  fail "Phase D (statically-impossible-construct canary) exited non-zero but never named the probe file — wrong reason"
fi
echo "verify_harness.sh: Phase D (statically-impossible-construct canary) OK — exit $CODE_D (non-zero), probe named"
rm -f "$IMPOSSIBLE_PROBE" "$IMPOSSIBLE_PROBE.uid"

# --- Cleanup + re-verify green ---------------------------------------------------------------
bash "$ROOT/tools/run_tests.sh" >/dev/null 2>&1
CODE_A2=$?
if [ "$CODE_A2" -ne 0 ]; then
  fail "Phase A (post-cleanup green) expected exit 0, got $CODE_A2"
fi
echo "verify_harness.sh: Phase A (post-cleanup green) OK — exit 0"

echo "verify_harness.sh: PASS — run_tests.sh proven green and red all four ways (B/C/D), tree clean"
exit 0
