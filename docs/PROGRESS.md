# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** M0 — Bootstrap (**in progress** — **every** §14 M0 *deliverable* is now built
  (CI script landed with M0-T4) and **both** §14 acceptance clauses pass headless, re-verified this
  iteration. The milestone is **deliberately held open for exactly one task, M0-T5**: this
  iteration *measured* a false-green mode in `run_tests.sh` itself — the very signal that reports
  clause (a) as passing (see Known risk below). Closing that before declaring M0 done is the
  honest call, not a §14 requirement; strictly by the §14 row, M0's criteria are satisfied.)
- **Next task:** M0-T5 — **harness hardening: make `tools/run_tests.sh` refuse the "GUT skipped /
  could not parse a test script" false green.** A *strengthening* of the harness contract, which is
  permitted; weakening is not. Cite §13.1, §13.6, §14. **Read decisions.md M0-T4 item (i) before
  speccing it — it supersedes the M0-T2 assumption:** the planned `Ignoring script` /
  `Failed to load script` refusal grep closes only ONE of two variants. A **syntactic** parse error
  in a test file prints *no diagnostic at all* and yields *identical* Scripts/Tests counts, so
  M0-T5 must **also** assert an expected script/test-count floor (or invoke `typecheck.sh`, which
  does catch both). Both variants are measured and reproduced twice.
- **Remaining M0 scope after T5:** none — the milestone closes there.
- **Blockers:** none

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **in progress** | **acceptance criteria: BOTH clauses MET headless** — (a) harness two-way proof (`verify_harness.sh` exit 0: real suite green, planted red canary ⇒ exit 1, tree clean); (b) invalid ruleset rejected with a line-numbered error (`run_tests.sh` exit 0, Scripts 6 / Tests 57 / Passing 57 / Asserts 418, no skipped scripts). **ALL §14 M0 deliverables are now built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), **CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate)**, `decisions.md`. **Not marked done:** held open for **M0-T5** only, because M0-T4 measured a false-green mode inside `run_tests.sh` — the signal that reports clause (a) (decisions.md M0-T4 item (i)). Nothing in the §14 row itself is outstanding. |
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
| 2026-08-04 | M0-T4 | CI script and the static-typing warnings-as-errors gate | landed | M0-T4: CI script and the static-typing warnings-as-errors gate |

## Notes for the next iteration

- **Pick up:** M0-T5 (harness hardening — see Current position for the *measured correction* that
  changes its scope). It is the last task in M0.
  `scripts/` now holds `sim/rules_loader.gd` + `sim/rules_error.gd` and `core/event.gd` +
  `core/event_bus.gd`, and nothing else, deliberately (§13.4: invent nothing ahead of its
  milestone). No GameState, Command, hex or map code exists yet, and **no concrete `Event`
  subclass exists** — those belong to the milestones that emit them.
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
  Scripts 6 / Tests 57 / Passing 57 / Asserts 418, and `bash tools/verify_harness.sh` → exit 0
  (it proves the red direction by planting a temporary failing canary, then self-cleans via
  `trap`). Run both — plus `bash tools/typecheck.sh` and `bash tools/ci.sh` from M0-T4 onward.
- `tools/run_tests.sh` is the harness **contract** — make it pass, do not rewrite or weaken it.
  It exits 2 while `project.godot` is missing (no longer reachable), 1 if GUT collects zero
  tests, and runs `--import` before GUT (GUT 9.7.1 exits 0 without that cache — decisions.md
  SETUP-2). The zero-collected guard is load-bearing: dropping `-ginclude_subdirs` collects
  **zero** scripts because no test sits directly in `res://tests` — verified by probe.
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
- **Known risk (non-blocking, real, hit live in M0-T2; scope CORRECTED by M0-T4 measurement):** a
  GDScript **parse error inside a test file** silently un-collects that whole file while
  `run_tests.sh` exits 0 and reports "All tests passed!" — `run_tests.sh`'s zero-collected guard
  does not catch it (other scripts still run). There are **two variants**, and they differ:
  1. **Statically-impossible construct** (M0-T2's live case, `loader is Node` against a
     `RefCounted`) → GUT logs `Ignoring script … because it does not extend GutTest`. Greppable.
  2. **Syntactic parse error** (M0-T4 probe, `var x: int = (`) → **no diagnostic whatsoever**: no
     `Ignoring script`, no `Failed to load script`, no filename anywhere in the output, and the
     Scripts/Tests/Asserts counts are **identical to the healthy tree**. Reproduced twice.
  So until M0-T5 lands, checking counts alone is **not** sufficient either — run
  `bash tools/typecheck.sh` (or `ci.sh`), which catches **both** variants (exit 1,
  `Failed to load script … with error "Parse error"`). M0-T5 must add a count **floor** to
  `run_tests.sh`, not merely the refusal grep the M0-T2 note assumed. Note also that
  `loader is Node` cannot be written in GDScript against a `RefCounted`; assert non-Node-ness via
  `get_class()` instead.
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
