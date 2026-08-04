#!/usr/bin/env bash
# Underwars M0 harness verifier — mechanical two-way proof of the amended §14 M0 acceptance
# criterion (docs/decisions.md 2026-08-04 SETUP-2 item 3):
#   a passing sentinel suite makes tools/run_tests.sh exit 0, AND a deliberately failing
#   sentinel makes the SAME script exit non-zero. This script performs both halves itself and
#   self-cleans via trap so no canary ever survives a failure or interruption.
#
# tools/run_tests.sh is the harness contract (do not edit it or this script from other stages).
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANARY="$ROOT/tests/unit/test_harness_redcanary.gd"

cleanup() {
  rm -f "$CANARY" "$CANARY.uid"
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

# --- Cleanup + re-verify green ---------------------------------------------------------------
rm -f "$CANARY" "$CANARY.uid"

bash "$ROOT/tools/run_tests.sh" >/dev/null 2>&1
CODE_A2=$?
if [ "$CODE_A2" -ne 0 ]; then
  fail "Phase A (post-cleanup green) expected exit 0, got $CODE_A2"
fi
echo "verify_harness.sh: Phase A (post-cleanup green) OK — exit 0"

echo "verify_harness.sh: PASS — run_tests.sh proven green and red both ways, tree clean"
exit 0
