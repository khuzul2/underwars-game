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
  generator, chunked MultiMesh renderer, camera rig, hex picking); M1-T1/M1-T2/M1-T3 delivered
  **HexMath (both slices) and `Los`**, and M1-T4 delivered **slice 1 of the generator** (`HexMap` +
  the §4.4 band/elevation bowl) — terrain **types**, the seeded composition, the renderer, camera rig
  and hex picking are all still missing. **Exactly ONE of the three §14 M1 acceptance criteria passes
  — re-checked against the §14 row (line 1097) this iteration** — *"LOS property tests"* (M1-T3,
  green headless). *"Golden mapgen test (seed ⇒ terrain hash)"* and *"60 fps on Medium map greybox"*
  remain unmet: no terrain-type assignment, no seeded composition, **no golden file exists at all**,
  and no renderer/camera/greybox exists.
- **Next task:** **M1-T5 — generator slice 2: terrain-type composition by seeded RNG + the PROJECT'S
  FIRST GOLDEN** (§4.2 palette over §4.4's bands, hashed as *seed ⇒ terrain hash*). Slice 1 landed
  the container and the deterministic bowl; slice 2 adds the §4.2 hex-type palette per band (70% Soft
  Dirt / 20% Hard Rock in the Rim, 55% Hard Rock / 15% Granite in the Mantle, granite-dominant Core —
  read §4.2 for the authoritative rows), the **first RNG in the sim** (seeded, through `state.rng`,
  never `randi()`), and `tests/golden/`'s first file. From the moment that golden lands, §13.6's
  re-record-only-with-a-logged-reason-in-the-same-commit rule is live **forever**. Continue the
  decisions.md lettering at **(R)** — M1-T4 ended at (Q).
- **Blockers:** **none.** `bash tools/run_tests.sh` exits **0** at Scripts 11 / Tests 183 /
  **Passing 183** / Failing 0 / Asserts 1879; `bash tools/typecheck.sh` exits 0 over 19 files;
  `bash tools/ci.sh` exits 0; `bash tools/verify_harness.sh` exits 0 across all four phases with the
  tree left clean (all re-measured at Land, 2026-08-04, M1-T4).

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **DONE** (2026-08-04, M0-T5) | **BOTH §14 acceptance clauses MET headless, checked against the §14 row this iteration** — (a) *sentinel suite green AND a deliberately failing sentinel makes `run_tests.sh` exit non-zero* (SETUP-2 amendment): `verify_harness.sh` exit 0 with **four** phases — A green, B failing canary, C syntactic parse error, D statically-impossible construct — each red phase non-zero **and naming its probe**, tree clean afterwards; (b) *invalid ruleset rejected with a line-numbered error*: pinned by `tests/unit/test_rules_loader.gd`, suite exit 0 at **Scripts 7 / Tests 62 / Passing 62 / Asserts 473** with the collected-script count equal to the `test_*.gd` count on disk. **ALL §14 M0 deliverables built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate), `decisions.md`. M0-T5 closed the last open item: the false-green mode *inside* the signal that reports clause (a) (decisions.md M0-T5, correcting M0-T4 item (i)). |
| M1 World | **in progress** (opened 2026-08-04, M1-T1; M1-T2, M1-T3 and M1-T4 landed 2026-08-04) | **1 of 3 §14 M1 criteria met, re-checked against the §14 row (line 1097) this iteration** — (a) *golden mapgen test (seed ⇒ terrain hash)*: **NOT met**, the §4.4 band/elevation bowl now exists (M1-T4) but there is no terrain-**type** assignment, no seeded composition and **no golden file at all**; (b) *60 fps on Medium map greybox*: **NOT met**, no renderer, camera rig or greybox scene exists; (c) *LOS property tests*: **MET headless** (M1-T3 — `tests/unit/test_los.gd`, 8 property sweeps incl. symmetry/reflexivity/all-open/adjacency/agreement/monotonicity over the 3,721 ordered pairs of the radius-4 disc, all green, and three adversarial mutation probes proved the subtlest pins load-bearing). **The milestone is therefore NOT marked done.** **Deliverables built so far: HexMath COMPLETE, both slices** (`scripts/core/hex_math.gd` — slice 1: axial/cube conversion, the fixed 6-direction table, neighbours/opposites, cube distance, radius membership, hex count; slice 2 (M1-T2): exact-integer `cube_round_scaled`, `line`, `ring`, `hexes_in_range` + the private `_floor_div`); **`Los` COMPLETE** (M1-T3, `scripts/core/los.gd` — the §4.1 blocking predicate, exactly two public functions over injected terrain `Callable`s, resolutions (H)–(L)); **concentric-bowl generator PARTIAL — slice 1 of 2** (M1-T4, `scripts/sim/hex_map.gd` + `scripts/sim/map_generator.gd` + `data/mapgen/concentric_bowl.json` — the elevation-only hex container with its pinned canonical order, and the §4.4 band/terrace rules as pure integer cross-multiplication, resolutions (M)–(Q); **no RNG, no terrain type, no golden — all deferred to M1-T5**). Still to build: generator slice 2 (§4.2 palette + seeded composition) **and the project's first golden**, chunked MultiMesh renderer, camera rig, hex picking. |
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
| 2026-08-04 | M1-T2 | HexMath slice 2: exact-integer hex lines, rings and ranges (tests stage; landed RED) | superseded → landed | WIP(blocked) M1-T2: HexMath slice 2: exact-integer hex lines, rings and ranges |
| 2026-08-04 | M1-T2 | HexMath slice 2: exact-integer hex lines, rings and ranges (**resumed at Implement; blocker cleared**) | landed | M1-T2: HexMath slice 2: exact-integer hex lines, rings and ranges |
| 2026-08-04 | M1-T3 | Los: hex line-of-sight blocking predicate over injected terrain (**meets the §14 M1 "LOS property tests" criterion**) | landed | M1-T3: Los: hex line-of-sight blocking predicate over injected terrain |
| 2026-08-04 | M1-T4 | HexMap plus the concentric-bowl band and elevation pass (generator slice 1) | landed | M1-T4: HexMap plus the concentric-bowl band and elevation pass (generator slice 1) |

