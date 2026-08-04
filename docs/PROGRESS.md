# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** M0 — Bootstrap (**in progress** — **both** §14 acceptance clauses pass headless;
  the milestone stays open because one §14 M0 *deliverable* is not built yet: the **CI script**.
  EventBus landed with M0-T3)
- **Next task:** M0-T4 — **CI script including the §11.3 static-typing gate**, per the §14 M0
  deliverables. Until it lands, typing is verified by diff review (§13.6). Cite §11.3, §13.1,
  §13.6, §14. **Read the M0-T4 intel note below before speccing it** — Godot 4.7 has no
  `--warnings-as-errors` CLI flag, and a maximal warning set does not pass on already-landed code.
- **Remaining M0 scope after T4:**
  - **M0-T5 (harness hardening)** — make `tools/run_tests.sh` refuse the
    "GUT skipped a test script it could not parse" false green (see Known risk below). This is a
    *strengthening* of the harness contract, which is permitted; weakening is not.
- **Blockers:** none

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **in progress** | **acceptance criteria: BOTH clauses MET headless** — (a) harness two-way proof (`verify_harness.sh` exit 0: real suite green, planted red canary ⇒ exit 1, tree clean); (b) invalid ruleset rejected with a line-numbered error (`run_tests.sh` exit 0, Scripts 5 / Tests 51 / Passing 51 / Asserts 341, no skipped scripts). **Milestone NOT done:** the §14 M0 deliverable *CI script* (M0-T4) is still outstanding. Deliverables built so far: Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, **EventBus (M0-T3)**, `decisions.md` |
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
| 2026-08-04 | M0-T3 | EventBus and typed Event base with deterministic delivery order | landed | M0-T3: EventBus and typed Event base with deterministic delivery order |

## Notes for the next iteration

- **Pick up:** M0-T4 (CI script + the §11.3 static-typing gate) — the last M0 deliverable.
  `scripts/` now holds `sim/rules_loader.gd` + `sim/rules_error.gd` and `core/event.gd` +
  `core/event_bus.gd`, and nothing else, deliberately (§13.4: invent nothing ahead of its
  milestone). No GameState, Command, hex or map code exists yet, and **no concrete `Event`
  subclass exists** — those belong to the milestones that emit them.
- **M0-T4 intel (measured this iteration on the pinned repo-local 4.7 binary — read before
  speccing):**
  - Godot 4.7 has **no `--warnings-as-errors` CLI flag** (checked `--help`). The §11.3 gate must be
    project-setting driven: `debug/gdscript/warnings/<name>=2` plus
    `--check-only --script <file>`, which exits 1 and prints `Warning treated as error`.
  - Under a **maximal** warning set (every warning at level 2) the two new sim-core files are the
    only clean ones in the repo. Already-landed code trips it: `scripts/sim/rules_loader.gd`
    (unsafe `Variant`→`Dictionary`/`Array` casts at ~57/135/155/310/314/339; `int()`/`float()` on
    `Variant` at ~107/117/139), `tests/unit/test_rules_loader.gd` (discarded `insert()` return,
    ~528), `tests/unit/test_sentinel.gd` (`int(Variant)`, ~23–24), `tests/unit/test_event_bus.gd`
    (four `unsafe_call_argument` against GUT's own untyped `assert_eq`, plus a discarded
    `PackedStringArray.append()`). M0-T4 must therefore **curate** the warning set —
    `unsafe_call_argument` and `return_value_discarded` are effectively incompatible with GUT's
    assert API — or fix those files. It cannot simply flip everything to error.
  - Related trap already fixed once: passing a `Variant` (e.g. `Array.pop_front()`) into a
    statically-typed parameter is a **hard parse error** under the gate, not a warning — the script
    fails to load, which in a test file is the silent-skip false green below. Assign through a
    typed local first.
- **EventBus contract (`scripts/core/event_bus.gd`, `scripts/core/event.gd`) — read
  decisions.md M0-T3 (a)–(f) before using it.** Public API: `subscribe`/`unsubscribe`/`emit`/
  `emit_all`/`clear`/`subscriber_count`/`is_dispatching`. Delivery is per-type registration order,
  oldest first; nested emits (and whole `emit_all` batches) are **queued FIFO**, never depth-first;
  the subscriber list is snapshotted per event with a liveness re-check, so `subscribe`/
  `unsubscribe`/`clear` inside a handler never affect the in-flight event; `subscribe` is
  idempotent per `(type, Callable)`; freed-target Callables are skipped and pruned. Handlers take
  exactly one `Event` parameter and their return value is ignored — the sim never queries observers.
  Event *types* are plain `StringName`s with **no whitelist anywhere in engine code** (§11.1's list
  ends in "…"); the test file enforces that by scanning both core files, so never write
  `hex_changed`/`unit_moved`/… as a literal in `scripts/core/` — doc comments are fine.
- **Constants are now data.** `data/ruleset.json` holds the full §12.1 constant set and
  `RulesLoader` (`scripts/sim/rules_loader.gd`) is the only sanctioned way to read it. Never
  re-type a §12.1 number as a literal in `.gd` code (§13.6) — go through
  `get_int` / `get_float` / `get_string` / `get_int_array` / `has` with a dotted path.
  Errors surface as `RulesError` (`line` 1-based, `path` dotted, `message`,
  `format_for(source)` → `"<source>:<line>: <message>"`). Line 0 means "file-level, no line" and
  is reserved for missing/unreadable files.
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 with
  Scripts 5 / Tests 51 / Passing 51 / Asserts 341, and `bash tools/verify_harness.sh` → exit 0
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
  breaks `--import`) and **no** gdscript warning settings — the §11.3 static-typing gate is
  **M0-T4's** deliverable. Until it lands, typing is verified by diff review (§13.6).
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
