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
  **HexMath (both slices) and `Los`**, M1-T4 + M1-T5 delivered the **concentric-bowl generator
  COMPLETE** (`HexMap` + the §4.4 band/elevation bowl, then the seeded `Rng`, the §4.4 terrain-type
  composition, `content_hash` and the first golden), and M1-T6 + M1-T7 delivered the **chunked
  MultiMesh renderer COMPLETE** (`HexLayout` — flat-top hex→world placement + the deterministic chunk
  partition; then `MapRenderer` — the project's **first `Node`**: one `MultiMeshInstance3D` per chunk,
  shared prism mesh + material, per-instance type/tint custom data and the dirty-chunk rebuild seam,
  plus `data/render/terrain_palette.json`). Still missing: the **camera rig (M1-T8, which also carries
  the greybox scene and the 60-fps measurement) and hex picking (M1-T9)**. **TWO of the three §14 M1
  acceptance criteria pass — re-checked against the §14 row (line 1097) this iteration** — *"Golden
  mapgen test (seed ⇒ terrain hash)"* (M1-T5, green headless) and *"LOS property tests"* (M1-T3,
  green headless). *"60 fps on Medium map greybox"* **REMAINS UNMET after M1-T7**: there is still no
  scene and no camera, and per decisions.md M1-T6 **(Z)** it is **not headless-measurable at all** (the
  `--headless` dummy renderer has no renderer) — it is a **manual windowed measurement now owed at
  M1-T8** (see the M1-T7 re-slice, decisions.md M1-T7 item 1: **(Z)**'s forward reference to "M1-T7"
  now points to **M1-T8**).
- **Next task:** **M1-T8 — the greybox scene + camera rig + the 60-fps measurement.** Create the first
  `scenes/Main.tscn` (a `MapRenderer` instanced from the scene, `WorldEnvironment` with **SDFGI off**
  per §10 line 680), the **CameraRig**, and then run the **MANUAL WINDOWED 60-fps measurement on the
  Medium map** (radius 32 / 3,169 hexes) and **log the number in decisions.md at that task even if it
  is bad** — that is the last unmet §14 M1 acceptance criterion. Read decisions.md **M1-T7 (AA)–(AH)**
  first; three carry-overs bite here: (a) `_clear_chunks()` frees **all** children of the
  `MapRenderer` node, so the `.tscn` must **not** give it non-chunk children; (b) `set_layout()` must
  be called **once** per renderer — the shared mesh is sized on first `build()` and is not resized
  later; (c) the **open cosmetic item** — whether Godot's `CylinderMesh` starts its first radial vertex
  at +X (flat-top, matching **(V)**) or 30° off is not verifiable headless, so check it **by eye** in
  the windowed run and log a yaw only if one is genuinely needed. `project.godot` still deliberately
  has **no** `run/main_scene`; if M1-T8 sets one, it must point at a scene that actually exists (a
  dangling path breaks `--import`). Hex picking is **M1-T9**; size each slice to ≤ ~300 LOC. Continue
  the decisions.md lettering at **(AI)** — M1-T7 ended at (AH).