## Notes for the next iteration

- **Pick up: M1-T5 = generator slice 2 — §4.2 terrain-type composition by seeded RNG, plus the
  PROJECT'S FIRST GOLDEN.** M1-T4 is finished and the tree is green; nothing is carried over. Read
  §4.2 (the hex-type table and its per-band percentages), §4.4 (the bowl's bands, now implemented),
  §11.1 (`state.rng`, stable-ID iteration order) and §13.6 (golden discipline) before speccing, and
  read decisions.md M1-T4 **(M)–(Q)** — slice 2 extends exactly those.
  - **This slice introduces the FIRST RNG IN THE SIM.** It must be seeded and reached through
    `state.rng` — **never** `randi()`/`randf()`, never wall-clock, never `Dictionary.keys()` order.
    Resolution (Q) deliberately carved **no** RNG exception into `map_generator.gd`'s S2 engine-free
    source scan, so slice 2 must **amend that scan with a logged reason** (permitting the seeded call
    shape only), never delete it. Draw rolls in the pinned canonical order (`r` ascending, then `q`)
    so the sequence is reproducible.
  - **This is the PROJECT'S FIRST GOLDEN** (§14 M1 criterion (a), *seed ⇒ terrain hash*). Get the
    seeded composition deterministic **first**, then record. `tests/golden/` is currently empty by
    design; from the moment the first file lands, §13.6's *"re-record only with a logged reason in
    the same commit"* applies **forever**. The thing it hashes is `HexMap` in its canonical order —
    already pinned by test at M1-T4 precisely so the golden cannot be built on a drifting order.
  - **The §4.2 percentages are CONTENT.** They belong in `data/mapgen/concentric_bowl.json` (a new
    top-level key, keeping the one-line-per-top-level-group layout that makes error lines meaningful)
    or a sibling under `data/mapgen/`, **never** as `.gd` literals — and prove it the way M1-T4 did,
    with a mutate-the-params-in-text test (property P10), not merely with a forbidding regex.
  - **`HexMap` gains its terrain-type field here** (see its contract note below): slice 1 stores
    elevation only, on purpose. Add the type array the same way — one `PackedInt32Array`, no
    `Dictionary`, no band array (band stays derivable from distance and is therefore not state).
  - **Write the five source scans fresh for any new file.** They are per-file and inherit nothing
    (`test_hex_map.gd` covers `hex_map.gd` only, and so on). Copy the shape from
    `tests/unit/test_map_generator.gd`: read raw source, **strip comment lines first** (load-bearing
    — doc blocks contain `§4.1`, which the no-float regex would otherwise hit), then scan for: no
    float literal; no `randi(`/`randf(`/`extends Node`/`SceneTree`/`get_tree`/`Engine.`/`Time.`/`OS.`;
    no map-size literal `24|32|40|1801|3169|4921`; a `## §<section>` doc comment on every public
    function **plus an explicit expected public-member list** (so a missing **or extra** member fails
    rather than passing vacuously); purity via `get_class()`, **never** `is Node` (statically
    impossible — parse-errors and silently un-collects the whole file; decisions.md M0-T2 item 11 /
    M0-T5 item (a)).
  - Continue the decisions.md lettering at **(R)** — M1-T4 ended at (Q).
  `scripts/` currently holds `sim/rules_loader.gd` + `sim/rules_error.gd` + `sim/hex_map.gd` +
  `sim/map_generator.gd`, `core/event.gd` + `core/event_bus.gd`, `core/hex_math.gd` and
  `core/los.gd`, and nothing else, deliberately (§13.4: invent nothing ahead of its milestone). No
  GameState, Command, renderer, terrain-type palette, vein, feature or spawn code exists yet, and
  **no concrete `Event` subclass exists** — those belong to the milestones that emit them.
- **`HexMap` + `MapGenerator` contract (`scripts/sim/hex_map.gd`, `scripts/sim/map_generator.gd`,
  `data/mapgen/concentric_bowl.json` — slice 1 COMPLETE as of M1-T4; read decisions.md M1-T4 (M)–(Q)
  before extending them).** Both are `class_name … extends RefCounted`, **instantiable** (unlike
  `HexMath`/`Los`, which are all-static). Public surfaces are **exact and mechanically scanned** — a
  missing *or extra* member fails: `HexMap` = `radius` + `hex_count`, `is_in_bounds`, `index_of`,
  `hexes`, `get_elevation`, `set_elevation`; `MapGenerator` = `errors` + `load_params_text`,
  `load_params_file`, `radius_for_size`, `band_count`, `band_id`, `band_index_at`, `elevation_at`,
  `generate`.
  - **(O) `HexMap` storage and CANONICAL ORDER — the golden hashes this, so do not touch it
    casually.** One `PackedInt32Array` over the axial bounding square, index
    `(r + radius) * (2 * radius + 1) + (q + radius)`; **no `Dictionary` anywhere**. Membership is
    `HexMath.distance(Vector2i.ZERO, hex) <= radius`, never a second bounds formula. Canonical order
    is **`r` ascending `-R..+R`, then `q` ascending within each `r`**, and `index_of` is strictly
    increasing along it (that assertion is what catches a q/r-swapped index — proven live by probe).
    `hexes()` returns a **fresh** `Array[Vector2i]` every call (M1-T2 trap 1, now re-pinned in its
    third file). Every accessor is **total**: off-disc `get_elevation` → `-1`, `index_of` → `-1`,
    `set_elevation` → silent no-op, `is_in_bounds` → false; negative radius → `hex_count() == 0` and
    empty `hexes()`. **Slice 1 stores ELEVATION ONLY**, deliberately.
  - **(M) band rule / (N) terrace rule — both pure integer CROSS-MULTIPLICATION, no division, so
    neither file carries `@warning_ignore("integer_division")` (a scan forbids the string).**
    `band_index_at(d,R)` = last (innermost) `k` with `d*100 <= outer_pct[k]*R`, else 0, where
    `outer_pct = [100, 70, 30]` summed from the innermost band. `elevation_at(d,R)` = elevation of
    the **first** row with `d*100 > from_pct*R` (**STRICT `>`**), else the innermost row's elevation
    **read from data**. **The strict `>` against the band rule's `<=` is the whole ballgame** — it is
    what makes terrace and band boundaries coincide where a percentage is shared (30 and 70 appear in
    both tables). `>=` misaligns them **only at exact-multiple radii** (R=40, d=12/28/34), which no
    hand-picked mid-band case detects; probe P1 measured exactly that. Both functions **early-return
    0 for `R <= 0`** — without it `band_index_at(0,0)` returns 2.
  - **The `85` in the terrace table is NOT a GDD number** — it is the midpoint of the Safe Rim band
    (`70 + 30/2`), realising §4.4's *"Rim 2–3"* as elevation 2 on the inner half and 3 on the outer.
    It is **tunable content** in the JSON. Likewise the §4.1 radii 24/32/40: neither `.gd` file
    contains `24|32|40|1801|3169|4921`, and a mutate-the-params-in-text test proves the numbers are
    genuinely read from data rather than shadowed by a code literal.
  - **(P) load contract.** Reuses the existing `RulesError`; **line 0 stays reserved for
    missing/unreadable files** and is never emitted for a schema error; schema errors attribute to
    the first line carrying the offending **top-level** key's JSON token, falling back to 1 — which
    only works because `data/mapgen/concentric_bowl.json` follows `ruleset.json`'s **load-bearing**
    layout (line 1 is a lone `{`; each top-level group on exactly one line). **Any error leaves the
    generator UNCONFIGURED** — `radius_for_size` → 0, `generate` → empty map — including a failed load
    after a successful one. Integral-vs-fractional checks live in the private `_is_integral`/`_as_int`
    helpers because Godot 4.7 parses **every** JSON number as `TYPE_FLOAT` (M0-T2 item 8); that is
    also the **narrowed** S1 float-scan exception (the `float` token is permitted only inside private
    decode helpers, tracked by enclosing function name).
  - **Two non-blocking traps recorded for slice 2** (decisions.md M1-T4 item 13): (a) in
    `_validate_map_sizes`/`_validate_bands` a bad-id entry can append to one parallel array and not
    the other — harmless today because any error discards the whole params set, but a real trap if
    slice 2 ever reads the arrays **before** checking `errors`; (b) `_validate_terraces` accepts an
    empty table and one whose innermost `from_share_pct` is not 0.
- **`Los` contract (`scripts/core/los.gd`, COMPLETE as of M1-T3) — the §4.1 blocking predicate that
  fog of war (§4.3), AI targeting (§10), ranged combat/cover (§7) and the light rules (§4.7) will all
  key off; read decisions.md M1-T3 (H)–(L) before extending it.** `class_name Los extends
  RefCounted`, **all-static, never instantiated** in production code. **Public API is EXACTLY two
  functions and must not grow** (a source scan enforces the exact member list):
  `has_line_of_sight(a: Vector2i, b: Vector2i, is_solid: Callable, elevation: Callable) -> bool` and
  `blocking_hexes(a, b, is_solid, elevation) -> Array[Vector2i]`, plus one private `_blocks`.
  - **The rule, verbatim from §4.1 (GDD line 172):** *"Line of sight uses standard hex line-drawing
    (lerp in cube space, round); a line is blocked by any Solid hex, or by any hex whose elevation
    exceeds **both** endpoints' elevation."* Implemented as: `path = HexMath.line(a, b)`;
    `cap = maxi(elev(a), elev(b))` computed **once**; an interior hex `path[i]`, `i` in `1..N-1`,
    blocks iff `is_solid(h)` **or** `elev(h) > cap` (strict).
  - **(H) Terrain arrives as two injected `Callable`s**, `is_solid(Vector2i) -> bool` and
    `elevation(Vector2i) -> int`, because no `GameState`/map type existed yet. **When the generator
    and `GameState` land, bind closures over them — do not change `los.gd`.**
  - **(I) Endpoints are NEVER tested** — a Solid endpoint does not block its own line. **(K)** falls
    out of that with no early return (`range(1, size-1)` is empty for sizes 1 and 2), so distance-0
    and distance-1 lines are unconditionally open. Do not "helpfully" add an early return.
  - **(J) "exceeds" is a STRICT `>`** against `maxi` of the two endpoint elevations; equal elevation
    does **not** block. **(L) an invalid `Callable` means open terrain** (`true` / `[]`, never
    `null`); `Los` knows no map bounds and imposes **no** 0–3 elevation range check — off-map and
    range semantics are the **caller's** job. `Los` compares; it does not police.
  - `blocking_hexes` allocates a **fresh** `Array[Vector2i]` per call (M1-T2 trap 1, re-pinned live).
  - **Never re-implement the line walk** — the scan requires the literal `HexMath.line(` to be
    present. §14's symmetry property is true *only* because resolution (D) makes
    `line(a,b) == reverse(line(b,a))` exactly, combined with the symmetric `maxi()` cap.
  - **Three adversarial mutation probes at Verify proved the pins load-bearing** (decisions.md M1-T3
    item 9). The one worth remembering: an **asymmetric cap** (`cap = elev(a)` instead of `maxi`) is
    invisible to **every** hand-walked case and is caught **only** by the 3,721-pair symmetry sweep.
    Never "simplify" that sweep away as a slow restatement of the examples.
  - **Deliberately absent and belonging to later milestones (§13.4):** `visible_hexes`, vision range
    (§4.3's *"Default unit vision: 4 hexes"*), fog-of-war knowledge states, and the Dark/Darkvision
    rules (§4.7). Do not add them to this file on the way past.
- **HexMath contract (`scripts/core/hex_math.gd`, COMPLETE as of M1-T2) — the coordinate layer every
  later system indexes; read decisions.md M1-T1 (A)/(B) and M1-T2 (C)–(G) before extending it.**
  `class_name HexMath extends RefCounted`, **all-static, never instantiated**. Axial is a plain
  `Vector2i` (q, r), cube a plain `Vector3i` (x, y, z) — integer Variant built-ins, not Nodes, so
  §11.1 purity holds and a 4,921-hex Large map allocates no per-hex objects. **API surface is 15
  public + 1 private, ALL IMPLEMENTED, ALL GREEN** — do not grow it casually:
  - **Slice 1 (M1-T1, 11 members):** `DIRECTIONS` (`Array[Vector2i]`), `DIRECTION_NAMES`
    (`PackedStringArray`), `axial_to_cube`, `cube_to_axial`, `is_valid_cube`, `neighbor`,
    `neighbors`, `opposite`, `distance`, `is_within_radius`, `hex_count_for_radius`.
  - **Slice 2 (M1-T2, 4 public + 1 private):**
    `cube_round_scaled(numerators: Vector3i, denom: int) -> Vector3i`,
    `line(a: Vector2i, b: Vector2i) -> Array[Vector2i]`,
    `ring(center: Vector2i, radius: int) -> Array[Vector2i]`,
    `hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]`, and the private
    `_floor_div(n: int, d: int) -> int`. Their contract is resolutions **(C)–(G)**, written out
    verbatim in the file header and in `tests/unit/test_hex_math.gd`'s header — the header lettering
    `(A)`/`(B)`/`(C)`/`(C2)`/`(D)`/`(E)`/`(F)`/`(G)` is cross-referenced by `hex_math.gd`,
    `test_hex_math.gd` and `decisions.md`, so **keep it stable and continue the sequence at (H)**.
    In one line each: (C) round-half-up means toward **+infinity**, computed exactly over rationals
    (`_floor_div(2n + d, 2d)`), never floats, and **`roundi()` is the WRONG primitive** (it rounds
    half away from zero); (C2) the cube-repair cascade breaks ties by repairing **z**; (D) exact
    numerators make `line(a,b)` exactly `reverse(line(b,a))`; (E) `ring(c, 1) == neighbors(c)`
    element-for-element; (F) a negative radius is the **empty array**; (G) `hexes_in_range` is the
    spiral `[c] + ring(1) + … + ring(r)`.
  - **The five traps the slice-2 suite exists to catch — re-read before touching any of the five
    bodies**, because each is silent and each breaks determinism (and M1's first golden): (1) a
    shared/static/`const` cached return array — all three array-returning functions build a **fresh**
    `Array[Vector2i]` per call; (2) truncating division on negatives (GDScript `int/int` truncates
    toward zero, so `_floor_div` corrects it — without that every negative-coordinate line rounds the
    wrong way); (3) a tie-break that repairs `y` instead of `z`; (4) `roundi()`/half-away-from-zero
    instead of round-half-up-toward-+inf; (5) any epsilon nudge — the reverse-symmetry property over
    3,721 ordered pairs fails immediately. Traps (1) and (3) were **proven live by adversarial
    mutation probes at Verify** (see decisions.md M1-T2 completion entry), not merely asserted.
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
- **CURRENT SUITE STATE IS GREEN.** `bash tools/run_tests.sh` → **exit 0** at **Scripts 11 /
  Tests 183 / Passing 183 / Failing 0 / Asserts 1879** (re-measured at Land, 2026-08-04, M1-T4).
  `Scripts 11` equals the number of `test_*.gd` on disk, so nothing is silently skipped;
  `bash tools/typecheck.sh` exits **0** over 19 files; `bash tools/ci.sh` and
  `bash tools/verify_harness.sh` both exit 0. Prior green baselines, for reference: M1-T3's
  9 / 129 / 129 / 1308, M1-T2's 8 / 106 / 106 / 1023, M1-T1's 8 / 86 / 86 / 835, and
  7 / 62 / 62 / 473 at the close of M0 (the M0 tracker row above deliberately keeps that historical
  figure). **Expect these totals to RISE as you add tests — they are enumerated, not hard-coded.**
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 on a healthy tree, and
  `bash tools/typecheck.sh` → exit 0 over **19** project `.gd` files, and
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
  - **NEVER pipe `"$OUT"` into `grep -q` in this script (M1-T4, a live FALSE GREEN, now fixed and
    pinned).** `grep -q` exits the instant it matches, the upstream `printf` dies of SIGPIPE, and
    `set -o pipefail` then reports the **whole pipeline as 141 even though the pattern MATCHED**.
    Below ~64 KB of output (one pipe buffer) the writer finishes first and the bug is invisible;
    M1-T4's run was **89 KB** and crossed the threshold, which inverted **both** guards: the coverage
    guard reported every on-disk script as missing (false red) and the load/parse refusal **stopped
    firing on `Failed to load script`** — exactly the false-green mode M0-T5 exists to prevent. Both
    greps now read from a **here-string** (`<<< "$OUT"`), which has no writer to kill; every guard
    string and regex alternative is byte-identical, so the fix is strengthening-only under SETUP-5.
    `tests/unit/test_run_tests_harness.gd::test_runner_never_feeds_grep_q_through_a_pipe` pins the
    property by shape. **Any future guard you add must use a here-string too.**
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
- **Process pattern proven 2026-08-04 (M1-T2), now CLOSED — kept as the standing playbook for the
  next time a stage dies.** The workflow's **Implement** stage returned **no result at all** (agent
  died or was skipped) and **Verify** consequently ran nothing and reported `green: false` with zero
  suites run. The loop correctly degraded to `WIP(blocked)` per CLAUDE.md rather than landing a false
  green, and the **next iteration resumed the same task at the Implement stage and finished it** —
  no re-Orient, no re-spec, no test churn. Three consequences worth internalising: (1) a *committed
  red tree* is a legitimate, documented loop state — do **not** "fix" it by deleting or weakening
  the failing tests, and do **not** re-run Orient to invent a different task; resume at Implement.
  (2) The Tests-stage stub convention is what made this safe: because the stubs kept `hex_math.gd`
  parseable, the red was loud (19 named value failures) instead of the silent whole-file
  un-collection that M0-T5 closed. Keep using it. (3) Naming the exact failing tests in **Blockers**
  is what made the resume mechanical — the resuming iteration matched all 19 names before touching
  anything, which proved the tree had not drifted. Always record the failure list, never just a count.
- **LOC-budget precedent set at M1-T3, so the next Orient does not mis-scope:** the ≤ ~300 LOC house
  rule is a **production-change** budget, and M1-T3 honoured it easily (27 code lines in `los.gd`).
  Its test file is 965 lines, because §14's *"LOS property tests"* acceptance criterion demands
  sweeps, not examples. When a §14 acceptance criterion names property tests, size the **production
  slice** to ≤ ~300 LOC and let the test file be as large as the criterion requires — do **not**
  ration assertions to hit a line count, and do not split a task merely because its suite is long.
- **Golden discipline, due NEXT TASK:** `tests/golden/` is still empty — M1-T4 deliberately created
  no golden (resolution (Q)), because a golden over a half-built generator would have to be
  re-recorded the moment terrain types land, and every re-record is a logged event forever. **M1-T5
  records the first one.** From that moment §13.6 applies: a golden may be re-recorded **only** with
  a logged reason in `decisions.md` in the *same commit*. Get the seeded composition deterministic
  first (`state.rng` only, no `randi()`, integer math), and hash `HexMap` in the **canonical order
  M1-T4 already pinned** (`r` ascending, then `q`) — a golden recorded over a drifting order or a
  nondeterministic generator is worse than none.
- **Adversarial mutation probes are now standing practice at Verify** (M1-T1 item 8 → M1-T4 item 8,
  four iterations running). Before declaring green, break the implementation on purpose — capture the
  file md5, mutate, run, restore, re-verify byte-identical — and **record what went red**. A property
  test that has never been observed failing is indistinguishable from one that cannot fail. M1-T4's
  yield: the terrace `>` vs `>=` slip is invisible except at exact-multiple radii, and a q/r-swapped
  canonical order is caught only by the `index_of`-monotonicity assertion — neither would have been
  trusted on inspection alone.
