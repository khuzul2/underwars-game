# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** **M2 — Dig & Economy is IN PROGRESS (opened 2026-08-04 by M2-T1).** **M2 is NOT
  done:** M2-T1 landed only the §11.1 state container (`GameState`, `PlayerState`, the shared `Fnv`
  fold) plus the §12.1 `dig_yields.artificial_granite` amendment that closed the M0-T2 item-10
  forward gap. **None of §14's three M2 acceptance criteria is met** — *"Scripted 20-turn dig
  scenario matches expected stockpiles exactly"*, *"deficit-bleed test"* and *"zone assigns nearest
  idle worker"* all need systems that do not exist yet — and of the §14 M2 deliverable list
  (*"Workers, Dig/Cancel commands, yields, vein nodes + Extractors, stockpiles/income/upkeep,
  housing, Mining Zones v0"*) only the **stockpiles** half of one item is built. There is still **no
  `Command`, no `CommandError`, no concrete `Event` subclass, no turn counter, no worker, no dig, no
  vein node, no Extractor, no income/upkeep, no housing and no zone** — every one is named as
  deliberately deferred in decisions.md **(AU)** item 8 and in the new files' headers.
- **Milestone:** **M1 — World is DONE (closed 2026-08-04 by M1-T9).** M0 — Bootstrap is **DONE**
  (closed by M0-T5): every §14 M0 deliverable is built (Godot project, GUT wired, `run_tests.sh`,
  EventBus, RulesLoader + `ruleset.json`, CI script, `decisions.md`), **both** §14 acceptance clauses
  pass headless, and the signal that reports clause (a) is itself proven against the false-green mode
  M0-T4 measured. **M1 closes because BOTH halves are now satisfied — the deliverable list AND the
  acceptance criteria** (a milestone closes only when both do). Its §14 row (line 1097) lists five
  deliverables and **all five are built**: **HexMath** (M1-T1/M1-T2, both slices, plus `Los`), the
  **concentric-bowl generator** (M1-T4 + M1-T5 — `HexMap` + the §4.4 band/elevation bowl, then the
  seeded `Rng`, the §4.4 terrain-type composition, `content_hash` and the first golden), the
  **chunked MultiMesh renderer** (M1-T6 + M1-T7 — `HexLayout`'s flat-top hex→world placement + the
  deterministic chunk partition; then `MapRenderer`, the project's **first `Node`**: one
  `MultiMeshInstance3D` per chunk, shared prism mesh + material, per-instance type/tint custom data
  and the dirty-chunk rebuild seam, plus `data/render/terrain_palette.json`), the **camera rig**
  (M1-T8, together with the project's **first scene** `scenes/Main.tscn`, `GreyboxBoot`,
  `data/render/camera.json` and **THE MEASUREMENT**), and — **as of M1-T9 — hex picking**
  (`scripts/render/hex_picker.gd`: the inverse of (W), a ray/plane intersector, the
  elevation-layered top-down pick and one thin `Camera3D` adapter). **ALL THREE §14 M1 acceptance
  criteria PASS — re-checked against the §14 row (line 1097) this iteration** — *"Golden mapgen test
  (seed ⇒ terrain hash)"* (M1-T5, green headless), *"LOS property tests"* (M1-T3, green headless)
  and *"60 fps on Medium map greybox"* (M1-T8, measured windowed — per (Z) it is not
  headless-measurable at all).
- **THE MEASUREMENT (M1-T8, decisions.md M1-T8 items in the header + (AO)) — logged, MET, and not
  re-openable by a later "optimisation" without a fresh number.** Windowed (per M1-T6 **(Z)** it is
  **not headless-measurable at all**), unattended, run twice on the repo-local pinned binary:
  `./godot/Godot_v4.7-stable_win64_console.exe --path . --resolution 1600x900`. Subject: `Main.tscn`
  at boot defaults — **hexes=3169** (Medium, radius 32) · **chunks=65** · **SDFGI off** · 1600×900 ·
  auto-orbiting. **Default (vsync on, 144 Hz panel): `fps_min=144.00 fps_avg=144.00 fps_max=144.00`
  in both runs. Uncapped (`--disable-vsync`): 236 / 357 / 395 / 608 fps** — every uncapped run ≥ 236,
  i.e. ≥ 3.9× the 60-fps target. Machine: Intel Core i7-14700HX · RTX 4070 Laptop (driver
  32.0.15.9282) · 64 GB · Windows 11 · Vulkan 1.4.325 Forward+. **Caveat that travels with the
  number:** at §9.1's widest legal framing (zoom 60 m, pitch 80°) only **8–9 of the 65 chunks** are in
  frustum, and with `hex_width_m` 18 the Medium map is ≈1150 m across, so the **whole** map cannot be
  framed inside §9.1's 60 m ceiling — the figure is honest for the view §9.1 permits, not for all 65
  chunks at once. The ceiling was **not** widened; the criterion was **not** reinterpreted.
- **Next task:** **M2-T2 — THE COMMAND SPINE (§11.1).** M2-T1 built the state container the spine
  hangs on; the spine itself is the next slice and it is **explicitly named in decisions.md (AU)
  item 8** as this task's deferral. §11.1 is binding: *every* `GameState` mutation flows through a
  **Command** with `validate(state) -> Error?` and `apply(state) -> Array[Event]`, a match is fully
  described by `(seed, command_log)`, and every state change emits an `Event` on the `EventBus`
  (which exists since M0-T3 and **has never had a concrete `Event` subclass**). Suggested slice:
  the `Command` base class + `CommandError` (mirroring `RulesError`'s shape — do **not** invent a
  second error vocabulary without a logged reason) + the **first real Command and the first
  concrete `Event`**, wired so `(seed, command_log)` replays to an identical
  `GameState.content_hash()`. Keep it ≤ ~300 LOC of production change; turn/current-player counters
  and §3.1's starting kit are still deferred (the kit needs its **own new §12.1 key and therefore
  its own §12.1 amendment**, exactly like M2-T1's `dig_yields` edit). **Continue the decisions.md
  lettering at (AV)** — M2-T1 used **(AU)** as a single umbrella resolution with eight numbered
  sub-items, and that letter is cross-referenced by `scripts/core/fnv.gd`,
  `scripts/sim/player_state.gd`, `scripts/sim/game_state.gd` and all three new test files, so **do
  not renumber it**.
- **Blockers:** **none.** `bash tools/run_tests.sh` exits **0** at Scripts 21 / Tests 503 /
  **Passing 503** / Failing 0 / Asserts 5646; `bash tools/typecheck.sh` exits 0 over 38 files;
  `bash tools/ci.sh` exits 0 (PASS); `bash tools/verify_harness.sh` exits 0 across all four phases
  with the tree left clean (all four measured at Verify; `run_tests.sh` and `typecheck.sh`
  re-measured independently at Land, 2026-08-04, M2-T1).

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **DONE** (2026-08-04, M0-T5) | **BOTH §14 acceptance clauses MET headless, checked against the §14 row this iteration** — (a) *sentinel suite green AND a deliberately failing sentinel makes `run_tests.sh` exit non-zero* (SETUP-2 amendment): `verify_harness.sh` exit 0 with **four** phases — A green, B failing canary, C syntactic parse error, D statically-impossible construct — each red phase non-zero **and naming its probe**, tree clean afterwards; (b) *invalid ruleset rejected with a line-numbered error*: pinned by `tests/unit/test_rules_loader.gd`, suite exit 0 at **Scripts 7 / Tests 62 / Passing 62 / Asserts 473** with the collected-script count equal to the `test_*.gd` count on disk. **ALL §14 M0 deliverables built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate), `decisions.md`. M0-T5 closed the last open item: the false-green mode *inside* the signal that reports clause (a) (decisions.md M0-T5, correcting M0-T4 item (i)). |
| M1 World | **DONE** (opened 2026-08-04 by M1-T1; **closed 2026-08-04 by M1-T9**) | **ALL 3 of 3 §14 M1 acceptance criteria MET *and* ALL 5 of 5 §14 M1 deliverables BUILT — both re-checked against the §14 row (line 1097) at Land this iteration** — (a) *golden mapgen test (seed ⇒ terrain hash)*: **MET headless** (M1-T5 — `tests/golden/test_mapgen_golden.gd` + `tests/golden/mapgen_concentric_bowl_small_seed1337.json`, radius 24 / 1,801 hexes / seed 1337 ⇒ `content_hash` `0xcad24923`, the value measured three times independently; the test fails loudly and never auto-records when the file is absent, and six adversarial probes incl. a reversed roll stream and a perturbation of the shipped data all went red on demand; **untouched and still green after M1-T8**, which hashes nothing and moves neither `HexMap` storage nor the canonical order); (b) *60 fps on Medium map greybox*: **MET as of M1-T8** — measured **windowed** (per decisions.md M1-T6 **(Z)** it is **not headless-measurable at all**: the `--headless` dummy renderer stores no MultiMesh instance data and draws nothing), unattended, **twice**, on `scenes/Main.tscn` at boot defaults — **hexes=3169** (Medium, radius 32) / **chunks=65** / **SDFGI off** / 1600×900 / auto-orbiting: **`fps_min=144.00 fps_avg=144.00 fps_max=144.00` in both vsync-capped runs (144 Hz panel), and 236 / 357 / 395 / 608 fps uncapped** on an i7-14700HX + RTX 4070 Laptop. Logged in full at decisions.md M1-T8 **with its caveat** (at §9.1's widest legal framing only 8–9 of the 65 chunks are in frustum; the whole ≈1150 m map cannot be framed inside §9.1's 60 m zoom ceiling, which was **not** widened); (c) *LOS property tests*: **MET headless** (M1-T3 — `tests/unit/test_los.gd`, 8 property sweeps incl. symmetry/reflexivity/all-open/adjacency/agreement/monotonicity over the 3,721 ordered pairs of the radius-4 disc, all green, and three adversarial mutation probes proved the subtlest pins load-bearing). **The milestone is MARKED DONE as of M1-T9: §14 M1's five deliverables are all built and its three acceptance criteria all pass headless** (criterion (b) measured windowed, because per **(Z)** it is not headless-measurable at all). A milestone closes only when its deliverables **and** its acceptance criteria are both satisfied — as of this commit both are. **Deliverables built: HexMath COMPLETE, both slices** (`scripts/core/hex_math.gd` — slice 1: axial/cube conversion, the fixed 6-direction table, neighbours/opposites, cube distance, radius membership, hex count; slice 2 (M1-T2): exact-integer `cube_round_scaled`, `line`, `ring`, `hexes_in_range` + the private `_floor_div`); **`Los` COMPLETE** (M1-T3, `scripts/core/los.gd` — the §4.1 blocking predicate, exactly two public functions over injected terrain `Callable`s, resolutions (H)–(L)); **concentric-bowl generator COMPLETE, both slices** (M1-T4 slice 1 + M1-T5 slice 2 — `scripts/core/rng.gd`, `scripts/sim/hex_map.gd`, `scripts/sim/map_generator.gd`, `data/mapgen/concentric_bowl.json`: the hex container with its pinned canonical order and terrain-type field, the §4.4 band/terrace rules and the §4.4 composition rule all as pure integer math, the single seeded `Rng`, and `content_hash` (FNV-1a 32-bit); resolutions (M)–(U)); **chunked MultiMesh renderer COMPLETE, both slices** (M1-T6 slice 1 — `scripts/render/hex_layout.gd` + `data/render/greybox.json`: flat-top hex→world placement on the XZ plane, the axial-square chunk partition with true floor division and (O)-matching key order, and the (P)-mirroring `RulesError` load contract; resolutions (V)–(Z), 44 tests. M1-T7 slice 2 — `scripts/render/map_renderer.gd` + `data/render/terrain_palette.json`: the project's **first `Node`** (`class_name MapRenderer extends Node3D`), one `MultiMeshInstance3D` per chunk in canonical order, ONE shared hexagonal `CylinderMesh` + ONE shared `StandardMaterial3D` for the whole renderer, per-instance transforms and type/tint custom data written from `HexLayout`/`HexMap`, the in-place dirty-chunk rebuild seam M2's dig will call, and the (AF) palette load contract reusing `RulesError`; resolutions (AA)–(AH), 43 tests, six adversarial probes). **camera rig COMPLETE, plus the project's first scene** (M1-T8 — `scripts/render/camera_rig.gd` + `data/render/camera.json`: the §9.1 orbiting rig with yaw **wrapping** into [0,360), pitch/zoom **clamping inclusively** to the printed 15–80° / 8–60 m bands read from data, the derived `looking_at` transform, camera-relative ground pan, the (AL) `RulesError` load contract and a thin WASD/Q-E/R-F/wheel/edge-pan input layer; `scripts/render/greybox_boot.gd` + `scenes/Main.tscn` — the project's **FIRST scene**, `run/main_scene` now set, `WorldEnvironment` with **SDFGI explicitly off**, a lit `DirectionalLight3D`; and the **flat-top correction yaw** in `MapRenderer` that M1-T7 item 16 owed; resolutions (AI)–(AP), 67 tests, seven adversarial probes). **hex picking COMPLETE — the last deliverable, and the one that CLOSES M1** (M1-T9 — `scripts/render/hex_picker.gd`, a pure `RefCounted` with **exactly five public functions and zero public vars**: the (AR) algebraic inverse of (W) reusing `HexMath.cube_round_scaled` for the cube repair, the (AS) ray/plane intersector, the (AQ) elevation-layered pick scanned **top-down** with an explicit empty-Array "no hex", and the thin `pick_from_screen` `Camera3D` adapter; resolutions (AQ)–(AT), 37 tests, thirteen adversarial probes of which **two found weak TESTS rather than weak code** and were fixed at Verify). |
| M2 Dig & Economy | **in progress** (opened 2026-08-04 by M2-T1) | **0 of 3 §14 M2 acceptance criteria met — the milestone is NOT done, and this row was checked against the §14 M2 row at Land.** (a) *"Scripted 20-turn dig scenario matches expected stockpiles exactly"* — **NOT met**: there is no turn, no worker, no dig and no Command, so nothing can be scripted yet; the *stockpile* half of the fixture now exists (`PlayerState`, per-player 64-bit integers, §5.1 *"No storage caps"*). (b) *"deficit-bleed test"* — **NOT met**: §3.4 step 2's *"every unpaid unit loses 10% max HP this turn"* needs units and upkeep, neither of which exists; what M2-T1 **did** pin is the half of §3.4 step 2 that constrains the stockpile — `spend` refuses **atomically** rather than going negative, because a shortage is paid in HP (decisions.md **(AU)** item 2). (c) *"zone assigns nearest idle worker"* — **NOT met**: no zones, no workers. **Deliverables built so far, of the §14 M2 list** (*"Workers, Dig/Cancel commands, yields, vein nodes + Extractors, stockpiles/income/upkeep, housing, Mining Zones v0"*): **stockpiles only** — `scripts/sim/player_state.gd` (opaque §5.1 resource ids, atomic non-negative `spend`, zero entries removed, ascending-id canonical order, 64-bit amounts) and `scripts/sim/game_state.gd` (§11.1's single serializable state: map + index-stable player roster + **the ONE** `state.rng`, with a reproducible `content_hash`) on the shared `scripts/core/fnv.gd` FNV-1a fold. Also landed: the **§12.1 `dig_yields.artificial_granite` amendment** (value **2**, governed by §4.2's `Artificial Granite \| 3 (owner: 1) \| \+2 Stone` row) — the M0-T2 item-10 forward gap, now closed in `data/ruleset.json` as a **required, line-numbered-validated** leaf **and** in the §12.1 table cell itself (decisions.md **(AU)** item 1; the one sanctioned GDD edit, made by Land in the M2-T1 commit). **Not built, deliberately (§13.4, decisions.md (AU) item 8):** `Command`, `CommandError`, every concrete `Event` subclass, turn/current-player counters, workers, dig progress, yield application, vein nodes, Extractors, income, upkeep, housing, Mining Zones, and §3.1's starting kit (which needs its own §12.1 key and amendment). |
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
| 2026-08-04 | M1-T8 | Greybox Main scene, CameraRig and the Medium-map 60 fps measurement (**the project's first `.tscn`; completes the camera-rig deliverable; MEETS the last §14 M1 acceptance criterion — 144/144/144 vsync-capped, ≥236 fps uncapped on 3,169 hexes / 65 chunks with SDFGI off; also resolves M1-T7's open flat-top `CylinderMesh` yaw**) | landed | M1-T8: Greybox Main scene, CameraRig and the Medium-map 60 fps measurement |
| 2026-08-04 | M1-T9 | HexPicker: ray-to-hex picking over elevation planes (**completes the LAST §14 M1 deliverable and CLOSES M1 — all five deliverables built, all three acceptance criteria met**) | landed | M1-T9: HexPicker: ray-to-hex picking over elevation planes (closes M1) |
| 2026-08-04 | M2-T1 | GameState and PlayerState stockpiles on a shared Fnv content hash (**OPENS M2**; also closes the M0-T2 item-10 `dig_yields.artificial_granite` gap — **the project's first §12.1 amendment, with the GDD cell edited by Land in the same commit**) | landed | M2-T1: GameState and PlayerState stockpiles on a shared Fnv content hash (opens M2) |

## Notes for the next iteration

- **Pick up: M2-T2 — THE COMMAND SPINE. M2 IS OPEN, NOT DONE** (M2-T1 landed the state container;
  **0 of 3** §14 M2 acceptance criteria are met). The tree is green and **nothing is carried over
  from M1 or from M2-T1** — M2-T1 left no blocker and no open item, and its one owed doc edit (the
  §12.1 cell) was made by Land in the same commit.
  - **THE §11.1 SPINE IS THE NEXT SLICE, and M2-T1 was deliberately only its container.** There is
    still **no `Command`, no `CommandError`, no concrete `Event` subclass and no turn counter** —
    every one is named as deferred in decisions.md **(AU)** item 8 and in the new files' headers, so
    do not treat their absence as an oversight. §11.1 is binding: *every* `GameState` mutation flows
    through a Command with `validate(state) -> Error?` and `apply(state) -> Array[Event]`, a match is
    fully described by `(seed, command_log)`, and the single seeded RNG is **`state.rng`** — an `Rng`
    (M1-T5), never a second generator and never one constructed inside a rule. `GameState` now
    **exists** and already folds `rng.rolls_drawn()` into its hash, so *"replaying `(seed,
    command_log)` reproduces the hash"* is directly testable the moment a Command exists. Suggested
    M2-T2 shape: `Command` base + `CommandError` (mirror `RulesError`'s `line`/`path`/`message`
    shape — do **not** fork a second error vocabulary without a logged reason) + the **first real
    Command and the first concrete `Event`**, with a replay test. Hang the first dig on it after.
  - **§14's M2 row is far bigger than one task — keep slicing it.** Deliverables: *"Workers,
    Dig/Cancel commands, yields, vein nodes + Extractors, stockpiles/income/upkeep, housing, Mining
    Zones v0"* (**stockpiles only, so far**); acceptance: *"Scripted 20-turn dig scenario matches
    expected stockpiles exactly; deficit-bleed test; zone assigns nearest idle worker"* (**none met**).
    Read **§5** (economy), **§3.4** (the turn sequence and the deficit bleed) and **§4.2** (the
    terrain/dig-yield table) alongside §14 before spec'ing the next slice.
  - **§3.1's STARTING KIT IS STILL DEFERRED AND NEEDS ITS OWN §12.1 AMENDMENT.** Every player
    currently starts **EMPTY** (decisions.md **(AU)** item 8). §3.1 prints 200 Gold / 100 Food /
    50 Stone / 20 Iron / 0 Magestone / 0 Mithril, but §12.1 has **no key for it**, so the task that
    lands it must add a new `data/ruleset.json` key **and** a dated decisions.md entry, and Land must
    edit the §12.1 cell in that same commit — exactly the procedure M2-T1 just ran for `dig_yields`.
  - **Read first:** decisions.md **(AU)** (this iteration — stockpile semantics, the `content_hash`
    fold order, the no-whitelist rule for resource ids, and the eight deferrals), **M1-T2 (C)/(C2)**
    (the rounding contract every later rule inherits), **M1-T3 (H)–(L)** (injected `Callable`s — the
    pattern that binds a real map to a rule without changing the rule), **M1-T4/M1-T5 (M)–(U)** (the
    map, its canonical order, the golden and the single `Rng`), and the **GOLDEN contract** bullet
    below, because M2's *"scripted 20-turn dig scenario"* is the project's second golden-shaped
    artefact.
  - **Continue the decisions.md lettering at (AV)** — M2-T1 used **(AU)** as a single umbrella
    resolution with eight numbered sub-items, cross-referenced by `scripts/core/fnv.gd`,
    `scripts/sim/player_state.gd`, `scripts/sim/game_state.gd` and all three new test files.
    **Do not renumber (AU).**
  - **(Z) STILL GOVERNS EVERY RENDERER ASSERTION.** Under `--headless` the dummy renderer **does not
    store MultiMesh instance data** — `set_instance_transform` → `get_instance_transform` returns the
    **identity**, `set_instance_custom_data` reads back `(0,0,0,1)`, and `MultiMesh.buffer` is **size
    0** even at `instance_count = 3` (re-measured at M1-T7). Readable headless: `instance_count`,
    `transform_format`, `use_custom_data`, `use_colors`, `mesh != null`, **resource properties**
    (which is what makes the SDFGI pin real), `get_class()`, node parenting/naming/order,
    `get_instance_id()`. Renderer tests stay **STRUCTURAL only**; an instance read-back assertion can
    only ever pass **vacuously**. Placement math is covered by `test_hex_layout.gd` — do not re-test
    it through a MultiMesh. **M1-T8 added the corollary: a `.tscn` may be `load()`ed and
    `instantiate()`d in a unit test but must NEVER be added to the tree** — `_ready()` would generate
    a 3,169-hex map inside the suite. Wrap the instance in `autofree`.
  - **Size it: ≤ ~300 LOC of PRODUCTION change** (the M1-T3 precedent below; let the suite be as large
    as the acceptance criterion requires — M1-T9's was 1,260 lines against 153 lines of picker).
  - **Write the source scans fresh for any new file.** They are per-file and inherit nothing. For a
    **sim/core** file copy `tests/unit/test_rng.gd`/`test_map_generator.gd`; for a **renderer** file
    the examples are `tests/unit/test_hex_layout.gd` (a pure `RefCounted` renderer helper),
    `tests/unit/test_map_renderer.gd` (an actual `Node`) and now `tests/unit/test_camera_rig.gd` (a
    `Node3D` **with an allowed-token list** — `Input.`, `get_viewport(`, `RulesError` are required
    **present**) and `tests/unit/test_greybox_scene.gd` (a scene + `project.godot` structural scan
    whose allowances — `Engine.get_frames_per_second(`, `get_tree()` — are **stripped before** the
    forbidden pass). All **strip comment lines FIRST** (load-bearing — doc blocks contain `§4.1`/`§9.1`
    and naive regexes hit them). **`RulesError` is explicitly ALLOWED in renderer files** (M1-T6 (Y));
    the **no-float** scan is deliberately **NOT** applied to renderer files (geometry is not a §11.1
    rule surface). Always keep: no map-size literal `24|32|40|1801|3169|4921`; a `## §<section>` doc
    comment on every public function (section list in a `DOC_SECTIONS` const); **an explicit expected
    public-member list** so a missing **or extra** member fails; and class-kind via `get_class()`,
    **never** `is Node` (a statically-decidable construct parse-errors and silently un-collects the
    whole file; decisions.md M0-T2 item 11 / M0-T5 item (a)) — for a Node file `get_class()` **names**
    the expected class instead of forbidding Node-ness. `tests/unit/test_hex_picker.gd` (M1-T9) is the
    newest worked example of the pure-`RefCounted` renderer shape, and adds one rule of its own: where
    a file has **no loader**, assert `RulesError` **ABSENT** so a second loader cannot grow there.
  `scripts/` currently holds `sim/rules_loader.gd` + `sim/rules_error.gd` + `sim/hex_map.gd` +
  `sim/map_generator.gd` + `sim/player_state.gd` + `sim/game_state.gd`, `core/event.gd` +
  `core/event_bus.gd`, `core/hex_math.gd`, `core/los.gd`, `core/rng.gd`, `core/fnv.gd`,
  `render/hex_layout.gd`, `render/map_renderer.gd`, `render/camera_rig.gd`,
  `render/greybox_boot.gd` and `render/hex_picker.gd`, and nothing else, deliberately (§13.4: invent
  nothing ahead of its milestone). `scenes/` holds exactly one file, `Main.tscn`. **There is still no
  shader** (§10 line 679's Lit/Dark tint is M3), **no selection state** (picking exists as of M1-T9,
  but tap-select/drag-box are M4/M8), **no `Command`, `CommandError`, turn counter, worker, dig,
  vein node, Extractor, housing, zone, cave feature, river, lair or spawn code**, and **still no
  concrete `Event` subclass**. `GameState` **now exists** (M2-T1) but is a *container only*. Those
  belong to the milestones that emit them — **M2-T2 is where the first `Command` and the first real
  `Event` arrive.**
- **`GameState` + `PlayerState` + `Fnv` contract (`scripts/sim/game_state.gd`,
  `scripts/sim/player_state.gd`, `scripts/core/fnv.gd`, NEW at M2-T1 — read decisions.md **(AU)**
  before touching any of them). This is §11.1's state container, and EVERY later M2 slice hangs off
  it.** All three are `class_name … extends RefCounted`, engine-free, integer/String only (no float
  literal, no `float` token), and none of them loads a document — so a source scan asserts
  `RulesError` is **ABSENT** in all three (the M1-T9 rule). `RandomNumberGenerator` appears in none
  of them: `scripts/core/rng.gd` is still its single home (M1-T5 **(R)**), and it is a forbidden
  token in every sim/core scan.
  - **Public surfaces are EXACT and mechanically scanned — a missing OR extra member fails.**
    `Fnv` = consts `OFFSET_BASIS` / `PRIME` / `MASK` + static funcs `fold_byte`, `fold_int64`,
    `fold_bytes`, `fold_string`, **zero public vars, no `_init`, never instantiated** (an extra
    *public const* fails too — extra helpers must be `_`-prefixed). `PlayerState` = **six** funcs
    `amount_of`, `add`, `spend`, `can_afford`, `resource_ids`, `content_hash`, **zero public vars**.
    `GameState` = `var map: HexMap`, `var rng: Rng` + `player_count`, `player`, `content_hash`
    (**five** members). **If a later slice needs a new public member, update the expected list in the
    same commit.**
  - **`content_hash()`, NEVER `hash()`** — overriding `Object.hash()` trips `native_method_override`
    (level 2 = hard error), and a scan asserts `func hash(` is absent. **The `GameState` seed
    parameter is `p_seed_value`, never `seed`** (`shadowed_global_identifier`, the M1-T5 (R) trap).
  - **THE FOLD ORDER IS FIXED AND DOCUMENTED IN `game_state.gd`'s HEADER, because a future golden
    will record it:** private seed → `rng.rolls_drawn()` → map-presence flag (0/1) → `map.content_hash()`
    when present → `player_count()` → per index ascending, the index then that player's hash.
    `PlayerState` folds, per held id in **ascending id order**: the id's UTF-8 bytes → the amount as
    **eight** little-endian bytes → a **separator byte** `0x1f`. **Three of those are load-bearing and
    each is pinned by exactly one test:** (a) **the RNG stream position** — drawing a roll changes the
    hash, because §11.1's replay contract is over `(seed, command_log)`; (b) **players fold BY INDEX**
    (§3.3) — only the *swap two players' stockpiles between index 0 and 1* test catches a multiset
    fold; (c) **the separator byte** — without it `{"a": 0x7878787878787878, "b": n}` and
    `{"axxxxxxxxb": n}` produce the **identical 18-byte stream**, and Verify measured that deleting it
    left the whole 502-test suite **GREEN** until the confusable-id test was added.
  - **`Fnv.fold_int64` folds EIGHT bytes; `hex_map.gd`'s private `_fold_int` folds FOUR — the
    duplication is DELIBERATE, RECORDED AND GUARDED, not an oversight** (decisions.md (AU) item 7).
    `HexMap` was **not** retrofitted because the M1-T5 golden (`0xcad24923`) records its 4-byte fold;
    collapsing them is an **opportunistic later task with that golden as its proof**. Do not "tidy"
    it on the way past. `Fnv`'s parameters are pinned against the **published FNV-1a 32-bit test
    vectors** (`"" → 0x811c9dc5`, `"a" → 0xe40c292c`, `"foobar" → 0xbf9cf968`) — an **external
    oracle**; never re-pin a hash against itself.
  - **Stockpile semantics (§5.1 + §3.4 step 2):** amounts are honest **64-bit** (`add("gold",
    5000000000)` reads back exactly — a `PackedInt32Array` store dies here); `add`/`spend` are
    **total** (non-positive amount or empty id ⇒ `false`, nothing touched); **`spend` refuses
    ATOMICALLY** rather than going negative, because §3.4 pays a shortage in **HP**, not in negative
    stock; **spending a balance to exactly 0 REMOVES the entry**, so *"never had it"* and *"spent it
    all"* hash identically; `can_afford` is **literally** the `spend` predicate.
  - **RESOURCE IDS ARE OPAQUE — no whitelist in engine code** (the §4.2 terrain-type precedent (T)/(AH)
    and the EventBus event-type precedent (f)). The seven §5.1 ids `food|gold|stone|iron|magestone|
    mithril|scrap` are **FORBIDDEN tokens** in `player_state.gd` and `game_state.gd` on
    comment-stripped source (watch incidental substrings — *"environment"* contains *"iron"*). §5.1's
    vocabulary is pinned **by test only**. Never add an enum or a `const` list of resources.
  - **Storage: no `Dictionary` key order may ever reach an output.** `PlayerState` uses a private
    `Dictionary` touched only by key lookup/assign/erase; `resource_ids()` sorts a **fresh copy** of
    the keys and returns a **fresh array every call**, pinned with **`is_same()` IDENTITY** assertions
    (the M1-T9 lesson: a self-clearing member cache passes a pollution-only freshness check). Probes
    confirmed both — returning `keys()` unsorted and caching the array each go red.
  - **`GameState` totality:** `player(i)` is the **same** object per index every call (a throwaway
    copy fails `is_same`), `null` outside `0..n-1`; a non-positive `p_player_count` clamps to the
    **empty roster** while `rng` is still non-null; a `null` map constructs cleanly and cannot collide
    with a real map thanks to the presence flag.
  - **Three residual GREEN mutants, analysed and judged equivalent/unreachable — do not re-derive
    them** (decisions.md (AU) item 11): dropping the `player_count()` fold (the per-index fold already
    encodes it), dropping the map-presence flag (a collision is unconstructible in a test, and the
    observable property *is* pinned), and folding the amount as a decimal String (still injective;
    the 8-byte fold is pinned at the `Fnv` level). **None is a code defect.**
- **`HexPicker` contract (`scripts/render/hex_picker.gd`, NEW at M1-T9 — read decisions.md M1-T9
  (AQ)–(AT) before touching it; it is the LAST M1 deliverable and it loads NO data).** `class_name
  HexPicker extends RefCounted` — a pure `RefCounted` like `HexLayout`: it holds no Node, subscribes
  to no `EventBus`, mutates no state and names **no** sim class (`HexMap`/`MapGenerator`/`Rng` are
  forbidden tokens in its scan). **Terrain reaches it ONLY through the injected `elevation_at`
  `Callable`** (the M1-T3 **(H)** precedent), so binding a closure over a real `HexMap` at M4 needs
  **zero change to this file**.
  - Public surface is **EXACTLY five functions and ZERO public vars** — `set_layout`, `world_to_hex`,
    `ray_plane_point`, `pick`, `pick_from_screen` — and the scan fails on a **missing OR extra**
    member. **There is deliberately no `errors` var**: this file loads no document, and the scan
    asserts `RulesError` is **ABSENT** so a second loader cannot grow here. Privates: `_layout`,
    `_is_configured`.
  - **(AQ) THE PICK RULE — scan elevation planes TOP-DOWN, and the order is load-bearing.**
    `pick(origin, direction, elevation_at, top_elevation)` intersects the ray with the flat top plane
    `y = level * elevation_step_m` for `level` from `maxi(top_elevation, 0)` **down to 0**, and
    accepts a level **iff the hex under that intersection actually has that elevation**; first
    acceptance wins; **an empty Array is an explicit "no hex"** (the `Los.blocking_hexes` precedent —
    no magic `Vector2i` sentinel). **A bottom-first scan passes almost everything** — only the
    hand-computed two-fixture discriminator (one ray, two maps, two different correct answers) catches
    it. **Honest caveat that travels with the rule:** it is a **top-face test, not a full ray/prism
    intersection**, so a ray grazing a tall column's **side** can resolve to the hex behind it.
    Acceptable at greybox fidelity; revisit when M4's selection needs more.
  - **(AR) `world_to_hex` is the exact algebraic INVERSE of (W)** — `q_frac = world.x / (1.5*R)`,
    `r_frac = world.z / (SQRT_3*R) - 0.5*q_frac`, **`world.y` IGNORED** — and it **REUSES
    `HexMath.cube_round_scaled`** (via the named `PICK_SCALE = 1000000`) for the cube repair. **Never
    re-implement the rounding**: the scan permits the string `cube_round` **only** inside
    `HexMath.cube_round_scaled(`, exactly as `Los` guards `HexMath.line(`. `SQRT_3` and `PICK_SCALE`
    are mathematical/algorithmic consts (the M1-T5 item 7 precedent), **not** §13.6 violations —
    but a test now pins `HexPicker.SQRT_3 == HexLayout.SQRT_3`, because a 1 % drift in the private
    copy moved **no hex** in the entire 868-case round-trip sweep.
  - **§4.1's 0–3 elevation range is a CALLER PARAMETER (`top_elevation`), not a literal and not a new
    data file** (the M1-T1 item 4 precedent for the map radii). `hex_width_m`/`elevation_step_m` are
    read **through `HexLayout`** and proven data-driven **by mutation of the params TEXT** —
    `data/render/greybox.json` stays byte-untouched because `test_hex_layout.gd` asserts it
    byte-for-byte.
  - **(AS) totality:** unconfigured (null layout **or** one whose load failed, i.e.
    `hex_width_m() <= 0.0`) ⇒ `pick` empty and `world_to_hex` `Vector2i.ZERO`; **`ray_plane_point` is
    layout-INDEPENDENT pure geometry and still answers**; `direction.y == 0`, `t < 0` or a zero-length
    ray ⇒ no hit; **`t == 0.0` IS a hit**; the direction need not be normalised; an **invalid
    `elevation_at` ⇒ a FLAT pick at y = 0** (the (L) spirit — the picker compares, it does not police
    the map), checked **after** the unconfigured guard; `top_elevation < 0` clamps to 0.
  - **`pick_from_screen` is the ONLY engine-coupled member and is UNTESTABLE HEADLESS** — a `Camera3D`
    added under the headless root reports **`get_viewport() == null`** (the (Z) family), so it is
    pinned by its **null-camera guard** plus a **required-token scan** for `project_ray_origin(` /
    `project_ray_normal(`, the same shape as M1-T8's `"Basis(Vector3.UP"` guard. **Never drop those
    tokens.** Whether it *feels* right is unassessed, like the rig's input layer.
  - **Every returned Array is FRESH per call**, pinned with `is_same()` **identity** assertions —
    M1-T9's Verify measured that a *pollution-only* freshness check is passed by a **self-clearing
    member cache**. Use the `test_hex_math.gd::_assert_fresh_pair` / `test_los.gd` P7 shape in every
    future freshness test; the weaker form is not load-bearing.
- **`CameraRig` + the greybox scene contract (`scripts/render/camera_rig.gd`,
  `scripts/render/greybox_boot.gd`, `data/render/camera.json`, `scenes/Main.tscn`, NEW at M1-T8 — read
  decisions.md M1-T8 (AI)–(AP) before touching any of them).**
  - **Public surface is EXACTLY `var errors: Array[RulesError]` + 19 functions** —
    `load_params_text`, `load_params_file`, `pitch_limits_deg`, `zoom_limits_m`, `pan_speed_mps`,
    `orbit_speed_dps`, `zoom_speed_mps`, `edge_pan_margin_px`, `yaw_deg`, `pitch_deg`, `zoom_m`,
    `focus_point`, `set_focus`, `orbit`, `tilt`, `dolly`, `pan`, `camera_transform`, `apply_to_camera`
    — and the scan fails on a **missing OR extra** member. **If M1-T9 puts picking here, update
    `tests/unit/test_camera_rig.gd`'s expected list in the SAME commit.** The accessor is `zoom_m()`
    and the mutator `dolly()` deliberately: anything shadowing a `Node3D` method trips
    `native_method_override` (level 2 = hard error).
  - **(AJ) YAW WRAPS, PITCH AND ZOOM CLAMP.** §9.1's *"rotate 360°"* is unbounded → `orbit()` wraps
    into **[0, 360)**; *"tilt 15–80°"* / *"zoom 8–60 m"* are bands → clamped **inclusively**. A
    successful load frames the rig at the **widest legal view** (yaw 0, pitch = max, zoom = max, focus
    origin) and there is **no absolute setter** — only the three relative mutators. `DEGREES_PER_TURN`
    (360.0) is a named **mathematical** const; **15/80/8/60 may not appear as literals** and the scan
    forbids `\b15\b`/`\b80\b`/`\b8\b`/`\b60\b` on comment-stripped code (it does not fire inside
    `360.0`, but it **would** fire on e.g. `0.8`).
  - **(AI) the derived transform:** `origin = focus + zoom * Vector3(cos P * sin Y, sin P, cos P *
    cos Y)` then `.looking_at(focus, Vector3.UP)`; **(AK) `pan(right_m, forward_m)` moves the FOCUS
    only**, `right(yaw) = (cos, 0, −sin)`, `forward(yaw) = (−sin, 0, −cos)`, `focus.y` invariant.
    **Probe P1 is the one to remember: a sin/cos swap is INVISIBLE to the 540-case distance sweep**
    (it preserves `|camera − focus|`) and is caught only by the hand offset table and the
    pan-axes/basis agreement — the two pins are complementary, never redundant.
  - **(AL) the loader mirrors (P)/(Y)/(AF) and REUSES `RulesError`** — declared key-spec order,
    line 0 reserved for missing files, integral-float accepted / fractional rejected for the single
    INT leaf `edge_pan_margin_px` (0 is legal), **semantic attribution pinned per key**, no cascading
    band error after a leaf's own failure, and **any** error leaves the rig UNCONFIGURED (accessors
    0 / `Vector2.ZERO` / `Vector3.ZERO` / `Transform3D.IDENTITY`, every mutator a silent no-op),
    including a failed load after a successful one.
  - **`data/render/camera.json` is CONTENT and its formatting is load-bearing** (line 1 a lone `{`,
    one top-level key per line): `id greybox_camera`, the four §9.1 limits **verbatim** (15/80/8/60)
    and four new tunables (`pan_speed_mps` 45, `orbit_speed_dps` 35, `zoom_speed_mps` 25,
    `edge_pan_margin_px` 16). It is a **separate file** from `greybox.json` because
    `test_hex_layout.gd` asserts that one **byte-for-byte**. Data-drivenness is proven **by mutation**.
  - **Input (§9.1 WASD + edge-pan) is thin, delegating and UNTESTED HEADLESS** — the suite `autofree`s
    every rig and **never adds one to the tree**, so `_process`/`_unhandled_input` never run there.
    `Input.` and `get_viewport(` are **explicitly allowed and asserted present**. R/F tilt reuses
    `orbit_speed_dps()` because §9.1 prints no tilt speed (decisions.md M1-T8 item 11); it becomes a
    fifth `camera.json` key the moment it needs to differ. **Nobody has yet assessed how any of it
    FEELS** — worth an eyes-on pass whenever a human next opens the scene.
  - **`scenes/Main.tscn` is a FIXED FOUR-CHILD scene** (`MapRenderer` with **zero** children,
    `CameraRig` with exactly one `Camera3D`, `WorldEnvironment`, `DirectionalLight3D`) and the child
    **set** is asserted, so an **extra** child fails. **SDFGI is pinned twice** — as a resource
    property and as literal `.tscn` text — so an engine default flip cannot silently turn it on.
    `project.godot` now has `run/main_scene="res://scenes/Main.tscn"`; its `[debug]` §11.3 gate
    section is untouched. **The `DirectionalLight3D` needs a real orientation**: as first written it
    had none, shone horizontally and the greybox rendered **black** — and a hand-written 12-float
    `Transform3D` in a `.tscn` is applied **TRANSPOSED** (it pointed the light *upward*), so use
    `rotation_degrees`.
  - **`GreyboxBoot` is the measurement instrument, and `Engine.get_frames_per_second()` is a
    ONE-SECOND-WINDOW AVERAGE** whose first two windows are always start-up transients (the engine's
    initial sentinel **1**, then the window containing `_ready()`'s generate + build); steady state
    arrives ~frame 180 at 144 Hz. `warmup_frames` 1500 / `auto_quit_frames` 3300 are **calibrated to
    this machine**, not principled — a much faster machine could need more. A too-short warm-up
    produces a **false LOW min**, which errs conservative and can never flatter the criterion.
  - **THE FLAT-TOP CORRECTION YAW — (AP), and the M1-T7 open item now CLOSED by measurement.** Godot
    4.7's `CylinderMesh(radial_segments 6)` puts its radial vertices at **{0, ±60, ±120, 180}° from +Z
    toward +X** — a vertex on **+Z**, **none on +X** — exactly **half a segment off** what
    `HexLayout`'s **(V)** flat-top placement needs, so identity-basis instances tile with visible
    triangular gaps and overlapping slivers. `MapRenderer` now writes
    `Basis(Vector3.UP, PI / RADIAL_SEGMENTS)` into every instance transform. **(Z) makes that basis
    unreadable headless — probe P7 confirmed reverting it breaks ZERO tests** — so
    `test_map_renderer.gd`'s `REQUIRED_TOKENS` entry `"Basis(Vector3.UP"` is the **only** automated
    guard; the tiling itself is verifiable only in a windowed run. **Never drop that token.**
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
  - **(AC)** per-instance transform (`hex_to_world`, MapRenderer-local space) and custom data
    (`tint_for(terrain_type)`, **alpha 1.0 reserved for M3's §10 line 679 Lit/Dark shader**) are
    **written, never read back** — (Z) makes a read-back vacuous, so the scan requires the literal
    `set_instance_transform(`/`set_instance_custom_data(` tokens instead. **(AH)** at M1 every
    in-bounds hex is drawn as solid rock; **cave culling arrives with M2's dig**. **The instance basis
    is NO LONGER identity as of M1-T8 (AP)** — it is `Basis(Vector3.UP, PI / RADIAL_SEGMENTS)`, the
    measured flat-top correction yaw, guarded only by `test_map_renderer.gd`'s `"Basis(Vector3.UP"`
    required token (see the CameraRig/scene bullet above).
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
- **Constants are now data**, and as of M2-T1 `data/ruleset.json` holds one key the §12.1 excerpt did
  **not** print — `dig_yields.artificial_granite.stone = 2`, governed by §4.2's row and now also in
  the §12.1 cell (see the CLOSED forward-gap bullet below for the amendment procedure).
  `data/ruleset.json` holds the full §12.1 constant set and
  `RulesLoader` (`scripts/sim/rules_loader.gd`) is the only sanctioned way to read it. Never
  re-type a §12.1 number as a literal in `.gd` code (§13.6) — go through
  `get_int` / `get_float` / `get_string` / `get_int_array` / `has` with a dotted path.
  Errors surface as `RulesError` (`line` 1-based, `path` dotted, `message`,
  `format_for(source)` → `"<source>:<line>: <message>"`). Line 0 means "file-level, no line" and
  is reserved for missing/unreadable files.
- **CURRENT SUITE STATE IS GREEN.** `bash tools/run_tests.sh` → **exit 0** at **Scripts 21 /
  Tests 503 / Passing 503 / Failing 0 / Asserts 5646** (re-measured at Land, 2026-08-04, M2-T1).
  `Scripts 21` equals the number of `test_*.gd` on disk, so nothing is silently skipped;
  `bash tools/typecheck.sh` exits **0** over 38 files (re-measured at Land); `bash tools/ci.sh`
  exits 0 (PASS with the three documented M7/E4/E5 skips) and `bash tools/verify_harness.sh` exits 0.
  Prior green baselines, for reference: M1-T9's 18 / 425 / 425 / 5144, M1-T8's
  17 / 388 / 388 / 4959, M1-T7's 15 / 321 / 321 / 3380, M1-T6's
  14 / 278 / 278 / 2760, M1-T5's
  13 / 234 / 234 / 2268, M1-T4's 11 / 183 / 183 / 1879, M1-T3's
  9 / 129 / 129 / 1308, M1-T2's 8 / 106 / 106 / 1023, M1-T1's 8 / 86 / 86 / 835, and
  7 / 62 / 62 / 473 at the close of M0 (the M0 tracker row above deliberately keeps that historical
  figure). **Expect these totals to RISE as you add tests — they are enumerated, not hard-coded.**
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 on a healthy tree, and
  `bash tools/typecheck.sh` → exit 0 over **38** project `.gd` files, and
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
- `project.godot` carries `run/main_scene="res://scenes/Main.tscn"` **as of M1-T8** — the scene
  exists, so the path is not dangling (a dangling one breaks `--import`, which every `tools/` script
  runs first). Its `[debug]` section is the §11.3 gate (M0-T4, above) and is **hand-written
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
- **Forward gap flagged at M0-T2 — CLOSED by M2-T1 (kept here as the worked example of the
  amendment procedure, not as an open item).** §4.2's terrain table gives Artificial Granite a dig
  yield of **+2 Stone** while the §12.1 excerpt's `dig_yields` object omitted `artificial_granite`,
  and `data/ruleset.json` mirrored that omission faithfully. M2-T1 added
  `"artificial_granite": {"stone": 2}` between `granite` and `rubble` in `data/ruleset.json` (§4.2
  row order, matching `dig_turns`' key order), made it a **required, line-numbered-validated INT
  leaf** with one new `_spec()` row in `rules_loader.gd`, logged decisions.md **(AU)** item 1, and —
  **Land only, in the same commit** — edited `docs/GAME_DESIGN.md` §12.1 line 784. **That is the
  full procedure for every future amendment**: table wins over prose, data first, schema second,
  dated decisions.md entry, GDD cell edited by Land in the same commit. **§3.1's starting kit is the
  next one that will need it** (it has no §12.1 key at all).
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
  **M1-T8's yield is the sharpest lesson yet, and it is about the LIMITS of a test suite: the three
  real defects this iteration found were all found by RUNNING THE THING, not by any assertion.**
  (i) a **sin/cos swap** in the camera offset is **invisible** to the 540-case distance sweep (a swap
  preserves `|camera − focus|`) and is caught only by the hand offset table and the pan-axes/basis
  agreement — complementary pins, never redundant ones; (ii) probe **P7 — reverting the flat-top
  correction yaw — went ZERO RED**, because (Z) makes the instance basis unreadable headless, so the
  greybox could tile with visible gaps while 388 tests stayed green (now guarded by a single required
  token); (iii) the scene's `DirectionalLight3D` shipped with **no rotation**, so the greybox rendered
  **black** and every fps number measured on it would have been meaningless — no structural test could
  see it, and a hand-written 12-float `Transform3D` in a `.tscn` is applied **TRANSPOSED**, which the
  first fix attempt discovered by pointing the light upward; and (iv) `Engine.get_frames_per_second()`
  is a **one-second-window average** whose first two windows are start-up transients, so the first
  measurement printed a bogus `fps_min=1.00` — an **instrument** artefact, not a performance dip.
  **When a milestone criterion is only measurable outside the suite, budget time to LOOK at the
  output, and probe the instrument before trusting its number.**
  **M1-T9's yield (thirteen probes; eleven red on demand, and — for the first time — TWO SURVIVORS
  that were defects in the TESTS, not the code):** (i) a **self-clearing member cache** passes a
  fresh-Array test that only checks *"pollution does not survive"* — every caller gets the **same
  aliased Array** and the suite stays green; only an **`is_same()` identity** assertion catches it, so
  use the `test_hex_math.gd::_assert_fresh_pair` / `test_los.gd` P7 shape and never the weaker one;
  (ii) **a 1 % drift in a file's private copy of `SQRT_3` moved no hex** across an 868-case round-trip
  sweep over the radius-8 disc × four elevations — a "round-trip proves the inverse is exact" claim is
  **false** unless the constant itself is pinned (`HexPicker.SQRT_3 == HexLayout.SQRT_3`). Both were
  fixed by **strengthening the tests, never the code** — the implementation was correct in both cases
  — and both mutants re-probe red. The standing lesson sharpens: **probe the SUITE, not only the
  implementation; a green mutant is a hole in the test, and Verify is where it must be found.**
  **M2-T1's yield (eighteen probes, ten iterations of the practice running) is three-part.**
  (i) **A THIRD consecutive iteration in which the battery found a weak TEST, not weak code:**
  deleting the separator byte from `PlayerState.content_hash()` left the whole 502-test suite
  **GREEN**, even though it makes `{"a": 0x7878787878787878, "b": n}` and `{"axxxxxxxxb": n}`
  serialize to the **identical 18-byte stream** — an id carries no length prefix and an amount is
  always exactly 8 bytes, so a delimiter is the only thing making §11.1's *"canonical serialization"*
  unambiguous. Closed by an additive test that builds the confusable id **from the amount's own
  little-endian bytes**, so it demonstrates the confusion rather than asserting it.
  (ii) **A PROCEDURAL TRAP THAT INVALIDATES A WHOLE PROBE PASS: Verify's first eight probes all
  "went red" because the driver resolved `bash` to WSL**, which cannot see the repo — every failure
  was a `CreateProcessCommon` error, not a test failure. **A probe that fails for the wrong reason
  proves nothing and is worse than no probe at all**, because it manufactures confidence exactly
  where the practice exists to remove it. Always check *what* went red, and drive probes through
  `C:/Program Files/Git/bin/bash.exe`. (iii) **EQUIVALENT MUTANTS ARE REAL — check before recording
  a survivor as a hole.** The spec's *"fold players as an unordered set (drop the index)"* mutant is
  equivalent (positional iteration still encodes the index) and had to be replaced with a genuine
  sort-by-hash multiset fold, which the swap test then killed; three other survivors (dropped
  `player_count` fold, dropped map-presence flag, amount folded as a decimal String) were likewise
  analysed as equivalent or unreachable and are recorded in decisions.md (AU) item 11 so nobody
  re-derives them.