- **Blockers:** **none.** `bash tools/run_tests.sh` exits **0** at Scripts 15 / Tests 321 /
  **Passing 321** / Failing 0 / Asserts 3380; `bash tools/typecheck.sh` exits 0 over 26 files;
  `bash tools/ci.sh` exits 0 (all three re-measured at Land, 2026-08-04, M1-T7); `bash
  tools/verify_harness.sh` exits 0 across all four phases with the tree left clean (re-run at
  M1-T7 Verify).

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **DONE** (2026-08-04, M0-T5) | **BOTH §14 acceptance clauses MET headless, checked against the §14 row this iteration** — (a) *sentinel suite green AND a deliberately failing sentinel makes `run_tests.sh` exit non-zero* (SETUP-2 amendment): `verify_harness.sh` exit 0 with **four** phases — A green, B failing canary, C syntactic parse error, D statically-impossible construct — each red phase non-zero **and naming its probe**, tree clean afterwards; (b) *invalid ruleset rejected with a line-numbered error*: pinned by `tests/unit/test_rules_loader.gd`, suite exit 0 at **Scripts 7 / Tests 62 / Passing 62 / Asserts 473** with the collected-script count equal to the `test_*.gd` count on disk. **ALL §14 M0 deliverables built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate), `decisions.md`. M0-T5 closed the last open item: the false-green mode *inside* the signal that reports clause (a) (decisions.md M0-T5, correcting M0-T4 item (i)). |
| M1 World | **in progress** (opened 2026-08-04, M1-T1; M1-T2 … M1-T7 landed 2026-08-04) | **2 of 3 §14 M1 criteria met, re-checked against the §14 row (line 1097) this iteration** — (a) *golden mapgen test (seed ⇒ terrain hash)*: **MET headless** (M1-T5 — `tests/golden/test_mapgen_golden.gd` + `tests/golden/mapgen_concentric_bowl_small_seed1337.json`, radius 24 / 1,801 hexes / seed 1337 ⇒ `content_hash` `0xcad24923`, the value measured three times independently; the test fails loudly and never auto-records when the file is absent, and six adversarial probes incl. a reversed roll stream and a perturbation of the shipped data all went red on demand; **untouched and still green after M1-T7**, which hashes nothing); (b) *60 fps on Medium map greybox*: **STILL NOT met after M1-T7** — the chunked MultiMesh renderer is now COMPLETE as a `Node`, but there is still **no `.tscn` and no camera**, and per decisions.md M1-T6 **(Z)** this criterion is **not headless-measurable at all** (the `--headless` dummy renderer stores no MultiMesh instance data and draws nothing), so it is scheduled as a **manual windowed measurement on the Medium map (radius 32 / 3,169 hexes, SDFGI off) logged in decisions.md at M1-T8** — the re-slice moved it one task later (decisions.md M1-T7 item 1); (c) *LOS property tests*: **MET headless** (M1-T3 — `tests/unit/test_los.gd`, 8 property sweeps incl. symmetry/reflexivity/all-open/adjacency/agreement/monotonicity over the 3,721 ordered pairs of the radius-4 disc, all green, and three adversarial mutation probes proved the subtlest pins load-bearing). **The milestone is therefore NOT marked done — criterion (b), the camera rig and hex picking remain.** **Deliverables built so far: HexMath COMPLETE, both slices** (`scripts/core/hex_math.gd` — slice 1: axial/cube conversion, the fixed 6-direction table, neighbours/opposites, cube distance, radius membership, hex count; slice 2 (M1-T2): exact-integer `cube_round_scaled`, `line`, `ring`, `hexes_in_range` + the private `_floor_div`); **`Los` COMPLETE** (M1-T3, `scripts/core/los.gd` — the §4.1 blocking predicate, exactly two public functions over injected terrain `Callable`s, resolutions (H)–(L)); **concentric-bowl generator COMPLETE, both slices** (M1-T4 slice 1 + M1-T5 slice 2 — `scripts/core/rng.gd`, `scripts/sim/hex_map.gd`, `scripts/sim/map_generator.gd`, `data/mapgen/concentric_bowl.json`: the hex container with its pinned canonical order and terrain-type field, the §4.4 band/terrace rules and the §4.4 composition rule all as pure integer math, the single seeded `Rng`, and `content_hash` (FNV-1a 32-bit); resolutions (M)–(U)); **chunked MultiMesh renderer COMPLETE, both slices** (M1-T6 slice 1 — `scripts/render/hex_layout.gd` + `data/render/greybox.json`: flat-top hex→world placement on the XZ plane, the axial-square chunk partition with true floor division and (O)-matching key order, and the (P)-mirroring `RulesError` load contract; resolutions (V)–(Z), 44 tests. M1-T7 slice 2 — `scripts/render/map_renderer.gd` + `data/render/terrain_palette.json`: the project's **first `Node`** (`class_name MapRenderer extends Node3D`), one `MultiMeshInstance3D` per chunk in canonical order, ONE shared hexagonal `CylinderMesh` + ONE shared `StandardMaterial3D` for the whole renderer, per-instance transforms and type/tint custom data written from `HexLayout`/`HexMap`, the in-place dirty-chunk rebuild seam M2's dig will call, and the (AF) palette load contract reusing `RulesError`; resolutions (AA)–(AH), 43 tests, six adversarial probes). Still to build: **the greybox scene + camera rig + the 60-fps measurement (M1-T8) and hex picking (M1-T9)** — no `.tscn` and no `scenes/` directory exists yet, and `project.godot` still deliberately has no `run/main_scene`. |
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
| 2026-08-04 | M1-T5 | Seeded Rng core, terrain-type composition (generator slice 2) and the project's first golden (**meets the §14 M1 "golden mapgen test" criterion; completes the generator deliverable**) | landed | M1-T5: Seeded Rng core, terrain-type composition (generator slice 2) and the project's first golden |
| 2026-08-04 | M1-T6 | HexLayout: flat-top hex-to-world placement and the deterministic chunk partition (renderer slice 1) (**opens `scripts/render/`; half of the chunked-MultiMesh-renderer deliverable**) | landed | M1-T6: HexLayout: flat-top hex-to-world placement and the deterministic chunk partition (renderer slice 1) |
| 2026-08-04 | M1-T7 | MapRenderer: chunked MultiMesh nodes, type/tint custom data and dirty-chunk rebuilds (renderer slice 2) (**the project's first `Node`; completes the chunked-MultiMesh-renderer deliverable; re-slices the scene/camera/60-fps measurement to M1-T8 and picking to M1-T9**) | landed | M1-T7: MapRenderer: chunked MultiMesh nodes, type/tint custom data and dirty-chunk rebuilds (renderer slice 2) |

## Notes for the next iteration

- **Pick up: M1-T8 = the greybox scene + CameraRig + THE 60-FPS MEASUREMENT.** M1-T7 is finished and
  the tree is green; nothing is carried over. The whole **sim** side of M1 is done and pinned
  (HexMath, Los, HexMap, MapGenerator, Rng, the golden) and the **chunked MultiMesh renderer is now
  COMPLETE** (`HexLayout` placement + partition, `MapRenderer` the Node — see both contract bullets
  below). What is left in M1: `scenes/Main.tscn` (a `MapRenderer` instanced from the scene, a
  `WorldEnvironment` with **SDFGI off** per §10 line 680), the **CameraRig**, the **manual windowed
  60-fps measurement on the Medium map** (radius 32 / 3,169 hexes) — then hex picking at **M1-T9**.
  Read §11.1's renderer/UI boundary and §11.2's directory layout before speccing, and read
  decisions.md **M1-T6 (V)–(Z)** and **M1-T7 (AA)–(AH)** in full.
  - **THE MEASUREMENT IS THE POINT OF M1-T8, not a postscript.** *"60 fps on Medium map greybox"* is
    the **last unmet §14 M1 acceptance criterion** and the one criterion that is **not headless-testable
    at all** — `--headless` has no renderer (decisions.md M1-T6 **(Z)**). It is a **MANUAL WINDOWED**
    measurement against the greybox scene with **SDFGI off** (§10 line 680), on **3,169 hexes**
    (§4.1 Medium radius 32). Plan it before writing the scene, run it, and **log the number in
    decisions.md at M1-T8 even if it is bad**. The re-slice that moved it here is decisions.md M1-T7
    item 1 — **(Z)**'s forward reference to "M1-T7" now points to M1-T8.
  - **Three carry-overs from M1-T7 that bite at M1-T8** (decisions.md M1-T7 item 13): (a)
    `MapRenderer._clear_chunks()` frees **all** children of the node, so the `.tscn` must **not** give
    the `MapRenderer` node non-chunk children — hang the camera and environment elsewhere in the
    scene; (b) `set_layout()` is effectively **once per renderer** — the shared prism mesh is sized on
    the first `build()` and is **not** resized by a later layout; (c) the **open cosmetic item**:
    whether Godot's `CylinderMesh` starts its first radial vertex at **+X** (flat-top, matching
    **(V)**) or 30° off is **not verifiable headless** and no yaw was guessed — check it **by eye** in
    the windowed run and log a yaw only if one is genuinely needed.
  - **`project.godot` still deliberately has NO `run/main_scene`.** If M1-T8 sets one, it must point
    at a scene that actually exists — a dangling path breaks `--import`, which every `tools/` script
    runs first.
  - **(Z) STILL GOVERNS EVERY RENDERER ASSERTION.** Under `--headless` the dummy renderer **does not
    store MultiMesh instance data** — `set_instance_transform` → `get_instance_transform` returns the
    **identity**, `set_instance_custom_data` reads back `(0,0,0,1)`, and `MultiMesh.buffer` is **size
    0** even at `instance_count = 3` (re-measured at M1-T7). Readable headless: `instance_count`,
    `transform_format`, `use_custom_data`, `use_colors`, `mesh != null`, resource properties,
    `get_class()`, node parenting/naming/order, `get_instance_id()`. Renderer tests stay **STRUCTURAL
    only**; an instance read-back assertion can only ever pass **vacuously**. Placement math is covered
    by `test_hex_layout.gd` — do not re-test it through a MultiMesh.
  - **Size it: ≤ ~300 LOC per slice.** Scene + camera + measurement is one task; picking is M1-T9.
  - **Write the source scans fresh for any new file.** They are per-file and inherit nothing. For a
    **sim/core** file copy `tests/unit/test_rng.gd`/`test_map_generator.gd`; for a **renderer** file
    the newest examples are `tests/unit/test_hex_layout.gd` (a pure `RefCounted` renderer helper) and
    `tests/unit/test_map_renderer.gd` (an actual `Node` — **copy this one for M1-T8**, it is the scan
    written for engine-bound code). Both **strip comment lines FIRST** (load-bearing — doc blocks
    contain `§4.1`, which naive regexes hit). **`RulesError` is explicitly ALLOWED in renderer files**
    (M1-T6 (Y)); the **no-float** scan is deliberately **NOT** applied to renderer files (geometry is
    not a §11.1 rule surface). Always keep: no map-size literal `24|32|40|1801|3169|4921`; a
    `## §<section>` doc comment on every public function (section list in a `DOC_SECTIONS` const);
    **an explicit expected public-member list** so a missing **or extra** member fails; and class-kind
    via `get_class()`, **never** `is Node` (a statically-decidable construct parse-errors and silently
    un-collects the whole file; decisions.md M0-T2 item 11 / M0-T5 item (a)) — for a Node file
    `get_class()` **names** the expected class instead of forbidding Node-ness.
  - Continue the decisions.md lettering at **(AI)** — M1-T7 ended at (AH).
  `scripts/` currently holds `sim/rules_loader.gd` + `sim/rules_error.gd` + `sim/hex_map.gd` +
  `sim/map_generator.gd`, `core/event.gd` + `core/event_bus.gd`, `core/hex_math.gd`, `core/los.gd`,
  `core/rng.gd`, `render/hex_layout.gd` and `render/map_renderer.gd`, and nothing else, deliberately
  (§13.4: invent nothing ahead of its milestone). **`MapRenderer` is the project's only `Node`; there
  is still no `.tscn`, no `scenes/` directory, no `Camera3D`, no `WorldEnvironment` and no shader**,
  and no GameState, Command, vein **node**, cave feature, river, lair or spawn code exists — nor any
  concrete `Event` subclass. Those belong to the milestones that emit them.
