# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** **M0 — Bootstrap: DONE** (closed by M0-T5). Every §14 M0 deliverable is built
  (Godot project, GUT wired, `run_tests.sh`, EventBus, RulesLoader + `ruleset.json`, CI script,
  `decisions.md`) and **both** §14 acceptance clauses pass headless — *and* the signal that reports
  clause (a) is now itself proven against the false-green mode M0-T4 measured. Next milestone:
  **M1 — World**.
- **Next task:** M1-T1 — **HexMath first slice: axial/cube coordinates + conversions + neighbours
  + distance, then lines/rings/LOS** (§4.1 hex grid, §4.3 line-of-sight, §11.2 `scripts/core/`
  placement, §11.1 determinism: integer math, no floats accumulating in rules). Split if the slice
  approaches ~300 LOC — **coordinates/neighbours/distance first, LOS and rings second**. The §14 M1
  row's full deliverable list (concentric-bowl generator, chunked MultiMesh renderer, camera rig,
  hex picking) and its acceptance criteria (golden mapgen test seed ⇒ terrain hash; 60 fps Medium
  greybox; LOS property tests) span several tasks — the **first golden in the project** lands with
  the mapgen hash, so re-read §13.2/§13.6 on golden discipline before recording it.
- **Blockers:** none

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **DONE** (2026-08-04, M0-T5) | **BOTH §14 acceptance clauses MET headless, checked against the §14 row this iteration** — (a) *sentinel suite green AND a deliberately failing sentinel makes `run_tests.sh` exit non-zero* (SETUP-2 amendment): `verify_harness.sh` exit 0 with **four** phases — A green, B failing canary, C syntactic parse error, D statically-impossible construct — each red phase non-zero **and naming its probe**, tree clean afterwards; (b) *invalid ruleset rejected with a line-numbered error*: pinned by `tests/unit/test_rules_loader.gd`, suite exit 0 at **Scripts 7 / Tests 62 / Passing 62 / Asserts 473** with the collected-script count equal to the `test_*.gd` count on disk. **ALL §14 M0 deliverables built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate), `decisions.md`. M0-T5 closed the last open item: the false-green mode *inside* the signal that reports clause (a) (decisions.md M0-T5, correcting M0-T4 item (i)). |
| M1 World | **next** | — |
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
| 2026-08-04 | M0-T4 | CI script and the static-typing warnings-as-errors gate | landed | M0-T4: CI script and the static-typing warnings-as-errors gate |
| 2026-08-04 | M0-T5 | Harden run_tests.sh against silently skipped test scripts (**closes M0**) | landed | M0-T5: Harden run_tests.sh against silently skipped test scripts |

## Notes for the next iteration

- **Pick up:** **M1-T1 — HexMath first slice** (§4.1, §4.3, §11.1, §11.2). M0 is closed; the
  harness, the typing gate and the data pipeline are all live and proven, so M1 is the first
  milestone that writes actual *game rules*. Read §4.1/§4.3 before coding and take the coordinate
  layer alone if LOS pushes the slice past ~300 LOC.
  `scripts/` currently holds `sim/rules_loader.gd` + `sim/rules_error.gd` and `core/event.gd` +
  `core/event_bus.gd`, and nothing else, deliberately (§13.4: invent nothing ahead of its
  milestone). No GameState, Command, hex or map code exists yet, and **no concrete `Event`
  subclass exists** — those belong to the milestones that emit them. M1 changes that: it is the
  first milestone allowed to add hex/map code, and the first to record a **golden**.
- **The §11.3 static-typing gate is LIVE from M0-T4 — every `.gd` you write must pass it.** Read
  decisions.md M0-T4 for the full contract; the operational facts:
  - Run it with `bash tools/typecheck.sh` (all project `.gd` outside `addons/`), or just
    `bash tools/ci.sh` (gate + suite + non-fatal skips for the not-yet-built §13.1 tools). Both
    are hardened: `typecheck.sh` aggregates **all** failures (never stops at the first) and fails
    loudly if enumeration finds **zero** files; `bash tools/typecheck.sh --self-test` is its
    two-way proof and drives the **tool**, not a bare engine call.
  - Config lives in `project.godot`'s `[debug]` section: **46 warnings at level 2**, **3 at level
    0** (`unsafe_cast`, `unsafe_call_argument`, `return_value_discarded` — each justified in
    decisions.md M0-T4 item c), `res://addons` exempt via `directory_rules`, **no project tree
    exempt**. `tests/unit/test_typing_gate.gd` pins all of it, including an anti-rot test that goes
    red if a future Godot adds a warning **or if a warning name is typo'd** in `project.godot`
    (a typo registers as a brand-new setting). Downgrading anything requires a decisions.md entry.
  - **`inferred_declaration` and `untyped_declaration` are errors**, so `:=` and bare `var x = …`
    are both rejected — always write `var x: T = …`. **`integer_division` is an error too, and
    deliberately so** (§11.1 round-half-up): from M2 every intentional `int/int` division needs an
    explicit `@warning_ignore("integer_division")` at the site.
  - Trap that predates the gate and still bites: passing a `Variant` (e.g. `Array.pop_front()`,
    or a `get_property_list()` element) into a statically-typed parameter is a **hard parse error**,
    not a warning — the script fails to load, which in a test file is the silent-skip false green
    below. Assign through a typed local first.
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
  **Scripts 7 / Tests 62 / Passing 62 / Asserts 473**, and `bash tools/verify_harness.sh` → exit 0
  with **four** phases (A green · B failing canary · C syntactic parse error · D
  statically-impossible construct), each red phase non-zero *and naming its probe*, self-cleaning
  via `trap`. Run both — plus `bash tools/typecheck.sh` and `bash tools/ci.sh` from M0-T4 onward.
  **Expect the Scripts/Tests totals to RISE as you add tests; they are enumerated, not hard-coded,
  so nothing needs updating when they do.**
