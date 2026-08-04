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
## STILL DELIBERATELY NOT BUILT (§13.4 — invent nothing ahead of its milestone): §3.4's nine
## per-player start-of-turn steps and three World-phase steps, §3.2/§12.1's victory turn limit
## and victory checks (M6), workers, dig progress, yields, vein nodes, Extractors, income/upkeep,
## housing, Mining Zones and §3.1's starting kit (which needs its own §12.1 key and amendment).
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

## §4.1's radii and hex counts are tunable content in data/mapgen/*.json — never in sim code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public surface of GameState at M2-T2 scope: two fields and SIX functions (EIGHT
## members — grown from five by (AV), in the same commit that adds the turn position, per the
## standing PROGRESS rule). `units`, `buildings`, `nodes`, `serialize` and friends all belong to
## later slices and would be invented API here (§13.4).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"player_count",
	"player",
	"turn",
	"current_player_index",
	"set_turn_position",
	"content_hash",
]
const REQUIRED_PUBLIC_VARS: Array[String] = ["map", "rng"]

## §11.1 line 707 (AU)(vi) as amended by (AV) — the DOCUMENTED fold order, as substrings that
## must appear in `content_hash()`'s body in exactly this sequence. A future golden will record
## this order; until then this scan is what stops it drifting silently.
const FOLD_ORDER_TOKENS: Array[String] = [
	"_seed_value",
	"rolls_drawn",
	"turn",
	"current_player_index",
	"map",
]

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§3.3"]


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


## S3 (AU)/§13.5/§13.6 — NO RESOURCE-ID WHITELIST IN ENGINE CODE, on the §4.2 terrain-type
## precedent (M1-T5 (T), M1-T7 (AH)). GameState must not name a §5.1 resource: the vocabulary is
## data, pinned by `tests/unit/test_player_state.gd`.
func test_source_carries_no_resource_id_whitelist() -> void:
	var code: String = _code_text(GAME_STATE_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % GAME_STATE_PATH)
	for id: String in RESOURCE_IDS:
		assert_false(
			code.contains(id),
			"(AU)/§13.5: resource ids are opaque data — %s must not name \"%s\"" % [
				GAME_STATE_PATH, id
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
## instead of passing vacuously and an EXTRA member (turn counters, units, buildings, a
## serializer, a second RNG accessor) fails too. The seed value stays PRIVATE: it is folded into
## content_hash, not handed out.
func test_public_api_is_exactly_the_eight_documented_members() -> void:
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


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A state on a real (radius `radius`) map, with `count` players.
func _state(seed_value: int, radius: int, count: int) -> GameState:
	return GameState.new(seed_value, HexMap.new(radius), count)


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