- **`MapRenderer` contract (`scripts/render/map_renderer.gd`, `data/render/terrain_palette.json`, NEW
  at M1-T7 — read decisions.md M1-T7 (AA)–(AH) before touching it). THE PROJECT'S FIRST `Node`**
  (`class_name MapRenderer extends Node3D`), and the boundary it opens is the standing risk: §11.1 is
  binding (`data → Sim Core (engine-free) → EventBus → Renderer/UI`, **the sim never calls the
  renderer**), engine-bound code lives **only** in `scripts/render/`, and **no source scan in
  `scripts/core/` or `scripts/sim/` may ever be weakened to make a renderer compile** — those trees
  still forbid `extends Node`/`SceneTree`/`get_tree`/`Engine.`/`Time.`/`OS.` and were left
  byte-untouched at M1-T7.
  - Public surface is **EXACTLY** `var errors: Array[RulesError]` + eight functions —
    `load_palette_text`, `load_palette_file`, `tint_for`, `set_layout`, `build`, `chunk_keys`,
    `mark_hex_dirty`, `flush_dirty` — and a source scan fails on a **missing OR extra** member. **No
    camera, no picking, no `EventBus` subscription, no shader** (§13.4). If M1-T8/M1-T9 needs a new
    public member, update the scan's expected list in the same commit.
  - **(AA)/(AE) structure and the dirty seam:** one `MultiMeshInstance3D` child per
    `HexLayout.chunk_keys()` key, **in canonical (X) order**, named `"chunk_%d_%d" % [key.x, key.y]`
    (negative keys round-trip). `mark_hex_dirty(hex)` marks `chunk_of(hex)` **only if built** (else a
    silent no-op); `flush_dirty(map)` rebuilds **only** marked chunks **IN PLACE** (same nodes, same
    `MultiMesh` objects — both pinned by `get_instance_id()`), returns keys in canonical order and
    clears the set. **This is the seam M2's dig calls** — wire the `EventBus` to it *there*, not here.
  - **(AD) ONE shared `CylinderMesh` + ONE shared `StandardMaterial3D` for the whole renderer** — the
    pin that makes a 3,169-hex Medium map viable; probe P3 showed **exactly one test** stands between
    the project and 1,801 mesh allocations, so never "simplify" it away. Geometry comes from
    `data/render/greybox.json` **via `HexLayout`** (`hex_width_m()/2.0`, `elevation_step_m()`); only
    `RADIAL_SEGMENTS = 6` is a code const (mathematical — a hexagon has six sides; the `SQRT_3`/FNV
    precedent). The material rides on `PrimitiveMesh.material`, not a `material_override`.
  - **NEVER `queue_free()` a chunk node** — it defers to the next frame while GUT asserts
    **synchronously**, so a rebuild appears to **double** the children. Use `remove_child(child)` then
    `child.free()`. This is now a standing rule for **every** Node file in this project; `queue_free(`
    is a forbidden token in the scan and probe P1 catches it behaviourally.
  - **MultiMesh FORMAT MUST BE SET BEFORE `instance_count`** (measured): assigning the count first
    makes the engine refuse both toggles — *"Instance count must be 0 to change the transform format"*
    / *"… to toggle whether custom data is used"* — and every later
    `set_instance_transform`/`set_instance_custom_data` then errors too. `transform_format` defaults to
    **`TRANSFORM_2D`**, and `use_custom_data`/`use_colors` default to **false**.
  - **(AB) totality:** `build()` draws only with a configured layout **AND** a loaded palette **AND** a
    non-null map with `hex_count() > 0`; otherwise zero children, empty `chunk_keys()`, empty
    `flush_dirty()`. **Any** palette error leaves the palette **UNLOADED** (including a failed load
    after a successful one), and *unloaded* means `tint_for(anything) == Color(0,0,0,1)` — the **black
    sentinel**, deliberately distinct from the loaded fallback grey, so a failed load never
    masquerades as working greybox art.
  - **(AF) the palette loader mirrors `MapGenerator`'s (P) and `HexLayout`'s (Y) exactly and REUSES
    `RulesError`** — line 0 reserved for missing/unreadable files, schema errors on the top-level key's
    own 1-based line (fallback 1), row errors attributed to the `tints` line, error order from the
    loader's **declared** key-spec order (`fallback_rgb` → `tints`) and never the parsed Dictionary's,
    unknown extra top-level keys load clean, integral floats accepted / fractional rejected / never
    truncated.
  - **`data/render/terrain_palette.json` is CONTENT and its formatting is load-bearing** (line 1 a lone
    `{`, one top-level key per line, like `ruleset.json`/`greybox.json`): `"id": "greybox_terrain"`,
    `fallback_rgb [128,128,128]`, and all **nine** §4.2 Solid tints — including `artificial_granite`
    and `rubble`, which the generator never emits. It is a **separate file** precisely because
    `test_hex_layout.gd` asserts `greybox.json` **byte-for-byte**. **There is NO terrain-type whitelist
    in engine code** (all nine ids are forbidden tokens in `map_renderer.gd`); §4.2's vocabulary is
    pinned **by test**, plus a **cross-file coverage property** that reds if a future
    `concentric_bowl.json` composition type has no palette entry. Data-drivenness is proven **by
    mutation**, not by a token scan.
  - **(AC)** per-instance transform (`hex_to_world`, identity basis, MapRenderer-local space) and
    custom data (`tint_for(terrain_type)`, **alpha 1.0 reserved for M3's §10 line 679 Lit/Dark
    shader**) are **written, never read back** — (Z) makes a read-back vacuous, so the scan requires the
    literal `set_instance_transform(`/`set_instance_custom_data(` tokens instead. **(AH)** at M1 every
    in-bounds hex is drawn as solid rock; **cave culling arrives with M2's dig**.
  - **Two known, deliberately unfixed observations** (decisions.md M1-T7 item 13): `const SPEC_KEYS` is
    declared but unreferenced (documentation only — the order comes from the fixed
    `_validate_fallback` → `_validate_tints` call sequence), and `_ensure_resources()` allocates the
    shared mesh once per renderer lifetime.
