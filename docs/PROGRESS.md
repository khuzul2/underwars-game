# Progress — Agent Loop State

Machine-readable state for the `underwars-iteration` workflow. The **Orient** agent reads this
file first every iteration and the **Land** agent updates it last. Keep it terse and factual.

Task-log convention: the **Commit** column holds the commit *subject* (which always starts with
the task ID); look up the SHA with `git log --oneline --grep "<task-id>:"`. `—` means
not-yet-committed.

## Current position

- **Phase:** 1 (MVP, GDD §14)
- **Milestone:** **M2 — Dig & Economy is IN PROGRESS (opened 2026-08-04 by M2-T1; M2-T2 landed the
  §11.1 command spine; M2-T3 landed §4.2's dig TABLE; M2-T4 landed the §11.1 UNIT ROSTER; M2-T5
  landed the DIG-SITE REGISTRY + `DigHexCommand` + `DigStartedEvent`; M2-T6 landed
  `CancelDigCommand` + `DigCancelledEvent`, closing the "Dig/Cancel commands" ORDERING PAIR; **M2-T7
  landed the DIG TICK — §3.4 step 4 — the YIELD APPLICATION, the hex-becomes-Cave transition, the
  project's FOURTH and FIFTH concrete `Event` subclasses, the THIRD §12.1 amendment and, at last,
  THE §13.2 TIER-3 GOLDEN**).**
  **M2 is NOT done — but it is no longer at zero: §14 M2 acceptance criterion (a) *"Scripted 20-turn
  dig scenario matches expected stockpiles exactly"* is MET as of M2-T7 (1 of 3).** M2-T1 landed the §11.1
  state container (`GameState`, `PlayerState`, the shared `Fnv` fold) plus the §12.1
  `dig_yields.artificial_granite` amendment that closed the M0-T2 item-10 forward gap; **M2-T2
  landed the spine itself** — `CommandError`, the `Command` base with `execute` as the one gate,
  `EndTurnCommand`, the project's **first concrete `Event` subclass** (`TurnEndedEvent`), §3.3's
  turn position on `GameState` and the §11.1 **replay-hash proof** as a property test; **M2-T3
  landed `DigRules`** (`scripts/sim/systems/dig_rules.gd` — the project's first `scripts/sim/systems/`
  file), which answers §4.2's whole Solid-hex dig paragraph **from data**: dig time per terrain type
  with the §7.1 Artificial-Granite owner variant, dig yield per type including the four vein lumps,
  the vein-node resource id, the max-diggers cap and §4.2 line 197's *"Dig 2× halves remaining time
  (round up)"* — together with **the project's second §12.1 amendment**, the new top-level `dig`
  group (`max_diggers_per_hex` + the nine-row `profiles` map that binds §4.2's terrain ids to
  §12.1's dig keys), and the `RulesLoader` `map` spec kind + `get_keys` that validate it;
  **M2-T4 landed the §11.1 line-704 UNIT ROSTER** — `scripts/sim/unit_state.gd` (the unit INSTANCE
  record: stable id, owner player index, opaque §12.2 `type_id`, axial position, hp/max_hp with a
  TOTAL clamping `set_hp`, and a documented FNV fold) plus six new `GameState` functions
  (`spawn_unit`, `unit`, `unit_ids`, `units_of`, `units_at`, `remove_unit`) over a private `_units`
  store and a `_next_unit_id` counter that starts at **1**, advances only on a successful spawn and
  **never reuses an id**, with the `content_hash` fold **extended by APPENDING** the roster steps;
  **M2-T5 landed SLICE 3a of the dig chain** — `scripts/sim/dig_site.gd` (the dig-site PROGRESS
  RECORD: hex, ordering player, total/remaining worker-turns, ascending digger ids, `content_hash`),
  five new `GameState` registry functions (`add_dig_site`, `dig_site`, `dig_site_hexes`,
  `dig_site_of_digger`, `remove_dig_site`) over a private `_dig_sites` Dictionary with the fold
  **again extended by APPENDING ONLY**, `scripts/sim/commands/dig_hex_command.gd` (**the second of
  §11.1 line 705's fourteen printed commands** and the first consumer of **both** `DigRules` and the
  unit roster — §4.2 line 197's adjacency + max-2-digger rules, an eleven-code rejection vocabulary
  in a fixed precedence, and the §7.1 ownership **seam**) and
  `scripts/sim/events/dig_started_event.gd` (**the project's second concrete `Event` subclass**,
  `&"dig_started"`, emitted for every accepted dig order and for nothing else);
  **M2-T6 landed SLICE 3b** — `scripts/sim/commands/cancel_dig_command.gd` (**the THIRD of §11.1 line
  705's fourteen printed commands**, a **pure consumer** of M2-T5: unit-targeted, six-code rejection
  vocabulary, and the four rules §4.2 does not print — decisions.md **(AZ)**) plus
  `scripts/sim/events/dig_cancelled_event.gd` (**the project's THIRD concrete `Event` subclass**,
  `&"dig_cancelled"`);
  **M2-T7 landed SLICE 4 — THE TICK** — `scripts/sim/systems/dig_tick.gd` (`DigTick`, the project's
  **second** `scripts/sim/systems/` file: §3.4 step 4 as a pure `RefCounted` rule module called
  **from** `EndTurnCommand.apply()` for the **INCOMING** player after the §3.3 rotation — a site
  spends `digger_ids().size()` worker-turns per tick (§4.2 line 197's **TOTAL worker-turns**), a
  site reaching 0 applies its §4.2 yield to the **SITE'S OWNER's** stockpile, flips the hex to
  `DigRules.cave_terrain_id()`, is removed from the registry and frees its diggers **implicitly**),
  `scripts/sim/events/dig_progressed_event.gd` + `scripts/sim/events/dig_completed_event.gd` (**the
  project's FOURTH and FIFTH concrete `Event` subclasses**, `&"dig_progressed"` / `&"dig_completed"`,
  progress **always** before completion), **the THIRD §12.1 amendment** (required string leaf
  `dig.cave_terrain_id` = `"plain_floor"`, named from §4.2's Cave-hex row *"Plain floor"*, with the
  §12.1 excerpt cell edited by Land in the M2-T7 commit and **§4.2's table byte-unchanged**) and
  **THE §13.2 TIER-3 GOLDEN, RECORDED AT LAST** (`tests/golden/dig_tick_scenario_seed4242.json`,
  `content_hash "0xb0629468"` — seed 4242 / radius 2 / 2 players / 45 commands / 20 turns) — all
  under decisions.md **(BA)**.
  **1 of §14's three M2 acceptance criteria is met** — criterion (a) *"Scripted 20-turn dig scenario
  matches expected stockpiles exactly"* is **MET** (`tests/sim/test_dig_scenario.gd`, hand-computed
  literals: player 0 → food 1 / gold 25 / stone 4, player 1 → iron 10 / magestone 15 / stone 1, with
  every un-yielded resource asserted **absent**); *"deficit-bleed test"* and *"zone assigns nearest
  idle worker"* still need systems that do not exist. Of the §14 M2 deliverable list (*"Workers,
  Dig/Cancel commands, yields, vein nodes + Extractors, stockpiles/income/upkeep, housing, Mining
  Zones v0"*) **stockpiles**, the **unit CONTAINER** (the roster, not a worker), **the WHOLE
  "Dig/Cancel commands" line as an ORDERING PAIR (`DigHex` + `CancelDig`)** and — as of M2-T7 — **the
  WHOLE "yields" line (the TABLE from M2-T3 *plus* its APPLICATION)** are built. **A DIG NOW
  DIGS**, and that is the whole of what changed: a hex is excavated, a stockpile moves and the
  terrain becomes Cave — but there is still **no §12.7 trait set (worker-ness is a TRAIT, i.e. DATA
  — there is no worker CLASS), no vein-node state, no Extractor, no income/upkeep, no housing cap
  and no zone**, and **none of §3.4's OTHER eight per-player steps or its three World-phase steps**
  — every one is named as deliberately deferred in decisions.md **(AV)** item 9, **(AW)** item 4,
  **(AX)** item 18, **(AY)** item 18, **(AZ)** item 14 and **(BA)** item 16 and in the new files'
  headers, and the absences are pinned **negatively** by test (step 4's own **Breach checks (§4.6)**
  and **Noise pings (§4.8)** are M5 — `rng.rolls_drawn()` is still **0** after any number of ticks
  and completions; an `EndTurn` built with **no** `DigRules` ticks nothing and leaves
  `content_hash()` byte-identical; a vein completion creates **no node**).
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
- **Next task:** **M2-T8 — THE RENDERER SEAM THE TICK OWES, then the NEXT §14 M2 ACCEPTANCE
  CRITERION (§3.4 / §5.1 / §5.2 / §10 / §11.1 / §14).** The dig chain's slices are now: **(1) the
  §4.2 dig TABLE — DONE, M2-T3** (`DigRules`); **(2) the unit ROSTER — DONE, M2-T4**; **(3a)
  `DigSite` + the registry + `DigHexCommand` + `DigStartedEvent` — DONE, M2-T5**; **(3b)
  `CancelDigCommand` + `DigCancelledEvent` — DONE, M2-T6**; **(4) the TICK + the yield APPLICATION +
  the hex-becomes-Cave transition + the TIER-3 GOLDEN — DONE, M2-T7.** **THE DIG CHAIN IS COMPLETE
  as a rule.** What it still owes is **one seam and one tint**: the `EventBus` →
  `MapRenderer.mark_hex_dirty` wiring and a `data/render/terrain_palette.json` entry for the Cave
  terrain id `plain_floor`, both **explicitly deferred from M2-T7's own spec** to keep production
  under the ≤ ~300 LOC ceiling (decisions.md **(BA)** item 16, and **(AV)** item 9 before it). That
  is a **small** task — size it honestly at Orient, and if it comes in well under the ceiling, the
  right thing is to pair it with the **next M2 deliverable**, not to pad it.
  - **CHOOSE THE NEXT M2 DELIVERABLE BY WHICH ACCEPTANCE CRITERION IT MOVES.** §14 M2 now stands at
    **1 of 3**. Criterion (b) *"deficit-bleed test"* needs **income + upkeep + §3.4 step 2's 10 %
    max-HP bleed** — `PlayerState.spend` already refuses **atomically** rather than going negative
    precisely because a shortage is paid in **HP** ((AU) item 2), and `UnitState.set_hp` is already
    a TOTAL clamping mutator, so the missing pieces are the **income/upkeep rules** and the **bleed
    step**, all of which are §3.4 steps 1–3 and therefore siblings of the tick that just landed —
    `DigTick`'s call site in `EndTurnCommand.apply()` is the shape the next eleven steps copy.
    Criterion (c) *"zone assigns nearest idle worker"* needs §5.3 **Mining Zones** and the §12.7
    **worker trait**, which is **DATA at M6** — so (b) is the cheaper next criterion and the one
    that keeps M2 moving in §3.4 order.
  - **DO NOT PULL FURTHER FORWARD THAN THE SLICE YOU PICK.** Still deferred and still named:
    **vein-node stock/rate and Extractors** ((AW) item 4, re-opened by name at **(BA)** item 8 — a
    vein dig currently pays only its §4.2 **LUMP** and the node is dropped with the terrain, pinned
    **positively**); §4.2's *"Dig 2×"* halving (`DigRules.halve_remaining_turns` **still has no
    caller**); §5.2's housing cap (`housing.hq` shipped, unused); §5.3's Mining Zones; §3.1's
    starting kit (**still needs its own §12.1 key and its own amendment**); §7.1's Raise Granite and
    any hex-builder storage (M3/M4 — `_digs_own_terrain` still answers `false`, so Artificial
    Granite costs **3**, never 1); §3.2/§12.1's `victory.turn_limit` **200** (M6 — the literal
    `200` is still a **forbidden token**); command/unit serialization (M7).
  - **THE TIER-3 GOLDEN NOW EXISTS AND IS UNDER §13.6's RE-RECORD RULE.**
    `tests/golden/dig_tick_scenario_seed4242.json` (`content_hash "0xb0629468"`) joins
    `tests/golden/mapgen_concentric_bowl_small_seed1337.json` (`0xcad24923`). **Any slice that
    extends the `content_hash` fold, adds a `GameState` field, or changes a §4.2/§12.1 number will
    move it** — and from now on a re-record is permitted **only with a logged reason in the same
    commit** (§13.6). Read the **GOLDEN contract** bullet below before touching either file; neither
    test has a record-mode flag, by design, and both must keep saying **"is MISSING"** (never *"does
    not exist"* / *"Nothing was run"* / *"have not been imported"* / *"Failed to load script"* /
    *"Ignoring script"*, any of which trips `tools/run_tests.sh`'s diagnostic grep and turns an
    honest assertion failure into a harness error).
  - **Continue the decisions.md lettering at (BB)** — M2-T7 used **(BA)** as a single umbrella
    resolution with ten lettered sub-items (i)–(x) plus six unlettered ones, cross-referenced by all
    three new production files and by five suites; **(AZ)** is cross-referenced by two production
    files and three suites, **(AY)** by four production files and five suites, **(AX)** by
    `unit_state.gd`, `game_state.gd` and two suites, **(AW)** by several files, **(AV)** by five and
    **(AU)** by four. **Do not renumber (AU), (AV), (AW), (AX), (AY), (AZ) or (BA).**
- **Blockers:** **none.** `bash tools/run_tests.sh` exits **0** at Scripts 38 / Tests 938 /
  **Passing 938** / Failing 0 / Asserts 11774; `bash tools/typecheck.sh` exits 0 over 69 files;
  `bash tools/ci.sh` PASSes; `bash tools/verify_harness.sh` PASSes across all four phases with the
  tree left clean (all four measured at Verify, 2026-08-05, M2-T7; Verify made **no** fix for the
  **SIXTH** iteration running — `fixes_made` empty again — and ran the standing **eight-probe
  adversarial mutation battery in which ALL EIGHT mutants were caught** (fixed-1 decrement, inverted
  completion comparison, dropped terrain flip, dropped site removal, yield credited to the current
  player instead of the site owner, reversed site iteration order, **deleted golden file**, swapped
  step-4 event order), each reverted and the restored tree re-verified **byte-identically** green).
  `sim_smoke` (M7), `content_cli` (E4) and `balance_lab` (E5) were correctly **SKIPped, not failed**.

## Milestone tracker

