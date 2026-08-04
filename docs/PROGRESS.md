# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** **M1 — World: IN PROGRESS** (opened by M1-T1). M0 — Bootstrap is **DONE** (closed
  by M0-T5): every §14 M0 deliverable is built (Godot project, GUT wired, `run_tests.sh`, EventBus,
  RulesLoader + `ruleset.json`, CI script, `decisions.md`), **both** §14 acceptance clauses pass
  headless, and the signal that reports clause (a) is itself proven against the false-green mode
  M0-T4 measured. **M1 is NOT done:** its §14 row lists five deliverables (HexMath, concentric-bowl
  generator, chunked MultiMesh renderer, camera rig, hex picking) and M1-T1 delivered the **first
  slice of the first one**; **none of the three §14 M1 acceptance criteria pass yet** (no golden
  mapgen test exists, no greybox/renderer exists to measure 60 fps on, no LOS code exists to
  property-test).
- **Next task:** **M1-T2 (RESUME) — finish HexMath slice 2: exact-integer hex lines, rings and
  ranges.** The iteration of 2026-08-04 landed **WIP(blocked)**: the Tests stage completed and is
  committed (20 new tests, sections H–M of `tests/unit/test_hex_math.gd`, confirmed RED for the
  right reason), but the **Implement stage returned no result** (agent died/skipped) and Verify ran
  nothing. `scripts/core/hex_math.gd` therefore currently ships **deliberately-wrong stubs** for the
  four new public members plus `_floor_div`, under a banner comment. **The next iteration's job is
  the Implement + Verify half only** — the spec, the derived values and the (C)–(G) resolutions are
  all already on disk (see the HexMath contract note below). Do **not** re-open the design, do
  **not** edit `tests/unit/test_hex_math.gd`, and do **not** start M1-T3.