- **`HexLayout` contract (`scripts/render/hex_layout.gd`, `data/render/greybox.json`, NEW at M1-T6 —
  read decisions.md M1-T6 (V)–(Z) before touching it). The FIRST file in `scripts/render/`, and still
  a pure `RefCounted`** (`class_name HexLayout extends RefCounted`) — it holds no Node, builds no
  mesh, creates no MultiMesh, and names **no** sim class (`HexMap`/`MapGenerator`/`Rng` are all
  forbidden tokens in its scan). It operates on an `Array[Vector2i]` handed to it by its caller; that
  decoupling is what makes it fully unit-testable headless, which matters because of (Z).
  - Public surface is **EXACTLY** `var errors: Array[RulesError]` + nine functions —
    `load_params_text`, `load_params_file`, `hex_width_m`, `elevation_step_m`, `chunk_hexes`,
    `hex_to_world`, `chunk_of`, `chunk_keys`, `partition` — and a source scan fails on a **missing OR
    extra** member. Privates: `_floor_div`, `_is_integral`, `_as_float`, `_add_error`, `_line_for_key`,
    `_clear_configuration`, `_chunk_less`. **If a later task needs a new public member, the scan's
    expected list must be updated in the same commit.** `MapRenderer` (M1-T7) is its first consumer and
    needed nothing added.
  - **(W) the formula:** XZ ground plane, **+Y up**, hex `(0,0)` at the **world origin**,
    `R = hex_width_m / 2`; `world.x = 1.5*R*q`, `world.z = SQRT_3*R*(r + 0.5*q)`,
    `world.y = elevation * elevation_step_m`. `SQRT_3 = 1.7320508075688772` is a **named const in the
    `.gd`** — a mathematical constant, the M1-T5 item 7 precedent, **not** a §13.6 violation.
  - **(V) FLAT-TOP, and the thing that looks like a bug and is not:** §4.1 index 0 is named **"E"**
    but under flat-top it points **30° off +X toward +Z**; index 2 `(0,-1)` and index 5 `(0,+1)` are
    the ones running straight along −Z/+Z. The six names are **INDEX LABELS ONLY** (M1-T1 (A)) —
    **never reorder or rename the direction table** to "fix" this; every sim value keys off it.
    **Probe P1 is the one to remember: swapping to pointy-top leaves the all-six-neighbours-equidistant
    property GREEN** — only the per-direction discriminator (dir 2/dir 5 have `world.x` **exactly
    0.0**; dir 0 has both components non-zero) catches it. Never fold that test into the equidistance
    sweep.
  - **(X) chunks are axial squares of `chunk_hexes` edge** with a **TRUE floor division** — GDScript's
    `int/int` truncates toward zero and would merge the four chunks around the origin into one 15×15
    super-chunk (probe P2). `chunk_keys()` is **distinct and sorted chunk-r (y) then chunk-q (x)**,
    matching `HexMap`'s (O) canonical order (probe P4 pins that specific order, not merely "sorted");
    `partition()` returns `Array[PackedInt32Array]` **parallel to `chunk_keys()`**, buckets holding
    **indices into the input array, in input order**. A `Dictionary` is used **only** as a local dedup
    set — no `Dictionary` iteration ever reaches an output (§11.1). Probe P3: only the **shuffled-input
    oracle** catches an order slip.
  - **(Y) load contract mirrors `MapGenerator`'s (P) exactly and REUSES `RulesError`** — do not invent
    a second error type. Line 0 stays reserved for missing/unreadable files; schema errors carry the
    key's own 1-based line (fallback 1); error order is the loader's **declared key-spec order**
    (`hex_width_m` → `elevation_step_m` → `chunk_hexes`), never the parsed Dictionary's; unknown keys
    load clean (the shipped `"id"` is one); **any error leaves the layout UNCONFIGURED**, including a
    failed load after a successful one (probe P6). `chunk_hexes` is an **INT** leaf (integral float
    `8.0` accepted, `8.5` rejected, never truncated); the other two are **FLOAT** leaves; all three
    must be **strictly positive**.
  - **The three tunables are CONTENT, and the `.gd` may not contain them as literals:**
    `data/render/greybox.json` = `{"id": "greybox", "hex_width_m": 18, "elevation_step_m": 3,
    "chunk_hexes": 8}`. **`hex_width_m` 18 sits inside §1.2's printed "≈ 15–20 m" range** (asserted
    both ways); `elevation_step_m` 3 and `chunk_hexes` 8 have **no printed GDD counterpart** and are
    entirely new tunable content. Its formatting is **load-bearing** (line 1 a lone `{`, one key per
    line) exactly like `ruleset.json` — re-pretty-printing it nested breaks the line-attribution
    tests. Mutate-the-params-in-text tests prove all three are genuinely read from data.