| Milestone | Status | Acceptance criteria met |
| --- | --- | --- |
| M0 Bootstrap | **DONE** (2026-08-04, M0-T5) | **BOTH §14 acceptance clauses MET headless, checked against the §14 row this iteration** — (a) *sentinel suite green AND a deliberately failing sentinel makes `run_tests.sh` exit non-zero* (SETUP-2 amendment): `verify_harness.sh` exit 0 with **four** phases — A green, B failing canary, C syntactic parse error, D statically-impossible construct — each red phase non-zero **and naming its probe**, tree clean afterwards; (b) *invalid ruleset rejected with a line-numbered error*: pinned by `tests/unit/test_rules_loader.gd`, suite exit 0 at **Scripts 7 / Tests 62 / Passing 62 / Asserts 473** with the collected-script count equal to the `test_*.gd` count on disk. **ALL §14 M0 deliverables built:** Godot project, GUT wired, `run_tests.sh`, RulesLoader + `ruleset.json`, EventBus (M0-T3), CI script (M0-T4: `tools/ci.sh` + `tools/typecheck.sh` + the `project.godot` §11.3 gate), `decisions.md`. M0-T5 closed the last open item: the false-green mode *inside* the signal that reports clause (a) (decisions.md M0-T5, correcting M0-T4 item (i)). |
| M1 World | **DONE** (opened 2026-08-04 by M1-T1; **closed 2026-08-04 by M1-T9**) | **ALL 3 of 3 §14 M1 acceptance criteria MET *and* ALL 5 of 5 §14 M1 deliverables BUILT — both re-checked against the §14 row (line 1097) at Land this iteration** — (a) *golden mapgen test (seed ⇒ terrain hash)*: **MET headless** (M1-T5 — `tests/golden/test_mapgen_golden.gd` + `tests/golden/mapgen_concentric_bowl_small_seed1337.json`, radius 24 / 1,801 hexes / seed 1337 ⇒ `content_hash` `0xcad24923`, the value measured three times independently; the test fails loudly and never auto-records when the file is absent, and six adversarial probes incl. a reversed roll stream and a perturbation of the shipped data all went red on demand; **untouched and still green after M1-T8**, which hashes nothing and moves neither `HexMap` storage nor the canonical order); (b) *60 fps on Medium map greybox*: **MET as of M1-T8** — measured **windowed** (per decisions.md M1-T6 **(Z)** it is **not headless-measurable at all**: the `--headless` dummy renderer stores no MultiMesh instance data and draws nothing), unattended, **twice**, on `scenes/Main.tscn` at boot defaults — **hexes=3169** (Medium, radius 32) / **chunks=65** / **SDFGI off** / 1600×900 / auto-orbiting: **`fps_min=144.00 fps_avg=144.00 fps_max=144.00` in both vsync-capped runs (144 Hz panel), and 236 / 357 / 395 / 608 fps uncapped** on an i7-14700HX + RTX 4070 Laptop. Logged in full at decisions.md M1-T8 **with its caveat** (at §9.1's widest legal framing only 8–9 of the 65 chunks are in frustum; the whole ≈1150 m map cannot be framed inside §9.1's 60 m zoom ceiling, which was **not** widened); (c) *LOS property tests*: **MET headless** (M1-T3 — `tests/unit/test_los.gd`, 8 property sweeps incl. symmetry/reflexivity/all-open/adjacency/agreement/monotonicity over the 3,721 ordered pairs of the radius-4 disc, all green, and three adversarial mutation probes proved the subtlest pins load-bearing). **The milestone is MARKED DONE as of M1-T9: §14 M1's five deliverables are all built and its three acceptance criteria all pass headless** (criterion (b) measured windowed, because per **(Z)** it is not headless-measurable at all). A milestone closes only when its deliverables **and** its acceptance criteria are both satisfied — as of this commit both are. **Deliverables built: HexMath COMPLETE, both slices** (`scripts/core/hex_math.gd` — slice 1: axial/cube conversion, the fixed 6-direction table, neighbours/opposites, cube distance, radius membership, hex count; slice 2 (M1-T2): exact-integer `cube_round_scaled`, `line`, `ring`, `hexes_in_range` + the private `_floor_div`); **`Los` COMPLETE** (M1-T3, `scripts/core/los.gd` — the §4.1 blocking predicate, exactly two public functions over injected terrain `Callable`s, resolutions (H)–(L)); **concentric-bowl generator COMPLETE, both slices** (M1-T4 slice 1 + M1-T5 slice 2 — `scripts/core/rng.gd`, `scripts/sim/hex_map.gd`, `scripts/sim/map_generator.gd`, `data/mapgen/concentric_bowl.json`: the hex container with its pinned canonical order and terrain-type field, the §4.4 band/terrace rules and the §4.4 composition rule all as pure integer math, the single seeded `Rng`, and `content_hash` (FNV-1a 32-bit); resolutions (M)–(U)); **chunked MultiMesh renderer COMPLETE, both slices** (M1-T6 slice 1 — `scripts/render/hex_layout.gd` + `data/render/greybox.json`: flat-top hex→world placement on the XZ plane, the axial-square chunk partition with true floor division and (O)-matching key order, and the (P)-mirroring `RulesError` load contract; resolutions (V)–(Z), 44 tests. M1-T7 slice 2 — `scripts/render/map_renderer.gd` + `data/render/terrain_palette.json`: the project's **first `Node`** (`class_name MapRenderer extends Node3D`), one `MultiMeshInstance3D` per chunk in canonical order, ONE shared hexagonal `CylinderMesh` + ONE shared `StandardMaterial3D` for the whole renderer, per-instance transforms and type/tint custom data written from `HexLayout`/`HexMap`, the in-place dirty-chunk rebuild seam M2's dig will call, and the (AF) palette load contract reusing `RulesError`; resolutions (AA)–(AH), 43 tests, six adversarial probes). **camera rig COMPLETE, plus the project's first scene** (M1-T8 — `scripts/render/camera_rig.gd` + `data/render/camera.json`: the §9.1 orbiting rig with yaw **wrapping** into [0,360), pitch/zoom **clamping inclusively** to the printed 15–80° / 8–60 m bands read from data, the derived `looking_at` transform, camera-relative ground pan, the (AL) `RulesError` load contract and a thin WASD/Q-E/R-F/wheel/edge-pan input layer; `scripts/render/greybox_boot.gd` + `scenes/Main.tscn` — the project's **FIRST scene**, `run/main_scene` now set, `WorldEnvironment` with **SDFGI explicitly off**, a lit `DirectionalLight3D`; and the **flat-top correction yaw** in `MapRenderer` that M1-T7 item 16 owed; resolutions (AI)–(AP), 67 tests, seven adversarial probes). **hex picking COMPLETE — the last deliverable, and the one that CLOSES M1** (M1-T9 — `scripts/render/hex_picker.gd`, a pure `RefCounted` with **exactly five public functions and zero public vars**: the (AR) algebraic inverse of (W) reusing `HexMath.cube_round_scaled` for the cube repair, the (AS) ray/plane intersector, the (AQ) elevation-layered pick scanned **top-down** with an explicit empty-Array "no hex", and the thin `pick_from_screen` `Camera3D` adapter; resolutions (AQ)–(AT), 37 tests, thirteen adversarial probes of which **two found weak TESTS rather than weak code** and were fixed at Verify). |
| M2 Dig & Economy | **in progress** (opened 2026-08-04 by M2-T1; spine landed by M2-T2; unit roster landed by M2-T4; `DigHex` + the dig-site registry landed by M2-T5; `CancelDig` landed by M2-T6; **the TICK + yield application + the hex-becomes-Cave transition landed by M2-T7**) | **1 of 3 §14 M2 acceptance criteria met — the milestone is NOT done, and this row was RE-CHECKED against the §14 M2 row (`docs/GAME_DESIGN.md` line 1102) at Land this iteration; the printed criterion text is unchanged.** (a) *"Scripted 20-turn dig scenario matches expected stockpiles exactly"* — **MET as of M2-T7, the first M2 criterion to fall**: `tests/sim/test_dig_scenario.gd` scripts **20 turns / 45 commands / 2 players / 7 workers / 6 targets** over a mix of §4.2 rows including **two vein rows** and a **multi-digger** site, and asserts **HAND-COMPUTED LITERAL** stockpiles derived from §4.2's printed table — **never read back from `DigRules`**, which would make the test a tautology — for **every** §5.1 resource id **including the zeroes**: player 0 → food **1** / gold **25** / stone **4** (iron, magestone, mithril **absent**), player 1 → iron **10** / magestone **15** / stone **1** (food, gold, mithril **absent**), plus a six-checkpoint turn-by-turn timeline. Verify re-derived both columns from the table independently and they agree. (b) *"deficit-bleed test"* — **NOT met**: §3.4 step 2's *"every unpaid unit loses 10% max HP this turn"* needs units and upkeep, neither of which exists; what M2-T1 **did** pin is the half of §3.4 step 2 that constrains the stockpile — `spend` refuses **atomically** rather than going negative, because a shortage is paid in HP (decisions.md **(AU)** item 2). (c) *"zone assigns nearest idle worker"* — **NOT met**: no zones, no workers. **Deliverables built so far, of the §14 M2 list** (*"Workers, Dig/Cancel commands, yields, vein nodes + Extractors, stockpiles/income/upkeep, housing, Mining Zones v0"*): **stockpiles, plus — as of M2-T3 — the *yields* LOOKUP TABLE (see the M2-T3 paragraph at the end of this cell)** — `scripts/sim/player_state.gd` (opaque §5.1 resource ids, atomic non-negative `spend`, zero entries removed, ascending-id canonical order, 64-bit amounts) and `scripts/sim/game_state.gd` (§11.1's single serializable state: map + index-stable player roster + **the ONE** `state.rng`, with a reproducible `content_hash`) on the shared `scripts/core/fnv.gd` FNV-1a fold. Also landed: the **§12.1 `dig_yields.artificial_granite` amendment** (value **2**, governed by §4.2's `Artificial Granite \| 3 (owner: 1) \| \+2 Stone` row) — the M0-T2 item-10 forward gap, now closed in `data/ruleset.json` as a **required, line-numbered-validated** leaf **and** in the §12.1 table cell itself (decisions.md **(AU)** item 1; the one sanctioned GDD edit, made by Land in the M2-T1 commit). **M2-T2 added the §11.1 SPINE those deliverables will hang on — infrastructure, not a §14 M2 deliverable line-item, and it moves no acceptance criterion:** `scripts/sim/commands/command_error.gd` (a NEW error type, deliberately not `RulesError` — decisions.md **(AV)(i)**), `scripts/sim/commands/command.gd` (the §11.1 base — `command_name`/`validate`/`apply` plus **`execute`, the ONE gate** that welds validate → apply → `EventBus.emit_all` so nothing can apply without validating, **(AV)(ii)**), `scripts/sim/commands/end_turn_command.gd` (the project's FIRST real Command, one of §11.1's fourteen printed names, carrying §3.3's rotation `next = (current + 1) % n` with `turn += 1` only on the wrap to 0), `scripts/sim/events/turn_ended_event.gd` (the project's **FIRST concrete `Event` subclass**, `&"turn_ended"`), and §3.3's **turn position** on `GameState` (`turn()` / `current_player_index()` / the total+atomic `set_turn_position()`, folded into `content_hash()` — **the fold order is AMENDED, see (AV)(vi)**). **§11.1's replay clause is now PROVEN, not merely intended**: `tests/sim/test_turn_replay.gd` (the project's first tier-2 suite) shows two fresh states on the same seed fed the same `command_log` agree on `content_hash()` **at every step**, that the log replays identically 3×, and that a rejected command changes nothing. **NO GOLDEN was recorded and §13.2 tier 3's golden is OWED, NOT FORGOTTEN — (AV) item 7.** **Not built, deliberately (§13.4, decisions.md (AV) item 9):** the other **thirteen** §11.1 commands, `Command.to_dict()`/serialization and a `CommandLog` (M7), §3.4's nine per-player steps and three World-phase steps (pinned **negatively** by test), §3.2/§12.1's `victory.turn_limit` and victory checks (M6), workers, dig progress, yield application, vein nodes, Extractors, income, upkeep, housing, Mining Zones, §3.1's starting kit (which needs its own §12.1 key and amendment), and any `EventBus` → `MapRenderer.mark_hex_dirty` wiring. **M2-T3 added the FIRST HALF of §14 M2's *"yields"* deliverable — the §4.2 dig TABLE as a pure lookup, not its application, and it moves NO acceptance criterion:** `scripts/sim/systems/dig_rules.gd` (`class_name DigRules extends RefCounted`, the project's first `scripts/sim/systems/` file — §11.2 line 724 prints that directory verbatim) answers §4.2's whole Solid-hex dig paragraph **entirely from loaded data** — `is_diggable` (true for exactly the nine printed Solid rows), `dig_turns_for(terrain_id, by_owner)` (1/2/4/3/1/2/2/2/4 with the §7.1 owner variant `artificial_granite → 1`, inert on the other eight rows), `yield_resource_ids` + `yield_amount` (food 1 · stone 2/4/2/1 · the four vein lumps gold 25 / iron 10 / magestone 15 / mithril 10), `vein_resource_id` (the four *"+ node"* rows only — **node STATE and Extractors are a LATER slice**, decisions.md **(AW)** item 4), `max_diggers_per_hex` (§4.2 line 197's *"max 2 simultaneous diggers per hex"*) and `halve_remaining_turns` (line 197's *"Dig 2× halves remaining time (round up)"* = ceil(n/2), **fixed point at 1**). **THE PROJECT'S SECOND §12.1 AMENDMENT landed with it** — a new top-level `dig` group in `data/ruleset.json` (line 5, one line) = `{max_diggers_per_hex: 2, profiles: {nine §4.2 terrain ids → turns_key / owner_turns_key / yield_key / vein_key}}`, i.e. **the binding between §4.2's terrain-id vocabulary and §12.1's dig-key vocabulary, put in DATA precisely so it is not a whitelist in engine code** ((T)/(AH)/(AU)(iv), and §13.5's M6 canary); the §12.1 excerpt gained the one new key line, edited by Land in the M2-T3 commit, and **§4.2's table is byte-unchanged**. `RulesLoader` grew (purely additively) a new **`map` spec kind** — author-chosen keys validated against one shared entry spec, keys visited in **ASCENDING sorted order** so `errors` stays deterministic, rejecting both a non-object and an **empty** `profiles` — and the public accessor `get_keys(dotted_path)` (ascending, fresh per call, total). **NO Command, NO GameState mutation, NO Event** — pinned negatively, and `tests/sim/test_turn_replay.gd` is untouched and still green. **M2-T4 added the §11.1 line-704 UNIT ROSTER — the CONTAINER half of §14 M2's *"Workers"* deliverable, and it moves NO acceptance criterion:** `scripts/sim/unit_state.gd` (`class_name UnitState extends RefCounted`, **new**, 146 lines) is one unit INSTANCE as a pure record — stable id, **owner player index** (units are a **TOP-LEVEL** `GameState` collection per §11.1 line 704, **never** a `PlayerState` field, and `tests/unit/test_player_state.gd` is byte-untouched and still green), the **opaque** §12.2 `type_id`, an axial `Vector2i` position, and `hp`/`max_hp` with a **TOTAL clamping** `set_hp` (overheal saturates, overkill floors, **0 hp does NOT remove the unit** — that is a later RULE) — exactly **nine** public functions plus `_init`, **zero public vars, zero public consts**, and a documented FNV fold — `unit_id` → `owner_index` → `hex.x` → `hex.y` → `hp` → `max_hp` → `type_id`'s UTF-8 bytes → the private `_SEPARATOR` (fixed-width fields first, the one variable-length field LAST, so the record is injective by construction). `scripts/sim/game_state.gd` (**+143 lines**) gained the roster itself: a private `_units` Dictionary (keyed by int id, **never iterated for output**) + `_next_unit_id`, and six public functions — `spawn_unit`, `unit`, `unit_ids`, `units_of`, `units_at`, `remove_unit` — each **total**, each list accessor sorting a **fresh copy** of the keys and returning a **fresh Array** every call (`units_of`/`units_at` are **linear scans** over `unit_ids()`; **no reverse index**), `unit(id)` returning the **SAME object** every call. **IDS START AT 1, ADVANCE ONLY ON A SUCCESSFUL SPAWN AND ARE NEVER REUSED** (0 means *"no unit"* — an algorithmic constant, the (AJ) precedent, **not** a §12.1 key); **every refusal is ATOMIC and BURNS NO ID** (owner outside `0..player_count()-1`, empty `type_id`, non-positive `max_hp`). **Placement is NOT validated** (`map` is never consulted; §6.4 stacking legality is M4) and **neutral ownership is deliberately NOT modelled** (§8.1/§3.2 need an explicit sentinel at M5 — never a silent -1). The `content_hash` fold was **EXTENDED BY APPENDING ONLY** — `_next_unit_id` → unit count → per ascending id (the id, then that unit's hash) — so *"spawned 3 then removed all 3"* cannot hash like *"never spawned"*; **no existing fold step was renamed or reordered**, and the unit-count step is a **knowingly EQUIVALENT MUTANT** kept for symmetry (the (AU) item 11 precedent — do not chase it). **NO Command, NO Event, NO data key, NO rule** — §13.6's *events* clause is **VACUOUS** here and said to be so ((AX) item 10); `tests/sim/test_turn_replay.gd` is untouched and green, `scripts/sim/commands/` and `scripts/sim/events/` gained no file, `data/ruleset.json` and `docs/GAME_DESIGN.md` are **byte-unchanged**, and **no golden was recorded** (still OWED — (AX) item 11). **M2-T5 added SLICE 3a of the dig chain — the FIRST HALF of §14 M2's *"Dig/Cancel commands"* line (`DigHex` only), and the FIRST M2 task that mutates state through a `Command`; it still moves NO acceptance criterion:** `scripts/sim/dig_site.gd` (**new**, 128 lines / 51 code — `class_name DigSite extends RefCounted`, the dig-site PROGRESS RECORD: `hex`, `owner_index`, `total_turns`, `remaining_turns` + a TOTAL clamping `set_remaining_turns`, a **fresh ASCENDING** `digger_ids()`, `add_digger`/`remove_digger`, `content_hash` — exactly **nine** public functions, **zero** public vars/consts, identity **read-only**, and **NO digger cap** because the cap is the Command's rule), five new `GameState` registry functions over a private `_dig_sites` Dictionary (`add_dig_site` — TOTAL, every refusal **ATOMIC**, and validating **nothing** about placement/terrain exactly as `spawn_unit` does not; `dig_site` — the **SAME object** every call; `dig_site_hexes` — **FRESH** every call in the canonical order **r ascending then q ascending** through an explicit private `_hex_before` comparator, **never** `Vector2i`'s default `<`, which sorts x first; `dig_site_of_digger` — a **LINEAR SCAN**, no reverse index; `remove_dig_site`), `scripts/sim/commands/dig_hex_command.gd` (**new**, 147 lines / 79 code — **the SECOND of §11.1 line 705's fourteen printed commands**, an immutable value object, the first consumer of **both** `DigRules` and the unit roster, carrying §4.2 line 197's **adjacency** (cube distance exactly 1 via the named private `_ADJACENT_DISTANCE`, all six §4.1 neighbours accepted) and **max-2-diggers** cap (read from §12.1 `dig.max_diggers_per_hex` through `DigRules` — the literal `2` is a **forbidden token**), an **eleven-code** rejection vocabulary in a fixed precedence (`null_state` → `no_map` → `no_players` → `not_current_player` → `no_such_unit` → `not_your_unit` → `unit_not_adjacent` → `not_diggable` → `site_not_yours` → `already_digging` → `dig_site_full`, each authored at its own call site), and the **§7.1 ownership SEAM** `_digs_own_terrain` — the **only** caller of `dig_turns_for`, answering `false` unconditionally today because **no hex carries a builder index** and §7.1's Raise Granite is **M3/M4**, so Artificial Granite comes out **3**, never 1) and `scripts/sim/events/dig_started_event.gd` (**new**, 64 lines / 30 code — **the project's SECOND concrete `Event` subclass**, `&"dig_started"`, emitted **exactly once** for every accepted dig order (creation **and** join) and for nothing else, with `to_dict()` calling the base **first** then flattening `hex` into `hex_q`/`hex_r` because §11.1 line 708's save is **JSON**). The `content_hash` fold was **EXTENDED BY APPENDING ONLY** again (site count → per hex in canonical order: `hex.x`, `hex.y`, that site's hash) with **no existing step renamed or reordered**, and it **deliberately DIVERGES from (AX)'s `_next_unit_id`**: *add-then-remove-every-site* **DOES** hash like *never-added*, because a dig site has **no dangling identity** to protect (asserted **positively** — (AY) item 9). **§13.6's *events* clause is LIVE for the first time in M2 and pinned in BOTH directions** (an event for every state change; an `apply()` with an unconfigured `DigRules` creates **no** site and returns an **EMPTY** array). **NO GDD edit, `data/ruleset.json` byte-unchanged, no new §12.1 key, no golden recorded** (still OWED, a **fourth** time — (AY) item 12). **M2-T6 added SLICE 3b — the SECOND HALF of §14 M2's *"Dig/Cancel commands"* line, which is now COMPLETE as an ORDERING PAIR; it still moves NO acceptance criterion:** `scripts/sim/commands/cancel_dig_command.gd` (**new**, 109 lines / **49 code** — **the THIRD of §11.1 line 705's fourteen printed commands**, an immutable value object `(player_index, unit_id)` and a **pure consumer** of what M2-T5 landed, adding **no** `GameState` and **no** `DigSite` function and **no** `data/ruleset.json` key) and `scripts/sim/events/dig_cancelled_event.gd` (**new**, 65 lines / **30 code** — **the project's THIRD concrete `Event` subclass**, `&"dig_cancelled"`, payload `player_index`/`unit_id`/`hex`/`remaining_turns`/`site_removed`, `to_dict()` base-first with `hex` flattened to `hex_q`/`hex_r`). **§4.2 PRINTS NOTHING ABOUT CANCEL, so four rules are §13.4 judgment calls logged under decisions.md (AZ):** (i) **cancel is UNIT-targeted, not hex-targeted** — `dig_site_of_digger(unit_id)` has exactly one answer by (AY)(iv)'s *one job per unit*, so the command takes **no hex and no `DigRules`** and is the exact inverse of `DigHex`; (ii) **the LAST digger leaving REMOVES the site and its progress is LOST** — an ownerless site would be un-startable by anyone (`site_not_yours`) while §5.3's Mining Zones re-issue Dig commands every turn, i.e. a **deadlock**, and §1.1 pillar 1 makes a dig a **commitment, not a free undo**; (iii) **a NON-last cancel leaves `remaining_turns`/`total_turns`/`owner_index` UNCHANGED** and the site alive (crew size is not progress); (iv) **`no_map` is deliberately NOT a code** — a cancel reads no terrain, so `state.map` is never consulted, pinned **POSITIVELY** by a mapless `GameState` that cancels successfully **and** by two source scans. The rejection vocabulary is **SIX** opaque `StringName`s, each at its own call site, in the precedence `null_state` → `no_players` → `not_current_player` → `no_such_unit` → `not_your_unit` → **`not_digging`** (the one genuinely new code, the exact inverse of `already_digging`), with **two** load-bearing orderings pinned (`no_players` before `not_current_player`; **`not_your_unit` before `not_digging`**, so an enemy's dig state never leaks through an error code). **The `content_hash` fold was NOT extended and NO `GameState` field was added** — which is why **no golden re-record was triggered and none was due** (still OWED, a **fifth** time — (AZ) item 9; slice 4 records it). §13.6's *events* clause pinned in **both** directions again (exactly one `DigCancelledEvent` per accepted cancel and nothing else; `apply()` on a unit with no site changes nothing and returns an **EMPTY** array). **NO GDD edit, `data/ruleset.json` byte-unchanged, `scripts/core/event.gd`/`event_bus.gd`/`game_state.gd`/`dig_site.gd`/`dig_rules.gd`/`dig_hex_command.gd` all byte-unchanged.** **Still NOT built after M2-T6:** §12.7's **trait set** (worker-ness is a TRAIT = DATA; there is **no worker CLASS** and no `is_worker()`, and **any** unit type may be assigned a dig or cancelled today), the dig **TICK**, yield **application**, the hex-becomes-Cave transition and the `EventBus` → `MapRenderer.mark_hex_dirty` wiring (**slice 4, M2-T7**), §4.2's *"Dig 2×"* halving (`halve_remaining_turns` has **no caller**), §7.1's Raise Granite and any hex-builder storage, vein-node stock/rate, Extractors, income, upkeep, §5.2's housing cap (`housing.hq` shipped and **unused**), Mining Zones, §3.1's starting kit, `data/units/*.json` stat blocks (M6), command/unit serialization (M7), movement/combat/damage and all twelve §3.4 steps. **M2-T7 added SLICE 4 — THE TICK — and it is the FIRST M2 task to MOVE AN ACCEPTANCE CRITERION (criterion (a), above), and the task that COMPLETES the §14 M2 deliverable line *"yields"* (the table landed at M2-T3; its APPLICATION lands here):** `scripts/sim/systems/dig_tick.gd` (**new**, 93 lines / **41 code** — `class_name DigTick extends RefCounted`, the project's **second** `scripts/sim/systems/` file and §3.4 **step 4** built as printed for the first time; **one** public function `tick_digs(state, player_index) -> Array[Event]`, **zero** public vars/consts; called **only** from `EndTurnCommand.apply()` — a turn-sequence rule, **not** a fourth of §11.1 line 705's fourteen printed commands), `scripts/sim/events/dig_progressed_event.gd` (**new**, 54 lines / **26 code** — the project's **FOURTH** concrete `Event` subclass, `&"dig_progressed"`, one per site whose remainder actually moved, carrying the **POST-tick** remainder) and `scripts/sim/events/dig_completed_event.gd` (**new**, 71 lines / **34 code** — the **FIFTH**, `&"dig_completed"`, carrying the owner index, hex, freed digger ids **ascending**, yielded resource ids **ascending** + amounts, and the new terrain id, so the yield **and** the terrain flip are both observable; it **copies** its three arrays on construction **and** hands out **duplicates** from `to_dict()`, both pinned with `is_same`), plus **40 changed lines** across `end_turn_command.gd` (an optional injected `DigRules`, `_init(p_player_index: int, p_dig_rules: DigRules = null)`), `dig_rules.gd` (one accessor `cave_terrain_id()`), `rules_loader.gd` (one spec entry) and `data/ruleset.json`: **218 new + 40 changed production lines**, inside the ≤ ~300 LOC ceiling — so the spec'd contingency split (tick now, completion + golden at M2-T8) was **measured and correctly NOT taken**, which is why the golden did **not** slip a sixth time. **THE RULE (decisions.md (BA)):** §3.4 step 4 runs **inside `EndTurnCommand.apply()`, AFTER the §3.3 rotation, for the INCOMING player** ((BA)(i) — the recorded consequence is that **player 0's very first turn of a match runs NO start-of-turn steps**, pinned by test); **only** sites whose `owner_index()` equals that player tick, so each site ticks **exactly once per full round** ((BA)(ii)); a site spends **`digger_ids().size()`** worker-turns per tick, never a fixed 1 (§4.2 line 197's **TOTAL worker-turns** — Hard Rock 2 finishes in **two** ticks with one digger and **one** with two; Dense Granite goes 4 → 2 → 0), with the **overshoot settled by `DigSite.set_remaining_turns`'s existing clamp, not a branch** — Soft Dirt (total 1) worked by two diggers lands on exactly 0 and yields **+1 Food EXACTLY ONCE** ((BA)(iii)); completion = the remainder reaching 0 **after** the decrement, applying the row's §4.2 yield to the **SITE'S OWNER's** stockpile (**never** *"the current player"* — pinned discriminatingly by a direct `tick_digs(state, 1)` call while the current index is 0), flipping the hex to `DigRules.cave_terrain_id()`, removing the site, and freeing the diggers **IMPLICITLY** (assignment **is** site membership — **no `UnitState` is mutated by a completion**; every digger keeps its hp and hex) ((BA)(iv)); **TWO** events, not four, **progress ALWAYS first** ((BA)(vi)); and an **unconfigured** `DigRules` — null **or** `DigRules.new(null)` — runs **no pass at all** ((BA)(vii), the second shape being a deliberate `cave_terrain_id().is_empty()` sentinel, because without it a one-turn site would "complete" with an empty yield and a hex flipped to `""`). **THE PROJECT'S THIRD §12.1 AMENDMENT landed with it** — required, line-number-validated string leaf `dig.cave_terrain_id` = **`"plain_floor"`** on the existing `dig` group (`data/ruleset.json` line **5**, group still on **ONE line** — `test_rules_loader.gd` pins `DIG_LINE == 5`), named from §4.2's Cave-hex table row *"Plain floor"* in the existing snake_case convention, reached through **one** new `DigRules` accessor so **no terrain id is ever named in engine code** (`dig_tick.gd`'s own scan makes `"plain_floor"`, `"cave"`, all nine §4.2 terrain ids, all six §5.1 resource ids and every §4.2 number a **forbidden token**, permitting only the standalone numerals **0** and **1**); the §12.1 excerpt cell (`docs/GAME_DESIGN.md` line **788**) was edited by **Land in the M2-T7 commit**, and **§4.2's table is byte-unchanged — no printed NUMBER moved**. **AND THE §13.2 TIER-3 GOLDEN IS RECORDED AT LAST, closing a debt restated FIVE times ((AV) 7, (AW) 5, (AX) 11, (AY) 12, (AZ) 9):** `tests/golden/test_dig_tick_golden.gd` + `tests/golden/dig_tick_scenario_seed4242.json`, `content_hash` **`"0xb0629468"`** (a **LOWERCASE 8-hex-digit STRING**, never a JSON number — Godot 4.7 parses every JSON number as `TYPE_FLOAT`) for seed **4242** / radius **2** / **2** players / **45** commands / **20** turns; it **fails loudly saying "is MISSING"**, prints recorded-vs-observed and the exact document to write, and has **NO record-mode flag by design** — and the hash the RED run printed (`0x1ccf2c23`) was the **STUB's** and was deliberately **not** recorded. It is a **FIRST RECORDING, not a re-record** (`goldens_rerecorded: false`), and Verify proved it live: it reds under a rules mutation **and** under deletion. **§13.6's *events* clause pinned in BOTH directions again** (an `EndTurn` with no dig sites emits **only** the `TurnEndedEvent` and leaves `content_hash()` **byte-identical**; `TurnEndedEvent` stays **FIRST** in the returned array). **FOUR pre-existing negative pins were RE-SCOPED and strictly STRENGTHENED, never deleted** (the (AZ)(vi) rule, honoured for the first time by a slice other than the one that wrote it), and `tests/sim/test_turn_replay.gd` gained a whole **section E** replaying a **TICKING** log that **completes a dig inside the replay**. **Still NOT built after M2-T7:** the `EventBus` → `MapRenderer.mark_hex_dirty` seam and a palette tint for `plain_floor` (**M2-T8** — the only thing deferred from M2-T7's own spec), §12.7's **trait set** (worker-ness is a TRAIT = DATA; **any** unit type may still dig), §4.2's *"Dig 2×"* halving (`halve_remaining_turns` **still has no caller**), **vein-node stock/rate** and **Extractors** ((BA) item 8 — a vein dig pays only its §4.2 **LUMP** and the node is dropped with the terrain, pinned **positively**), §7.1's Raise Granite and any hex-builder storage, income, upkeep and §3.4 step 2's deficit bleed, §5.2's housing cap, Mining Zones, §3.1's starting kit, `data/units/*.json` stat blocks (M6), command/unit serialization (M7 — which must **re-inject** `DigRules` into `EndTurnCommand`, (BA) item 7), movement/combat/damage, and §3.4's **other eight** per-player steps and **three** World-phase steps (including step 4's own **Breach checks (§4.6)** and **Noise pings (§4.8)**, M5, pinned negatively by `rng.rolls_drawn()` still **0**). |
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
| 2026-08-04 | M2-T2 | Command spine: Command base, CommandError, EndTurnCommand, first concrete Event and the replay-hash proof (**the §11.1 spine — the project's first Command, first concrete `Event` subclass, first `tests/sim/` suite and the first MEASURED proof that `(seed, command_log)` replays to an identical hash; no GDD cell edited, no golden recorded**) | landed | M2-T2: Command spine: Command base, CommandError, EndTurnCommand, first concrete Event and the replay-hash proof |
| 2026-08-04 | M2-T3 | DigRules: data-driven dig times, owner variant and dig yields (**§4.2's whole dig table as a pure lookup; opens `scripts/sim/systems/`; the project's SECOND §12.1 amendment — the new `dig` group binding §4.2 terrain ids to §12.1 dig keys IN DATA — plus the `RulesLoader` `map` spec kind and `get_keys`; one GDD §12.1 line added by Land, §4.2's table byte-unchanged; no Command, no state mutation, no golden recorded**) | landed | M2-T3: DigRules: data-driven dig times, owner variant and dig yields |
| 2026-08-05 | M2-T4 | UnitState and the GameState unit roster with stable ascending ids (**§11.1 line 704's TOP-LEVEL unit collection as a pure CONTAINER — the new `UnitState` record plus six `GameState` roster functions; ids from 1, never reused, every refusal atomic and burning no id; the `content_hash` fold EXTENDED BY APPENDING ONLY; `GameState`'s exact public surface grown 8 → 14 in this same commit; NO Command, NO Event, NO data key, NO rule — §13.6's events clause vacuous and said so; NO GDD edit, `data/ruleset.json` byte-unchanged, no golden recorded**) | landed | M2-T4: UnitState and the GameState unit roster with stable ascending ids |
| 2026-08-05 | M2-T5 | DigHexCommand, dig-site progress state and the first dig event (**slice 3a of the dig chain — the dig chain's slice 3 was RE-SLICED here, `CancelDigCommand` + `DigCancelledEvent` become M2-T6; the new `DigSite` progress record + five `GameState` registry functions + `DigHexCommand` (the SECOND of §11.1 line 705's fourteen printed commands, first consumer of `DigRules` AND the unit roster, eleven-code rejection vocabulary, §4.2 line 197's adjacency + max-2-digger rules, the §7.1 ownership SEAM answering `false` until Raise Granite at M3/M4) + `DigStartedEvent` (the project's SECOND concrete `Event` subclass); the `content_hash` fold EXTENDED BY APPENDING ONLY again, deliberately DIVERGING from (AX) — add-then-remove-every-site hashes like never-added; `GameState`'s exact public surface grown 14 → 19 in this same commit; §13.6's events clause LIVE for the first time in M2 and pinned in BOTH directions; NO GDD edit, `data/ruleset.json` byte-unchanged, no new §12.1 key, no golden recorded — still OWED a fourth time**) | landed | M2-T5: DigHexCommand, dig-site progress state and the first dig event |
| 2026-08-05 | M2-T6 | CancelDigCommand, dig cancellation and the third printed command (**slice 3b of the dig chain — the "Dig/Cancel commands" ORDERING PAIR is now complete; `CancelDigCommand` (the THIRD of §11.1 line 705's fourteen printed commands, unit-targeted, six-code rejection vocabulary with `not_digging` the one new code) + `DigCancelledEvent` (the project's THIRD concrete `Event` subclass); the four rules §4.2 does NOT print resolved and logged under (AZ) — unit-targeted cancel, LAST digger removes the site with its progress LOST, a partial cancel leaves `remaining_turns` UNCHANGED, and `no_map` deliberately ABSENT and pinned positively; NO `GameState`/`DigSite` function added (surfaces stay at 19 and 9), the `content_hash` fold NOT extended, so no golden re-record was triggered — the tier-3 golden is still OWED a fifth time and slice 4 records it; the two slice-3a scoped pins RE-SCOPED and strictly STRENGTHENED, never weakened; NO GDD edit, `data/ruleset.json` byte-unchanged; Verify's eight-probe mutation battery caught all eight**) | landed | M2-T6: CancelDigCommand and DigCancelledEvent (dig chain slice 3b) |
| 2026-08-05 | M2-T7 | Dig tick and completion: yields applied, hex becomes Cave, plus the owed tier-3 golden (**slice 4 of the dig chain — THE SLICE WHERE THE DIG CHAIN FINALLY MOVES A NUMBER, and the FIRST M2 task to MEET a §14 acceptance criterion: (a) "Scripted 20-turn dig scenario matches expected stockpiles exactly" is MET, so M2 goes 0/3 → 1/3, and the deliverable line "yields" is COMPLETE (table M2-T3 + application here); new `DigTick` (§3.4 step 4 as a pure `RefCounted` rule module called from `EndTurnCommand.apply()` for the INCOMING player after the §3.3 rotation — N diggers spend N worker-turns per tick per §4.2 line 197, completion credits the SITE'S OWNER, flips the hex to the data-supplied Cave terrain, removes the site and frees its diggers implicitly with NO `UnitState` mutated) + `DigProgressedEvent` and `DigCompletedEvent` (the project's FOURTH and FIFTH concrete `Event` subclasses, progress ALWAYS before completion); `EndTurnCommand` gained an OPTIONAL injected `DigRules` (a null/unconfigured one ticks nothing — pinned in BOTH directions, and both shapes of "unconfigured" handled); THE PROJECT'S THIRD §12.1 AMENDMENT — required string leaf `dig.cave_terrain_id` = "plain_floor", one GDD §12.1 excerpt line edited by Land in this same commit, §4.2's table byte-unchanged; THE §13.2 TIER-3 GOLDEN RECORDED AT LAST — `dig_tick_scenario_seed4242.json`, content_hash "0xb0629468" — closing a debt restated at (AV) 7, (AW) 5, (AX) 11, (AY) 12 and (AZ) 9, a FIRST recording and not a re-record; production measured at 218 new + 40 changed lines so the spec'd contingency split was correctly NOT taken; four negative pins RE-SCOPED and STRENGTHENED, never deleted; resolution (BA), ten lettered sub-items; Verify's eight-probe mutation battery caught all eight and made NO fix for the sixth iteration running**) | landed | M2-T7: Dig tick and completion: yields applied, hex becomes Cave, plus the owed tier-3 golden |
| 2026-08-05 | SETUP-6 | game.bat launcher + free_run play mode (`scenes/Play.tscn`); measurement contract (AO) unchanged | landed | SETUP-6: game.bat launcher and free_run play mode |

## Notes for the next iteration

- **Pick up: M2-T8 — the RENDERER SEAM the tick owes, and then the NEXT §14 M2 ACCEPTANCE
  CRITERION. M2 IS OPEN, NOT DONE — but it is no longer at zero: 1 of 3** (M2-T1 landed the
  state container, M2-T2 the §11.1 spine, M2-T3 §4.2's dig **table**, M2-T4 the §11.1 unit
  **roster**, M2-T5 the dig-site **registry** + `DigHexCommand` + `DigStartedEvent`, M2-T6
  `CancelDigCommand` + `DigCancelledEvent`, and **M2-T7 the TICK + the yield APPLICATION + the
  hex-becomes-Cave transition + the tier-3 GOLDEN**, which **MET criterion (a)**). The tree is green
  and **nothing is carried over** — M2-T7 left no blocker and Verify made no fix (**sixth**
  iteration running with an empty `fixes_made`). **M2-T7 DID edit the GDD**, for the first time
  since M2-T3: one §12.1 excerpt line (**line 788**, the `dig` group, which gained
  `"cave\_terrain\_id": "plain\_floor"`), by Land, in the same commit as the **(BA)** entry. **§4.2's
  table is byte-unchanged — no printed NUMBER has ever moved in this project.**
  - **THE DIG CHAIN IS COMPLETE AS A RULE. ALL FOUR SLICES HAVE LANDED — DO NOT RE-OPEN THEM,
    AND DO NOT PULL THE THINGS THEY DEFERRED FORWARD WITHOUT A DECISIONS ENTRY.** (1) the §4.2 dig
    **table** — **DONE, M2-T3** (`DigRules`); (2) the unit **roster** on `GameState` — **DONE,
    M2-T4** (`UnitState` + six roster functions); **(3a) `DigSite` + the dig-site registry +
    `DigHexCommand` + `DigStartedEvent` — DONE, M2-T5** (the §7.1 ownership determination is a
    **single private seam**, `_digs_own_terrain`, the **only** caller of `dig_turns_for` —
    decisions.md **(AY)** item 2; §4.2 line 197's **max-2-diggers cap** is counted from
    `DigSite.digger_ids()`, **not** from `units_at`, because a *digger* is an assignment, not a
    location); **(3b) `CancelDigCommand` + `DigCancelledEvent` — DONE, M2-T6** (the four rules §4.2
    does not print, settled at **(AZ)** — **cancel is UNIT-targeted**, the **LAST digger leaving
    removes the site and its progress is LOST**, a **partial cancel changes nothing but the crew**,
    and **`no_map` is deliberately not a code**); **(4) §3.4 step 4's TICK + the yield APPLICATION +
    the hex-becomes-Cave transition + the two new events + THE TIER-3 GOLDEN — DONE, M2-T7**, under
    **(BA)**. **What slice 4 deliberately left behind, and it is now M2-T8's whole first half:** the
    `EventBus` → `MapRenderer.mark_hex_dirty` seam and a `data/render/terrain_palette.json` entry
    for `plain_floor` ((AV) item 9, re-stated at **(BA)** item 16) — the tick flips a hex's terrain
    and **nothing tells the renderer**, which is a real gap and not a stylistic one. Everything
    else slice 4 named as deferred stays deferred: §4.2's *"Dig 2×"* halving
    (`DigRules.halve_remaining_turns` **still has no caller** — no ability exists), **vein-node
    stock/rate and Extractors** ((AW) item 4, **re-opened by name** at **(BA)** item 8 — a vein dig
    pays only its §4.2 **LUMP** and the node is **dropped with the terrain**, asserted
    **positively**, so the Extractor slice must **re-open** this rather than discover it), and
    §3.4's other eight per-player steps and three World-phase steps.
  - **§3.4 NOW HAS A CALL SITE, AND THE NEXT ELEVEN STEPS COPY ITS SHAPE.** `DigTick` is a rule
    **module** (`scripts/sim/systems/`), not a Command — §3.4's steps are **turn-sequence rules**,
    and inventing a `BeginTurn` command would have been inventing vocabulary outside §11.1 line
    705's fourteen printed names ((BA)(i)). `EndTurnCommand.apply()` rotates first, appends
    `TurnEndedEvent` **first**, then appends the step-4 events for the **INCOMING** player. **The
    recorded consequence to design around: player 0's very first turn of a match runs NO
    start-of-turn steps at all** — harmless today (a match starts empty), and pinned by test so that
    the slice landing §3.1's starting kit, or the World phase, sees the gap explicitly rather than
    inheriting it. **Injected rules are OPTIONAL and default to null:**
    `EndTurnCommand.new(i)` still ticks nothing, which is what let all 846 pre-existing tests keep
    compiling — and **M7's command-log deserializer must RE-INJECT a loaded `DigRules` into
    `EndTurnCommand`** exactly as (AY)(iii) already requires for `DigHexCommand`, or a replayed
    `EndTurn` becomes a **silent no-tick**, the single most dangerous shape of bug this project can
    ship ((BA) item 7).
  - **THE SPINE EXISTS: any slice that CHANGES STATE must RIDE it, never bypass it.** Every
    `GameState` mutation **must** be a `Command` subclass whose `apply` is reached only through
    `Command.execute(state, bus)` — that is the one gate, and probe P3 (applying before validating)
    reds 18 tests, so it is enforced, not merely documented. Read the **`Command` spine contract**
    bullet below and decisions.md **(AV)** before writing a line. §11.1's replay clause is now a
    **measured** property (`tests/sim/test_turn_replay.gd`), so any new Command must keep it true:
    be an **immutable value object** (all parameters in `_init`, `self` never mutated by
    `validate`/`apply`), draw randomness **only** from `state.rng`, and emit an `Event` for **every**
    state change. **M2-T3 AND M2-T4 are the sanctioned exceptions and the shape to copy for any
    future pure lookup or pure container:** `DigRules` mutates nothing and the unit roster runs no
    rule, so neither is a Command and §13.6's *events* clause is **vacuous** for both — that had to
    be **said in decisions.md** ((AW) item 8, (AX) item 10), not assumed. **The exception EXPIRED at
    M2-T5:** `DigHexCommand` is the second Command, `DigStartedEvent` the second concrete Event, and
    from here on the moment a rule decides something, it rides the spine and owes an Event.
  - **§13.2 TIER 3's GOLDEN IS RECORDED. THE DEBT IS CLOSED — AND IT IS NOW AN ASSET UNDER §13.6's
    RE-RECORD RULE, WHICH IS A DIFFERENT KIND OF OBLIGATION.** *"Fixed seed + recorded command log ⇒
    recorded `GameState.hash()` after N turns"* was deferred **five** times, correctly each time
    (M2-T2 would have frozen the fold before units/dig/income existed; M2-T3 changes no state at
    all; M2-T4 **and** M2-T5 each **extended the fold**, so an early freeze would have cost two
    re-records; M2-T6 extended nothing and so triggered nothing), and was **recordable at M2-T7 for
    exactly the reason the earlier entries predicted** — it is the first slice whose state genuinely
    **evolves over N turns**. `tests/golden/dig_tick_scenario_seed4242.json` now holds
    `content_hash` **`"0xb0629468"`** for seed **4242** / radius **2** / **2** players / **45**
    commands / **20** turns, driven by `tests/golden/test_dig_tick_golden.gd`. **Three rules travel
    with it, and they apply to `tests/golden/mapgen_concentric_bowl_small_seed1337.json`
    (`0xcad24923`) too:** (a) the hash is a **LOWERCASE 8-hex-digit STRING**, never a JSON number,
    because Godot 4.7 parses **every** JSON number as `TYPE_FLOAT`; (b) the test **fails loudly and
    NEVER auto-records** when the file is absent, prints recorded-vs-observed plus the exact document
    to write, and has **no record-mode flag, by design** — and its message must say **"is MISSING"**,
    never *"does not exist"* / *"Nothing was run"* / *"have not been imported"* / *"Failed to load
    script"* / *"Ignoring script"*, any of which trips `tools/run_tests.sh`'s diagnostic grep and
    converts an honest assertion failure into a harness error; (c) **from the M2-T7 commit forward a
    re-record is permitted ONLY with a logged reason in the same commit** (§13.6). **Any slice that
    extends the `content_hash` fold, adds a `GameState` field, or moves a §4.2/§12.1 number will
    move this hash** — expect that, log it, and never "fix" a golden to match new code without
    first proving the code is what the tables say. What exists alongside it is the §11.1 line 708
    proof, now in its third generation: `tests/sim/test_turn_replay.gd` replays a **seven-step
    MIXED** log (spawn two units → `DigHex` create → `DigHex` join → **`CancelDig`** → a full
    `EndTurn` round → `DigHex` again) **and**, as of M2-T7's **section E**, a **TICKING** 10-command
    log that **completes a dig inside the replay**, into two fresh states on the same seed — agreeing
    on `content_hash()` at **every** step and replaying identically **3×**.
  - **§14's M2 row is far bigger than one task — keep slicing it, and pick the slice that MOVES A
    CRITERION.** Deliverables: *"Workers, Dig/Cancel commands, yields, vein nodes + Extractors,
    stockpiles/income/upkeep, housing, Mining Zones v0"* (**stockpiles + the unit CONTAINER + the
    WHOLE "Dig/Cancel commands" line as an ORDERING PAIR (`DigHex` + `CancelDig`) + — as of M2-T7 —
    the WHOLE "yields" line (the TABLE from M2-T3 *plus* its APPLICATION), so far; the container is
    still not a worker, and vein nodes/Extractors, income/upkeep, housing and zones are all
    untouched**); acceptance: *"Scripted 20-turn dig scenario matches expected stockpiles exactly;
    deficit-bleed test; zone assigns nearest idle worker"* (**1 of 3 — (a) MET at M2-T7**).
    **(b) *"deficit-bleed test"* is the cheaper next criterion and the one that keeps M2 moving in
    §3.4 order:** it needs **income + upkeep + §3.4 step 2's 10 % max-HP bleed**, and both halves of
    its state already exist and are already pinned — `PlayerState.spend` refuses **atomically**
    rather than going negative *precisely because* a shortage is paid in **HP** ((AU) item 2), and
    `UnitState.set_hp` is a **TOTAL clamping** mutator where **0 hp does NOT remove the unit** (that
    is a later rule). **(c) *"zone assigns nearest idle worker"* needs §5.3 Mining Zones AND the
    §12.7 worker trait, which is DATA at M6** — so it is the more expensive of the two.
    Read **§5** (economy), **§3.4** (the turn sequence and the deficit bleed) and **§4.2** (the
    terrain/dig-yield table) alongside §14 before spec'ing the next slice.
  - **§3.1's STARTING KIT IS STILL DEFERRED AND NEEDS ITS OWN §12.1 AMENDMENT — AND IT IS NOW
    TWO-SIDED.** Every player currently starts with an **EMPTY stockpile AND an EMPTY unit roster**
    (decisions.md **(AU)** item 8, re-affirmed by **(AV)** item 9, **(AW)** item 4, **(AX)** item
    18 and **(AY)** item 18). §3.1 line 120 prints *"3 Workers, 1 basic T1 combat unit"* **and** 200 Gold / 100 Food /
    50 Stone / 20 Iron / 0 Magestone / 0 Mithril, but §12.1 has **no key for either half**, so the
    task that lands it must add a new `data/ruleset.json` key **and** a dated decisions.md entry,
    and Land must edit the §12.1 cell in that same commit — exactly the procedure M2-T1 ran for
    `dig_yields`. The unit half additionally needs the §12.2 **definitions** (`data/units/*.json`,
    **M6**) before *"1 basic T1 combat unit"* can name anything: `spawn_unit`'s `type_id` is an
    **opaque** String and `max_hp` is **caller-supplied** precisely so the container does not have to
    wait for them.
  - **§3.2/§12.1's `victory.turn_limit` 200 IS M6, NOT M2.** The turn counter now exists, so it is
    newly tempting to "just add the check". Don't: victory conditions are M6, and a
    comment-stripped source scan currently **forbids the literal `200`** in all four M2-T2
    production files (decisions.md **(AV)** item 3). The turn counter being 1-based is what makes
    §3.2's printed *"If turn 200 is reached"* mean what it says.
  - **Read first:** decisions.md **(BA)** (this iteration — **§3.4 step 4's whole rule**: where the
    tick runs and for **whom** ((BA)(i)/(ii), and why player 0's first turn runs nothing), **N
    diggers spend N worker-turns per tick** and why the **overshoot is settled by an existing clamp
    rather than a branch** ((BA)(iii)), completion's **four** state changes and why the yield goes to
    the **SITE'S OWNER** ((BA)(iv)), **the THIRD §12.1 amendment** and the now-routine amendment
    procedure ((BA)(v)), **TWO events not four** and the named `TerrainChangedEvent` candidate for M3
    ((BA)(vi)), **the two shapes of "unconfigured"** and the M7 re-injection debt ((BA)(vii)), the
    **vein-node gap re-opened by name** ((BA)(viii)), the **negatively pinned** M5 breach/noise
    deferral ((BA)(ix)), and **how the tier-3 golden was recorded** — including why the RED run's
    printed hash was the **stub's** and must never be recorded ((BA)(x))),
    **(AZ)** (the four rules **§4.2 does not print**:
    **unit-targeted cancel**, **last-digger-removes-the-site with progress LOST** and its
    orphan-site/§5.3-zone **deadlock** argument, **partial cancel changes nothing but the crew**, and
    the **deliberate absence of `no_map`** pinned *positively*; the **six-code vocabulary** and its
    two load-bearing orderings; how a **scoped negative pin is RE-SCOPED rather than deleted** when
    the slice it named finally lands; the `JSON.stringify(data, "", false)` citation of (AW)(vii)(a);
    and the **fifth** re-statement of the owed tier-3 golden),
    **(AY)** (the **3a/3b re-slice** and its measured
    LOC reason, the **§7.1 ownership seam** and where it lands, the **injected-`DigRules`** decision
    and what M7's serializer must re-inject, **one owner per site / one job per unit**, the
    **eleven-code rejection vocabulary and its precedence**, the **second append-only fold
    amendment** and why it deliberately **diverges** from (AX)'s `_next_unit_id`, the
    `set_remaining_turns` totality guard, the **one known sharp edge** (a literal `null` `DigRules`
    crashes rather than rejecting — deliberate, see (AY) item 14), and the deferrals),
    **(AX)** (units as a **top-level** collection, id
    minting/atomicity, the opaque `type_id`, the **first** append-only fold amendment and its known
    equivalent mutant, the separator analysis, the Command-only mutators, and the deferrals),
    **(AW)** (`DigRules`, the §12.1 `dig` group, the loader's `map` kind, and why a non-mutating
    slice's *events* clause is vacuous), **(AV)** (the Command spine, why `CommandError` is not
    `RulesError`, why `execute` exists, turn numbering, the rejection vocabulary, the **amended fold
    order**, and the owed tier-3 golden), **(AU)** (stockpile semantics, the no-whitelist rule for
    resource ids, the original fold order and the eight deferrals),
    **M1-T2 (C)/(C2)** (the rounding contract every later rule inherits), **M1-T3 (H)–(L)** (injected
    `Callable`s — the pattern that binds a real map to a rule without changing the rule),
    **M1-T4/M1-T5 (M)–(U)** (the map, its canonical order, the golden and the single `Rng`), and the
    **GOLDEN contract** bullet below, which now governs **two** recorded artefacts —
    `mapgen_concentric_bowl_small_seed1337.json` (`0xcad24923`, M1-T5) and
    `dig_tick_scenario_seed4242.json` (`0xb0629468`, M2-T7).
  - **Continue the decisions.md lettering at (BB)** — M2-T7 used **(BA)** as a single umbrella
    resolution with ten lettered sub-items (i)–(x) plus six unlettered ones, cross-referenced by all
    three new production files (`dig_tick.gd`'s header quotes (BA)(iii)–(BA)(vii) verbatim) and by
    five suites; M2-T6 used **(AZ)** (two production files and three suites), M2-T5 **(AY)** (four
    production files and five suites), M2-T4 **(AX)** (`scripts/sim/unit_state.gd`,
    `scripts/sim/game_state.gd` and two suites), M2-T3 **(AW)** (several files), M2-T2 **(AV)**
    (five files) and M2-T1 **(AU)** (four files). **Do not renumber (AU), (AV), (AW), (AX), (AY),
    (AZ) or (BA).**
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
    **sim/core** file copy `tests/unit/test_rng.gd`/`test_map_generator.gd`, or — the newest and
    strictest worked examples — `tests/unit/test_unit_state.gd` (M2-T4: **nine** mechanical scans
    over comment-stripped source, whose **forbidden-numerals** pass permits only `0`, `1` and the
    hex `0x1f`, whose whitelist pass forbids §12.7's `worker`/`dig_mult`, the faction names, the
    seven §5.1 resource ids and `housing`, and which pins the **fold order in sequence** plus the
    header doc block; the fold itself is additionally pinned by an **`Fnv`-derived ORACLE** test that
    re-derives it independently — never pin a hash against itself) and `tests/unit/test_dig_rules.gd`
    (M2-T3: nine scans including a forbidden-numerals pass permitting only 0/1/2, a
    **required-tokens** pass for the §12.1 schema paths, and the (J) negative pin that the file names
    no `GameState`/`Command`/`Event`/`EventBus`); for a **renderer** file
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
  `sim/map_generator.gd` + `sim/player_state.gd` + `sim/game_state.gd` + `sim/unit_state.gd` +
  `sim/dig_site.gd`,
  `sim/commands/command.gd` +
  `sim/commands/command_error.gd` + `sim/commands/end_turn_command.gd` +
  `sim/commands/dig_hex_command.gd` + `sim/commands/cancel_dig_command.gd`,
  `sim/events/turn_ended_event.gd` + `sim/events/dig_started_event.gd` +
  `sim/events/dig_cancelled_event.gd` + `sim/events/dig_progressed_event.gd` +
  `sim/events/dig_completed_event.gd`,
  `sim/systems/dig_rules.gd` + `sim/systems/dig_tick.gd`, `core/event.gd` +
  `core/event_bus.gd`, `core/hex_math.gd`,
  `core/los.gd`, `core/rng.gd`, `core/fnv.gd`, `render/hex_layout.gd`, `render/map_renderer.gd`,
  `render/camera_rig.gd`, `render/greybox_boot.gd` and `render/hex_picker.gd`, and nothing else,
  deliberately (§13.4: invent nothing ahead of its milestone). `scenes/` holds exactly one file,
  `Main.tscn`; `tests/` now has a **`tests/sim/`** directory (tier-2 system tests) alongside
  `tests/unit/` and `tests/golden/`, and `tests/golden/` now holds **TWO** recorded artefacts.
  **There is still no shader** (§10 line 679's Lit/Dark tint is
  M3), **no selection state** (picking exists as of M1-T9, but tap-select/drag-box are M4/M8), and
  **no worker TRAIT, no vein-node state, no Extractor, no income, no upkeep, no housing,
  no zone, no cave feature, river, lair or spawn code** — the §4.2 dig **numbers** are readable as of
  M2-T3 (`sim/systems/dig_rules.gd`), a **unit can exist** as of M2-T4
  (`sim/unit_state.gd` + the `GameState` roster), a dig can be **ORDERED and CANCELLED** as of
  M2-T5/M2-T6
  (`sim/dig_site.gd` + the `GameState` dig-site registry + `sim/commands/dig_hex_command.gd` +
  `sim/commands/cancel_dig_command.gd`), and **as of M2-T7 A DIG ACTUALLY DIGS**
  (`sim/systems/dig_tick.gd` — the tick, the yield application and the hex-becomes-Cave transition)
  — but **the renderer is not told** (the `EventBus` → `MapRenderer.mark_hex_dirty` seam and a
  `plain_floor` palette entry are **M2-T8**), and **nothing yet spawns a
  unit**: `spawn_unit` still has no caller in production code (only the commands' *validate* reads
  the roster), exactly as intended until §3.1's starting kit lands.
  **`Command`, `CommandError`, the turn counter and the first concrete `Event` subclass NOW EXIST**
  (M2-T2) — the spine is built, and as of M2-T6 **`EndTurnCommand`, `DigHexCommand` and
  `CancelDigCommand` are the
  THREE of §11.1's fourteen printed
  commands that are implemented** (the other eleven belong to their own
  milestones), while **five concrete `Event` subclasses** now exist (`turn_ended`, `dig_started`,
  `dig_cancelled`, and — as of M2-T7 — `dig_progressed` and `dig_completed`), with
  `scripts/core/event.gd` and `event_bus.gd` **still byte-unchanged since M0-T3**: an event owns its
  own `TYPE_NAME` and the bus holds **no vocabulary** (the **(f)** precedent, honoured five times).
  **`scripts/sim/systems/` EXISTS** (M2-T3) and holds exactly **two**
  files (`dig_rules.gd`, `dig_tick.gd`); §11.2 line 724 prints it verbatim as *"systems/ (economy,
  breach, escalation, victory)"*, and the rest belong to the milestones that need them.
- **`DigSite` + THE `GameState` DIG-SITE REGISTRY + `DigHexCommand` + `DigStartedEvent`
  (`scripts/sim/dig_site.gd`, five new `GameState` functions,
  `scripts/sim/commands/dig_hex_command.gd`, `scripts/sim/events/dig_started_event.gd`, NEW at
  M2-T5 — read decisions.md **(AY)** before touching any of them. This is slice 3a of the dig
  chain; slice 3b (`CancelDig`) **consumed it unchanged at M2-T6** and slice 4 (the tick) consumes it
  next).** All four are pure
  `RefCounted`, engine-free, integer/String only — **no `float` token, no float literal**, no
  `Node`/`SceneTree`/`Engine.`/`Input.`/`get_tree(`/`randi`/`RandomNumberGenerator` — and none loads
  a document, so a scan asserts `RulesError` and `RulesLoader` are **ABSENT** (the M1-T9
  no-second-loader rule). **The only standalone numerals in all three new files are `0` and `1`**;
  `2, 3, 4, 10, 15, 25, 60, 120, 150, 250`, the nine §4.2 terrain ids, the seven §5.1 resource ids,
  `housing`, `worker`, `dig_mult` and the four faction names are **forbidden tokens**.
  - **NOT ONE DIG NUMBER LIVES IN ENGINE CODE — every one is reached through `DigRules`.** All nine
    §4.2 dig times (soft_dirt 1 · hard_rock 2 · dense_granite 4 · artificial_granite 3 · rubble 1 ·
    gold_vein 2 · iron_vein 2 · magestone_crust 2 · mithril_seam 4) are swept by test **through the
    command**, and §4.2 line 197's cap is read at every call from §12.1 `dig.max_diggers_per_hex`
    via `DigRules.max_diggers_per_hex()`. The **one** named private const is
    `_ADJACENT_DISTANCE: int = 1` — §4.1's fixed neighbour geometry, a **named mathematical
    constant** (the **(AJ)** precedent), deliberately **not** a §12.1 key. `halve_remaining_turns`
    (§4.2's *"Dig 2×"*) has **no caller** and is pinned **negatively**.
  - **THE §7.1 OWNERSHIP SEAM IS ONE PRIVATE FUNCTION AND THE TOKEN `dig_turns_for(` OCCURS EXACTLY
    ONCE IN THE PROJECT.** `DigHexCommand._digs_own_terrain(state, hex, player_index)` answers
    `false` **unconditionally** today — **no hex carries a builder index**, and §7.1's Raise Granite
    (10 Stone, 1 turn, Sapper active), the **only** producer of Artificial Granite, is **M3/M4**; the
    mapgen composition never emits it. So Artificial Granite comes out **3, never 1**, which is the
    reachable half of §7.1 line 367. **Do NOT add hex-builder storage casually**: it forces a
    `HexMap` fold change and therefore a **re-record of the M1-T5 mapgen golden** (`0xcad24923`).
    **The task that lands Raise Granite flips this one function** — never thread a new parameter
    through the command ((AY) item 2).
  - **`DigRules` IS INJECTED ALREADY-LOADED; `GameState` HOLDS NO `RulesLoader` AND MUST NOT GAIN
    ONE.** `DigHexCommand._init(p_player_index, p_unit_id, p_hex, p_dig_rules)` — the M1-T3
    **(H)/(L)** injected-dependency precedent. **M7 debt, recorded now:** a serialized `DigHex`
    carries only `player_index`/`unit_id`/`hex`, so the command-log serializer must **re-inject** the
    loaded rules ((AY) item 3).
  - **ELEVEN REJECTION CODES IN A FIXED PRECEDENCE, EACH AUTHORED AT ITS OWN CALL SITE** (no enum,
    no const list, no whitelist — (AV)/(AU)(iv)/(T)/(AH)): `null_state` → `no_map` → `no_players` →
    `not_current_player` → `no_such_unit` → `not_your_unit` → `unit_not_adjacent` → `not_diggable` →
    `site_not_yours` → `already_digging` → `dig_site_full`. Four orderings are load-bearing and each
    is pinned: **`no_players` before `not_current_player`** (an empty roster still reads current
    index 0); **an out-of-range issuer is `not_current_player`** (the (AV) reasoning); **an off-map
    target is `not_diggable`, never a new code** (`get_terrain_type()` is `""` off-map and
    `is_diggable("")` is false — out-of-bounds, unset and Cave hexes share one honest code, and a
    twelfth code would be invented vocabulary); **`already_digging` before `dig_site_full`**. Every
    rejection leaves `content_hash()` byte-identical, emits **nothing**, and creates/changes no site;
    `validate` is a **pure predicate** on both paths.
  - **ONE OWNER PER SITE, ONE JOB PER UNIT ((AY) item 4).** A site records the **ordering player**;
    another player's `DigHex` on that hex is `site_not_yours`. A unit is assigned to **at most one**
    site (`already_digging`, checked via `dig_site_of_digger`) — that is what made slice 3b's
    *cancel* **unit-targeted** ((AZ)(i)) and what will make slice 4's *tick* unambiguous. Neither is
    a §12.1 constant; both are structural.
  - **THE RECORD ENFORCES NO CAP, AND THAT IS DELIBERATE.** `DigSite` = **nine** public functions
    (`hex`, `owner_index`, `total_turns`, `remaining_turns`, `set_remaining_turns`, `digger_ids`,
    `add_digger`, `remove_digger`, `content_hash`) + `_init`, **zero** public vars/consts, identity
    **read-only**. `add_digger` refuses only a **duplicate** and an id **≤ 0**; it will hold four
    diggers if called directly — the cap is the **Command's** rule ((AX)(vi) placement precedent).
    `digger_ids()` is **fresh and ASCENDING** every call. `set_remaining_turns` is **TOTAL** and
    clamps into `[0, maxi(total_turns, 0)]` (the `set_hp` precedent; the `maxi` is a totality guard
    for a degenerate record the registry refuses anyway — (AY) item 13) and **does NOT remove the
    site**: completion is a **slice-4 RULE**, pinned negatively. **A join leaves `total_turns` and
    `remaining_turns` untouched** — §4.2's *"total worker-turns"* is a property of the hex.
  - **THE REGISTRY IS TOTAL, ATOMIC, AND VALIDATES NOTHING ABOUT THE MAP.** `add_dig_site` refuses
    (null, hash byte-identical) a duplicate hex, an owner outside `0..player_count()-1` and
    `total_turns` ≤ 0 — and accepts an off-map hex and a terrain-less hex, exactly as `spawn_unit`
    does not validate placement. `dig_site(hex)` returns the **SAME object** every call;
    `dig_site_hexes()` is **FRESH** every call in the canonical order **r ascending then q
    ascending** through the explicit private `_hex_before` comparator — **never** `Vector2i`'s
    default `<`, which sorts **x** first (a fixture proves the two orders differ);
    `dig_site_of_digger` is a **LINEAR SCAN**, **no reverse index** ((AX)(xiii)). `_dig_sites` is a
    private `Dictionary` keyed by `Vector2i`, **never iterated for output**.
  - **THE SECOND FOLD AMENDMENT, AND IT DELIBERATELY DIVERGES FROM THE FIRST ((AY) item 9).**
    `GameState.content_hash()` now ends … → `_next_unit_id` → unit count → per unit id ascending →
    **site count** → **per hex in canonical order: `hex.x`, `hex.y`, that site's `content_hash()`**.
    **Appended only; no existing step renamed or reordered.** Unlike the roster, **add-then-remove-
    every-site DOES hash like never-added** — a unit id is a **dangling identity** (the next spawn
    differs), a dig site is not (the next site on hex `h` is identical either way) — and that is
    asserted **positively** so it cannot drift. `DigSite.content_hash()` folds `hex.x` → `hex.y` →
    `owner_index` → `total_turns` → `remaining_turns` → the digger **COUNT** → the ids **ascending**
    through the shared `scripts/core/fnv.gd`: **count-prefixed, therefore injective WITHOUT a
    separator byte** (contrast `UnitState._SEPARATOR`, which exists only because `type_id` is a
    variable-length String — (AX)(ix)). It is re-derived by an **`Fnv`-built ORACLE** test; **never
    pin a hash against itself.**
  - **`DigStartedEvent` IS THE PROJECT'S SECOND CONCRETE `Event` SUBCLASS AND §13.6's *EVENTS*
    CLAUSE IS NOW LIVE.** `TYPE_NAME = &"dig_started"` (the event's **own** name —
    `scripts/core/event.gd` and `event_bus.gd` hold no vocabulary and were **not** edited, the M0-T3
    **(f)** precedent). **Exactly one** event per accepted dig order — creation (`site_created ==
    true`) **and** join (`site_created == false`) — and for nothing else. The other direction is
    pinned too: `apply()` with an **unconfigured** `DigRules` (`DigRules.new(null)`) creates **no**
    site and returns an **EMPTY** `Array[Event]`. `to_dict()` calls the **base first** (so `"type"`
    stays key 0), then appends `player_index`, `unit_id`, **`hex_q`, `hex_r`**, `remaining_turns`,
    `site_created` — **the raw `Vector2i` is never serialized**, because §11.1 line 708's save is
    **JSON**. §11.1 line 706's printed event names are **illustrative** ((AT)/(f)).
  - **ONE KNOWN SHARP EDGE, LEFT ALONE ON PURPOSE ((AY) item 14):** `validate()` dereferences the
    injected `_dig_rules` without a null guard, so a literal `null` **crashes** rather than
    rejecting. The case §13.6 requires — `DigRules.new(null)`, a real object over no document — is
    handled correctly everywhere. Adding a twelfth code would be **inventing vocabulary** (§13.4);
    the right place to settle it is M7's command **deserialization**, explicitly and with an entry.
- **`CancelDigCommand` + `DigCancelledEvent` (`scripts/sim/commands/cancel_dig_command.gd`,
  `scripts/sim/events/dig_cancelled_event.gd`, NEW at M2-T6 — read decisions.md **(AZ)** before
  touching either. This is slice 3b; it added NO `GameState` and NO `DigSite` function, extended NO
  fold and consumed NO data.)** Both are pure `RefCounted`, engine-free, integer/String only — **no
  `float` token, no float literal**, no `Node`/`SceneTree`/`Engine.`/`Input.`/`get_tree(`/`randi`/
  `Time.`/`OS.` — and the only standalone numerals in either file are **`0` and `1`** (`apply()` uses
  `is_empty()`, not `size() == 0`, so it introduces none at all).
  - **CANCEL IS UNIT-TARGETED ((AZ)(i)) — `_init(p_player_index, p_unit_id)`, NO hex and NO
    `DigRules`.** `dig_site_of_digger(unit_id)` has exactly one answer ((AY) item 4), so the command
    is total without naming a hex and is the exact inverse of `DigHex`. It reads **no data**, so
    unlike `DigHex` ((AY) item 3) **M7's deserializer has nothing to re-inject**; the file names no
    `DigRules`, `RulesLoader`, `RulesError`, `HexMath` or `HexMap` (all scanned).
  - **SIX rejection codes, each at its own call site, in precedence `null_state` → `no_players` →
    `not_current_player` → `no_such_unit` → `not_your_unit` → `not_digging`** — five reused from
    `DigHex` with the same meaning, **`not_digging`** the one new code (the exact inverse of
    `already_digging`; it also fires on a **second** cancel of the same unit). **Two orderings are
    load-bearing and pinned:** `no_players` before `not_current_player` (an empty roster still reads
    current index 0), and **`not_your_unit` before `not_digging`** (an enemy's dig state must never
    leak through an error code). An out-of-range issuer is `not_current_player`, never a new code.
  - **`no_map` IS DELIBERATELY ABSENT ((AZ)(iv)) AND THE ABSENCE IS PINNED POSITIVELY.** A cancel
    reads no terrain, so `validate` never consults `state.map`; a `GameState.new(seed, null, 2)`
    whose unit is on a site **cancels successfully and emits**. **Do not "restore" the check by
    symmetry with `DigHex`** — and do not add a null guard for the constructor contract either
    ((AY) item 14 is deliberate, not an oversight).
  - **THE LAST DIGGER REMOVES THE SITE AND ITS PROGRESS IS LOST ((AZ)(ii)); A PARTIAL CANCEL CHANGES
    NOTHING BUT THE CREW ((AZ)(iii)).** An ownerless site with kept progress is un-startable by
    anyone (`site_not_yours`) while §5.3's zones re-issue Dig orders every turn — a **deadlock**; and
    §1.1 pillar 1 makes a dig a **commitment**. When a crew-mate remains, `owner_index()`,
    `total_turns()` and `remaining_turns()` are all **unchanged** (crew size is not progress —
    the symmetric partner of *"a join leaves them untouched"*), and `digger_ids()` comes back fresh
    and ascending without the departed id. Cancelling **frees a capped slot**: 2 diggers ⇒ a third
    `DigHex` is `dig_site_full` ⇒ cancel one ⇒ the third is accepted as a **join**.
  - **`DigCancelledEvent` IS THE THIRD CONCRETE `Event` SUBCLASS.** `TYPE_NAME = &"dig_cancelled"`
    (its **own** name — `scripts/core/event.gd` and `event_bus.gd` are **byte-unchanged**, the M0-T3
    **(f)** precedent); **one** public const, **five** public vars (`player_index`, `unit_id`, `hex`,
    `remaining_turns`, `site_removed`), **one** public function. **Exactly one** event per accepted
    cancel and nothing else; `apply()` on a unit with **no** site changes nothing and returns an
    **EMPTY** `Array[Event]`. `to_dict()` is base-first, then `player_index`, `unit_id`, **`hex_q`,
    `hex_r`**, `remaining_turns`, `site_removed` — **the raw `Vector2i` is never serialized**
    (§11.1 line 708's save is JSON), and any fixture asserting document order must call
    **`JSON.stringify(data, "", false)`** ((AW)(vii)(a), cited a sixth time at (AZ)(x)).
  - **RETIRING A SCOPED NEGATIVE PIN: RE-SCOPE IT, NEVER DELETE IT ((AZ)(vi)) — the rule this slice
    established.** `test_no_cancel_dig_exists_anywhere_yet` became
    `test_cancel_dig_exists_in_exactly_one_production_file` (an *absence* assertion became an
    *exactly-one-and-here* assertion, plus a new assertion that `DigHex` does not name it), and
    `test_game_state.gd`'s `COMMAND_FILES`/`EVENT_FILES` were extended and re-worded. **Prefer the
    strictly stronger assertion; never drop one because the slice it named has landed.**
- **`DigTick` + `DigProgressedEvent` + `DigCompletedEvent` (`scripts/sim/systems/dig_tick.gd`,
  `scripts/sim/events/dig_progressed_event.gd`, `scripts/sim/events/dig_completed_event.gd`, NEW at
  M2-T7 — read decisions.md **(BA)** before touching any of them. This is slice 4, the LAST slice of
  the dig chain, and it CONSUMED M2-T5's registry and M2-T6's semantics unchanged: it added NO
  `GameState` function, NO `DigSite` function and NO `Command`.)** All three are pure `RefCounted`,
  engine-free, integer/String only — **no `float` token, no float literal**, no
  `Node`/`SceneTree`/`Engine.`/`Input.`/`get_tree(`/`randi`/`RandomNumberGenerator`/`Time.`/`OS.` —
  and none loads a document, so a scan asserts `RulesError` and `RulesLoader` are **ABSENT** (the
  M1-T9 no-second-loader rule).
  - **`DigTick` IS A RULE MODULE, NOT A COMMAND, AND IT HAS EXACTLY ONE CALLER.**
    `class_name DigTick extends RefCounted`, `_init(p_dig_rules: DigRules)`, **one** public function
    `tick_digs(state: GameState, player_index: int) -> Array[Event]`, **zero** public vars, **zero**
    public consts. §3.4's twelve steps are **turn-sequence rules**; there is no `BeginTurn` among
    §11.1 line 705's fourteen printed command names and **inventing one would be inventing
    vocabulary** ((BA)(i)). It is called **only** from `EndTurnCommand.apply()` — never from a Node,
    never from a second Command — and it is legitimate for it to call the Command-only mutators
    (`GameState.remove_dig_site`, `DigSite.set_remaining_turns`, `PlayerState.add`,
    `HexMap.set_terrain_type`) **because it executes inside `apply()`**. **The next eleven §3.4 steps
    copy this shape**, and each gets its own file in `scripts/sim/systems/`.
  - **NOT ONE DIG NUMBER AND NOT ONE ID LIVES IN `dig_tick.gd` — the strictest scan in the project.**
    Its comment-stripped source may contain **only the standalone numerals `0` and `1`**. The nine
    §4.2 dig times (**1/2/4/3/1/2/2/2/4**), the nine yields (**1/2/4/2/1/25/10/15/10**), the vein
    node figures (60/120/150/250, 3/6/10), the literal **`200`**, all nine §4.2 **terrain ids**, all
    six §5.1 **resource ids**, the strings `"cave"` and `"plain_floor"`, and every §12.1 **dotted
    schema path** are **forbidden tokens** — every one of them is reached through a `DigRules`
    accessor. (Calling `DigRules.cave_terrain_id()` is explicitly permitted: the scan forbids the
    quoted **literal**, not the accessor **name**.) `end_turn_command.gd` must name `DigTick` and
    must **not** call `set_terrain_type` / `add_dig_site` / `remove_dig_site` / `set_remaining*`
    itself — also scanned.
  - **THE RULE ORDER IS PINNED, NOT INCIDENTAL ((BA)(iii)/(iv)/(vi)).** Snapshot
    `state.dig_site_hexes()` **FIRST** (fresh, canonical **r ascending then q ascending** — never
    `Vector2i`'s default `<`, which sorts x first), filter by `site.owner_index() == player_index`,
    then per site: **skip a zero-digger site entirely** (no event — a totality pin, unreachable
    today because (AZ)(ii) removes a site when its last digger leaves);
    `set_remaining_turns(remaining - digger_count)` (**the existing clamp handles the overshoot** —
    Soft Dirt total 1 with two diggers lands on exactly 0 and yields **+1 EXACTLY ONCE**); emit
    `DigProgressedEvent` with the **POST-tick** remainder; if it reached 0, read the terrain, apply
    each `yield_resource_ids`/`yield_amount` pair via `PlayerState.add` **to the SITE'S OWNER**,
    `map.set_terrain_type(hex, cave_terrain_id())`, `remove_dig_site(hex)`, then emit
    `DigCompletedEvent`. **Progress ALWAYS precedes completion.** Because the snapshot is taken
    before any removal, removing sites mid-loop is safe.
  - **"UNCONFIGURED" HAS TWO SHAPES AND BOTH ARE COMPLETE NO-OPS ((BA)(vii)).** A **null**
    `DigRules`, a `DigRules.new(null)` (detected by `cave_terrain_id().is_empty()`), a **null**
    `state` and a **mapless** `state` each run **no pass at all** and return an **EMPTY** array.
    The second shape is the load-bearing one: without it a one-turn site would decrement to zero and
    "complete" with an **empty yield** and a hex flipped to **`""`** — a silent corruption, not a
    no-op. **Do not "simplify" that guard away.** The known, accepted consequence: because the loader
    legitimately accepts empty strings elsewhere (`owner_turns_key`/`yield_key`), a hand-typo'ed
    **empty** `dig.cave_terrain_id` in data would **silently disable the tick** rather than failing
    load.
  - **`EndTurnCommand` NOW TAKES AN OPTIONAL INJECTED `DigRules`** —
    `_init(p_player_index: int, p_dig_rules: DigRules = null)`, still an **immutable value object**
    (`validate`/`apply` never mutate `self`), public surface **unchanged** at `player_index` /
    `command_name` / `validate` / `apply` (an **extra** member fails the scan). `apply()` rotates
    first, appends `TurnEndedEvent` **FIRST**, then appends the tick's events. **M7 DEBT: the
    command-log deserializer must RE-INJECT a loaded `DigRules`** — a serialized `EndTurn` carries
    only `player_index`, and one that forgot the injection replays as a **silent no-tick**.
  - **THE FOURTH AND FIFTH CONCRETE `Event` SUBCLASSES.** `TYPE_NAME` `&"dig_progressed"` /
    `&"dig_completed"`, each owned by the event itself (`scripts/core/event.gd` and `event_bus.gd`
    are **byte-unchanged** — the M0-T3 **(f)** precedent). `DigProgressedEvent(player_index, hex,
    digger_count, remaining_turns)`; `DigCompletedEvent(player_index, hex, digger_ids,
    resource_ids, amounts, terrain_id)` — **ids ascending**, and it **COPIES its three arrays on
    construction AND hands out DUPLICATES from `to_dict()`** (both pinned with `is_same`).
    `to_dict()` calls the **base FIRST** so `"type"` stays key 0, then flattens `hex` into
    **`hex_q`/`hex_r`** — **the raw `Vector2i` is never serialized**, because §11.1 line 708's save
    is **JSON**. **Two events, not four**, for the four things a completion changes: the completion
    event's **payload** makes each sub-change observable ((BA)(vi)). **A generic
    `TerrainChangedEvent` is the named candidate for M3**, when §4.5's collapse gives the terrain
    flip a **second** producer — one producer is not a pattern.
  - **COMPLETION MUTATES NO `UnitState`, AND CREATES NO VEIN NODE.** Diggers are freed
    **IMPLICITLY** — assignment **is** site membership — so every digger survives a completion with
    its **hp and hex unchanged** (pinned). A vein completion applies **only the §4.2 LUMP**; the
    node is **dropped with the terrain** ((BA)(viii), re-opening (AW) item 4), asserted
    **positively**: exactly the stockpile, exactly one hex's terrain and the site registry change,
    and nothing else. `rng.rolls_drawn()` is still **0** — step 4's **Breach checks (§4.6)** and
    **Noise pings (§4.8)** are **M5** ((BA)(ix)).
- **`DigRules` contract + THE §12.1 `dig` GROUP (`scripts/sim/systems/dig_rules.gd`,
  `data/ruleset.json`'s new `dig` group, `RulesLoader`'s `map` kind + `get_keys`, NEW at M2-T3 —
  read decisions.md **(AW)** before touching any of them). This is §4.2's dig TABLE, and slices
  3–4 of the dig chain consume it.** `class_name DigRules extends RefCounted` — pure sim core
  (§11.1): engine-free, integer-only, **no `float` token and no float literal**, every returned
  Array **fresh and ascending**. It **CONSUMES an already-loaded `RulesLoader`** (`DigRules.new(p_rules)`),
  never loads a document itself, and therefore has **no `errors` var** — a scan asserts `RulesError`
  is **ABSENT** (the M1-T9 no-second-loader rule). It mutates nothing, so `GameState`, `Command`,
  `Event` and `EventBus` are **forbidden tokens** in it ((AW) item 8).
  - **Public surface is EXACTLY seven functions and ZERO public vars and ZERO public consts** —
    `is_diggable`, `dig_turns_for`, `yield_resource_ids`, `yield_amount`, `vein_resource_id`,
    `max_diggers_per_hex`, `halve_remaining_turns` (plus `_init(p_rules: RulesLoader)`) — and the
    scan fails on a **missing OR extra** member. Privates: `_HALVE_DIVISOR`, `_rules`,
    `_profile_key`. Class kind is checked via `get_class()`, **never** `is Node`.
  - **§13.6 IS STRICT HERE AND THIS FILE IS THE WORKED EXAMPLE: not one dig number may appear in
    it.** The only standalone numerals in the comment-stripped source are `0`, `1` and the single
    `2` of `const _HALVE_DIVISOR` (§4.2 line 197's halving divisor — a **named mathematical const**,
    the (AJ) precedent, deliberately **not** a §12.1 key). The nine §4.2 terrain ids, the seven §5.1
    resource ids and the table values **3, 4, 10, 15, 25, 60, 120, 150, 250** are all **forbidden
    tokens** (watch incidental substrings — *"environment"* contains *"iron"*). What the file **may**
    and **must** name are the §12.1 schema paths (`dig.profiles.`, `dig_turns.`, `dig_yields.`,
    `vein_nodes.`, `dig.max_diggers_per_hex`) and the four profile leaf names — the contract with
    data, exactly as `RulesLoader._spec()` holds it.
  - **THE `dig` GROUP IS THE TERRAIN-ID → §12.1-KEY BINDING, AND IT LIVES IN DATA ON PURPOSE
    ((AW) item 1).** `data/ruleset.json` line **5** (one line; `dig_yields` stays line **4** — M0-T2
    item 7's layout contract is tested) holds `{"max_diggers_per_hex": 2, "profiles": {nine §4.2
    terrain ids → `turns_key` / `owner_turns_key` / `yield_key` / `vein_key`}}`, `""` meaning *not
    applicable*. Vein rows read their lump from `vein_nodes.<vein_key>.lump`, and **`vein_key`
    doubles as the §5.1 resource id**. Any new terrain type is a **data** edit — that is what keeps
    §13.5's M6 zero-engine-change canary reachable. **Never move this binding into code.**
  - **`RulesLoader` gained a `map` spec kind whose ERROR ORDER IS BY ASCENDING KEY, never parse
    order** ((AW) item 2): a node carrying `"entry"` (one shared child spec) rejects a non-object,
    rejects an **EMPTY** object, then validates every observed key sorted ascending. Its companion
    `get_keys(dotted_path) -> Array[String]` is ascending, **fresh per call** and total (empty for a
    missing path or a non-object leaf). `_attribute_line` needed no change. The whole loader change
    is **purely additive** — never weaken an existing kind to fit a new group.
  - **KNOWN, RECORDED ATTRIBUTION COLLISION — do not "fix" it back ((AW) item 6).**
    `test_reject_missing_dig_yields_artificial_granite` now expects line **5**, not 4: `dig.profiles`
    is keyed by §4.2 **terrain** ids, one of which is literally `artificial_granite`, so M0-T2 item
    3's forward scan now finds a real token instead of falling back to the group line. The
    assertion is re-pinned (exactly one error, exact line, exact path, `rules` empty), not weakened.
  - **TWO MEASURED FACTS TO KEEP ((AW) item 7):** `JSON.stringify`'s `sort_keys` parameter
    **DEFAULTS TO `true`** on the pinned 4.7 build — any fixture depending on **document** order must
    pass `JSON.stringify(data, "", false)`; and §4.2 line 197's round-up halving has a **FIXED POINT
    AT 1** (`ceil(1/2) = 1`), so *"Dig 2×"* speeds a dig up but **can never finish it** — a `floor`
    implementation would drive 1 → 0 and let stacked Dig 2× complete digs for free.
    `halve_remaining_turns` is `(n + 1) / _HALVE_DIVISOR` guarded by `n <= 0 → 0`. **Both of §4.2
    line 197's numbers are 2**, which is why the suite patches `dig.max_diggers_per_hex` to **3** and
    asserts the halving is **unchanged**.
  - **UNCONFIGURED AND TOTAL EVERYWHERE (the (AL) precedent).** A null loader, a **failed** loader,
    and any unknown or empty terrain id all answer `is_diggable` false / `dig_turns_for` 0 for
    **both** owner flags / empty ids / amount 0 / `vein_resource_id` `""`, and an unconfigured
    `max_diggers_per_hex()` is **0**. `is_diggable` is true for **exactly** the nine §4.2 Solid rows.
    A cross-data test also requires every `composition[].weights[].type` in
    `data/mapgen/concentric_bowl.json` to have a `dig.profiles` entry, so **no generated hex can be
    undiggable by omission** (that file is read, never edited — the M1-T5 golden hashes it).
  - **`by_owner` MEANS "THE DIGGING PLAYER OWNS THIS ARTIFICIAL GRANITE" AND NOTHING ELSE**
    ((AW) item 3, §4.2 line 188 *"3 (owner: 1)"* + §7.1 line 367). `DigRules` takes the bool and
    **never decides ownership** — that determination belongs to slice 3's dig Command. Exactly one
    row has a variant; the flag is **inert** on the other eight and a test pins that.
  - **NOT BUILT HERE, DELIBERATELY ((AW) item 4):** vein-node **state** (`vein_nodes.<id>.stock`/
    `rate` are shipped and validated but unused), Extractors (§5.2), workers, dig commands, dig
    progress, yield **application**, the hex-becomes-Cave transition and every §3.4 step.
- **THE §11.1 COMMAND SPINE (`scripts/sim/commands/command.gd`, `command_error.gd`,
  `end_turn_command.gd`, `scripts/sim/events/turn_ended_event.gd`, NEW at M2-T2 — read decisions.md
  **(AV)** before touching any of them, or before adding a Command). EVERY later mutation of
  `GameState` is a subclass of this.** All four are pure `RefCounted`, engine-free, integer/String
  only (no float literal, no `float` token, no `randi()`/`randf()`/`RandomNumberGenerator`, no
  `Node`/`SceneTree`/`Engine.`/`Time.`/`OS.`), and none loads a document — so a scan asserts
  `RulesError` is **ABSENT** in all four (the M1-T9 rule). The literal **`200`** is forbidden in all
  four (§3.2/§12.1's `victory.turn_limit` is **M6**).
  - **`execute(state, bus)` IS THE ONE GATE, and it is the only sanctioned way to run a Command.**
    It calls `validate`; on a non-null `CommandError` it returns **immediately**, having called
    `apply` **zero** times and emitted nothing; otherwise it calls `apply(state)` and routes the
    `Array[Event]` through `bus.emit_all(events)` **in array order**, then returns `null`.
    **`bus == null` is legal** (headless) and is a **silent drop**. `execute` **never returns the
    events** — a caller who wants them subscribes to the bus (§11.1: the sim never calls the
    renderer). The base `validate` **REJECTS** (`abstract_command`) so a subclass that forgets to
    override it **fails closed**. Probe P3 (apply-before-validate) reds **18** tests; P4 (emit on a
    rejection) and P9 (emit nothing on success) both red too. **Never add a second composition path.**
  - **Public surfaces are EXACT and mechanically scanned — a missing OR extra member fails.**
    `CommandError` = vars `code: StringName` + `message: String`, funcs `_init` + `format_for`
    (renders `"<source>: <code>: <message>"`), **zero public consts**. `Command` = funcs
    `command_name`, `validate`, `apply`, `execute` and **zero public vars**. `EndTurnCommand` = funcs
    `_init`, `player_index`, `command_name`, `validate`, `apply` and **zero public vars**.
    `TurnEndedEvent` = const `TYPE_NAME` + vars `player_index`, `next_player_index`, `turn` + funcs
    `_init`, `to_dict`.
  - **`CommandError` IS DELIBERATELY NOT `RulesError` — (AV)(i), and the reason is load-bearing.**
    `RulesError.line` is 1-based over a **document** with **0 reserved** for file-level failures, and
    `path` is a dotted JSON key path; a command rejection has **neither**. Do not "unify" them. Do
    not add a `line` to `CommandError` either.
  - **REJECTION CODES ARE OPAQUE `StringName`s AUTHORED AT THEIR OWN CALL SITE — no enum, no const
    list, no whitelist anywhere in engine code** (the (AU)(iv)/(T)/(AH)/(f) precedent). Today's
    vocabulary: `abstract_command` (the base), `null_state`, `no_players`, `not_current_player`
    (which **also** covers an out-of-range index — the current index is always in range, so
    out-of-range can never be current). Every rejection carries a **non-empty** `message`.
    `validate` is a **pure predicate**: it must leave `content_hash()` byte-identical and emit
    nothing.
  - **A COMMAND IS AN IMMUTABLE VALUE OBJECT.** All parameters set in `_init`; `self` is **never**
    mutated by `validate` or `apply`, because §11.1's replay contract executes the same
    `command_log` more than once (`tests/sim/test_turn_replay.gd` replays it **3×**). Probe P7
    (mutate self in `apply`) reds. `_player_index` is private with a read-only `player_index()`.
  - **§3.3's ROTATION IS A RULE AND LIVES IN THE COMMAND; `GameState` ONLY STORES THE POSITION.**
    `next = (current + 1) % player_count`, `turn += 1` **only** when `next` wraps to 0 (a full round
    of all players is **one turn**). A fresh state is **turn 1, index 0** at every roster size
    including the empty one ((AV)(iii)). `set_turn_position` is **TOTAL and ATOMIC** — a silent
    no-op if `p_turn < 1` or the index is outside `0..n-1`, and both counters move together or
    neither does ((AV)(v)). Probes P5, P6 and P10 red.
  - **`TurnEndedEvent` is the project's FIRST concrete `Event` subclass**, `TYPE_NAME =
    &"turn_ended"`, payload `player_index` / `next_player_index` / `turn` (**the turn number AFTER
    the advance**); `to_dict()` calls the **base first** so `"type"` stays the first key
    (`scripts/core/event.gd` line 23's contract). **Exactly ONE event per accepted EndTurn.**
    `scripts/core/event.gd` and `event_bus.gd` stay **pure infrastructure and free of every event
    name** — they were not edited and a test scans them for that. Concrete events live in
    `scripts/sim/events/` because they carry **sim** payloads ((AV)(viii); §11.2's printed file list
    is illustrative — the (f)/(AT) precedent).
  - **THE RUNNING PARSE-TRAP LIST — every one of these silently un-collects a WHOLE file, which is
    the M0-T5 item (a) false green.** (a) **`log` is a GDScript built-in** — a variable *or
    parameter* named `log` is `shadowed_global_identifier` = level 2 = a hard error (use
    `command_log`); (b) a **literal percent sign inside a String** later used with the format
    operator is *"unsupported format character in operator %"*; (c) **`seed` is a built-in too**
    (M1-T5 **(R)** — use `p_seed_value`); (d) **NEW AT M2-T4: `owner` and `name` are BASE-CLASS
    PROPERTIES of `Node`**, and `GutTest` extends `Node`, so a parameter *or `for` iterator* named
    either in a **test** file is `shadowed_variable_base_class` = level 2 = a hard error (hit live;
    the fix is documented on `_spawn` in `tests/unit/test_game_state.gd`); (e) `func hash(` trips
    `native_method_override`; (f) `x is Node` against a RefCounted-typed variable is a **statically
    impossible cast** rejected at parse time — always check class kind with `get_class()`.
- **`UnitState` + THE `GameState` UNIT ROSTER (`scripts/sim/unit_state.gd`, the six new
  `GameState` functions, NEW at M2-T4 — read decisions.md **(AX)** before touching either. This is
  §11.1 line 704's TOP-LEVEL `units` collection, and slices 3–4 of the dig chain consume it).**
  `class_name UnitState extends RefCounted` — pure sim core (§11.1): engine-free, integer/String
  only, **no `float` token and no float literal**, no `RandomNumberGenerator` (M1-T5 **(R)**), and it
  **loads no document**, so a scan asserts `RulesError` is **ABSENT** (the M1-T9 no-second-loader
  rule). It is a **RECORD**: it names no `GameState`, `Command`, `Event` or `EventBus`, and the
  roster runs **no rule** — §13.6's *events* clause is **vacuous** for this slice and (AX) item 10
  says so.
  - **Public surface is EXACTLY nine functions and ZERO public vars and ZERO public consts** —
    `unit_id`, `owner_index`, `type_id`, `hex`, `set_hex`, `hp`, `max_hp`, `set_hp`, `content_hash`
    (plus `_init(p_unit_id, p_owner_index, p_type_id, p_hex, p_max_hp)`) — and the scan fails on a
    **missing OR extra** member. The one private const is `_SEPARATOR`. **`GameState`'s exact list
    grew 8 → 14 in the M2-T4 commit itself** (`spawn_unit`, `unit`, `unit_ids`, `units_of`,
    `units_at`, `remove_unit`) **and 14 → 19 in the M2-T5 commit** (the five dig-site registry
    functions); **`PlayerState`'s did NOT move** — units and dig sites are both **top-level**
    collections, never player fields.
  - **IDS: FROM 1, NEVER REUSED, AND NEVER BURNED ON A REFUSAL.** `_next_unit_id` starts at **1** and
    advances **only** on a successful spawn; **0 means "no unit"** (an algorithmic constant, the (AJ)
    precedent — **not** a §12.1 key), so `unit(0)`, `unit(-1)` and any never-minted or removed id all
    answer **null**. `spawn_unit` refuses (null) an owner outside `0..player_count()-1`, an **empty**
    `type_id` and a non-positive `max_hp`, and **every refusal is ATOMIC**: `content_hash()` is
    byte-identical *and* the counter did not move, so the next successful spawn gets the id it would
    have got anyway. A recycled id would silently rebind a dangling reference and break replay —
    **never add id reuse, and never "compact" the roster.**
  - **ORDER AND FRESHNESS (§11.1 line 707).** `_units` is a private `Dictionary` keyed by int id,
    touched **only** by lookup/assign/erase and **never iterated for output**; `unit_ids()` sorts a
    **fresh copy** of the keys and returns a **fresh Array every call**; `units_of`/`units_at` are
    **LINEAR SCANS over `unit_ids()`** — **do not build a reverse index** (a second source of truth
    is a determinism hazard, and it was judged premature at this size). Freshness is pinned **both**
    with `is_same()` **identity** assertions and with a pollution check, because a self-clearing
    member cache passes the weaker one alone. `unit(id)` returns the **SAME object** every call (the
    `player(i)` precedent), so a mutation through it persists.
  - **THE RECORD'S RULES, and what is deliberately NOT one.** Identity (`unit_id`/`owner_index`/
    `type_id`) is **read-only — there are no setters**. `set_hp` is **TOTAL and CLAMPS** into
    `[0, max_hp]` (overheal saturates, overkill floors) and **0 hp does NOT remove the unit** —
    whether 0 hp kills is a §3.4/§6 **RULE** for a later slice, pinned **negatively** here.
    `max_hp` never changes; `hp` starts equal to it. **Placement is NOT validated** — `spawn_unit`
    accepts any `Vector2i` and never consults `map` (cave/bounds/§5.2 housing legality is a
    **Command** rule; §6.4 stacking legality is **M4**, so `units_at` may return several ids).
    **Neutral ownership is NOT modelled**: §8.1 creeps and §3.2's *"units become neutral hostiles"*
    need an **explicit sentinel at M5** — never silently accept -1.
  - **`type_id` IS OPAQUE AND `max_hp` IS CALLER-SUPPLIED — no whitelist, no stat table** (the
    (T)/(AH)/(AU)(iv) precedent). §12.2's definitions are `data/units/*.json` at **M6**, and §12.7's
    `worker` is a **TRAIT (data), not a class** — there is **no `is_worker()`**. The tokens `worker`,
    `dig_mult`, `sapper`, `digger`, `thrall`, the four faction names, the seven §5.1 resource ids and
    `housing` are **forbidden** in both `unit_state.gd` and `game_state.gd`; the only standalone
    numerals in `unit_state.gd` are `0`, `1` and the hex `0x1f`.
  - **THE FOLD, and the one thing that is knowingly equivalent.** `UnitState` folds
    `unit_id → owner_index → hex.x → hex.y → hp → max_hp → type_id`'s UTF-8 bytes `→ _SEPARATOR`
    through the shared `scripts/core/fnv.gd` (**never** `HexMap`'s private 4-byte `_fold_int` — the
    M1-T5 golden `0xcad24923` records that one). **Fixed-width fields first, the single
    variable-length field LAST**, which makes the record injective *without* the separator — so
    unlike `PlayerState`'s, this separator **cannot** be killed by a confusable-pair fixture ((AX)
    item 9: it is pinned by the fold-order scan and by an `Fnv`-derived oracle instead; do not go
    looking for the missing test). The roster appends to `GameState`'s fold — see the fold bullet
    below — and its **unit-count step is a KNOWN EQUIVALENT MUTANT** kept for symmetry with the
    player fold ((AX) item 8, the (AU) item 11 precedent): **do not chase it.**
  - **MUTATORS ARE COMMAND-ONLY BY DOCUMENTATION.** `spawn_unit`, `remove_unit`, `set_hex` and
    `set_hp` carry the `set_turn_position`/`HexMap.set_elevation` doc comment; GDScript has no
    package-private, so **review is the enforcement**. From slice 3 onward they must be called from
    inside a `Command.apply()` and every call owes an `Event`.
- **`GameState` + `PlayerState` + `Fnv` contract (`scripts/sim/game_state.gd`,
  `scripts/sim/player_state.gd`, `scripts/core/fnv.gd`, NEW at M2-T1, `GameState` **extended at
  M2-T2 and again at M2-T4** — read decisions.md **(AU)**, **(AV)** and **(AX)** before touching any
  of them). This is §11.1's
  state container, and EVERY later M2 slice hangs off it.** All three are `class_name … extends RefCounted`, engine-free, integer/String only (no float
  literal, no `float` token), and none of them loads a document — so a source scan asserts
  `RulesError` is **ABSENT** in all three (the M1-T9 rule). `RandomNumberGenerator` appears in none
  of them: `scripts/core/rng.gd` is still its single home (M1-T5 **(R)**), and it is a forbidden
  token in every sim/core scan.
  - **Public surfaces are EXACT and mechanically scanned — a missing OR extra member fails.**
    `Fnv` = consts `OFFSET_BASIS` / `PRIME` / `MASK` + static funcs `fold_byte`, `fold_int64`,
    `fold_bytes`, `fold_string`, **zero public vars, no `_init`, never instantiated** (an extra
    *public const* fails too — extra helpers must be `_`-prefixed). `PlayerState` = **six** funcs
    `amount_of`, `add`, `spend`, `can_afford`, `resource_ids`, `content_hash`, **zero public vars**.
    `GameState` = `var map: HexMap`, `var rng: Rng` + `player_count`, `player`, `content_hash`,
    — **as of M2-T2** — `turn`, `current_player_index`, `set_turn_position`, — **as of M2-T4** —
    `spawn_unit`, `unit`, `unit_ids`, `units_of`, `units_at`, `remove_unit`, and — **as of M2-T5** —
    `add_dig_site`, `dig_site`, `dig_site_hexes`, `dig_site_of_digger`, `remove_dig_site`
    (**NINETEEN** members;
    the list was grown 5 → 8 in the M2-T2 commit, 8 → 14 in the M2-T4 commit and 14 → 19 in the
    M2-T5 commit, each time in the
    same commit as the code — and **M2-T6 added NONE**: a pure-consumer slice should move no
    container surface, and *"the exact list is unchanged"* is itself pinned negatively). **If a later
    slice needs a new public member, update the expected list
    in the same commit.**
  - **`content_hash()`, NEVER `hash()`** — overriding `Object.hash()` trips `native_method_override`
    (level 2 = hard error), and a scan asserts `func hash(` is absent. **The `GameState` seed
    parameter is `p_seed_value`, never `seed`** (`shadowed_global_identifier`, the M1-T5 (R) trap).
  - **THE FOLD ORDER IS FIXED AND DOCUMENTED IN `game_state.gd`'s HEADER, because the SLICE-4 golden
    will record it — AMENDED BY M2-T2 (AV)(vi), EXTENDED BY M2-T4 (AX)(viii) AND AGAIN BY M2-T5
    (AY)(ix), UNCHANGED BY M2-T6, and this is the
    CURRENT copy:** private seed →
    `rng.rolls_drawn()` → **turn** → **current_player_index** → map-presence flag (0/1) →
    `map.content_hash()` when present → `player_count()` → per index ascending, the index then that
    player's hash → **`_next_unit_id`** → **the unit count** → **per unit id ascending, the id then
    that unit's `content_hash()`** → **the dig-site count** → **per hex in canonical order (r
    ascending, then q ascending): `hex.x`, `hex.y`, that site's `content_hash()`**. (M2-T2
    **inserted** the two turn-position steps; M2-T4
    **APPENDED** the three roster steps; M2-T5 **APPENDED** the two dig-site steps; **M2-T6 changed
    nothing**, which is why it triggered no golden re-record. **No existing step has ever been
    renamed or reordered — an
    amendment is append-or-insert plus a decisions.md entry, never a rewrite** — and two tests scan
    for exactly this order, one over `content_hash()`'s comment-stripped body, one over the header
    doc block. `_next_unit_id` folds **first** of the roster steps so that *"spawned then removed
    every unit"* cannot hash like *"never spawned"*; the **unit count** is a knowingly equivalent
    step kept for symmetry — (AX) item 8. The dig-site steps deliberately **DIVERGE**: there is no
    site counter, so *"dug then cancelled everything"* **does** hash like *"never dug"*, and that is
    asserted positively — (AY)(ix), re-asserted from the cancel side at (AZ)(ii).)
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
  - **THERE ARE NOW TWO GOLDENS: §13.2's TIER-3 GOLDEN WAS RECORDED AT M2-T7 AND THE DEBT IS
    CLOSED (decisions.md (BA) item 10).** §13.2 tier 3 is *"fixed seed + recorded command log ⇒
    recorded `GameState.hash()` after N turns"*. It was deferred **five** times — correctly each
    time, because freezing `GameState`'s fold before units/dig existed would have forced a re-record
    on every M2 slice, and M2-T4 and M2-T5 each **did** extend the fold — and was recorded at the
    first slice whose state genuinely evolves over N turns.
    `tests/golden/dig_tick_scenario_seed4242.json` records the run *and* the hash: `scenario`,
    `seed 4242`, `map_radius 2`, `player_count 2`, `turns 20`, `commands 45`, a `command_log`
    description, and `content_hash "0xb0629468"` — again a **lowercase 8-hex-digit STRING**, driven
    by `tests/golden/test_dig_tick_golden.gd`, which mirrors `test_mapgen_golden.gd` exactly.
    **The hash the RED run printed (`0x1ccf2c23`) was the STUB's** — the hash of a state where
    nothing ticked — and recording it would have frozen a no-op; **always take the observed hash
    only after the rule is green.** The property test (`tests/sim/test_turn_replay.gd`) remains and
    was **extended** with a ticking section, not replaced: a golden pins one run, a property test
    pins every run.
  - **A golden may be re-recorded ONLY with a dated `docs/decisions.md` reason in the SAME commit.**
    **Both** `tests/golden/test_mapgen_golden.gd` and `tests/golden/test_dig_tick_golden.gd` **fail
    loudly when the file is absent and never auto-record**; each failure message prints the recorded
    and observed hashes, the exact document to write, and that rule verbatim — **the failure message
    IS the recording procedure**. Never add a "record mode" flag to either.
  - **HARNESS TRAP, found live and now a standing rule for every test author:**
    `tools/run_tests.sh`'s refusal grep scans the **whole run output** for `Nothing was run` /
    `does not exist` / `have not been imported` / `Failed to load script` / `Ignoring script`. A test
    **failure message** containing any of those five phrases makes the runner exit 1 with "GUT
    reported a diagnostic …" even though GUT ran everything correctly. **Both** goldens' messages
    therefore say *"is MISSING"*, not *"does not exist"*. **Never put those phrases in a failure
    message; never weaken the harness to accommodate one.**
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
- **Constants are now data**, and `data/ruleset.json` has been **amended twice**, both times by the
  same procedure: M2-T1 added `dig_yields.artificial_granite.stone = 2` (governed by §4.2's row) and
  **M2-T3 added the whole new top-level `dig` group** (`max_diggers_per_hex` + the nine-row
  `profiles` map — §4.2 line 197 and the terrain-id → dig-key binding). Both are now printed in the
  §12.1 excerpt, edited **by Land, in the same commit as the decisions.md entry** ((AU)(i), (AW)(i));
  see the CLOSED forward-gap bullet below for the procedure. **M2-T5 needed NO new key** — the
  `dig` group already carried everything `DigHexCommand` reads, which is the intended payoff of
  putting the terrain-id → dig-key binding in data rather than in engine code ((AW)(i), §13.5) —
  and **M2-T6 needed none either**: cancel semantics are **structural rules, not tunables**, so
  `CancelDigCommand` reads **no data at all** ((AZ)(i)). *"Is this a §12.1 constant or a structural
  rule?"* is a question to answer explicitly, not by reflex: a number §4.2/§12.1 prints is **data**;
  *"the last digger leaving removes the site"* is a **rule** and belongs in code with a logged entry.
  `data/ruleset.json` holds the full §12.1 constant set and
  `RulesLoader` (`scripts/sim/rules_loader.gd`) is the only sanctioned way to read it. Never
  re-type a §12.1 number as a literal in `.gd` code (§13.6) — go through
  `get_int` / `get_float` / `get_string` / `get_int_array` / `get_keys` / `has` with a dotted path.
  Errors surface as `RulesError` (`line` 1-based, `path` dotted, `message`,
  `format_for(source)` → `"<source>:<line>: <message>"`). Line 0 means "file-level, no line" and
  is reserved for missing/unreadable files.
- **CURRENT SUITE STATE IS GREEN.** `bash tools/run_tests.sh` → **exit 0** at **Scripts 33 /
  Tests 846 / Passing 846 / Failing 0 / Asserts 10077** (measured at Verify, 2026-08-05, M2-T6, and
  re-run at Land with the same totals).
  `Scripts 33` equals the number of `test_*.gd` on disk, so nothing is silently skipped;
  `bash tools/typecheck.sh` exits **0** over 61 files; `bash tools/ci.sh`
  exits 0 (PASS with the three documented M7/E4/E5 skips) and `bash tools/verify_harness.sh` exits 0.
  Prior green baselines, for reference: M2-T5's 31 / 795 / 795 / 9295, M2-T4's 28 / 690 / 690 / 7885, M2-T3's
  27 / 643 / 643 / 7452, M2-T2's 26 / 598 / 598 / 6435, M2-T1's
  21 / 503 / 503 / 5646, M1-T9's 18 / 425 / 425 / 5144, M1-T8's
  17 / 388 / 388 / 4959, M1-T7's 15 / 321 / 321 / 3380, M1-T6's
  14 / 278 / 278 / 2760, M1-T5's
  13 / 234 / 234 / 2268, M1-T4's 11 / 183 / 183 / 1879, M1-T3's
  9 / 129 / 129 / 1308, M1-T2's 8 / 106 / 106 / 1023, M1-T1's 8 / 86 / 86 / 835, and
  7 / 62 / 62 / 473 at the close of M0 (the M0 tracker row above deliberately keeps that historical
  figure). **Expect these totals to RISE as you add tests — they are enumerated, not hard-coded.**
- The green signal is real and two-way: `bash tools/run_tests.sh` → exit 0 on a healthy tree, and
  `bash tools/typecheck.sh` → exit 0 over **61** project `.gd` files, and
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
  dated decisions.md entry, GDD cell edited by Land in the same commit. **M2-T3 ran it a second
  time** for the whole new `dig` group (a *new key*, not a missing leaf — decisions.md **(AW)**
  item 1; §4.2's table stayed byte-unchanged and only the §12.1 excerpt gained a line). **§3.1's
  starting kit is the next one that will need it** (it has no §12.1 key at all).
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
  **M2-T5 added the counter-lesson: MEASURE the ceiling at Orient, and RE-SLICE when the arithmetic
  says so ((AY) item 1).** M2-T4 spent **289** lines on **two** files in this repo's doc-heavy
  style, so a slice needing a record + a registry + **two** commands + **two** events was
  arithmetically over budget before a line was written; splitting it into 3a (**203 production code
  lines**, landed) and 3b (M2-T6, **79 production code lines**, landed) was the honest call, and the
  split was pinned mechanically at both ends — a test enumerates `scripts/sim/commands/`, and the
  `cancel_dig` token scan went from *"appears in NO production file"* (3a) to *"appears in EXACTLY
  ONE"* (3b) without ever being deleted ((AZ)(vi)).
  **Doc lines are not free here** (`dig_site.gd` is 128 lines for 51 of code;
  `cancel_dig_command.gd` is 109 for 49), so
  budget on **code** lines and say which number you measured. **The payoff of a clean re-slice is
  visible in the follow-on:** because 3a landed `remove_digger`/`remove_dig_site`/`dig_site_of_digger`
  already pinned, 3b was **pure rule** — 79 code lines against 2,333 lines of new suite.
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
  **M2-T2's yield (ten probes, eleven iterations of the practice running) is the first CLEAN sweep:
  all ten went red and NOTHING survived** — after three consecutive iterations in which the battery
  found a weak *test* rather than weak code, this one found neither, which is what a mature suite is
  supposed to look like and is only believable *because* the previous three did not. Two parts are
  worth carrying forward. (i) **Probe the ORDER, not just the outcome.** *"`execute` validates before
  it applies"* is unfalsifiable if the probe command's `apply` is a no-op — the probe has to **really
  mutate the state** so that applying-first is observable; done that way it reds **18** tests, and the
  §11.1 gate is proven rather than asserted. (ii) **The §13.6 *"events emitted for every state
  change"* clause became NON-VACUOUS for the first time in the project**, and probe P9 (make `apply`
  return an empty array) is what proves it — up to now that clause had been *stated as vacuous* every
  iteration, and the habit of stating it anyway is exactly what made it obvious the moment it started
  to bite. **Two parse traps were also measured live**, both of which silently un-collect an entire
  test file: `log` is a GDScript built-in (`shadowed_global_identifier`, level 2 = hard error), and a
  literal percent sign inside a String later used with the format operator is a parse error.
  **M2-T4's yield was a surgical SPOT-CHECK rather than a full battery, and it was enough**: deleting
  the `_next_unit_id` step from `GameState.content_hash()` reds **exactly the two right tests** (the
  spawn-then-remove-everything discriminator and the fold-order source scan), which is the shape you
  want — the most load-bearing new fold step pinned **behaviourally AND by the order scan**.
  **M2-T5's yield is a new instrument: an INDEPENDENT 27-ASSERTION PROBE written from scratch at
  Verify, run headless, then deleted with the tree confirmed clean.** Rather than mutating the
  implementation, it **re-derived** the contract from the GDD and checked the code against it — all
  nine §4.2 dig times through the command, the r-then-q order proven **different** from `Vector2i`'s
  default sort, insertion-order invariance **and** the deliberate add-then-remove-all divergence, the
  third digger refused with the cap read from data, a rejected `execute` proven atomic, the
  unconfigured-rules empty-event path, a mixed `DigHex`+`EndTurn` log replaying byte-identically 3×
  with **no** §3.4 step-4 tick, and `to_dict()`'s key order surviving a JSON round trip. **27/27
  passed.** Use it **alongside** mutation probes, not instead: a mutation battery asks *"is this pin
  load-bearing?"*, an independent probe asks *"is the pinned behaviour the one the GDD prints?"* —
  and only the second can catch a suite that pins the wrong thing consistently. Verify also
  **audited the test diff for weakening** (+733/−30, every removed line a doc comment or a renamed
  test header that was strictly **extended**) — do that too whenever a task modifies an existing
  suite.
  **M2-T6's yield (eight probes, ALL EIGHT caught — a second clean sweep) adds two lessons.**
  (i) **PROBE THE ABSENCE OF A CHECK, not only the presence of one.** *"`no_map` is deliberately not
  a code here"* ((AZ)(iv)) is the kind of claim that rots silently, so the probe was to **ADD** the
  check — it reds the mapless positive pin **and** two source scans, which is what proves the
  absence is load-bearing rather than merely current. Whenever a slice **narrows** an inherited
  vocabulary, probe by re-widening it. (ii) **VERIFY RE-DERIVED, RATHER THAN BELIEVED, THE
  IMPLEMENTER'S ONE TEST EDIT.** Implement had changed a Tests-stage assertion
  (`JSON.stringify(serialized)` → `JSON.stringify(serialized, "", false)`); Verify **reverted the
  edit and re-ran**, observed the alphabetized key order, and only then accepted it — and probe 3
  (moving `"type"` to the end of `to_dict()`) confirmed the *fixed* assertion still bites. **An
  implementer edit to a test is guilty until re-measured**: the honest ones survive that, and the
  distinction between *"the test was wrong"* and *"the test was inconvenient"* is exactly what a
  re-measurement makes visible. Verify again audited the test diff for weakening (+27/−10 and
  +17/−9 on the two re-scoped suites, `test_turn_replay.gd` sections A–C **byte-untouched**).