- **Blockers:** **`bash tools/run_tests.sh` exits 1** — Scripts 8 / Tests 106 / Passing 87 /
  **Failing 19** / Asserts 950/1023. All 19 failures are the new M1-T2 tests failing on **values**
  against the deliberately-wrong stubs in `scripts/core/hex_math.gd` (the 24 pre-existing hex_math
  tests and the 62 tests in the other 7 files are all green, and `bash tools/typecheck.sh` exits 0
  over 13 files — so the red is purely value-based, not a gate or parse artefact). The 19:
  `test_floor_div_is_true_floor_not_truncation_toward_zero`,
  `test_floor_div_satisfies_the_defining_floor_inequality`,
  `test_cube_round_scaled_rounds_half_toward_positive_infinity`,
  `test_cube_round_scaled_breaks_ties_by_repairing_z`,
  `test_cube_round_scaled_always_returns_a_valid_nearby_cube`,
  `test_cube_round_scaled_is_the_identity_for_a_non_positive_denominator`,
  `test_line_degenerate_and_straight_runs`,
  `test_line_tie_cases_resolve_through_the_z_repair`,
  `test_line_reversed_endpoints_give_the_reversed_line`,
  `test_line_long_off_origin_case`, `test_ring_radius_one_is_exactly_neighbors`,
  `test_ring_hand_walked_cases`, `test_ring_and_range_degenerate_radii_are_total`,
  `test_hexes_in_range_is_the_spiral_composition_of_rings`,
  `test_hexes_in_range_size_matches_the_hex_count_formula`,
  `test_line_properties_over_the_radius_four_disc`,
  `test_ring_properties_out_to_radius_eight`,
  `test_hexes_in_range_properties_out_to_radius_eight`,
  `test_line_ring_and_range_return_fresh_arrays_each_call`.
  (`test_slice_two_calls_are_repeatable` passes against the stubs and is therefore not a red signal
  — any deterministic function satisfies it; it becomes load-bearing only against a real
  implementation that might cache.)

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **DONE** (2026-08-04, M0-T5) | **BOTH §14 acceptance clauses MET headless, checked against the §14 row this iteration** — (a) *sentinel suite green AND a deliberately failing sentinel makes `run_tests.sh` exit non-zero* (SETUP-2 amendment): `verify_harness.sh` exit 0 with **four** phases — A green, B failing canary, C syntactic parse error, D statically-impossible construct — each red phase non-zero **and naming its probe**, tree clean afterwards; (b) *invalid ruleset rejected with a line-numbered error*: pinned by `tests/unit/test_rules_loader.gd`, suite exit 0 at **Scripts 7 / Tests 62 / Passing 62 / Asserts 473** with the collected-script count equal to the `test_*.gd` count on disk. **ALL §14 M0 deliverables built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate), `decisions.md`. M0-T5 closed the last open item: the false-green mode *inside* the signal that reports clause (a) (decisions.md M0-T5, correcting M0-T4 item (i)). |
| M1 World | **in progress** (opened 2026-08-04, M1-T1) · **M1-T2 BLOCKED (2026-08-04)** | **NONE of the three §14 M1 criteria met yet, checked against the §14 row this iteration** — (a) *golden mapgen test (seed ⇒ terrain hash)*: no generator and no golden file exist (the project's first golden); (b) *60 fps on Medium map greybox*: no renderer, camera rig or greybox scene exists; (c) *LOS property tests*: no LOS code exists — that is M1-T3, and it is **not** reached yet. **Deliverables built so far: HexMath slice 1 only** (`scripts/core/hex_math.gd` — axial/cube conversion, the fixed 6-direction table, neighbours/opposites, cube distance, radius membership, hex count; 24 tests, all §4.1 values pinned). **Slice 2 (lines/rings/ranges) is SPEC'D AND TEST-PINNED BUT NOT IMPLEMENTED** — 20 tests landed RED against deliberately-wrong stubs; the suite is red at 19 failures and M1-T2 must be resumed at the Implement stage. Still to build: HexMath lines/rings/ranges bodies (M1-T2 resume), `Los` (M1-T3, `scripts/core/los.gd` per §11.2), concentric-bowl generator (§4.4), chunked MultiMesh renderer, camera rig, hex picking. |
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
| 2026-08-04 | SETUP-5 | Workflow boilerplate: run_tests.sh is strengthening-only, not frozen | landed | SETUP-5: workflow boilerplate — run_tests.sh strengthening-only, not frozen |
| 2026-08-04 | M1-T1 | HexMath slice 1: axial/cube conversions, fixed neighbour order, cube distance (**opens M1**) | landed | M1-T1: HexMath slice 1: axial/cube conversions, fixed neighbour order, cube distance |
| 2026-08-04 | M1-T2 | HexMath slice 2: exact-integer hex lines, rings and ranges | **blocked** (tests landed RED; Implement stage returned no result) | WIP(blocked) M1-T2: HexMath slice 2: exact-integer hex lines, rings and ranges |

## Notes for the next iteration

- **Pick up: FINISH M1-T2 — it is blocked mid-iteration, not finished.** The repo is committed in a
  deliberately RED state (see **Blockers** above for the exact 19 failing test names). Everything
  the Implement stage needs is already on disk:
  - **Where the open question was settled:** lines/rings/ranges live in `scripts/core/hex_math.gd`,
    **not** a new file — §14's M1 row names the deliverable *"HexMath (axial/cube, LOS, lines,
    rings)"*, so only the LOS predicate splits out, into `scripts/core/los.gd` at **M1-T3** per
    §11.2. **Do not create `los.gd` in M1-T2.**
  - **What to do:** replace the block in `scripts/core/hex_math.gd` banner-marked
    `SLICE 2 (M1-T2) — DELIBERATELY-WRONG TESTS-STAGE STUBS` with real bodies implementing
    resolutions **(C)–(G)**, which are written out in full in that file's own header doc block and
    again in `tests/unit/test_hex_math.gd`'s header. Fix **code** to match the pinned values; never
    the reverse — `tests/unit/test_hex_math.gd` is not to be edited, and its expected values were
    each re-derived independently against a reference model before being pinned.
  - **The five traps the suite exists to catch:** (1) a shared/static/`const` cached return array —
    all three array-returning functions must build a fresh `Array[Vector2i]` per call; (2)
    truncating division on negatives (GDScript `int/int` truncates toward zero — `_floor_div` must
    correct it); (3) a tie-break that repairs `y` instead of `z`; (4) `roundi()`/half-away-from-zero
    instead of round-half-up-toward-+inf; (5) any epsilon nudge — the reverse-symmetry property over
    3,721 ordered pairs fails immediately.
  - **Then run:** `bash tools/run_tests.sh` (expect exit 0, Scripts 8, Tests 106),
    `bash tools/typecheck.sh` (exit 0, 13 files), `bash tools/ci.sh`, `bash tools/verify_harness.sh`.
    At Verify make the two subtlest pins **live**, exactly as M1-T1 did for `neighbors()`: mutate
    `ring()` to return a shared cached array and confirm the freshness test goes red; flip the
    cascade's final `else` to repair `y` and confirm `line((0,0),(2,-1))` and `line((0,0),(1,1))` go
    red; restore byte-identically (md5) after each probe.
  - **Only after that is green** does the pointer move to **M1-T3 = `Los`** in `scripts/core/los.gd`
    (§11.2), pinning §4.1's blocking rule verbatim: *"a line is blocked by any Solid hex, or by any
    hex whose elevation exceeds **both** endpoints' elevation"*. **Open design question M1-T3 must
    resolve under §13.4:** no `GameState` and no map type exist yet, so `Los` must take terrain as
    **injected query parameters** (two `Callable`s, or a tiny typed read-only view) rather than
    inventing a map type ahead of §4.4. Note also that `test_hex_math.gd`'s no-float / no-map-size
    source scans cover `hex_math.gd` **only** — a new `los.gd` is not automatically covered, so
    write the equivalent scans for it.
  `scripts/` currently holds `sim/rules_loader.gd` + `sim/rules_error.gd`, `core/event.gd` +
  `core/event_bus.gd` and `core/hex_math.gd`, and nothing else, deliberately (§13.4: invent nothing
  ahead of its milestone). No GameState, Command, generator, renderer or map code exists yet, and
  **no concrete `Event` subclass exists** — those belong to the milestones that emit them. M1 is
  the first milestone allowed to add hex/map code and the first to record a **golden**.