- **`Rng` contract (`scripts/core/rng.gd`, NEW at M1-T5 — read decisions.md M1-T5 (R) before
  touching it).** `class_name Rng extends RefCounted`. **This file is the SINGLE place in the entire
  project allowed to name `RandomNumberGenerator`**, and that is enforced *negatively* by a token
  scan in every sibling test file (`test_hex_map.gd`, `test_map_generator.gd` both list
  `RandomNumberGenerator` in `ENGINE_BOUND_TOKENS`) and *positively* by `tests/unit/test_rng.gd`
  (which requires `RandomNumberGenerator` **and** `randi_range(` to be present, while `randi(`,
  `randf(` and `randomize(` stay forbidden even there). **Add the same negative token to the scan of
  every new sim/core file you write.**
  - Public surface is **exactly** `roll_percent() -> int` (1..100 inclusive) and
    `rolls_drawn() -> int`, **no public vars** — a missing *or extra* member fails the scan.
  - `_init(seed_value: int)` **assigns `_rng.seed` explicitly**; a default-constructed
    `RandomNumberGenerator` is **randomly seeded** and `randomize()` is never called. The parameter
    **must not be named `seed`** — GDScript's global `seed()` makes that `shadowed_global_identifier`,
    level 2 = a hard error under the M0-T4 gate.
  - **Integer path only**: `randi_range(1, 100)`. `randf`/`randf_range` are forbidden — a float in a
    rule breaks §11.1's byte-identical determinism.
  - **When `GameState` lands, `state.rng` is an `Rng`** — do not introduce a second RNG, and do not
    let any rule construct its own.