- `tools/run_tests.sh` is the harness **contract** — make it pass, do not rewrite or weaken it
  (*strengthening* is permitted and is what M0-T5 did; every prior guard is kept verbatim and
  `tests/unit/test_run_tests_harness.gd` test 3 re-asserts all of them, so a weakening edit turns
  the suite red). Guards now in force: exits 2 while `project.godot` is missing (no longer
  reachable); exits 1 if GUT collects zero tests; runs `--import` before GUT (GUT 9.7.1 exits 0
  without that cache — decisions.md SETUP-2); refuses on `Nothing was run` / `does not exist` /
  `have not been imported` / **`Failed to load script`** / **`Ignoring script`**; and — the
  evasion-proof one — **enumerates every `tests/**/test_*.gd` on disk and requires each to appear
  in GUT's output AND GUT's own `Scripts` total to equal that count** (M0-T5). The
  `-ginclude_subdirs` flag stays load-bearing: dropping it collects **zero** scripts because no
  test sits directly in `res://tests` — verified by probe.
- **Naming rule your test files must obey, now mechanically enforced (§13.2):** GUT 9.7.1 only
  collects files named `test_*.gd` (`addons/gut/gut.gd:229`), recursively under `res://tests`. The
  M0-T5 disk enumeration uses that exact rule, so a `.gd` file under `tests/` **without** the
  `test_` prefix is invisible to both — and a *probe* without it proves nothing (that naming
  mistake is what confounded decisions.md M0-T4 item (i)).
- **Debt handoff for M7 / E4 / E5 — read when you build `sim_smoke.gd`, `content_cli.gd` or
  `balance_lab.gd`:** `tools/ci.sh` currently skips each of the three by a plain **file-existence**
  check. The moment one of those files lands, `ci.sh` stops skipping it and prints a NOTE that it
  does not know how to invoke it — **wiring the real invocation (with the §13.1 argument list) is
  part of the task that creates the file**, not a later cleanup.
- Godot is repo-local: `godot/Godot_v4.7-stable_win64_console.exe` — the ONLY binary any agent
  may use (decisions.md SETUP-3). Never the `godot` PATH shim.
- `project.godot` deliberately has **no** `run/main_scene` (no scene exists; a dangling path
  breaks `--import`). Its `[debug]` section is the §11.3 gate (M0-T4, above) and is **hand-written
  and `--import`-stable**: Godot re-saves it byte-identically, *including* lines whose value equals
  its own default — which is what makes the "explicitly off" exclusion assertions possible. Do not
  "tidy" those lines away.
- Commit the `.gd.uid` sidecars Godot 4.4+ generates next to each `.gd`; never commit `.godot/`
  (gitignored). `.json` data files get no `.import` sidecar in Godot 4.7.
- **Known risk — CLOSED by M0-T5 (kept here as the standing explanation, not an open item).** A
  GDScript **parse error inside a test file** silently un-collects that whole file while every
  other script still runs; before M0-T5 `run_tests.sh` exited 0 and printed "All tests passed!"
  with totals byte-identical to a healthy tree. It now exits 1 on both variants — the syntactic one
  (`var x: int = (`) and the statically-impossible one (`is Node` against a `RefCounted`, M0-T2's
  live case) — and `verify_harness.sh` Phases C/D re-prove that every run. **Correction you must
  not re-derive from the old note:** decisions.md M0-T4 item (i) claimed the syntactic variant
  prints *no diagnostic at all*; that was an artefact of a probe named `_verify_parse_error.gd`,
  which lacks GUT's `test_` prefix, so GUT never tried to load it. Both variants **do** print
  `Failed to load script` **and** `Ignoring script` when the file is named `test_*.gd`. See
  decisions.md M0-T5 items (a)–(c). Still true and still useful: `typecheck.sh` catches both
  variants independently, and `loader is Node` cannot be written in GDScript against a
  `RefCounted` — assert non-Node-ness via `get_class()` instead.
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
- **Small known weakness, deliberately left for a later task (M0-T5 item g):**
  `tests/unit/test_run_tests_harness.gd` test 1 checks the coverage guard sits before the final
  `exit "$CODE"` by comparing `find("Scripts") < rfind('exit "$CODE"')`, which a header comment
  satisfies. The behavioural proof (live Phases C/D + the negative control) covers the property
  today. Tightening it to anchor on the guard's own code line is a fine opportunistic fix; it was
  scope creep inside M0-T5.
- **Golden discipline, first exercised in M1:** no golden file exists yet. When M1 records the
  mapgen hash, §13.6 applies from that moment — a golden may be re-recorded **only** with a logged
  reason in `decisions.md` in the *same commit*. Get the seeded generation deterministic first
  (`state.rng` only, no `randi()`, stable iteration order, integer math), because a golden recorded
  over a nondeterministic generator is worse than none.
