## GameState — GDD §11.1 (Layered Design, **binding**), §3.3 (Turn Model), §11.2
## (`scripts/sim/`), §11.3, §13.2 tier 1, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 704): "**GameState**: single serializable object — map (hex array: type,
##         elevation, features, light, stress, knowledge per player), players (stockpiles, techs,
##         meters), units, buildings, nodes, turn counters, and **one**
##         **RandomNumberGenerator** **seeded at match start** (the only RNG in the program;
##         every roll goes through state.rng)."
##   §11.1 (line 703): "No Node, no Scene Tree, no engine singletons, no rendering, no
##         **randi()** — the core must run headless byte-identically."
##   §11.1 (line 707): "**Determinism rules:** iterate collections in stable ID order; no float
##         accumulation in rules ...  GameState.hash() (FNV over canonical serialization) must be
##         reproducible."
##   §11.1 (line 708): "replaying (seed, command_log) must reproduce the hash."
##   §3.3  (line 137): "Sequential player turns (IGOUGO, Civ-style), **fixed order by player
##         index**, then a **World phase**."
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §11.1 or §3.3**. The binding prior resolutions are M1-T5 **(R)** (`Rng` is the single home of
## the engine RandomNumberGenerator; `state.rng` is an `Rng`) and M1-T5 **(U)** (FNV-1a 32-bit,
## named `content_hash` and never `hash`). §11.1 legislates *what* GameState contains but no API,
## so the surface below is a §13.4 resolution lettered **(AU)** (M1-T9 ended the lettering at
## (AT)), recorded by Land:
##   (AU) GameState at M2-T1 scope.
##       - `_init(p_seed_value, p_map, p_player_count)`. The seed parameter MUST NOT be named
##         `seed`: GDScript's global `seed()` makes that `shadowed_global_identifier`, which is
##         level 2 = a HARD ERROR under the live M0-T4 gate (the same trap M1-T5 (R) hit).
##       - The seed value is kept PRIVATE and folded into `content_hash`, because §11.1's replay
##         contract is over `(seed, command_log)`.
##       - `state.rng` is the ONE `Rng`. Its STREAM POSITION (`rolls_drawn()`) is part of the
##         content hash: two states that have rolled a different number of times are not the same
##         replayable state.
##       - Players are folded BY INDEX (§3.3 "fixed order by player index"), never as a set.
##       - Totality (the (AS)/(B)/(L) spirit): `player(i)` answers null outside 0..n-1, a
##         non-positive player count is the empty roster, and a null map constructs cleanly.
##
## AMENDED BY M2-T2, resolution **(AV)** ((AU) is cross-referenced by four files — do NOT
## renumber it). §3.3's turn position now lives here, and the fold grew to cover it:
##   (AV) THE TURN POSITION.
##       - Private `_turn` / `_current_player_index`, public `turn()` / `current_player_index()`
##         and ONE mutator `set_turn_position(p_turn, p_player_index)`, documented as "§11.1 —
##         intended to be written only from a Command's apply()" (GDScript has no
##         package-private; `HexMap.set_elevation` is the precedent).
##       - A fresh state starts at **turn 1, index 0**, independently of the roster size — an
##         empty roster still reads turn 1 / index 0. §3.2 line 133's "If turn 200 is reached"
##         counts from 1; §14/§13.2's "after N turns" is silent.
##       - The mutator is TOTAL in the (B)/(L)/(AS) spirit: a SILENT NO-OP if `p_turn < 1` or
##         `p_player_index` is outside `0..player_count()-1`, and **both counters are written
##         together or neither is**, so a buggy caller can never park the state in an
##         unreachable position.
##       - THE ROTATION ITSELF IS NOT HERE: it is a §3.3 RULE and lives in `EndTurnCommand`.
##         `GameState` only stores the position.
##       - THE FOLD ORDER GAINS THE TURN POSITION, immediately after `rng.rolls_drawn()` and
##         BEFORE the map-presence flag: private seed -> `rng.rolls_drawn()` -> turn ->
##         current_player_index -> map-presence flag (0/1) -> `map.content_hash()` when present
##         -> `player_count()` -> per index ascending, the index then that player's hash. No
##         existing step is renamed or reordered, and NO GOLDEN IS RECORDED for GameState in
##         this slice (§13.6 — recording it before units/dig/income exist would guarantee a
##         re-record every subsequent slice; the golden is owed, not forgotten, and the replay
##         contract lands as a property test in `tests/sim/test_turn_replay.gd`).
##
## EXTENDED BY M2-T4, resolution **(AX)** ((AU)/(AV)/(AW) are cross-referenced by four, five and
## several files respectively — do NOT renumber any of them). §11.1 line 704 lists **units** as a
## TOP-LEVEL GameState collection ("map ..., players (stockpiles, techs, meters), **units**,
## buildings, nodes, turn counters ..."), NOT as a PlayerState field, so the roster lands here and
## a unit carries its owner as an integer player index. `tests/unit/test_player_state.gd` is
## therefore UNTOUCHED and still green — PlayerState's public surface does not move:
##   (AX) THE UNIT ROSTER (a pure CONTAINER — no Command, no Event, no data key, no rule).
##       - Private `_units` (keyed by int id, touched only by lookup/assign/erase) and
##         `_next_unit_id`; six public functions `spawn_unit`, `unit`, `unit_ids`, `units_of`,
##         `units_at`, `remove_unit`.
##       - IDS START AT 1 AND ARE NEVER REUSED. **0 means "no unit"** — an algorithmic constant
##         (the (AJ) precedent), not a §12.1 key. A reused id would silently rebind dangling
##         references and break §11.1's replay contract.
##       - Every list accessor sorts a FRESH copy of the keys and returns a FRESH Array each call
##         (§11.1 line 707 "iterate collections in stable ID order"), pinned with `is_same()`
##         IDENTITY assertions as well as a pollution check — the M1-T9 lesson: a self-clearing
##         member cache passes a pollution-only check.
##       - `spawn_unit` is TOTAL and every refusal is ATOMIC: an owner outside
##         `0..player_count()-1`, an EMPTY `type_id` or a non-positive `max_hp` answers null,
##         leaves `content_hash()` byte-identical AND BURNS NO ID.
##       - PLACEMENT IS NOT VALIDATED HERE: `spawn_unit` accepts ANY `Vector2i` and never
##         consults `map`. Legality (cave hex, in bounds, §5.2 housing free) is a Command rule for
##         a later slice, and §6.4's stacking legality is M4 — the container stacks freely.
##       - NEUTRAL OWNERSHIP IS DELIBERATELY NOT MODELLED (§8.1 creeps, §3.2's "their units become
##         neutral hostiles"): every owner index outside the roster is refused, and M5 must add an
##         explicit sentinel rather than silently inventing -1.
##       - THE FOLD IS EXTENDED BY APPENDING ONLY — no existing step is renamed or reordered
##         ((AV)(vi) is the precedent for how to amend it): ... `player_count()` -> per player
##         index ascending -> **`_next_unit_id`** -> **the unit count** -> **per unit id
##         ascending: the id, then that unit's `content_hash()`**. `_next_unit_id` folds FIRST of
##         the three because it is what makes "spawned 3 then removed all 3" differ from "never
##         spawned", which §11.1's replay contract requires. The unit-count step is knowingly an
##         EQUIVALENT MUTANT given the per-id fold — it is kept for symmetry with the player fold,
##         exactly as (AU) item 11 recorded for `player_count()`; Verify must not chase it.
##       - MUTATORS ARE COMMAND-ONLY BY DOCUMENTATION (`GameState.set_turn_position` and
##         `HexMap.set_elevation` are the precedents; GDScript has no package-private), and
##         because NO rule runs in this slice §13.6's "events emitted for every state change"
##         clause is VACUOUS here — the (AW) item 8 precedent, which must be SAID in
##         `docs/decisions.md`, not assumed.
##
## EXTENDED AGAIN BY M2-T5, resolution **(AY)** ((AU)/(AV)/(AW)/(AX) are cross-referenced by many
## files — do NOT renumber any of them). §11.1 line 704 lists `nodes` alongside `units` as a
## TOP-LEVEL GameState collection, and a DIG SITE is the first such per-hex progress record, so the
## registry lands here beside the unit roster:
##   (AY) THE DIG-SITE REGISTRY (a pure CONTAINER — the RULES live in `DigHexCommand`).
##       - Private `_dig_sites` keyed by `Vector2i` and NEVER iterated for output; five public
##         functions `add_dig_site`, `dig_site`, `dig_site_hexes`, `dig_site_of_digger`,
##         `remove_dig_site`.
##       - `add_dig_site` is TOTAL and every refusal is ATOMIC (null, `content_hash()`
##         byte-identical): a DUPLICATE hex, an owner outside `0..player_count()-1`, and a
##         non-positive `total_turns`.
##       - PLACEMENT AND TERRAIN ARE NOT VALIDATED HERE, exactly as `spawn_unit` does not validate
##         placement: legality (adjacency, diggability, §4.2 line 197's max-2 cap, whose turn it
##         is) is the COMMAND's job.
##       - `dig_site(hex)` answers the SAME object every call (the `player()`/`unit()` precedent);
##         `dig_site_hexes()` is FRESH per call in the canonical order **r ascending, then q
##         ascending** — the SAME order as `HexMap.hexes()`, spelled out rather than borrowed from
##         `Vector2i`'s default `<` (which sorts x first and would give a DIFFERENT sequence).
##       - `dig_site_of_digger(unit_id)` is a LINEAR SCAN over `dig_site_hexes()` — no reverse
##         index (the `units_of`/`units_at` precedent: a second source of truth is a determinism
##         hazard).
##       - THE FOLD IS EXTENDED BY APPENDING ONLY, after the unit fold: the SITE COUNT, then per
##         hex in canonical order `hex.x`, `hex.y`, that site's `content_hash()`. No existing step
##         is renamed or reordered ((AV)(vi)/(AX) is the only sanctioned amendment shape).
##       - DELIBERATE DIVERGENCE FROM (AX)'s `_next_unit_id`: "added then removed every site"
##         DOES hash like "never added". A dig site has no dangling identity to protect — it is
##         keyed by its hex, not by a minted id — so there is no counter to fold, and that is
##         asserted POSITIVELY below so it cannot drift silently.
##
## STILL DELIBERATELY NOT BUILT (§13.4 — invent nothing ahead of its milestone): §3.4's nine
## per-player start-of-turn steps and three World-phase steps (step 4's DIG TICK included — the
## registry stores progress but nothing spends it), §3.2/§12.1's victory turn limit
## and victory checks (M6), §12.7's trait set (worker-ness is a TRAIT, i.e. DATA — §12.7 line
## 1015), yields, vein nodes, Extractors, income/upkeep, §5.2's housing cap
## (`housing.hq` is already shipped in `data/ruleset.json` and stays UNUSED), Mining Zones and
## §3.1's starting kit (which needs its own §12.1 key and amendment).
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/game_state.gd`. They are
## per-file and inherit NOTHING from the other scan suites.
extends GutTest

const GAME_STATE_PATH: String = "res://scripts/sim/game_state.gd"

## §12.6's example seed, so this file's seeds come from the GDD rather than from invention.
const GOLDEN_SEED: int = 1337
const OTHER_SEED: int = 1338

## §3.1 "Skirmish: 2-4 players" — the roster sizes this suite sweeps.
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

## Small enough to build many of, big enough to have interior hexes to edit.
const TEST_MAP_RADIUS: int = 2

## Rolls compared when proving two states share one seeded stream.
const SEQUENCE_ROLLS: int = 20

## The 32-bit ceiling every content hash must respect (§11.1, M1-T5 (U)).
const HASH_MASK: int = 0xffffffff

## §5.1 resource ids used to move a player's stockpile. They are pinned as PlayerState's
## vocabulary by `tests/unit/test_player_state.gd`; here they are just opaque strings.
const SAMPLE_RESOURCE_ID: String = "gold"
const OTHER_RESOURCE_ID: String = "food"

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is on the
## list per M1-T5 item 6: `scripts/core/rng.gd` is its SINGLE home in the whole project, so
## GameState must reach the one seeded stream through `Rng`, never build a second one.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"Time.",
	"OS.",
]

## §5.1's seven resources. FORBIDDEN tokens in game_state.gd: there is no resource-id whitelist
## in engine code (the §4.2 terrain-type precedent, M1-T5 (T) / M1-T7 (AH)).
const RESOURCE_IDS: Array[String] = [
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §12.7 line 1015 ("worker | dig\_mult | Can Dig/Build; dig-speed multiplier") and §5.2 line 293
## ("**Housing** is the unit cap: HQ +6, each housing building +4"). FORBIDDEN tokens in
## game_state.gd: worker-ness is a TRAIT (data), not a class, and the housing cap is a LATER
## slice — `housing.hq` is already shipped in `data/ruleset.json` and must stay UNUSED.
const TRAIT_AND_CAP_TOKENS: Array[String] = ["worker", "dig_mult", "housing"]

## §4.1's radii and hex counts are tunable content in data/mapgen/*.json — never in sim code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## §12.2's printed example definition id (`{"id": "dwarf_crossbow", ... "hp": 70, ...}`) and
## §12.3's printed sibling `dwarf_shield_bearer`, so this suite invents no content. Both are
## OPAQUE strings to `GameState` — `data/units/*.json` is an M6 deliverable ((AX)).
const UNIT_TYPE_ID: String = "dwarf_crossbow"
const OTHER_UNIT_TYPE_ID: String = "dwarf_shield_bearer"

## §12.2's printed `"hp": 70`, supplied by the CALLER at this slice: there is no unit stat table
## in engine code until M6.
const UNIT_MAX_HP: int = 70

## (AX) — ids are minted from 1 upward; 0 means "no unit".
const NO_UNIT_ID: int = 0
const FIRST_UNIT_ID: int = 1

## §4.1 "axial coordinates (q, r)" — the positions this suite spawns onto.
const HEX_A: Vector2i = Vector2i(0, 0)
const HEX_B: Vector2i = Vector2i(1, -1)
const HEX_C: Vector2i = Vector2i(-2, 3)

## Far outside TEST_MAP_RADIUS: (AX) — `spawn_unit` never consults `map`, because placement
## legality is a Command rule for a later slice.
const HEX_OFF_MAP: Vector2i = Vector2i(999, -999)

## §4.2 — the hexes the dig-site registry fixtures use. Deliberately chosen so that sorting by
## `Vector2i`'s DEFAULT `<` (x first, then y) gives a DIFFERENT sequence from the canonical
## r-ascending-then-q-ascending order (AY) requires: default order would be
## (-1,2), (0,0), (1,-1), (2,-1); the canonical order is (1,-1), (2,-1), (0,0), (-1,2).
const SITE_HEX_A: Vector2i = Vector2i(0, 0)
const SITE_HEX_B: Vector2i = Vector2i(1, -1)
const SITE_HEX_C: Vector2i = Vector2i(-1, 2)
const SITE_HEX_D: Vector2i = Vector2i(2, -1)

## The insertion order the registry fixtures use, and the CANONICAL order they must enumerate in
## (r ascending, then q ascending — the same order `HexMap.hexes()` produces, §11.1 line 707).
const SITE_INSERTION_ORDER: Array[Vector2i] = [SITE_HEX_A, SITE_HEX_B, SITE_HEX_C, SITE_HEX_D]
const SITE_CANONICAL_ORDER: Array[Vector2i] = [SITE_HEX_B, SITE_HEX_D, SITE_HEX_A, SITE_HEX_C]

## §4.2 line 185 "Hard Rock | 2" and line 186 "Dense Granite | 4" — dig times supplied by the
## CALLER here: the §4.2 table lives in `DigRules` over §12.1 data (M2-T3), never in the container.
const SITE_TOTAL_TURNS: int = 2
const OTHER_SITE_TOTAL_TURNS: int = 4

## The COMPLETE public surface of GameState at M2-T5 scope: two fields and SEVENTEEN functions
## (NINETEEN members — grown from five by (AV) to eight, from eight by (AX) to fourteen, and from
## fourteen by (AY) to nineteen in the same commit that adds the dig-site registry, per the
## standing PROGRESS rule). `buildings`, `serialize` and friends all belong to later slices and
## would be invented API here (§13.4).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"player_count",
	"player",
	"turn",
	"current_player_index",
	"set_turn_position",
	"content_hash",
	"spawn_unit",
	"unit",
	"unit_ids",
	"units_of",
	"units_at",
	"remove_unit",
	"add_dig_site",
	"dig_site",
	"dig_site_hexes",
	"dig_site_of_digger",
	"remove_dig_site",
]
const REQUIRED_PUBLIC_VARS: Array[String] = ["map", "rng"]

## §11.1 line 707 (AU)(vi) as amended by (AV) and EXTENDED BY APPENDING by (AX) — the DOCUMENTED
## fold order, as substrings that must appear in `content_hash()`'s body in exactly this
## sequence. A future golden will record this order; until then this scan is what stops it
## drifting silently. NOTE the amendment shape: the roster tokens are APPENDED and NO existing
## token moved, which is the only sanctioned way to grow the fold ((AV)(vi)).
const FOLD_ORDER_TOKENS: Array[String] = [
	"_seed_value",
	"rolls_drawn",
	"turn",
	"current_player_index",
	"map",
	"_next_unit_id",
	"unit_ids",
	"dig_site_hexes",
]

## (AY)/G1 NEGATIVE PIN, RE-SCOPED BY M2-T6 (slice 3b) AND AGAIN BY M2-T7 (slice 4) — the `.gd`
## files `scripts/sim/commands/` and `scripts/sim/events/` hold after this slice. M2-T7 adds
## **ZERO** Commands (§3.4 step 4 is a RULE reached from `EndTurnCommand.apply()`, not a fourth of
## §11.1 line 705's fourteen printed names) and **EXACTLY TWO** Events — `DigProgressedEvent` and
## `DigCompletedEvent`, the FOURTH and FIFTH concrete subclasses ((BA)(v): TWO events, not four,
## with the completion's payload making each sub-change observable). The rule module itself lands
## in `scripts/sim/systems/`, enumerated separately below.
const COMMAND_FILES: Array[String] = [
	"cancel_dig_command.gd",
	"command.gd",
	"command_error.gd",
	"dig_hex_command.gd",
	"end_turn_command.gd",
]
const EVENT_FILES: Array[String] = [
	"dig_cancelled_event.gd",
	"dig_completed_event.gd",
	"dig_progressed_event.gd",
	"dig_started_event.gd",
	"turn_ended_event.gd",
]

## (BA) — §11.2 line 724 prints `systems/` verbatim ("systems/ (economy, breach, escalation,
## victory)"). M2-T7 adds EXACTLY ONE file there: `dig_tick.gd`, §3.4 step 4's rule.
const SYSTEM_FILES: Array[String] = [
	"dig_rules.gd",
	"dig_tick.gd",
]

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§3.3", "§4.2"]


# =============================================================================================
# A. CONSTRUCTION AND THE PLAYER ROSTER (§3.3 "fixed order by player index")
# =============================================================================================

## §11.1/§3.3 — the roster is exactly the requested size, and every index 0..n-1 yields a
## PlayerState. §3.1's "2-4 players" is swept.
func test_the_roster_is_exactly_the_requested_size() -> void:
	for count: int in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		var state: GameState = GameState.new(GOLDEN_SEED, HexMap.new(TEST_MAP_RADIUS), count)
		assert_eq(state.player_count(), count, "§3.3: player_count() == the requested roster size")
		for index: int in range(count):
			assert_not_null(
				state.player(index), "§3.3: player(%d) exists in a %d-player match" % [index, count]
			)


## §3.3 — every index is a DISTINCT, non-aliased PlayerState, and the SAME object each time it is
## asked for, so a mutation through `player(i)` is observable. An implementation handing back a
## throwaway copy, or the same shared object for every index, fails here.
func test_players_are_distinct_stable_objects_per_index() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MAX_PLAYERS)
	var first: PlayerState = state.player(0)
	assert_not_null(first, "sanity: player(0) exists")
	if first == null:
		return
	assert_true(
		is_same(first, state.player(0)),
		"§3.3: player(i) must return the SAME PlayerState each call, not a throwaway copy"
	)
	for index: int in range(1, MAX_PLAYERS):
		var other: PlayerState = state.player(index)
		assert_not_null(other, "sanity: player(%d) exists" % index)
		assert_false(
			is_same(first, other), "§3.3: player(0) and player(%d) must be distinct" % index
		)

	assert_true(first.add(SAMPLE_RESOURCE_ID, 5), "sanity: the deposit is accepted")
	assert_eq(
		state.player(0).amount_of(SAMPLE_RESOURCE_ID),
		5,
		"§3.3: a mutation through player(0) must be visible through player(0)"
	)
	assert_eq(
		state.player(1).amount_of(SAMPLE_RESOURCE_ID),
		0,
		"§3.3/§5.1: stockpiles are PER-PLAYER — player 0's deposit must not reach player 1"
	)


## (AU) totality — an index outside 0..n-1 answers null rather than tearing down a headless run
## (the M1-T1 (B) / M1-T3 (L) / M1-T9 (AS) spirit).
func test_player_is_total_outside_the_roster() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	assert_null(state.player(-1), "(AU): player(-1) is null, not a crash")
	assert_null(state.player(MIN_PLAYERS), "(AU): player(n) is null, not a crash")
	assert_null(state.player(MIN_PLAYERS + 99), "(AU): a far index is null, not a crash")


## (AU) totality — a non-positive roster is the EMPTY roster, and the one seeded RNG still
## exists: a degenerate match must still be a usable, hashable state.
func test_a_non_positive_player_count_is_the_empty_roster() -> void:
	for count: int in [0, -1, -MAX_PLAYERS]:
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		assert_eq(state.player_count(), 0, "(AU): a roster size of %d clamps to 0" % count)
		assert_null(state.player(0), "(AU): the empty roster has no player 0")
		assert_not_null(state.rng, "§11.1: the one seeded RNG exists even with no players")
		var observed: int = state.content_hash()
		assert_gte(observed, 0, "§11.1: a degenerate state still hashes")
		assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")


## (AU) totality — a null map constructs cleanly and the state stays hashable. `map` holds the
## caller's object, it is not copied: the map is shared state, not a snapshot.
func test_a_null_map_constructs_cleanly_and_the_map_is_not_copied() -> void:
	var headless: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	assert_null(headless.map, "(AU): a null map stays null")
	var observed: int = headless.content_hash()
	assert_gte(observed, 0, "§11.1: a mapless state still hashes")
	assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")

	var map: HexMap = HexMap.new(TEST_MAP_RADIUS)
	var mapped: GameState = GameState.new(GOLDEN_SEED, map, MIN_PLAYERS)
	assert_true(is_same(mapped.map, map), "§11.1: GameState holds the map, it does not copy it")


# =============================================================================================
# B. THE ONE SEEDED RNG (§11.1 "the only RNG in the program; every roll goes through state.rng")
# =============================================================================================

## §11.1 / M1-T5 (R) — `state.rng` is an `Rng`: a pure RefCounted exposing the seeded percent
## roll and its stream position, freshly at position 0. Duck-typed via `rolls_drawn()`/
## `roll_percent()` and get_class() — `is Node` would be a PARSE ERROR here.
func test_state_rng_is_the_one_seeded_rng_at_position_zero() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	assert_not_null(state.rng, "§11.1: GameState carries ONE RandomNumberGenerator, via Rng")
	if state.rng == null:
		return
	assert_eq(state.rng.get_class(), "RefCounted", "§11.1: the RNG is a pure RefCounted (Rng)")
	assert_true(state.rng.has_method("roll_percent"), "(R): state.rng exposes roll_percent()")
	assert_true(state.rng.has_method("rolls_drawn"), "(R): state.rng exposes rolls_drawn()")
	assert_eq(state.rng.rolls_drawn(), 0, "§11.1: the match-start stream has drawn nothing yet")


## §11.1 "seeded at match start" — two states built with the same seed produce byte-identical
## roll streams; a different seed produces a different one. This is what makes
## "replaying (seed, command_log) must reproduce the hash" possible at all.
func test_the_stream_is_a_function_of_the_seed_alone() -> void:
	var first: Array[int] = _rolls(GameState.new(GOLDEN_SEED, null, MIN_PLAYERS), SEQUENCE_ROLLS)
	var second: Array[int] = _rolls(GameState.new(GOLDEN_SEED, null, MIN_PLAYERS), SEQUENCE_ROLLS)
	var other: Array[int] = _rolls(GameState.new(OTHER_SEED, null, MIN_PLAYERS), SEQUENCE_ROLLS)
	assert_eq(first.size(), SEQUENCE_ROLLS, "sanity: the sample is complete")
	assert_eq(first, second, "§11.1: the same seed must give the same stream")
	assert_ne(first, other, "§11.1: seeds %d and %d must differ" % [GOLDEN_SEED, OTHER_SEED])


## §11.1 — two GameStates share no RNG state: drawing from one must not advance the other. A
## `static` engine object would make two concurrent matches (or a replay next to a live match)
## non-deterministic.
func test_two_states_share_no_rng() -> void:
	var drained: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	var fresh: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	var pulled: Array[int] = _rolls(drained, SEQUENCE_ROLLS)
	assert_eq(pulled.size(), SEQUENCE_ROLLS, "sanity: the first stream was drawn")
	assert_eq(fresh.rng.rolls_drawn(), 0, "§11.1: drawing from one state must not advance another")
	assert_eq(
		_rolls(fresh, SEQUENCE_ROLLS),
		pulled,
		"§11.1: a second state on the same seed reproduces the sequence from its own start"
	)


# =============================================================================================
# C. content_hash (§11.1 "FNV over canonical serialization ... must be reproducible")
# =============================================================================================

## §11.1 — two states built identically hash identically, and the hash is stable across calls
## (no wall clock, no counter, no roll drawn just to hash).
func test_identical_states_hash_identically_and_reproducibly() -> void:
	var first: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var second: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(first.content_hash(), first.content_hash(), "§11.1: the hash is reproducible")
	assert_eq(
		first.content_hash(), second.content_hash(), "§11.1: identical states hash identically"
	)


## §11.1 / M1-T5 (U) — the hash is a 32-bit value, like every other content hash in the project.
func test_content_hash_stays_within_thirty_two_bits() -> void:
	var samples: Array[GameState] = [
		GameState.new(GOLDEN_SEED, null, 0),
		GameState.new(GOLDEN_SEED, null, MIN_PLAYERS),
		_state(OTHER_SEED, TEST_MAP_RADIUS, MAX_PLAYERS),
	]
	for state: GameState in samples:
		var observed: int = state.content_hash()
		assert_gte(observed, 0, "§11.1: a content hash is unsigned")
		assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")


## §11.1 "replaying (seed, command_log) must reproduce the hash" — the SEED is part of the state,
## so two otherwise-identical states built from different seeds must not collide.
func test_content_hash_folds_the_seed() -> void:
	assert_ne(
		_state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS).content_hash(),
		_state(OTHER_SEED, TEST_MAP_RADIUS, MIN_PLAYERS).content_hash(),
		"§11.1: the match seed is part of the replayable state"
	)


## §11.1 — the RNG STREAM POSITION is part of the state. Two states that agree on every stockpile
## and hex but have rolled a different number of times are NOT the same replayable state: the
## next roll differs, so every future turn diverges.
func test_content_hash_folds_the_rng_stream_position() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var before: int = state.content_hash()
	var roll: int = state.rng.roll_percent()
	assert_gte(roll, 1, "sanity: a percent roll was actually drawn")
	assert_eq(state.rng.rolls_drawn(), 1, "sanity: the stream advanced by exactly one")
	assert_ne(
		state.content_hash(),
		before,
		"§11.1: the RNG stream position is part of the replayable state"
	)


## §11.1 — the roster size is part of the state.
func test_content_hash_folds_the_player_count() -> void:
	assert_ne(
		_state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS).content_hash(),
		_state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS + 1).content_hash(),
		"§11.1: the number of players is part of the state"
	)


## §11.1 — any stockpile change moves the hash: a new id, and a changed amount under a held id.
func test_content_hash_folds_every_player_stockpile() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var player: PlayerState = state.player(0)
	assert_not_null(player, "sanity: player(0) exists")
	if player == null:
		return
	var empty_hash: int = state.content_hash()
	assert_true(player.add(SAMPLE_RESOURCE_ID, 1), "sanity: the deposit is accepted")
	var one_hash: int = state.content_hash()
	assert_ne(empty_hash, one_hash, "§11.1: a player's stockpile is part of the state")
	assert_true(player.add(SAMPLE_RESOURCE_ID, 1), "sanity: the second deposit is accepted")
	assert_ne(one_hash, state.content_hash(), "§11.1: a changed amount changes the hash")

	var second_player: PlayerState = state.player(1)
	assert_not_null(second_player, "sanity: player(1) exists")
	if second_player == null:
		return
	var before_second: int = state.content_hash()
	assert_true(second_player.add(OTHER_RESOURCE_ID, 3), "sanity: the deposit is accepted")
	assert_ne(before_second, state.content_hash(), "§11.1: EVERY player is folded, not just #0")


## §3.3 "fixed order by player index" — players are folded BY INDEX, never as an unordered set.
## Swapping two players' stockpiles between index 0 and index 1 is a DIFFERENT match state (a
## different player is rich), so the hash must change. A set-shaped fold survives every other
## test in this file and dies here.
func test_content_hash_folds_players_by_index_not_as_a_set() -> void:
	var straight: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var swapped: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	if not _deposit(straight, 0, SAMPLE_RESOURCE_ID, 7):
		return
	if not _deposit(straight, 1, OTHER_RESOURCE_ID, 11):
		return
	if not _deposit(swapped, 0, OTHER_RESOURCE_ID, 11):
		return
	if not _deposit(swapped, 1, SAMPLE_RESOURCE_ID, 7):
		return
	assert_ne(
		straight.content_hash(),
		swapped.content_hash(),
		"§3.3: players are folded by INDEX — swapping two players' stockpiles is a new state"
	)


## §11.1 — the map is part of the state: editing ONE hex's terrain type, and separately ONE hex's
## elevation, each moves the hash. This is what welds `HexMap.content_hash()` (M1-T5 (U), whose
## golden `0xcad24923` stays untouched by this task) into the state hash.
func test_content_hash_folds_the_map() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(state.map, "sanity: the fixture carries a map")
	if state.map == null:
		return
	var origin: Vector2i = Vector2i.ZERO
	var before_terrain: int = state.content_hash()
	state.map.set_terrain_type(origin, "hard_rock")
	var after_terrain: int = state.content_hash()
	assert_ne(before_terrain, after_terrain, "§11.1: the map's terrain is part of the state")
	state.map.set_elevation(origin, 3)
	assert_ne(after_terrain, state.content_hash(), "§11.1: the map's elevation is part of the state")


## §11.1 — a PRESENCE flag distinguishes "no map" from "a map": an absent map and an empty map
## are different states and must not collide, whatever either map's own hash happens to be.
func test_a_missing_map_never_collides_with_a_present_one() -> void:
	var mapless: int = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS).content_hash()
	var empty_map: int = GameState.new(GOLDEN_SEED, HexMap.new(-1), MIN_PLAYERS).content_hash()
	var point_map: int = GameState.new(GOLDEN_SEED, HexMap.new(0), MIN_PLAYERS).content_hash()
	assert_ne(mapless, empty_map, "§11.1: \"no map\" and \"the empty map\" are different states")
	assert_ne(mapless, point_map, "§11.1: \"no map\" and \"a one-hex map\" are different states")
	assert_ne(empty_map, point_map, "§11.1: two different maps are different states")


# =============================================================================================
# C2. THE TURN POSITION ((AV); §3.3 line 137 "fixed order by player index")
#     The ROTATION is a rule and lives in EndTurnCommand — GameState only STORES the position.
# =============================================================================================

## (AV) — a fresh state starts at turn 1, index 0, at EVERY roster size including the empty one.
## §3.2 line 133 prints "If turn 200 is reached", which counts from 1.
func test_a_fresh_state_starts_at_turn_one_player_zero() -> void:
	for count: int in [0, -1, MIN_PLAYERS, 3, MAX_PLAYERS]:
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		assert_eq(state.turn(), 1, "(AV): a fresh state is on turn 1 (roster %d)" % count)
		assert_eq(
			state.current_player_index(),
			0,
			"(AV): a fresh state is on player 0 (roster %d)" % count
		)


## (AV) — the one mutator writes BOTH counters, and they read back exactly.
func test_set_turn_position_writes_both_counters() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MAX_PLAYERS)
	state.set_turn_position(7, 3)
	assert_eq(state.turn(), 7, "(AV): the turn is written")
	assert_eq(state.current_player_index(), 3, "(AV): the current player index is written")
	state.set_turn_position(1, 0)
	assert_eq(state.turn(), 1, "(AV): turn 1 is a legal position to return to")
	assert_eq(state.current_player_index(), 0, "(AV): index 0 is a legal position to return to")


## (AV) totality — a turn below 1 is a SILENT NO-OP, and BOTH counters stay put: "both are
## written together or neither is" is what stops a buggy caller parking the state in an
## unreachable position.
func test_set_turn_position_refuses_a_turn_below_one_atomically() -> void:
	for bad_turn: int in [0, -1, -200]:
		var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
		state.set_turn_position(5, 2)
		var before: int = state.content_hash()
		state.set_turn_position(bad_turn, 1)
		assert_eq(state.turn(), 5, "(AV): turn %d is refused — the turn stays put" % bad_turn)
		assert_eq(
			state.current_player_index(),
			2,
			"(AV): turn %d is refused ATOMICALLY — the index stays put too" % bad_turn
		)
		assert_eq(state.content_hash(), before, "(AV): a refused write changes nothing at all")


## (AV) totality — a player index outside 0..player_count()-1 is a SILENT NO-OP, atomically.
func test_set_turn_position_refuses_an_out_of_range_index_atomically() -> void:
	for bad_index: int in [-1, -99, 3, 4, 9999]:
		var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
		state.set_turn_position(5, 2)
		var before: int = state.content_hash()
		state.set_turn_position(9, bad_index)
		assert_eq(
			state.turn(),
			5,
			"(AV): index %d is outside the roster — the turn stays put" % bad_index
		)
		assert_eq(
			state.current_player_index(),
			2,
			"(AV): index %d is outside the roster — the index stays put" % bad_index
		)
		assert_eq(state.content_hash(), before, "(AV): a refused write changes nothing at all")


## (AV) totality — on the EMPTY roster NO index is in range, so every write is refused and the
## degenerate state stays readable at turn 1 / index 0 rather than becoming unreachable.
func test_set_turn_position_is_a_no_op_on_the_empty_roster() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 0)
	var before: int = state.content_hash()
	for index: int in [0, 1, -1]:
		state.set_turn_position(4, index)
	assert_eq(state.turn(), 1, "(AV): the empty roster stays on turn 1")
	assert_eq(state.current_player_index(), 0, "(AV): the empty roster stays on index 0")
	assert_eq(state.content_hash(), before, "(AV): a refused write changes nothing at all")


## (AV)/§11.1 — THE TURN IS PART OF THE REPLAYABLE STATE: two states identical except for the
## turn number must not collide.
func test_content_hash_folds_the_turn() -> void:
	var early: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, 3)
	var late: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, 3)
	early.set_turn_position(1, 1)
	late.set_turn_position(2, 1)
	assert_eq(early.current_player_index(), late.current_player_index(), "sanity: same index")
	assert_ne(
		early.content_hash(),
		late.content_hash(),
		"(AV)/§11.1: the turn number is part of the replayable state"
	)


## (AV)/§3.3 — THE CURRENT PLAYER IS PART OF THE REPLAYABLE STATE: two states identical except
## for whose turn it is must not collide (§3.3 "fixed order by player index").
func test_content_hash_folds_the_current_player_index() -> void:
	var first: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, 3)
	var second: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, 3)
	first.set_turn_position(2, 0)
	second.set_turn_position(2, 1)
	assert_eq(first.turn(), second.turn(), "sanity: same turn")
	assert_ne(
		first.content_hash(),
		second.content_hash(),
		"(AV)/§3.3: whose turn it is is part of the replayable state"
	)


## (AV) — the turn position is INDEPENDENT of the stockpiles: moving the position on two states
## whose players differ still yields two different hashes, and the same position on two identical
## states still yields the same hash (so the fold is a function of both, not of either alone).
func test_the_turn_position_and_the_players_are_folded_independently() -> void:
	var left: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, 3)
	var right: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, 3)
	left.set_turn_position(3, 2)
	right.set_turn_position(3, 2)
	assert_eq(
		left.content_hash(), right.content_hash(), "(AV): equal states at equal positions collide"
	)
	if not _deposit(right, 1, SAMPLE_RESOURCE_ID, 4):
		return
	assert_ne(
		left.content_hash(),
		right.content_hash(),
		"(AV): the position does not mask a stockpile difference"
	)


# =============================================================================================
# C3. THE UNIT ROSTER — STABLE ASCENDING IDS ((AX); §11.1 line 704 "units", line 707 "iterate
#     collections in stable ID order")
# =============================================================================================

## §11.1 line 707 — the FIRST spawned unit is id 1 and ids ascend strictly in spawn order. The
## roster is a top-level GameState collection (§11.1 line 704), not a PlayerState field.
func test_the_first_spawned_unit_is_id_one_and_ids_ascend() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(state.unit_ids(), [] as Array[int], "(AX): a fresh state holds no unit")
	for expected: int in [1, 2, 3]:
		var spawned: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP)
		assert_not_null(spawned, "(AX): a legal spawn is accepted")
		if spawned == null:
			return
		assert_eq(spawned.unit_id(), expected, "§11.1: ids ascend from 1 in spawn order")
		assert_eq(spawned.owner_index(), 0, "§11.1 line 704: the unit carries its owner index")
		assert_eq(spawned.type_id(), UNIT_TYPE_ID, "§12.2: the definition id is stored verbatim")
		assert_eq(spawned.hex(), HEX_A, "§4.1: the unit is placed where it was asked for")
		assert_eq(spawned.hp(), UNIT_MAX_HP, "§12.2: a spawned unit starts at full health")
	assert_eq(state.unit_ids(), [1, 2, 3] as Array[int], "§11.1: stable ID order, ascending")


## (AX) — 0 means "NO UNIT", so `unit(0)` is null even on a populated roster; so are a negative id
## and any id above the highest minted one. Totality in the (B)/(L)/(AS)/(AU) spirit.
func test_id_zero_and_out_of_range_ids_are_no_unit() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_gt(_spawn(state, 0, HEX_A), 0, "sanity: the first spawn is accepted")
	assert_gt(_spawn(state, 1, HEX_B), 0, "sanity: the second spawn is accepted")
	assert_null(state.unit(NO_UNIT_ID), "(AX): 0 means \"no unit\", never the first unit")
	assert_null(state.unit(-1), "(AX): a negative id is null, not a crash")
	assert_null(state.unit(3), "(AX): an unminted id is null, not a crash")
	assert_null(state.unit(9999), "(AX): a far id is null, not a crash")


## (AX)/§11.1 — IDS ARE NEVER REUSED. Re-minting a removed id would silently rebind every
## dangling reference to it and break the replay contract, so the counter only ever moves forward.
func test_unit_ids_are_never_reused_after_a_removal() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	for i: int in range(3):
		assert_gt(_spawn(state, 0, HEX_A), 0, "sanity: spawn %d is accepted" % i)
	assert_true(state.remove_unit(2), "sanity: unit 2 is removed")
	var fourth: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP)
	assert_not_null(fourth, "(AX): spawning after a removal is accepted")
	if fourth == null:
		return
	assert_eq(fourth.unit_id(), 4, "(AX): the freed id 2 is NEVER reused — the next id is 4")
	assert_eq(state.unit_ids(), [1, 3, 4] as Array[int], "§11.1: stable ID order, ascending")


## (AX) — `unit(id)` returns the SAME object every call (the (AU) `player(i)` precedent), so a
## mutation through it persists. An implementation handing back a throwaway copy fails here.
func test_unit_returns_the_same_object_every_call() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var spawned: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP)
	assert_not_null(spawned, "sanity: the spawn is accepted")
	if spawned == null:
		return
	var found: UnitState = state.unit(spawned.unit_id())
	assert_true(is_same(spawned, found), "(AX): spawn_unit returns the ROSTER's object")
	assert_true(
		is_same(state.unit(FIRST_UNIT_ID), state.unit(FIRST_UNIT_ID)),
		"(AX): unit(id) must return the SAME UnitState each call, not a throwaway copy"
	)
	found.set_hp(1)
	assert_eq(
		state.unit(FIRST_UNIT_ID).hp(), 1, "(AX): a mutation through unit(id) must be visible"
	)


## (AX) totality — `remove_unit` answers true EXACTLY ONCE for an id, false on the second call and
## false for an id that never existed; afterwards the unit is gone from every roster view.
func test_remove_unit_is_total_and_answers_true_exactly_once() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(state, 0, HEX_A), FIRST_UNIT_ID, "sanity: the spawn is accepted")
	assert_true(state.remove_unit(FIRST_UNIT_ID), "(AX): the first removal succeeds")
	assert_false(state.remove_unit(FIRST_UNIT_ID), "(AX): the second removal is refused")
	for unknown: int in [NO_UNIT_ID, -1, 2, 9999]:
		assert_false(state.remove_unit(unknown), "(AX): removing id %d is refused" % unknown)
	assert_null(state.unit(FIRST_UNIT_ID), "(AX): a removed unit is gone")
	assert_eq(state.unit_ids(), [] as Array[int], "(AX): gone from unit_ids()")
	assert_eq(state.units_of(0), [] as Array[int], "(AX): gone from units_of()")
	assert_eq(state.units_at(HEX_A), [] as Array[int], "(AX): gone from units_at()")


# =============================================================================================
# C4. CANONICAL ORDER, TOTALITY AND FRESHNESS OF THE ROSTER VIEWS (§11.1 line 707)
# =============================================================================================

## §11.1 line 707 "iterate collections in stable ID order" — `unit_ids()`, `units_of()` and
## `units_at()` are ALL ascending by unit id, even when the units were spawned in a scrambled
## owner/hex order. An implementation that returns `Dictionary.keys()` (insertion order) or that
## groups by owner/hex first fails here.
func test_every_roster_view_is_ascending_by_unit_id() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MAX_PLAYERS)
	assert_eq(_spawn(state, 3, HEX_C), 1, "sanity: id 1 -> owner 3 at C")
	assert_eq(_spawn(state, 0, HEX_A), 2, "sanity: id 2 -> owner 0 at A")
	assert_eq(_spawn(state, 3, HEX_A), 3, "sanity: id 3 -> owner 3 at A")
	assert_eq(_spawn(state, 1, HEX_B), 4, "sanity: id 4 -> owner 1 at B")
	assert_eq(_spawn(state, 0, HEX_C), 5, "sanity: id 5 -> owner 0 at C")
	assert_eq(_spawn(state, 3, HEX_A), 6, "sanity: id 6 -> owner 3 at A")

	assert_eq(state.unit_ids(), [1, 2, 3, 4, 5, 6] as Array[int], "§11.1: ascending by id")
	assert_eq(state.units_of(3), [1, 3, 6] as Array[int], "§11.1: units_of() ascends by id")
	assert_eq(state.units_of(0), [2, 5] as Array[int], "§11.1: units_of() ascends by id")
	assert_eq(state.units_of(1), [4] as Array[int], "§11.1: units_of() ascends by id")
	assert_eq(state.units_of(2), [] as Array[int], "§11.1: a player with no units answers empty")
	assert_eq(
		state.units_at(HEX_A),
		[2, 3, 6] as Array[int],
		"§6.4 is M4: the CONTAINER stacks freely and answers every id on the hex, ascending"
	)
	assert_eq(state.units_at(HEX_C), [1, 5] as Array[int], "§11.1: units_at() ascends by id")
	assert_eq(state.units_at(HEX_B), [4] as Array[int], "§11.1: units_at() ascends by id")


## §11.1/M1-T9 — every roster view is a FRESH Array each call. Pinned with `is_same()` IDENTITY
## assertions AND a mutate-then-re-read pollution check, because a SELF-CLEARING member cache
## passes a pollution-only check (the M1-T9 lesson, re-learned from `resource_ids()` at M2-T1).
func test_roster_views_are_fresh_arrays_every_call() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(state, 0, HEX_A), 1, "sanity: id 1")
	assert_eq(_spawn(state, 0, HEX_A), 2, "sanity: id 2")

	assert_false(
		is_same(state.unit_ids(), state.unit_ids()),
		"§11.1: unit_ids() must build a FRESH array every call, never hand out a cache"
	)
	assert_false(
		is_same(state.units_of(0), state.units_of(0)),
		"§11.1: units_of() must build a FRESH array every call"
	)
	assert_false(
		is_same(state.units_at(HEX_A), state.units_at(HEX_A)),
		"§11.1: units_at() must build a FRESH array every call"
	)

	var expected: Array[int] = [1, 2]
	var pulled_ids: Array[int] = state.unit_ids()
	pulled_ids.clear()
	pulled_ids.append(-1)
	assert_eq(state.unit_ids(), expected, "§11.1: mutating the returned array must not pollute")
	var pulled_owned: Array[int] = state.units_of(0)
	pulled_owned.clear()
	assert_eq(state.units_of(0), expected, "§11.1: mutating the returned array must not pollute")
	var pulled_here: Array[int] = state.units_at(HEX_A)
	pulled_here.clear()
	assert_eq(state.units_at(HEX_A), expected, "§11.1: mutating the returned array must not pollute")


## (AX) totality — `units_of` on an out-of-range owner and `units_at` on an empty hex both answer
## an EMPTY array, never null (the `Los.blocking_hexes` precedent: an explicit empty answer, no
## magic sentinel).
func test_units_of_and_units_at_are_total() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	for probed_owner: int in [-1, -99, MIN_PLAYERS, MIN_PLAYERS + 1, 9999]:
		assert_eq(
			state.units_of(probed_owner),
			[] as Array[int],
			"(AX): units_of(%d) is outside the roster — empty, not null" % probed_owner
		)
	assert_eq(state.units_at(HEX_A), [] as Array[int], "(AX): an empty hex answers empty")
	assert_eq(state.units_at(HEX_OFF_MAP), [] as Array[int], "(AX): an off-map hex answers empty")
	assert_eq(_spawn(state, 0, HEX_A), 1, "sanity: the spawn is accepted")
	assert_eq(state.units_at(HEX_B), [] as Array[int], "(AX): a hex holding nothing answers empty")
	for probed_owner: int in [-1, MIN_PLAYERS, 9999]:
		assert_eq(
			state.units_of(probed_owner),
			[] as Array[int],
			"(AX): units_of(%d) stays empty on a populated roster" % probed_owner
		)


# =============================================================================================
# C5. TOTALITY AND ATOMICITY OF spawn_unit ((AX); the (AU)/(AL) totality precedent)
# =============================================================================================

## (AX) — an owner index outside `0..player_count()-1` is REFUSED (null). §8.1's creeps and §3.2's
## "their units become neutral hostiles" will need an explicit owner sentinel when M5 lands; -1
## must NOT be silently invented here.
func test_spawn_unit_refuses_an_owner_outside_the_roster() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	for bad_owner: int in [-1, -99, MIN_PLAYERS, MIN_PLAYERS + 1, 9999]:
		assert_null(
			state.spawn_unit(bad_owner, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP),
			"(AX): owner %d is outside 0..player_count()-1 and must be refused" % bad_owner
		)
	assert_eq(state.unit_ids(), [] as Array[int], "(AX): a refused spawn creates no unit")


## (AX) — on the EMPTY roster NO owner index is in range, so every spawn is refused and the
## degenerate state stays a usable, hashable state.
func test_every_owner_index_is_refused_on_the_empty_roster() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 0)
	for probed_owner: int in [-1, 0, 1, MAX_PLAYERS]:
		assert_null(
			state.spawn_unit(probed_owner, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP),
			"(AX): the empty roster owns nothing — owner %d is refused" % probed_owner
		)
	assert_eq(state.unit_ids(), [] as Array[int], "(AX): the empty roster holds no unit")


## (AX) — an EMPTY `type_id` and a non-positive `max_hp` are refused. `type_id` is opaque, so the
## only thing that can be checked without inventing a whitelist is that it is non-empty; `max_hp`
## is caller-supplied, and a unit with no health at all is not a representable §12.2 unit.
func test_spawn_unit_refuses_an_empty_type_id_and_a_non_positive_max_hp() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_null(
		state.spawn_unit(0, "", HEX_A, UNIT_MAX_HP), "(AX): an empty definition id is refused"
	)
	for bad_hp: int in [0, -1, -5]:
		assert_null(
			state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, bad_hp),
			"(AX): max_hp %d is refused — a §12.2 unit has health" % bad_hp
		)
	assert_eq(state.unit_ids(), [] as Array[int], "(AX): a refused spawn creates no unit")


## (AX) — EVERY refusal is ATOMIC: `content_hash()` is byte-identical before and after, AND THE ID
## COUNTER DOES NOT ADVANCE. The second half is the assertion that catches an id burned on a
## rejected spawn — a bug no hash comparison alone can see.
func test_a_refused_spawn_is_atomic_and_burns_no_id() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var before: int = state.content_hash()
	assert_null(state.spawn_unit(-1, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP), "sanity: refused")
	assert_null(state.spawn_unit(MIN_PLAYERS, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP), "sanity: refused")
	assert_null(state.spawn_unit(0, "", HEX_A, UNIT_MAX_HP), "sanity: refused")
	assert_null(state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, 0), "sanity: refused")
	assert_null(state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, -5), "sanity: refused")
	assert_eq(state.content_hash(), before, "(AX): a refused spawn changes nothing at all")

	var first: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP)
	assert_not_null(first, "sanity: the legal spawn is accepted")
	if first == null:
		return
	assert_eq(first.unit_id(), FIRST_UNIT_ID, "(AX): five refusals burned NO id — the next id is 1")

	var mid: int = state.content_hash()
	assert_null(state.spawn_unit(9999, UNIT_TYPE_ID, HEX_B, UNIT_MAX_HP), "sanity: refused")
	assert_null(state.spawn_unit(0, "", HEX_B, UNIT_MAX_HP), "sanity: refused")
	assert_eq(state.content_hash(), mid, "(AX): a refused spawn changes nothing at all")
	var second: UnitState = state.spawn_unit(1, OTHER_UNIT_TYPE_ID, HEX_B, UNIT_MAX_HP)
	assert_not_null(second, "sanity: the legal spawn is accepted")
	if second == null:
		return
	assert_eq(second.unit_id(), 2, "(AX): refusals after a spawn burn NO id either")


## (AX) — PLACEMENT IS NOT VALIDATED HERE. `spawn_unit` accepts any `Vector2i` and never consults
## `map`: legality (cave hex, in bounds, §5.2 housing free) is a Command rule for a LATER slice,
## and §6.4's stacking legality is M4. Pinned positively so a later slice cannot claim the
## container was silently enforcing it.
func test_spawn_unit_validates_no_placement_and_stacks_freely() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(state.map, "sanity: the fixture carries a map")
	assert_eq(_spawn(state, 0, HEX_OFF_MAP), 1, "(AX): a hex far outside the map is accepted")
	assert_eq(
		state.units_at(HEX_OFF_MAP), [1] as Array[int], "(AX): the unit really is placed there"
	)
	assert_eq(_spawn(state, 0, HEX_A), 2, "sanity: a second spawn")
	assert_eq(_spawn(state, 1, HEX_A), 3, "(AX): two OWNERS may stack on one hex at this layer")
	assert_eq(_spawn(state, 1, HEX_A), 4, "(AX): §5.2 housing is not enforced by the container")
	assert_eq(
		state.units_at(HEX_A), [2, 3, 4] as Array[int], "§6.4 is M4 — the container stacks freely"
	)


# =============================================================================================
# C6. UNIT RECORDS THROUGH THE CONTAINER ((AX); §3.4 step 2, §4.1)
# =============================================================================================

## (AX) NEGATIVE PIN — `set_hp(0)` does NOT remove the unit. Whether 0 hp kills is a RULE (§6, §3.4
## step 2's bleed) and belongs to a later slice; pinned negatively so the container never grows a
## hidden rule.
func test_a_unit_at_zero_hp_stays_in_the_roster() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(state, 0, HEX_A), FIRST_UNIT_ID, "sanity: the spawn is accepted")
	var gunner: UnitState = state.unit(FIRST_UNIT_ID)
	assert_not_null(gunner, "sanity: the unit is in the roster")
	if gunner == null:
		return
	gunner.set_hp(0)
	assert_eq(gunner.hp(), 0, "(AX): 0 hp is representable")
	assert_eq(state.unit_ids(), [FIRST_UNIT_ID] as Array[int], "(AX): 0 hp does NOT remove")
	assert_eq(state.units_of(0), [FIRST_UNIT_ID] as Array[int], "(AX): 0 hp does NOT remove")
	assert_eq(state.units_at(HEX_A), [FIRST_UNIT_ID] as Array[int], "(AX): 0 hp does NOT remove")
	assert_not_null(state.unit(FIRST_UNIT_ID), "(AX): 0 hp does NOT remove")


## (AX)/§4.1 — `set_hex` moves the unit between the `units_at` buckets, and both buckets stay
## ascending by id. `units_at` is a LINEAR SCAN over the roster, never a reverse index that could
## drift out of sync with the units themselves (a second source of truth is a determinism hazard).
func test_set_hex_moves_a_unit_between_the_units_at_buckets() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(state, 0, HEX_A), 1, "sanity: id 1 at A")
	assert_eq(_spawn(state, 0, HEX_A), 2, "sanity: id 2 at A")
	assert_eq(_spawn(state, 0, HEX_B), 3, "sanity: id 3 at B")
	var mover: UnitState = state.unit(1)
	assert_not_null(mover, "sanity: unit 1 is in the roster")
	if mover == null:
		return
	mover.set_hex(HEX_B)
	assert_eq(state.units_at(HEX_A), [2] as Array[int], "(AX): the old hex loses the id")
	assert_eq(state.units_at(HEX_B), [1, 3] as Array[int], "(AX): the new hex gains it, ascending")
	assert_eq(state.unit_ids(), [1, 2, 3] as Array[int], "(AX): a move changes no id")


# =============================================================================================
# C7. THE ROSTER IN THE CONTENT HASH ((AX); §11.1 line 707/708)
# =============================================================================================

## §11.1 — two states populated identically hash identically, repeatedly, and within 32 bits.
func test_identically_populated_states_hash_identically() -> void:
	var first: GameState = _populated(GOLDEN_SEED)
	var second: GameState = _populated(GOLDEN_SEED)
	assert_eq(first.content_hash(), first.content_hash(), "§11.1: the hash is reproducible")
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: two states with identical rosters hash identically"
	)
	var observed: int = first.content_hash()
	assert_gte(observed, 0, "§11.1: a content hash is unsigned")
	assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")


## §11.1 — the roster is part of the replayable state: spawning moves the hash, and so does any
## change to a unit's OWN record (which is what welds `UnitState.content_hash()` into the state).
func test_content_hash_folds_the_unit_roster_and_each_units_record() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var empty_hash: int = state.content_hash()
	assert_eq(_spawn(state, 0, HEX_A), FIRST_UNIT_ID, "sanity: the spawn is accepted")
	var one_hash: int = state.content_hash()
	assert_ne(empty_hash, one_hash, "§11.1: the unit roster is part of the state")

	var gunner: UnitState = state.unit(FIRST_UNIT_ID)
	assert_not_null(gunner, "sanity: the unit is in the roster")
	if gunner == null:
		return
	gunner.set_hp(1)
	var hurt_hash: int = state.content_hash()
	assert_ne(one_hash, hurt_hash, "§11.1: a unit's hp is part of the state")
	gunner.set_hex(HEX_B)
	assert_ne(hurt_hash, state.content_hash(), "§11.1: a unit's position is part of the state")

	assert_eq(_spawn(state, 1, HEX_C), 2, "sanity: a second spawn")
	assert_ne(hurt_hash, state.content_hash(), "§11.1: EVERY unit is folded, not just the first")


## §11.1 line 707 — UNITS ARE FOLDED BY ID, NEVER AS A SET. Two states holding the same two units
## with the owners SWAPPED between id 1 and id 2 are different match states (a different player
## owns the first unit), so the hashes must differ. A multiset-shaped fold survives every other
## test in this file and dies exactly here (the (AU) lesson (b), which only the swap catches).
func test_content_hash_folds_units_by_id_not_as_a_set() -> void:
	var straight: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(straight, 0, HEX_A), 1, "sanity: id 1 -> owner 0")
	assert_eq(_spawn(straight, 1, HEX_A), 2, "sanity: id 2 -> owner 1")

	var swapped: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(swapped, 1, HEX_A), 1, "sanity: id 1 -> owner 1")
	assert_eq(_spawn(swapped, 0, HEX_A), 2, "sanity: id 2 -> owner 0")

	assert_eq(straight.unit_ids(), swapped.unit_ids(), "fixture: the two rosters hold the same ids")
	assert_ne(
		straight.content_hash(),
		swapped.content_hash(),
		"§11.1: units are folded BY ID — swapping two units' owners is a new state"
	)


## §11.1 line 708 "replaying (seed, command\_log) must reproduce the hash" — SPAWNING THREE UNITS
## AND REMOVING ALL THREE DOES NOT HASH LIKE NEVER HAVING SPAWNED. The two states differ only in
## `_next_unit_id`, and that difference is real: the next spawn is id 4 in one and id 1 in the
## other, so every future command log diverges. This is the test that makes folding
## `_next_unit_id` load-bearing.
func test_spawning_then_removing_every_unit_does_not_hash_like_never_spawning() -> void:
	var churned: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	for i: int in range(3):
		assert_gt(_spawn(churned, 0, HEX_A), 0, "sanity: spawn %d is accepted" % i)
	for id: int in [1, 2, 3]:
		assert_true(churned.remove_unit(id), "sanity: unit %d is removed" % id)

	var fresh: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(churned.unit_ids(), [] as Array[int], "fixture: the churned roster is empty")
	assert_eq(fresh.unit_ids(), [] as Array[int], "fixture: the fresh roster is empty")
	assert_ne(
		churned.content_hash(),
		fresh.content_hash(),
		"§11.1: the id counter is part of the replayable state — the next spawn differs"
	)

	var churned_next: UnitState = churned.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP)
	var fresh_next: UnitState = fresh.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP)
	assert_not_null(churned_next, "sanity: the churned state still spawns")
	assert_not_null(fresh_next, "sanity: the fresh state still spawns")
	if churned_next == null or fresh_next == null:
		return
	assert_eq(churned_next.unit_id(), 4, "(AX): ids are never reused after a removal")
	assert_eq(fresh_next.unit_id(), FIRST_UNIT_ID, "(AX): a fresh state still starts at 1")


## §11.1 — the roster is folded INDEPENDENTLY of the rest of the state: two states that differ
## only in a unit's definition id, and two that differ only in a unit's max_hp, must not collide.
func test_content_hash_separates_states_differing_only_in_one_units_record() -> void:
	var left: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var right: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(
		left.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP), "sanity: the left spawn is accepted"
	)
	assert_not_null(
		right.spawn_unit(0, OTHER_UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP),
		"sanity: the right spawn is accepted"
	)
	assert_ne(
		left.content_hash(), right.content_hash(), "§12.2: a unit's definition id reaches the hash"
	)

	var tough: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(
		tough.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP + 1),
		"sanity: the tough spawn is accepted"
	)
	assert_ne(
		left.content_hash(), tough.content_hash(), "§3.4 step 2: a unit's max_hp reaches the hash"
	)


# =============================================================================================
# C9. THE DIG-SITE REGISTRY ((AY); §4.2, §11.1 line 704 "nodes", line 707 stable order)
#     A pure CONTAINER: adjacency, diggability and §4.2 line 197's cap are the COMMAND's rules
#     (pinned in `tests/unit/test_dig_hex_command.gd`), never the registry's.
# =============================================================================================

## (AY) — a fresh state holds NO dig site, and `add_dig_site` hands back a `DigSite` carrying the
## identity it was asked for, reachable afterwards through `dig_site(hex)`.
func test_add_dig_site_registers_a_site_with_the_requested_identity() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "(AY): a fresh state holds no site")
	assert_null(state.dig_site(SITE_HEX_A), "(AY): an unregistered hex answers null")

	var site: DigSite = state.add_dig_site(SITE_HEX_A, 1, SITE_TOTAL_TURNS)
	assert_not_null(site, "(AY): a legal registration is accepted")
	if site == null:
		return
	assert_eq(site.hex(), SITE_HEX_A, "(AY): the site knows its hex")
	assert_eq(site.owner_index(), 1, "(AY): ONE owner per site — the ordering player")
	assert_eq(site.total_turns(), SITE_TOTAL_TURNS, "§4.2: the caller supplies the dig time")
	assert_eq(site.remaining_turns(), SITE_TOTAL_TURNS, "§4.2: a fresh site has all turns left")
	assert_eq(site.digger_ids(), [] as Array[int], "(AY): the COMMAND assigns the diggers")
	assert_eq(
		state.dig_site_hexes(), [SITE_HEX_A] as Array[Vector2i], "(AY): the site is registered"
	)


## (AY) — `dig_site(hex)` returns the SAME object every call (the `player()`/`unit()` precedent),
## so a mutation through it persists. An implementation handing back a throwaway copy fails here.
func test_dig_site_returns_the_same_object_every_call() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var registered: DigSite = state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS)
	assert_not_null(registered, "sanity: the registration is accepted")
	if registered == null:
		return
	assert_true(
		is_same(registered, state.dig_site(SITE_HEX_A)),
		"(AY): add_dig_site returns the REGISTRY's object"
	)
	assert_true(
		is_same(state.dig_site(SITE_HEX_A), state.dig_site(SITE_HEX_A)),
		"(AY): dig_site(hex) must return the SAME DigSite each call, not a throwaway copy"
	)
	registered.set_remaining_turns(1)
	assert_eq(
		state.dig_site(SITE_HEX_A).remaining_turns(),
		1,
		"(AY): a mutation through dig_site(hex) must be visible on the next call"
	)


## (AY) — a DUPLICATE hex is refused (null): one site per hex, so "the site on this hex" is a
## function. The refusal is ATOMIC — the existing site is untouched and the hash does not move.
func test_add_dig_site_refuses_a_duplicate_hex_atomically() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var first: DigSite = state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS)
	assert_not_null(first, "sanity: the first registration is accepted")
	if first == null:
		return
	var before: int = state.content_hash()
	assert_null(
		state.add_dig_site(SITE_HEX_A, 1, OTHER_SITE_TOTAL_TURNS),
		"(AY): a second site on the same hex is refused"
	)
	assert_true(is_same(state.dig_site(SITE_HEX_A), first), "(AY): the original site is untouched")
	assert_eq(first.owner_index(), 0, "(AY): the refusal did not re-own the site")
	assert_eq(first.total_turns(), SITE_TOTAL_TURNS, "(AY): the refusal did not re-size the site")
	assert_eq(state.content_hash(), before, "(AY): a refused registration changes nothing at all")


## (AY) — an owner outside `0..player_count()-1` and a non-positive `total_turns` are REFUSED,
## atomically. §8.1's creeps and §3.2's "their units become neutral hostiles" will need an explicit
## owner sentinel at M5; -1 must NOT be silently invented here (the (AX) rule).
func test_add_dig_site_refuses_an_illegal_owner_or_total_atomically() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var before: int = state.content_hash()
	for bad_owner: int in [-1, -99, MIN_PLAYERS, MIN_PLAYERS + 1, 9999]:
		assert_null(
			state.add_dig_site(SITE_HEX_A, bad_owner, SITE_TOTAL_TURNS),
			"(AY): owner %d is outside 0..player_count()-1 and must be refused" % bad_owner
		)
	for bad_total: int in [0, -1, -SITE_TOTAL_TURNS]:
		assert_null(
			state.add_dig_site(SITE_HEX_A, 0, bad_total),
			"(AY): total_turns %d is not a §4.2 dig time and must be refused" % bad_total
		)
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "(AY): no site was registered")
	assert_eq(state.content_hash(), before, "(AY): every refusal is ATOMIC")


## (AY) — on the EMPTY roster NO owner index is in range, so every dig-site registration is refused
## and the degenerate state stays a usable, hashable state (the (AX) `spawn_unit` precedent).
func test_every_owner_index_is_refused_for_a_dig_site_on_the_empty_roster() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 0)
	for probed_owner: int in [-1, 0, 1, MAX_PLAYERS]:
		assert_null(
			state.add_dig_site(SITE_HEX_A, probed_owner, SITE_TOTAL_TURNS),
			"(AY): the empty roster owns nothing — owner %d is refused" % probed_owner
		)
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "(AY): the empty roster holds no site")


## (AY) — PLACEMENT AND TERRAIN ARE NOT VALIDATED HERE. The registry accepts ANY `Vector2i` and
## never consults `map`: adjacency, diggability and §4.2 line 197's cap are the COMMAND's rules.
## Pinned positively so a later slice cannot claim the container was silently enforcing them.
func test_add_dig_site_validates_no_placement_or_terrain() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(state.map, "sanity: the fixture carries a map")
	assert_not_null(
		state.add_dig_site(HEX_OFF_MAP, 0, SITE_TOTAL_TURNS),
		"(AY): a hex far outside the map is accepted — legality is the Command's job"
	)
	assert_not_null(
		state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS),
		"(AY): a hex with NO terrain set is accepted — diggability is the Command's job"
	)
	assert_eq(state.dig_site_hexes().size(), 2, "(AY): both registrations took")


## §11.1 line 707 "iterate collections in stable ID order" / (AY) — `dig_site_hexes()` enumerates
## in the CANONICAL order **r ascending, then q ascending** (the same order `HexMap.hexes()`
## produces), NOT `Vector2i`'s default `<` (which sorts x first). The fixture is chosen so those
## two orders DIFFER, which is what makes this test load-bearing.
func test_dig_site_hexes_uses_the_canonical_r_then_q_order() -> void:
	var state: GameState = _sited(GOLDEN_SEED)
	assert_eq(
		state.dig_site_hexes(),
		SITE_CANONICAL_ORDER,
		"§11.1 line 707: dig sites enumerate r ascending, then q ascending"
	)

	var default_order: Array[Vector2i] = SITE_INSERTION_ORDER.duplicate()
	default_order.sort()
	assert_ne(
		default_order,
		SITE_CANONICAL_ORDER,
		"fixture: Vector2i's DEFAULT sort must differ from the canonical order, or this pins nothing"
	)


## (AY) — the enumeration is a function of the SET of registered hexes, not of insertion order:
## two states built in OPPOSITE order enumerate identically AND hash identically.
func test_insertion_order_changes_neither_the_enumeration_nor_the_hash() -> void:
	var forwards: GameState = _sited(GOLDEN_SEED)
	var backwards: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var reversed_order: Array[Vector2i] = []
	for i: int in range(SITE_INSERTION_ORDER.size()):
		reversed_order.append(SITE_INSERTION_ORDER[SITE_INSERTION_ORDER.size() - 1 - i])
	for where: Vector2i in reversed_order:
		assert_not_null(
			backwards.add_dig_site(where, 0, SITE_TOTAL_TURNS),
			"fixture: %s is registered" % str(where)
		)
	assert_eq(
		backwards.dig_site_hexes(),
		forwards.dig_site_hexes(),
		"§11.1 line 707: the canonical order does not depend on insertion order"
	)
	assert_eq(
		backwards.content_hash(),
		forwards.content_hash(),
		"§11.1: two states holding the same sites are the same replayable state"
	)


## §11.1/M1-T9 — `dig_site_hexes()` builds a FRESH Array every call. Pinned with an `is_same()`
## IDENTITY assertion AND a mutate-then-re-read pollution check, because a SELF-CLEARING member
## cache passes a pollution-only check (the M1-T9 lesson, re-learned at M2-T1 and M2-T4).
func test_dig_site_hexes_is_a_fresh_array_every_call() -> void:
	var state: GameState = _sited(GOLDEN_SEED)
	assert_false(
		is_same(state.dig_site_hexes(), state.dig_site_hexes()),
		"§11.1: dig_site_hexes() must build a FRESH array every call, never hand out a cache"
	)
	var pulled: Array[Vector2i] = state.dig_site_hexes()
	pulled.clear()
	pulled.append(HEX_OFF_MAP)
	assert_eq(
		state.dig_site_hexes(),
		SITE_CANONICAL_ORDER,
		"§11.1: mutating the returned array must not pollute the registry"
	)


## (AY) — `dig_site_of_digger` is a LINEAR SCAN over `dig_site_hexes()`, never a reverse index (a
## second source of truth is a determinism hazard). It answers the SAME object `dig_site(hex)` does
## and null for a unit that digs nothing, including id 0 ("no unit") and a negative id.
func test_dig_site_of_digger_finds_the_one_job_and_is_total() -> void:
	var state: GameState = _sited(GOLDEN_SEED)
	assert_null(state.dig_site_of_digger(1), "(AY): a unit digging nothing answers null")
	for bad_id: int in [NO_UNIT_ID, -1, 9999]:
		assert_null(state.dig_site_of_digger(bad_id), "(AY): id %d digs nothing" % bad_id)

	var here: DigSite = state.dig_site(SITE_HEX_A)
	var there: DigSite = state.dig_site(SITE_HEX_C)
	assert_not_null(here, "sanity: the site on A exists")
	assert_not_null(there, "sanity: the site on C exists")
	if here == null or there == null:
		return
	assert_true(here.add_digger(1), "fixture: unit 1 digs the site on A")
	assert_true(there.add_digger(2), "fixture: unit 2 digs the site on C")
	assert_true(is_same(state.dig_site_of_digger(1), here), "(AY): unit 1's job is the site on A")
	assert_true(is_same(state.dig_site_of_digger(2), there), "(AY): unit 2's job is the site on C")
	assert_null(state.dig_site_of_digger(3), "(AY): unit 3 still digs nothing")

	assert_true(here.remove_digger(1), "fixture: unit 1 is unassigned")
	assert_null(state.dig_site_of_digger(1), "(AY): an unassigned unit digs nothing again")


## (AY) totality — `remove_dig_site` answers true EXACTLY ONCE for a registered hex, false on the
## second call and false for a hex that never had one; afterwards the site is gone from every view.
func test_remove_dig_site_is_total_and_answers_true_exactly_once() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var site: DigSite = state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS)
	assert_not_null(site, "sanity: the registration is accepted")
	if site == null:
		return
	assert_true(site.add_digger(1), "fixture: unit 1 digs it")
	assert_true(state.remove_dig_site(SITE_HEX_A), "(AY): the first removal succeeds")
	assert_false(state.remove_dig_site(SITE_HEX_A), "(AY): the second removal is refused")
	for unknown: Vector2i in [SITE_HEX_B, SITE_HEX_C, HEX_OFF_MAP]:
		assert_false(
			state.remove_dig_site(unknown), "(AY): removing %s is refused" % str(unknown)
		)
	assert_null(state.dig_site(SITE_HEX_A), "(AY): a removed site is gone")
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "(AY): gone from dig_site_hexes()")
	assert_null(state.dig_site_of_digger(1), "(AY): its digger holds no job any more")


## (AY)/§3.4 step 4 NEGATIVE PIN — `set_remaining_turns` CLAMPS into `[0, total_turns]` and DOES
## NOT remove the site: completion is a RULE (§3.4 step 4), and it is SLICE 4. Pinned through the
## registry as well as on the record, because "the site vanishes at 0" is exactly the shortcut a
## later slice might take without saying so.
func test_a_site_at_zero_remaining_stays_in_the_registry() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var site: DigSite = state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS)
	assert_not_null(site, "sanity: the registration is accepted")
	if site == null:
		return
	site.set_remaining_turns(-1)
	assert_eq(site.remaining_turns(), 0, "(AY): the clamp floors at 0")
	site.set_remaining_turns(SITE_TOTAL_TURNS + 99)
	assert_eq(site.remaining_turns(), SITE_TOTAL_TURNS, "(AY): the clamp saturates at total_turns")
	site.set_remaining_turns(0)
	assert_not_null(state.dig_site(SITE_HEX_A), "§3.4 step 4 is SLICE 4 — 0 does NOT remove")
	assert_eq(
		state.dig_site_hexes(),
		[SITE_HEX_A] as Array[Vector2i],
		"§3.4 step 4 is SLICE 4 — the exhausted site is still registered"
	)


# =============================================================================================
# C10. THE DIG-SITE REGISTRY IN THE CONTENT HASH ((AY); §11.1 line 707/708)
# =============================================================================================

## §11.1 — the registry is part of the replayable state: registering a site moves the hash, and so
## does any change to a site's OWN record (which is what welds `DigSite.content_hash()` in).
func test_content_hash_folds_the_registry_and_each_sites_record() -> void:
	var state: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	var empty_hash: int = state.content_hash()
	var site: DigSite = state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS)
	assert_not_null(site, "sanity: the registration is accepted")
	if site == null:
		return
	var one_hash: int = state.content_hash()
	assert_ne(empty_hash, one_hash, "§11.1: the dig-site registry is part of the state")

	site.set_remaining_turns(1)
	var worked_hash: int = state.content_hash()
	assert_ne(one_hash, worked_hash, "§4.2: a site's REMAINING time is part of the state")
	assert_true(site.add_digger(1), "sanity: a digger is assigned")
	var staffed_hash: int = state.content_hash()
	assert_ne(worked_hash, staffed_hash, "§4.2 line 197: the digger set is part of the state")

	assert_not_null(
		state.add_dig_site(SITE_HEX_B, 1, OTHER_SITE_TOTAL_TURNS), "sanity: a second registration"
	)
	assert_ne(staffed_hash, state.content_hash(), "§11.1: EVERY site is folded, not just the first")


## §11.1 line 707 — SITES ARE FOLDED BY HEX, NEVER AS A SET. Two states holding the same two sites
## with the OWNERS swapped between the two hexes are different match states, so the hashes must
## differ. A multiset-shaped fold survives every other test in this file and dies exactly here.
func test_content_hash_folds_sites_by_hex_not_as_a_set() -> void:
	var straight: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(straight.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS), "sanity: A -> owner 0")
	assert_not_null(straight.add_dig_site(SITE_HEX_B, 1, SITE_TOTAL_TURNS), "sanity: B -> owner 1")

	var swapped: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(swapped.add_dig_site(SITE_HEX_A, 1, SITE_TOTAL_TURNS), "sanity: A -> owner 1")
	assert_not_null(swapped.add_dig_site(SITE_HEX_B, 0, SITE_TOTAL_TURNS), "sanity: B -> owner 0")

	assert_eq(
		straight.dig_site_hexes(), swapped.dig_site_hexes(), "fixture: the same two hexes are dug"
	)
	assert_ne(
		straight.content_hash(),
		swapped.content_hash(),
		"§11.1: sites are folded BY HEX — swapping two sites' owners is a new state"
	)


## (AY) — THE DELIBERATE DIVERGENCE FROM (AX)'s `_next_unit_id`, asserted POSITIVELY so it cannot
## drift silently: "registered every site then removed every site" DOES hash like "never registered
## anything". A unit id is a MINTED identity that dangling references depend on, so (AX) folds the
## counter; a dig site is keyed by its HEX, mints nothing and leaves nothing dangling, so there is
## no counter to fold and none may be invented.
func test_adding_then_removing_every_site_hashes_like_never_adding_one() -> void:
	var churned: GameState = _sited(GOLDEN_SEED)
	for where: Vector2i in SITE_INSERTION_ORDER:
		assert_true(churned.remove_dig_site(where), "sanity: %s is removed" % str(where))
	var fresh: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(churned.dig_site_hexes(), [] as Array[Vector2i], "fixture: the churned registry is empty")
	assert_eq(
		churned.content_hash(),
		fresh.content_hash(),
		"(AY): a dig site has no dangling identity — unlike (AX)'s _next_unit_id, nothing is folded"
	)

	var unit_churned: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_eq(_spawn(unit_churned, 0, HEX_A), FIRST_UNIT_ID, "sanity: a unit is minted")
	assert_true(unit_churned.remove_unit(FIRST_UNIT_ID), "sanity: the unit is removed")
	assert_ne(
		unit_churned.content_hash(),
		fresh.content_hash(),
		"(AX): the CONTRAST — a minted unit id IS folded, which is why the two rules differ"
	)


## §11.1 — the registry is folded INDEPENDENTLY of the rest of the state: two states differing only
## in a site's total dig time, and two differing only in which hex is being dug, must not collide.
func test_content_hash_separates_states_differing_only_in_one_site() -> void:
	var left: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(left.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS), "sanity")
	var deeper: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(deeper.add_dig_site(SITE_HEX_A, 0, OTHER_SITE_TOTAL_TURNS), "sanity")
	assert_ne(
		left.content_hash(), deeper.content_hash(), "§4.2: the site's total dig time reaches the hash"
	)

	var elsewhere: GameState = _state(GOLDEN_SEED, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(elsewhere.add_dig_site(SITE_HEX_B, 0, SITE_TOTAL_TURNS), "sanity")
	assert_ne(
		left.content_hash(), elsewhere.content_hash(), "§4.1: WHICH hex is being dug reaches the hash"
	)


# =============================================================================================
# C8. §13.4 NEGATIVE PINS — what M2-T5 deliberately does NOT add
# =============================================================================================

## (AY)/G1, RE-SCOPED BY M2-T6 AND AGAIN BY M2-T7 — slice 4 adds ZERO Command files, EXACTLY TWO
## Event files (`DigProgressedEvent`, `DigCompletedEvent`) and EXACTLY ONE `systems/` file
## (`DigTick`). Pinned by enumerating the three spine directories so a stray file cannot appear
## unremarked (§13.4) — and so "(BA)(v): TWO events, not four" is enforced on disk, not only in
## prose.
func test_exactly_the_expected_spine_files_exist_after_this_slice() -> void:
	assert_eq(
		_gd_files("res://scripts/sim/commands"),
		COMMAND_FILES,
		"(BA): M2-T7 adds NO Command — §3.4 step 4 is a rule reached from EndTurnCommand.apply()"
	)
	assert_eq(
		_gd_files("res://scripts/sim/events"),
		EVENT_FILES,
		"(BA)(v): M2-T7 adds exactly TWO Events — dig_progressed and dig_completed, not four"
	)
	assert_eq(
		_gd_files("res://scripts/sim/systems"),
		SYSTEM_FILES,
		"§11.2 line 724/(BA): M2-T7 adds exactly one systems/ file — the §3.4 step-4 rule"
	)


## §3.4 (lines 141–165) NEGATIVE PIN, EXTENDED BY (AX) AND (AY) AND RE-SCOPED BY M2-T7 — the other
## eight per-player start-of-turn steps and the three World-phase steps are ALL still
## unimplemented, and §3.4 step 4 ticks only when a [DigRules] is INJECTED ((BA)(vi)). This
## fixture builds `EndTurnCommand.new(index)` with NO table, so after any number of accepted
## EndTurns NO unit is spawned, moved, paid, bled or killed, **no dig progress is spent**, no site
## is removed, and the one seeded stream has still drawn nothing. The POSITIVE counterpart lives in
## `tests/unit/test_dig_tick.gd` / `tests/sim/test_dig_scenario.gd`.
func test_ending_turns_without_dig_rules_spawns_no_unit_and_ticks_no_dig() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MAX_PLAYERS)
	var site: DigSite = state.add_dig_site(SITE_HEX_A, 0, SITE_TOTAL_TURNS)
	assert_not_null(site, "fixture: a dig site is registered")
	if site == null:
		return
	for k: int in range(3 * MAX_PLAYERS):
		var rejection: CommandError = EndTurnCommand.new(state.current_player_index()).execute(
			state, null
		)
		assert_null(rejection, "sanity: EndTurn %d is accepted" % k)
	assert_eq(
		state.unit_ids(),
		[] as Array[int],
		"§3.4: no rule spawns a unit yet — the roster is written only by spawn_unit"
	)
	assert_eq(
		state.dig_site_hexes(),
		[SITE_HEX_A] as Array[Vector2i],
		"§3.4 step 4 is SLICE 4 — no dig completes and no site is removed"
	)
	assert_eq(
		site.remaining_turns(),
		SITE_TOTAL_TURNS,
		"§3.4 step 4 is SLICE 4 — \"Dig progress ticks\" spends NO worker-turn yet"
	)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1: nothing in this slice is random — the one seeded stream must not advance"
	)


# =============================================================================================
# D. MECHANICAL SOURCE SCANS ON scripts/sim/game_state.gd (§11.1, §11.2, §11.3, §13.6)
#    Written FRESH for this file — a new file inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)". Comment stripping
## is LOAD-BEARING: the doc block above cites "§11.1"/"§3.3", which `\.[0-9]` would hit.
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(GAME_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			GAME_STATE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % GAME_STATE_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % GAME_STATE_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R): there is exactly ONE
## RandomNumberGenerator in the program and it lives in `scripts/core/rng.gd`. GameState reaches
## it through `Rng`, so the token must NOT appear here — that is what "the only RNG in the
## program" means mechanically.
func test_source_is_engine_free_and_builds_no_second_rng() -> void:
	var code: String = _code_text(GAME_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				GAME_STATE_PATH, banned
			]
		)
	assert_true(
		code.contains("Rng"),
		"§11.1/(R): GameState must reach the one seeded stream through Rng"
	)


## S3 (AU)/(AX)/§13.5/§13.6 — NO RESOURCE-ID, TRAIT OR HOUSING WHITELIST IN ENGINE CODE, on the
## §4.2 terrain-type precedent (M1-T5 (T), M1-T7 (AH)). GameState must not name a §5.1 resource
## (the vocabulary is data, pinned by `tests/unit/test_player_state.gd`); nor §12.7 line 1015's
## `worker`/`dig_mult`, because WORKER-NESS IS A TRAIT, not a class — the roster stores an opaque
## `type_id` and knows nothing about what a unit can do; nor `housing`, because §5.2's unit cap is
## a LATER slice and `housing.hq` must stay UNUSED in `data/ruleset.json`.
func test_source_carries_no_resource_trait_or_housing_whitelist() -> void:
	var code: String = _code_text(GAME_STATE_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	for id: String in RESOURCE_IDS:
		assert_false(
			code.contains(id),
			"(AU)/§13.5: resource ids are opaque data — %s must not name \"%s\"" % [
				GAME_STATE_PATH, id
			]
		)
	for token: String in TRAIT_AND_CAP_TOKENS:
		assert_false(
			code.contains(token),
			"§12.7/§5.2: traits and the housing cap are DATA/later slices — %s must not name %s" % [
				GAME_STATE_PATH, token
			]
		)


## S4 §4.4 line 238 / §13.6 — map sizes are tunable content in data/mapgen/*.json; the state
## container receives a HexMap, it never re-types a radius or a hex count.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(GAME_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"),
		OK,
		"sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(
		hit,
		"§4.4/§13.6: map sizes live in data/mapgen/*.json — %s must not hard-code %s" % [
			GAME_STATE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S5 §13.4 + M0-T4 — this file loads no document (RulesLoader is the one validator, §12), and it
## must NOT override `Object.hash()`: `native_method_override` is level 2 = a hard error under the
## live typing gate, which is why the member is `content_hash` (M1-T5 (U)). The seed parameter
## must not be named `seed` either — `shadowed_global_identifier` is level 2 as well (M1-T5 (R)).
func test_source_declares_no_loader_and_shadows_no_global() -> void:
	var code: String = _code_text(GAME_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	assert_false(
		code.contains("RulesError"),
		"§13.4: %s loads no document and must not carry a loader" % GAME_STATE_PATH
	)
	assert_false(
		code.contains("func hash("),
		"(U)/M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			GAME_STATE_PATH
		]
	)
	assert_true(
		code.contains("content_hash"),
		"(U): the reproducible §11.1 hash is named content_hash in %s" % GAME_STATE_PATH
	)
	var shadowed: RegEx = RegEx.new()
	assert_eq(
		shadowed.compile("\\bseed\\s*:"), OK, "sanity: the shadowed-parameter pattern compiles"
	)
	assert_null(
		shadowed.search(code),
		"(R)/M0-T4: a parameter named `seed` trips shadowed_global_identifier (level 2 = error)"
	)


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (buildings, a serializer, a second RNG
## accessor, a `unit_count()`/`dig_site_count()` convenience) fails too. The seed value, both
## roster privates (`_units`, `_next_unit_id`), the registry store (`_dig_sites`) and the private
## `_hex_before` comparator all stay PRIVATE: they are folded into content_hash, not handed out.
## The list was grown 8 -> 14 by (AX) and 14 -> 19 by (AY), each time IN THE SAME COMMIT that adds
## the collection (the standing rule).
func test_public_api_is_exactly_the_nineteen_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(GAME_STATE_PATH, public_functions, undocumented)

	var state: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, GAME_STATE_PATH]
		)
		assert_true(
			state.has_method(required),
			"§11.2: %s must be callable on a GameState instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			GAME_STATE_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); absent on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(GAME_STATE_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public FIELD surface of %s is exactly %s (the seed stays private)" % [
			GAME_STATE_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)


## S7 §11.1/§11.2 — GameState is a pure [RefCounted] living in `scripts/sim/`. Asserted through
## get_class() — `is Node` is a PARSE ERROR here (M0-T2 item 11 / M0-T5 item (a)).
func test_game_state_is_a_pure_refcounted_in_scripts_sim() -> void:
	assert_true(
		FileAccess.file_exists(GAME_STATE_PATH), "§11.2: GameState lives at %s" % GAME_STATE_PATH
	)
	assert_eq(
		GameState.new(GOLDEN_SEED, null, MIN_PLAYERS).get_class(),
		"RefCounted",
		"§11.1: GameState must be a pure RefCounted"
	)


## S8 (AU)(vi) as amended by (AV) — THE FOLD ORDER IS DOCUMENTED AND SCANNED. §11.1 line 707 says
## the hash must be reproducible but prints no composition, so the order is a logged decision; a
## future golden will record it, and until that golden exists this scan is the only thing that
## stops the order drifting silently. The turn position folds AFTER the RNG stream position and
## BEFORE the map-presence flag, and no existing step is renamed or reordered.
func test_source_folds_the_turn_position_in_the_documented_order() -> void:
	var code: String = _code_text(GAME_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	var at: int = code.find("func content_hash(")
	assert_ne(at, -1, "sanity: %s declares content_hash()" % GAME_STATE_PATH)
	if at == -1:
		return
	var body: String = code.substr(at)
	var previous: int = -1
	for token: String in FOLD_ORDER_TOKENS:
		var found: int = body.find(token)
		assert_ne(
			found,
			-1,
			"(AV): content_hash() must fold \"%s\" — the documented order is %s" % [
				token, str(FOLD_ORDER_TOKENS)
			]
		)
		if found == -1:
			return
		assert_gt(
			found,
			previous,
			"(AV): the fold order is %s — \"%s\" is out of place" % [
				str(FOLD_ORDER_TOKENS), token
			]
		)
		previous = found


## S9 (AV)/§13.6 — the fold order is DOCUMENTED IN THE FILE'S HEADER (that is where a later
## golden's author will read it), and the header must be updated in the same commit that changes
## the fold. Checked on the RAW text, because a doc block is exactly what this asserts about.
func test_the_header_documents_the_turn_position_in_the_fold() -> void:
	var raw: String = _raw_text(GAME_STATE_PATH)
	var class_at: int = raw.find("class_name GameState")
	assert_ne(class_at, -1, "sanity: %s declares class_name GameState" % GAME_STATE_PATH)
	if class_at == -1:
		return
	var header: String = raw.substr(0, class_at)
	assert_true(
		header.contains("turn"),
		"(AV): %s's header must document the turn in the content_hash fold order" % GAME_STATE_PATH
	)
	assert_true(
		header.contains("current_player_index"),
		"(AV): %s's header must document the current player index in the fold order" % [
			GAME_STATE_PATH
		]
	)
	assert_true(
		header.contains("_next_unit_id"),
		"(AX): %s's header must document the id counter in the fold order" % GAME_STATE_PATH
	)
	assert_true(
		header.contains("unit count"),
		"(AX): %s's header must document the unit count in the fold order" % GAME_STATE_PATH
	)
	assert_true(
		header.contains("dig site"),
		"(AY): %s's header must document the dig-site registry in the fold order" % GAME_STATE_PATH
	)
	assert_true(
		header.contains("canonical order"),
		"(AY): %s's header must document the canonical hex order the registry folds in" % [
			GAME_STATE_PATH
		]
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A state on a real (radius `radius`) map, with `count` players.
func _state(seed_value: int, radius: int, count: int) -> GameState:
	return GameState.new(seed_value, HexMap.new(radius), count)


## Spawns one §12.2-shaped unit for `owner_index` at `where` and returns its minted id, asserting
## the spawn was accepted. Returns 0 ("no unit", (AX)) when it was refused, so a caller can report
## a single clear failure instead of a null-call cascade.
##
## TRAP measured live at M2-T4: `owner` and `name` are BASE-CLASS PROPERTIES of [Node], which
## `GutTest` extends, so a parameter or `for` iterator named either is
## `shadowed_variable_base_class` = level 2 = a HARD ERROR that silently un-collects the whole
## test file (the `seed`/`log` traps of M1-T5 (R) and M2-T2, in a new disguise).
func _spawn(state: GameState, owner_index: int, where: Vector2i) -> int:
	var spawned: UnitState = state.spawn_unit(owner_index, UNIT_TYPE_ID, where, UNIT_MAX_HP)
	assert_not_null(spawned, "sanity: the spawn for owner %d is accepted" % owner_index)
	if spawned == null:
		return NO_UNIT_ID
	return spawned.unit_id()


## A state on a real map with MIN_PLAYERS players, carrying a fixed roster: three units across
## two owners and three hexes, one of them damaged and one of them a different definition id.
## Built the same way every time, so two calls must hash identically.
func _populated(seed_value: int) -> GameState:
	var state: GameState = _state(seed_value, TEST_MAP_RADIUS, MIN_PLAYERS)
	assert_not_null(
		state.spawn_unit(0, UNIT_TYPE_ID, HEX_A, UNIT_MAX_HP), "fixture: unit 1 is spawned"
	)
	assert_not_null(
		state.spawn_unit(1, OTHER_UNIT_TYPE_ID, HEX_B, UNIT_MAX_HP), "fixture: unit 2 is spawned"
	)
	assert_not_null(
		state.spawn_unit(0, UNIT_TYPE_ID, HEX_C, UNIT_MAX_HP), "fixture: unit 3 is spawned"
	)
	var hurt: UnitState = state.unit(2)
	assert_not_null(hurt, "fixture: unit 2 is in the roster")
	if hurt != null:
		hurt.set_hp(1)
	return state


## A state on a real map with MIN_PLAYERS players, carrying four dig sites registered in
## SITE_INSERTION_ORDER (which is deliberately NOT the canonical enumeration order). Built the same
## way every time, so two calls must hash identically.
func _sited(seed_value: int) -> GameState:
	var state: GameState = _state(seed_value, TEST_MAP_RADIUS, MIN_PLAYERS)
	for where: Vector2i in SITE_INSERTION_ORDER:
		assert_not_null(
			state.add_dig_site(where, 0, SITE_TOTAL_TURNS), "fixture: %s is registered" % str(where)
		)
	return state


## Every `.gd` file in `directory`, ascending, so a stray new file in a spine directory fails the
## §13.4 negative pin. `.gd.uid` sidecars are filtered out — they are engine bookkeeping.
func _gd_files(directory: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			out.append(file_name)
	out.sort()
	return out


## `count` consecutive percent rolls drawn through `state.rng`, as a typed array.
func _rolls(state: GameState, count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(count):
		out.append(state.rng.roll_percent())
	return out


## Deposits `amount` of `resource_id` into player `index`, asserting each step. Returns false when
## the roster does not hand the player over, so the caller can bail without a null-call cascade.
func _deposit(state: GameState, index: int, resource_id: String, amount: int) -> bool:
	var player: PlayerState = state.player(index)
	assert_not_null(player, "sanity: player(%d) exists" % index)
	if player == null:
		return false
	var accepted: bool = player.add(resource_id, amount)
	assert_true(accepted, "sanity: the deposit into player %d is accepted" % index)
	return accepted


## Walks a source file and fills `public_functions` with every public function name (in source
## order) and `undocumented` with those whose preceding comment block cites no DOC_SECTIONS entry.
func _collect_public_functions(
	path: String,
	public_functions: Array[String],
	undocumented: Array[String]
) -> void:
	var lines: PackedStringArray = _raw_text(path).split("\n")
	for i: int in range(lines.size()):
		var stripped: String = lines[i].strip_edges()
		if not (stripped.begins_with("func ") or stripped.begins_with("static func ")):
			continue
		var name_at: int = stripped.find("func ") + 5
		var paren_at: int = stripped.find("(", name_at)
		if paren_at == -1:
			continue
		var function_name: String = stripped.substr(name_at, paren_at - name_at)
		if function_name.begins_with("_"):
			continue
		public_functions.append(function_name)
		var doc_block: String = ""
		var j: int = i - 1
		while j >= 0 and lines[j].strip_edges().begins_with("#"):
			doc_block = lines[j] + "\n" + doc_block
			j -= 1
		var documented: bool = false
		for section: String in DOC_SECTIONS:
			if doc_block.contains(section):
				documented = true
		if not documented:
			undocumented.append(function_name)


## Every top-level public `var` declared by a source file, in source order, so an EXTRA public
## field fails the scan.
func _collect_public_vars(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with("var "):
			continue
		var rest: String = raw_line.substr(4)
		var cut: int = rest.length()
		for token: String in [":", "=", " "]:
			var at: int = rest.find(token)
			if at != -1 and at < cut:
				cut = at
		var declared: String = rest.substr(0, cut)
		if not declared.begins_with("_"):
			out.append(declared)
	return out


## Reads a source file verbatim, comments included.
func _raw_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "source must be readable: %s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## Reads a source file with every comment stripped, so asserting on source content can never be
## tripped by a doc comment that quotes the very rule being enforced.
func _code_text(path: String) -> String:
	var code_lines: PackedStringArray = PackedStringArray()
	for raw_line: String in _raw_text(path).split("\n"):
		var comment_at: int = raw_line.find("#")
		code_lines.append(raw_line if comment_at == -1 else raw_line.substr(0, comment_at))
	return "\n".join(code_lines)
