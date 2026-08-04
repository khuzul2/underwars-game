# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** M0 — Bootstrap (**in progress** — harness clause of the acceptance criterion
  passes headless; the "invalid ruleset rejected with a line-numbered error" clause is still open)
- **Next task:** M0-T2 — EventBus + RulesLoader + `data/ruleset.json`. Scope: `scripts/sim`
  EventBus (§11.1 observer contract), a `RulesLoader` that reads constants from `data/ruleset.json`
  (never hard-coded — §11.1/§12.1) and **rejects an invalid ruleset with a line-numbered error**
  (the remaining §14 M0 acceptance clause; this is the Phase-1 substitute for `content_cli.gd`,
  exercised by GUT tests). Cite §11.1, §11.2, §12.1, §14.
- **Remaining M0 scope after T2:** M0-T3 — CI script **including the §11.3 static-typing gate
  (`--warnings-as-errors`)**, per GDD §14 M0 deliverables.
- **Blockers:** none

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **in progress** | partial — harness clause MET headless (sentinel suite green, exit 0, Scripts 3 / Tests 6; deliberately failing sentinel ⇒ `run_tests.sh` exit 1); "invalid ruleset rejected with a line-numbered error" NOT yet met (M0-T2) |
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
| 2026-08-04 | SETUP-3 | Self-contained toolchain (repo-local Godot 4.7 binary) | landed | SETUP-3: self-contained toolchain (repo-local Godot) |
| 2026-08-04 | M0-T1 | Bootstrap Godot project and wire the GUT sentinel suite | landed | M0-T1: bootstrap Godot project and wire the GUT sentinel suite |

## Notes for the next iteration

- **Pick up:** M0-T2 (EventBus + RulesLoader + `data/ruleset.json` with line-numbered validation
  errors). `scripts/sim/`, `scripts/core/` and `data/` now exist as empty `.gitkeep` dirs — the
  §11.2 skeleton is pinned in git, drop the new files straight in. Nothing under `scripts/`
  contains code yet, deliberately (§13.4: invent nothing ahead of its milestone).
- The green signal is now real and two-way: `bash tools/run_tests.sh` → exit 0 with
  Scripts 3 / Tests 6 / Passing 6, and `bash tools/verify_harness.sh` → exit 0 (it proves the
  red direction by planting a temporary failing canary, then self-cleans via `trap`). Run both.
- `tools/run_tests.sh` is the harness **contract** — make it pass, do not rewrite or weaken it.
  It exits 2 while `project.godot` is missing (no longer reachable), 1 if GUT collects zero
  tests, and runs `--import` before GUT (GUT 9.7.1 exits 0 without that cache — decisions.md
  SETUP-2). The zero-collected guard is load-bearing: dropping `-ginclude_subdirs` collects
  **zero** scripts because no test sits directly in `res://tests` — verified by probe.
- Godot is repo-local: `godot/Godot_v4.7-stable_win64_console.exe` — the ONLY binary any agent
  may use (decisions.md SETUP-3). Never the `godot` PATH shim.
- `project.godot` deliberately has **no** `run/main_scene` (no scene exists; a dangling path
  breaks `--import`) and **no** gdscript warning settings — the `--warnings-as-errors`
  static-typing gate (§11.3) is M0-T3's deliverable. Until it lands, typing is verified by diff
  review (§13.6).
- Commit the `.gd.uid` sidecars Godot 4.4+ generates next to each `.gd`; never commit `.godot/`
  (gitignored). The three sentinel `.uid`s are stable across re-imports (checksum-verified).
- **Known risk (non-blocking, operator action):** `.claude/settings.json` allowlists
  `bash tools/run_tests.sh` but not `bash tools/verify_harness.sh`; a fully unattended run may
  prompt. Loop agents deliberately do not edit permission config — see decisions.md M0-T1.