- **The GOLDEN contract (`tests/golden/`, LIVE from M1-T5 — §13.6 now applies FOREVER).**
  `mapgen_concentric_bowl_small_seed1337.json` records the run *and* the hash: `generator`,
  `size_id "small"`, `radius 24`, `seed 1337`, `hex_count 1801`, `content_hash "0xcad24923"` — the
  hash as a **lowercase 8-hex-digit STRING**, never a JSON number (Godot 4.7 parses every JSON number
  as `TYPE_FLOAT`).
  - **A golden may be re-recorded ONLY with a dated `docs/decisions.md` reason in the SAME commit.**
    `tests/golden/test_mapgen_golden.gd` **fails loudly when the file is absent and never
    auto-records**; its failure message prints the recorded and observed hashes, the exact document
    to write, and that rule verbatim — **the failure message IS the recording procedure**. Never add
    a "record mode" flag.
  - **HARNESS TRAP, found live and now a standing rule for every test author:**
    `tools/run_tests.sh`'s refusal grep scans the **whole run output** for `Nothing was run` /
    `does not exist` / `have not been imported` / `Failed to load script` / `Ignoring script`. A test
    **failure message** containing any of those five phrases makes the runner exit 1 with "GUT
    reported a diagnostic …" even though GUT ran everything correctly. The golden's message therefore
    says *"is MISSING"*, not *"does not exist"*. **Never put those phrases in a failure message; never
    weaken the harness to accommodate one.**
  - What the golden hashes is `HexMap.content_hash()` — **FNV-1a 32-bit** (basis `2166136261`, prime
    `16777619`, every step masked `& 0xffffffff`) over `hexes()` in the (O) canonical order: `radius`
    once, then per hex `x`, `y`, `elevation` as 4 little-endian bytes each, the type id's UTF-8 bytes,
    then separator `0x1f`. It is `content_hash`, **not** `hash` — overriding `Object.hash()` trips
    `native_method_override` (level 2 = error). The FNV constants are **hash-algorithm** constants and
    correctly live as `const` in `.gd`, not in `data/` (decisions.md M1-T5 item 7) — do not "fix" that
    as a §13.6 violation. `_fold_int` computes `shift = 8 * byte_index` rather than a literal
    `[0, 8, 16, 24]` array purely because the bare `24` would trip the map-size token scan.
