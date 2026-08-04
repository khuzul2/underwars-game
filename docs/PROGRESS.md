# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** M0 — Bootstrap
- **Next task:** M0-T1 (first iteration: Orient defines it — expected scope: `project.godot` +
  GUT wiring so the pre-provided `tools/run_tests.sh` runs, plus a passing sentinel test.
  M0 acceptance is strengthened per decisions.md 2026-08-04: a deliberately failing sentinel
  must make `run_tests.sh` exit non-zero AND the passing suite must exit zero — "empty suite
  green" is NOT acceptable, the hardened runner rejects zero-tests-collected by design.)
- **Remaining M0 scope after T1:** EventBus, RulesLoader + `data/ruleset.json` (invalid ruleset
  rejected with line-numbered error), CI script **including the §11.3 static-typing gate
  (warnings-as-errors)**, per GDD §14 M0 deliverables.
- **Blockers:** none

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **not started** | — |
| M1 World | not started | — |
| M2 Dig & Economy | not started | — |
| M3 Build, Light, Structure | not started | — |
| M4 Units & Combat | not started | — |
| M5 Living World | not started | — |
| M6 Factions from Data | not started | — |
| M7 AI v0 + Persistence | not started | — |
| M8 Playable Alpha | not started | — |

(Phase 2: E1–E5 and Phase 3: C1–C6 tracked here once Phase 1 completes.)

## Task log

| Date | Task ID | Title | Status | Commit |
| --- | --- | --- | --- | --- |
| 2026-08-04 | SETUP | Environment: repo, GDD import, GUT 9.7.1 vendored, loop workflow | landed | SETUP: environment for the agent loop |
| 2026-08-04 | SETUP-2 | Harden loop environment (3-lens audit fixes: test harness, workflow script, docs) | landed | SETUP-2: harden loop environment (audit fixes) |

## Notes for the next iteration

- `tools/run_tests.sh` already exists and is the harness **contract** — make it pass, do not
  rewrite or weaken it. It exits 2 while `project.godot` is missing (harness unavailable, not a
  test failure), 1 if GUT collects zero tests, and it runs `--import` before GUT (GUT 9.7.1
  exits 0 without that cache — see decisions.md 2026-08-04).
- Godot is repo-local: `godot/Godot_v4.7-stable_win64_console.exe` — the ONLY binary any agent
  may use (decisions.md SETUP-3). Never the `godot` PATH shim.
- `.claude/settings.json` allowlists godot/git/test commands for unattended runs.