- **HexMath contract (`scripts/core/hex_math.gd`, landed M1-T1) — the coordinate layer every later
  system indexes; read decisions.md M1-T1 (A)/(B) before extending it.** `class_name HexMath extends
  RefCounted`, **all-static, never instantiated**. Axial is a plain `Vector2i` (q, r), cube a plain
  `Vector3i` (x, y, z) — integer Variant built-ins, not Nodes, so §11.1 purity holds and a
  4,921-hex Large map allocates no per-hex objects. **API surface is now 15 public + 1 private, but
  only the first 11 are IMPLEMENTED** — do not grow it casually:
  - **Landed and stable (M1-T1, 11 members):** `DIRECTIONS` (`Array[Vector2i]`), `DIRECTION_NAMES`
    (`PackedStringArray`), `axial_to_cube`, `cube_to_axial`, `is_valid_cube`, `neighbor`,
    `neighbors`, `opposite`, `distance`, `is_within_radius`, `hex_count_for_radius`.
  - **Present as DELIBERATELY-WRONG STUBS (M1-T2, blocked — 4 public + 1 private):**
    `cube_round_scaled(numerators: Vector3i, denom: int) -> Vector3i`,
    `line(a: Vector2i, b: Vector2i) -> Array[Vector2i]`,
    `ring(center: Vector2i, radius: int) -> Array[Vector2i]`,
    `hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]`, and the private
    `_floor_div(n: int, d: int) -> int`. They exist **only** so the test file parses (a call to a
    missing method is a parse error, which silently un-collects the whole file — the M0-T5 false
    green, decisions.md M0-T5 item (a)). **Nothing may call them until M1-T2 is finished.** Their
    contract is resolutions **(C)–(G)**, written out verbatim in the file header and in
    `tests/unit/test_hex_math.gd`'s header — the header lettering `(A)`/`(B)`/`(C)`/`(C2)`/`(D)`/
    `(E)`/`(F)`/`(G)` is cross-referenced by `hex_math.gd`, `test_hex_math.gd` and `decisions.md`,
    so **keep it stable and continue the sequence**. In one line each: (C) round-half-up means
    toward **+infinity**, computed exactly over rationals (`floor_div(2n + d, 2d)`), never floats,
    and **`roundi()` is the WRONG primitive** (it rounds half away from zero); (C2) the cube-repair
    cascade breaks ties by repairing **z**; (D) exact numerators make `line(a,b)` exactly
    `reverse(line(b,a))`; (E) `ring(c, 1) == neighbors(c)` element-for-element; (F) a negative
    radius is the **empty array**; (G) `hexes_in_range` is the spiral `[c] + ring(1) + … + ring(r)`.
  - **Direction indices are FIXED and load-bearing** (§4.1): `0 E (+1,0)`, `1 NE (+1,-1)`,
    `2 NW (0,-1)`, `3 W (-1,0)`, `4 SW (-1,+1)`, `5 SE (0,+1)`; `opposite(i) == (i+3)%6`, which is a
    true geometric property here (`DIRECTIONS[i] + DIRECTIONS[opposite(i)] == ZERO` for all six).
    Rings, pathfinding and mapgen will all key off this order — **never reorder or rename it**.
    The "Flat-top hexes" phrase in §4.1 does **not** license renaming: hex-to-screen orientation is
    a renderer concern (decisions.md M1-T1 resolution **(A)**; keep that lettering — both
    `hex_math.gd` and `test_hex_math.gd` reference it).
  - `neighbors()` returns a **fresh** `Array[Vector2i]` per call — a `const Array` is not deeply
    immutable in GDScript, so a cached/shared return value is a cross-caller corruption hazard.
    Pinned by test (verified live by an adversarial mutation probe at Verify).
  - An **out-of-range direction index is the identity**: `neighbor(h, dir) == h` and
    `opposite(dir) == dir` for `dir` outside 0..5 — no crash, no assert abort headless
    (resolution **(B)**; keep the lettering).
  - **No map-size constant lives in the file** and a source-scan test mechanically forbids one
    (regex over `24|32|40|1801|3169|4921`). The §4.1 radii are tunable generator parameters and
    belong to `data/mapgen/*.json` (§4.4) at the generator task. `hex_count_for_radius` exposes only
    the formula `3*r*(r+1)+1`.
  - **Integer math only**, mechanically scanned: no float literal and no `float` token anywhere in
    the file; `distance` is `maxi(absi(dx), maxi(absi(dy), absi(dz)))` on cube coords, so it needs no
    division and carries no `@warning_ignore("integer_division")`.
  - **Arithmetic warning for anyone re-deriving distances by hand:** the M1-T1 task spec listed
    `distance((1,-3),(4,2)) == 5`; that was a **miscalculation**. With §4.1's mapping the cubes are
    `(1,2,-3)` and `(4,-6,2)`, delta `(-3,8,-5)`, so the answer is **8** (both closed forms agree).
    Re-derived independently three times. The test pins 8. Do not "fix" it back to 5.
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
- **CURRENT SUITE STATE IS RED BY DESIGN, and it is the M1-T2 blocker, not a harness fault.**
  `bash tools/run_tests.sh` → **exit 1** with **Scripts 8 / Tests 106 / Passing 87 / Failing 19 /
  Asserts 950/1023** (measured at Land, 2026-08-04). `Scripts 8` equals the number of `test_*.gd`
  on disk, so nothing is silently skipped, and `bash tools/typecheck.sh` still exits **0** over 13
  files — the red is purely value-based. The last **green** baseline was M1-T1's
  **Scripts 8 / Tests 86 / Passing 86 / Asserts 835** (it was 7 / 62 / 62 / 473 at the close of M0 —
  the M0 tracker row above deliberately keeps that historical figure). **Target once M1-T2's
  Implement stage lands: exit 0 at Scripts 8 / Tests 106 / Passing 106.**
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 on a healthy tree, and
  `bash tools/typecheck.sh` → exit 0 over **13** project `.gd` files, and
  `bash tools/verify_harness.sh` → exit 0
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
- **Process risk observed 2026-08-04 (M1-T2), recorded so the next iteration recognises the
  shape:** the workflow's **Implement** stage returned **no result at all** (agent died or was
  skipped) and **Verify** consequently ran nothing and reported `green: false` with zero suites run.
  The loop then correctly degraded to `WIP(blocked)` per CLAUDE.md rather than landing a false
  green. Two consequences worth internalising: (1) a *committed red tree* is a legitimate,
  documented loop state — do **not** "fix" it by deleting or weakening the failing tests, and do
  **not** re-run Orient to invent a different task; resume at Implement. (2) The Tests-stage stub
  convention is what made this safe: because the stubs keep `hex_math.gd` parseable, the red is
  loud (19 named value failures) instead of the silent whole-file un-collection that M0-T5 closed.
  Keep using it.
- **Golden discipline, first exercised in M1:** no golden file exists yet. When M1 records the
  mapgen hash, §13.6 applies from that moment — a golden may be re-recorded **only** with a logged
  reason in `decisions.md` in the *same commit*. Get the seeded generation deterministic first
  (`state.rng` only, no `randi()`, stable iteration order, integer math), because a golden recorded
  over a nondeterministic generator is worse than none.