- **`HexMap` + `MapGenerator` contract (`scripts/sim/hex_map.gd`, `scripts/sim/map_generator.gd`,
  `data/mapgen/concentric_bowl.json` — **COMPLETE, both slices**, as of M1-T5; read decisions.md
  M1-T4 (M)–(Q) and M1-T5 (S)–(U) before extending them).** Both are `class_name … extends
  RefCounted`, **instantiable** (unlike `HexMath`/`Los`, which are all-static). Public surfaces are
  **exact and mechanically scanned** — a missing *or extra* member fails: `HexMap` = `radius` +
  `hex_count`, `is_in_bounds`, `index_of`, `hexes`, `get_elevation`, `set_elevation`,
  `get_terrain_type`, `set_terrain_type`, `content_hash`; `MapGenerator` = `errors` +
  `load_params_text`, `load_params_file`, `radius_for_size`, `band_count`, `band_id`,
  `band_index_at`, `elevation_at`, `terrain_type_at`, `generate`.
  - **(O) `HexMap` storage and CANONICAL ORDER — THE GOLDEN NOW HASHES THIS, so changing it is a
    golden re-record and therefore a logged event forever.** One `PackedInt32Array` (elevation) plus
    one `PackedStringArray` (terrain type, added at M1-T5) over the **same** axial bounding-square
    index `(r + radius) * (2 * radius + 1) + (q + radius)`; **no `Dictionary` anywhere**, and **no
    band array** (band stays derivable from distance and is therefore not state). Membership is
    `HexMath.distance(Vector2i.ZERO, hex) <= radius`, never a second bounds formula. Canonical order
    is **`r` ascending `-R..+R`, then `q` ascending within each `r`**, and `index_of` is strictly
    increasing along it (that assertion is what catches a q/r-swapped index — proven live by probe).
    `hexes()` returns a **fresh** `Array[Vector2i]` every call (M1-T2 trap 1, now re-pinned in its
    third file). Every accessor is **total**: off-disc `get_elevation` → `-1`, `get_terrain_type` →
    `""`, `index_of` → `-1`, `set_elevation`/`set_terrain_type` → silent no-op, `is_in_bounds` →
    false; negative radius → `hex_count() == 0` and empty `hexes()`. A fresh map reads `""` on every
    in-bounds hex, and the two arrays never alias.
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
  - **(S) COMPOSITION RULE + (T) the shipped weights — how a hex gets its TYPE (M1-T5).** Each band
    in `data/mapgen/concentric_bowl.json`'s `"composition"` carries an **ordered** list of
    `{type, pct}` rows summing to **exactly 100**. `terrain_type_at(band_index, roll)` walks them
    **in listed order** accumulating `pct` and returns the first row with **`roll <= cumulative`** —
    pure integer math, no division, and **no RNG inside the rule**, which is what makes the
    exhaustive 300-roll boundary sweep possible. `generate(map_radius, rng)` draws **exactly one**
    `rng.roll_percent()` per hex, **unconditionally and before any branch**, in the (O) canonical
    order, so the stream position is a function of the hex index **alone**; `null` rng or an
    unconfigured generator → empty map and **zero** rolls. **Probe B is the one to remember: a
    REVERSED roll order keeps confinement, distribution, determinism *and* the roll count green — the
    canonical-order oracle in `test_map_generator.gd` is the only pin that catches it. Never
    "simplify" it away.**
  - **Only FOUR composition numbers are printed in §4.4** (rim 70 soft_dirt / 20 hard_rock, mantle
    55 hard_rock / 15 dense_granite) plus the **ordinal** *"Granite-dominant"* for the Core; those are
    transcribed verbatim and the ordinal is satisfied strictly. Everything else (rim iron/gold 5+5,
    mantle magestone 5 + soft_dirt 25, core 70/25/5) is **new tunable content**, not a GDD value.
    **There is NO terrain-type whitelist anywhere in engine code** (EventBus resolution (f)
    precedent) — ids are opaque strings to the generator, so §4.2's nine-id vocabulary,
    `mithril_seam`'s *"Deep Core only"* confinement and the `artificial_granite`/`rubble` exclusion
    are pinned **BY TEST**. Do not add an enum or a `const` list of types to `.gd`.
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
  - **The `"composition"` group obeys the same load contract**, validated by `_validate_composition`
    **after** `_validate_bands` and matched against the **LOCAL** band-id list, never a committed
    parallel array (this is how M1-T4 item 13(a)'s latent trap was avoided). All errors are collected
    at the `"composition"` line: missing key, non-array, non-object entry, unknown band, band with no
    entry, duplicate band, weights not summing to 100, a **fractional** pct (integral floats are
    accepted, fractional ones rejected, never truncated), a non-string/empty type id, an empty
    weights array. A dropped band id in a `"bands"` fixture produces **cascading** composition errors
    — harmless and deliberate (decisions.md M1-T5 item 10).
  - **Remaining non-blocking trap from M1-T4 item 13** (still open, still unreachable from shipped
    data): (b) `_validate_terraces` accepts an empty `terraces` table and one whose innermost
    `from_share_pct` is not 0. Trap (a) — parallel arrays half-appended on a bad id — was **heeded at
    M1-T5** and is still latent-only, because every validator writes into locals and commits only
    when `errors.is_empty()`.
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
- **CURRENT SUITE STATE IS GREEN.** `bash tools/run_tests.sh` → **exit 0** at **Scripts 15 /
  Tests 321 / Passing 321 / Failing 0 / Asserts 3380** (re-measured at Land, 2026-08-04, M1-T7).
  `Scripts 15` equals the number of `test_*.gd` on disk, so nothing is silently skipped;
  `bash tools/typecheck.sh` exits **0** over 26 files; `bash tools/ci.sh` exits 0 (PASS with the
  three documented M7/E4/E5 skips) and `bash tools/verify_harness.sh` exits 0. Prior green baselines,
  for reference: M1-T6's 14 / 278 / 278 / 2760, M1-T5's 13 / 234 / 234 / 2268, M1-T4's
  11 / 183 / 183 / 1879, M1-T3's
  9 / 129 / 129 / 1308, M1-T2's 8 / 106 / 106 / 1023, M1-T1's 8 / 86 / 86 / 835, and
  7 / 62 / 62 / 473 at the close of M0 (the M0 tracker row above deliberately keeps that historical
  figure). **Expect these totals to RISE as you add tests — they are enumerated, not hard-coded.**
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 on a healthy tree, and
  `bash tools/typecheck.sh` → exit 0 over **26** project `.gd` files, and
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
- **Golden discipline is now LIVE, not upcoming.** `tests/golden/` holds the project's first golden
  as of M1-T5 (`mapgen_concentric_bowl_small_seed1337.json`, `content_hash 0xcad24923`), and §13.6
  applies **forever**: a golden may be re-recorded **only** with a dated `docs/decisions.md` reason in
  the *same commit*. The full contract — file format, the never-auto-record rule, the FNV fold, and
  the harness phrase trap — is in the **GOLDEN contract** bullet above; read it before you touch
  `HexMap`'s storage, its canonical order, `content_hash`, the composition table or the shipped
  `data/mapgen/concentric_bowl.json`, because **any** of those changes the hash.
- **Adversarial mutation probes are now standing practice at Verify** (M1-T1 item 8 → M1-T7 item 12,
  seven iterations running). Before declaring green, break the implementation on purpose — capture the
  file md5, mutate, run, restore, re-verify byte-identical — and **record what went red**. A property
  test that has never been observed failing is indistinguishable from one that cannot fail. M1-T4's
  yield: the terrace `>` vs `>=` slip is invisible except at exact-multiple radii, and a q/r-swapped
  canonical order is caught only by the `index_of`-monotonicity assertion. **M1-T5's yield is
  sharper still:** a **reversed RNG stream** leaves confinement, distribution, determinism *and* the
  roll count green — only the canonical-order oracle and the golden catch it; and deleting the golden
  file proved the golden test fails loudly rather than silently re-recording itself. Neither would
  have been trusted on inspection alone. **M1-T6's yield (six probes, three of them added at Verify
  rather than inherited from the spec): swapping the renderer to POINTY-TOP leaves the
  all-six-neighbours-equidistant property GREEN** — equidistance cannot distinguish the two
  orientations, so only a per-direction discriminator pins flat-top; a chunk-key sort of
  chunk-q-then-chunk-r instead of chunk-r-then-chunk-q reds only 2 tests, so "sorted somehow" is a
  strictly weaker property than what is implemented; and **Verify adding its own probes beyond the
  spec's list is now the expectation, not a bonus** — P4/P5/P6 each found a pin that no inherited
  probe exercised. **M1-T7's yield (six probes, all red on demand, file md5 restored byte-identical
  each time): the resource-sharing pin is SURGICALLY NARROW** — allocating a fresh `CylinderMesh` per
  chunk reds **exactly one** test (`test_all_chunks_share_one_prism_mesh_and_one_material`), and that
  one test is all that stands between the project and 1,801 mesh allocations on a Small map, so it
  must never be folded into a broader assertion; **`queue_free()` instead of `remove_child()+free()`
  makes a same-frame rebuild appear to DOUBLE the children** (GUT asserts synchronously, `queue_free`
  defers a frame) — a failure mode that reads as a logic bug and is caught only by the same-frame
  idempotence test; and **assigning `instance_count` before the MultiMesh format makes the engine
  silently REFUSE the format toggles** (*"Instance count must be 0 to change the transform format"*),
  after which every per-instance write errors too.
