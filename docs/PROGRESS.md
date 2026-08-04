# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** M0 — Bootstrap (**in progress** — **both** §14 acceptance clauses now pass
  headless; the milestone stays open because two §14 M0 *deliverables* are not built yet:
  EventBus and the CI script)
- **Next task:** M0-T3 — **EventBus** (`scripts/core/`, §11.1 observer contract): typed event
  objects, subscribe/emit, sim-never-calls-renderer direction, deterministic delivery order.
  Pure `RefCounted`, no Node/SceneTree/singletons. Cite §11.1, §11.2, §11.3, §13.2, §14.
- **Remaining M0 scope after T3:**
  - **M0-T4** — CI script **including the §11.3 static-typing gate (`--warnings-as-errors`)**,
    per the §14 M0 deliverables. Until it lands, typing is verified by diff review (§13.6).
  - **M0-T5 (candidate, harness hardening)** — make `tools/run_tests.sh` refuse the
    "GUT skipped a test script it could not parse" false green (see Known risk below). This is a
    *strengthening* of the harness contract, which is permitted; weakening is not.
- **Blockers:** none

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **in progress** | **acceptance criteria: BOTH clauses MET headless** — (a) harness two-way proof (`verify_harness.sh` exit 0: real suite green, planted red canary ⇒ exit 1, tree clean); (b) invalid ruleset rejected with a line-numbered error (`run_tests.sh` exit 0, Scripts 4 / Tests 32 / Passing 32 / Asserts 242, no skipped scripts). **Milestone NOT done:** §14 M0 deliverables *EventBus* (M0-T3) and *CI script* (M0-T4) are still outstanding |
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
| 2026-08-04 | SETUP-4 | Allowlist `verify_harness.sh` for unattended runs | landed | SETUP-4: allowlist verify_harness.sh for unattended runs |
| 2026-08-04 | M0-T2 | RulesLoader and data/ruleset.json with line-numbered validation errors | landed | M0-T2: RulesLoader and data/ruleset.json with line-numbered validation errors |

## Notes for the next iteration

- **Pick up:** M0-T3 (EventBus, §11.1 observer contract). `scripts/core/` is still an empty
  `.gitkeep` dir — drop the new files straight in. Nothing beyond `scripts/sim/rules_loader.gd`
  + `rules_error.gd` exists under `scripts/`, deliberately (§13.4: invent nothing ahead of its
  milestone). No GameState, Command, hex or map code exists yet.
- **Constants are now data.** `data/ruleset.json` holds the full §12.1 constant set and
  `RulesLoader` (`scripts/sim/rules_loader.gd`) is the only sanctioned way to read it. Never
  re-type a §12.1 number as a literal in `.gd` code (§13.6) — go through
  `get_int` / `get_float` / `get_string` / `get_int_array` / `has` with a dotted path.
  Errors surface as `RulesError` (`line` 1-based, `path` dotted, `message`,
  `format_for(source)` → `"<source>:<line>: <message>"`). Line 0 means "file-level, no line" and
  is reserved for missing/unreadable files.
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 with
  Scripts 4 / Tests 32 / Passing 32 / Asserts 242, and `bash tools/verify_harness.sh` → exit 0
  (it proves the red direction by planting a temporary failing canary, then self-cleans via
  `trap`). Run both.
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
  (gitignored). `.json` data files get no `.import` sidecar in Godot 4.7.
- **Known risk (non-blocking, real, hit live in M0-T2):** a GDScript **parse error inside a test
  file** makes GUT log `Ignoring script … because it does not extend GutTest` and still exit 0 —
  the whole suite silently vanishes while the run reports "All tests passed!". `run_tests.sh`'s
  zero-collected guard does not catch it (other scripts still run). Until M0-T5 lands, every
  Verify stage must check the **Scripts/Tests counts**, not the exit code alone, and grep the
  output for `Ignoring script` / `Failed to load`. Note also that
  `loader is Node` cannot be written in GDScript against a `RefCounted` — it is a statically
  impossible cast, rejected at parse time, and is exactly what triggered this in M0-T2; assert
  non-Node-ness via `get_class()` instead.
- **Godot 4.7 JSON facts** (probed on the pinned repo-local binary, twice, independently — the
  docs disagree, see decisions.md M0-T2): `JSON.get_error_line()` is **0-based** (RulesLoader
  normalizes to 1-based); the parser **accepts trailing commas**, so they are useless as a
  syntax-error fixture; every JSON number arrives as `TYPE_FLOAT`, even `1` — so int validation
  is "accept an integral float, reject a fractional one", never truncate.
- **Forward gap to resolve at M2 (not a bug now):** §4.2's terrain table gives Artificial Granite
  a dig yield of **+2 Stone**, but the §12.1 excerpt's `dig_yields` object omits
  `artificial_granite`. `data/ruleset.json` mirrors the §12.1 excerpt faithfully, so the key is
  deliberately absent and the schema does not require it. M2 (Dig & Economy) must add it, with
  its own decisions.md entry at that time.
- `data/ruleset.json` formatting is **load-bearing, not cosmetic**: line 1 is a lone `{` and each
  §12.1 top-level group occupies exactly one line, so schema-error line attribution is meaningful
  and the tests can compute expected line numbers from the fixture instead of magic constants.
  Re-pretty-printing it fully nested will break `tests/unit/test_rules_loader.gd`.
