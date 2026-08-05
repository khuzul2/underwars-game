## DigHexCommand — the SECOND of §11.1 line 705's fourteen printed commands, and the first
## consumer of `DigRules` AND of the §11.1 unit roster. GDD §11.1 (Layered Design, **binding**),
## §4.2 (Hex Types — **the authority for every dig number below**), §7.1 (the Artificial-Granite
## owner variant), §4.1 (hex geometry — adjacency), §3.4 (Order of Operations — step 4's tick is
## SLICE 4 and is pinned NEGATIVELY here), §12.1, §12.7, §11.2, §11.3, §13.2 tier 1, §13.4, §13.6,
## §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 705): "**Commands** (command pattern): MoveUnit, AttackUnit, AttackHex, DigHex,
##         CancelDig, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein,
##         SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -> Error? and
##         apply(state) -> Array[Event]. **Every mutation of GameState goes through a Command**."
##   §4.2  (lines 184-193, "Solid type | Dig time (worker-turns)"): Soft Dirt 1 · Hard Rock 2 ·
##         Dense Granite 4 · Artificial Granite **3 (owner: 1)** · Rubble 1 · Gold Vein 2 ·
##         Iron Vein 2 · Magestone Crust 2 · Mithril Seam 4.
##   §4.2  (line 197): "Dig time is total worker-turns; multiple workers on adjacent hexes may work
##         the same target (**max 2 simultaneous diggers per hex**). \"Dig 2x\" halves remaining
##         time (round up)."
##   §7.1  (line 367): "Sappers can build **Artificial Granite** (10s, 1 turn) on any adjacent
##         empty cave hex ... **Enemies dig it in 3 turns; Dwarves clear their own in 1.**"
##   §4.1  (line 172): "**Flat-top hexes, axial coordinates (q, r)**; cube coordinates for
##         algorithms. **Distance = cube distance.** Neighbor order (fixed, index 0-5): E, NE, NW,
##         W, SW, SE."
##   §3.4  (step 4): "Dig progress ticks; completed digs apply yields, then **Breach checks**
##         (§4.6), then **Noise pings** (§4.8)." — SLICE 4, pinned NEGATIVELY below.
##   §3.4  (step 9): "**Action phase:** the player issues commands until End Turn." — why an order
##         from anyone but the current player is rejected.
##   §12.7 (line 1015): "worker | dig\_mult | Can Dig/Build; dig-speed multiplier" — worker-ness is
##         a TRAIT, i.e. DATA, and `data/units/*.json` is M6, so ANY unit type may be assigned in
##         this slice and `worker`/`dig_mult` are FORBIDDEN tokens in the command source.
##
## `docs/decisions.md` was re-scanned END TO END this iteration: the only logged overrides touching
## §12.1/§4.2 in the whole project are **(AU)(i)** (`dig_yields.artificial_granite.stone = 2`, a
## transcription of §4.2's own "\+2 Stone") and **(AW)(i)** (the top-level `dig` group binding §4.2
## terrain ids to §12.1 dig keys — no numeric value moved). NOTHING overrides §4.2's dig times,
## §4.2 line 197, §4.1, §7.1, §3.4 or §11.1, so every printed value below governs unamended.
## **(AW)(iii) is binding: `DigRules` takes a bool and never decides ownership** — the
## determination lands HERE.
##
## §11.1 names the command but prints no signature, so the surface below is a §13.4 resolution
## lettered **(AY)** ((AU)/(AV)/(AW)/(AX) are cross-referenced by many files — do NOT renumber any
## of them):
##   (AY) THE DIG ORDER.
##       - An IMMUTABLE value object: `(player_index, unit_id, hex, dig_rules)` in `_init`, and
##         neither `validate` nor `apply` ever mutates `self` (§11.1 replays the same log twice).
##       - `DigRules` is INJECTED ALREADY-LOADED (the M1-T3 (H)/(L) injected-dependency precedent).
##         `GameState` holds no `RulesLoader` and must NOT gain one in this slice.
##       - THE §7.1 OWNERSHIP SEAM is ONE private function and the ONLY caller of `dig_turns_for`.
##         Today it answers "not the owner" unconditionally: no hex anywhere carries a builder
##         index, and §7.1's Raise Granite — the ONLY producer of Artificial Granite — is M3/M4.
##       - ONE OWNER PER DIG SITE and ONE JOB PER UNIT: a site belongs to the player who ordered
##         it, and a unit digs at most one site (which is what makes slice 3b's cancel and slice
##         4's tick unambiguous).
##       - REJECTION VOCABULARY AND PRECEDENCE, opaque StringNames authored at their own call
##         sites (no enum, no const list in engine code — the (AV)/(AU)(iv)/(T)/(AH) rule), in
##         exactly this order: `null_state`, `no_map`, `no_players`, `not_current_player`,
##         `no_such_unit`, `not_your_unit`, `unit_not_adjacent`, `not_diggable`, `site_not_yours`,
##         `already_digging`, `dig_site_full`.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY; the base class through `get_base_script()`.
##
## The source scans at the bottom are written FRESH for `scripts/sim/commands/dig_hex_command.gd`.
extends GutTest

const DIG_HEX_PATH: String = "res://scripts/sim/commands/dig_hex_command.gd"
const COMMAND_PATH: String = "res://scripts/sim/commands/command.gd"
const COMMANDS_DIR: String = "res://scripts/sim/commands"
const SCRIPTS_DIR: String = "res://scripts"
const RULESET_PATH: String = "res://data/ruleset.json"

## §12.6's example seed, so this file's seed comes from the GDD rather than from invention.
const GOLDEN_SEED: int = 1337

## §3.1 line 118 "Skirmish: 2-4 players".
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

## Big enough that every neighbour of the origin AND a distance-2 hex are in bounds, small enough
## to build many of. §4.1's real radii (24/32/40) live in data/mapgen/*.json.
const MAP_RADIUS: int = 2

## §4.1 "axial coordinates (q, r)" — the target and the hexes the diggers stand on. ADJACENT_HEX,
## SECOND_ADJACENT_HEX and THIRD_ADJACENT_HEX are `HexMath.DIRECTIONS` 0, 1 and 2 (E, NE, NW) from
## TARGET_HEX; the fixture asserts their distances rather than trusting the transcription.
const TARGET_HEX: Vector2i = Vector2i(0, 0)
const ADJACENT_HEX: Vector2i = Vector2i(1, 0)
const SECOND_ADJACENT_HEX: Vector2i = Vector2i(1, -1)
const THIRD_ADJACENT_HEX: Vector2i = Vector2i(0, -1)

## A SECOND diggable target, chosen so SECOND_ADJACENT_HEX is adjacent to BOTH targets — that is
## what makes "one job per unit" testable without moving a unit.
const OTHER_TARGET_HEX: Vector2i = Vector2i(2, -2)

## Distance 2 from TARGET_HEX and still in bounds at radius 2 (§4.1 "Distance = cube distance").
const FAR_HEX: Vector2i = Vector2i(2, 0)

## In bounds at radius 2, adjacent to an OUT-OF-BOUNDS hex — the fixture for "an off-map target is
## `not_diggable`, not a separate code" (`HexMap.get_terrain_type` answers "" out of bounds).
const EDGE_HEX: Vector2i = Vector2i(2, 0)
const OFF_MAP_HEX: Vector2i = Vector2i(3, 0)

## §4.2's nine Solid-hex rows, in TABLE ORDER.
const SOLID_TERRAIN_IDS: Array[String] = [
	"soft_dirt",
	"hard_rock",
	"dense_granite",
	"artificial_granite",
	"rubble",
	"gold_vein",
	"iron_vein",
	"magestone_crust",
	"mithril_seam",
]

## §4.2 column "Dig time (worker-turns)", transcribed from lines 184-193. THE COMMAND MUST REACH
## THESE THROUGH `DigRules` — the source scan below forbids every one of them as a literal.
const DIG_TURNS: Dictionary = {
	"soft_dirt": 1,
	"hard_rock": 2,
	"dense_granite": 4,
	"artificial_granite": 3,
	"rubble": 1,
	"gold_vein": 2,
	"iron_vein": 2,
	"magestone_crust": 2,
	"mithril_seam": 4,
}

## §4.2 line 188 "Artificial Granite | **3 (owner: 1)**" / §7.1 line 367. EXACTLY ONE row has an
## owner variant, and NOTHING in this slice can be its owner (see (AY) above).
const OWNER_VARIANT_TERRAIN_ID: String = "artificial_granite"
const OWNER_VARIANT_TURNS: int = 1
const OWNER_VARIANT_ENEMY_TURNS: int = 3

## The §4.2 row the generic fixtures dig: "Hard Rock | 2 | \+2 Stone | Baseline".
const FIXTURE_TERRAIN_ID: String = "hard_rock"
const FIXTURE_TURNS: int = 2

## An id that is NOT one of §4.2's nine Solid rows (a Cave-table id), so `DigRules.is_diggable`
## answers false for it. The vocabulary is DATA — this constant lives in the TEST.
const CAVE_TERRAIN_ID: String = "plain_floor"

## §4.2 line 197 "max 2 simultaneous diggers per hex", read from §12.1's `dig.max_diggers_per_hex`
## via `DigRules.max_diggers_per_hex()` ((AW)(i)). The literal must NOT appear in the command.
const MAX_DIGGERS_PER_HEX: int = 2

## §12.2's printed example definition id and §12.3's printed sibling, so this suite invents no
## content. §12.7's `worker` trait is DATA and `data/units/*.json` is M6, so ANY type may dig.
const UNIT_TYPE_ID: String = "dwarf_crossbow"
const OTHER_UNIT_TYPE_ID: String = "dwarf_shield_bearer"

## §12.2's printed `"hp": 70`, supplied by the CALLER at this slice.
const UNIT_MAX_HP: int = 70

## (AX) — roster ids start at 1; 0 means "no unit".
const NO_UNIT_ID: int = 0

## §11.1 line 705's FOURTEEN printed command names, snake_cased. THE LIST LIVES IN THIS TEST and
## never in engine code (the (AU)(iv)/(T)/(AH)/M0-T3 (f) no-whitelist rule). Copied verbatim from
## `tests/unit/test_end_turn_command.gd`.
const PRINTED_COMMAND_NAMES: Array[String] = [
	"move_unit",
	"attack_unit",
	"attack_hex",
	"dig_hex",
	"cancel_dig",
	"build_structure",
	"train_unit",
	"research_tech",
	"use_ability",
	"convert_depleted_vein",
	"set_zone",
	"set_rally",
	"garrison_ruin",
	"end_turn",
]

## (AY) — the ELEVEN rejection codes this Command authors, IN PRECEDENCE ORDER.
const CODE_NULL_STATE: StringName = &"null_state"
const CODE_NO_MAP: StringName = &"no_map"
const CODE_NO_PLAYERS: StringName = &"no_players"
const CODE_NOT_CURRENT_PLAYER: StringName = &"not_current_player"
const CODE_NO_SUCH_UNIT: StringName = &"no_such_unit"
const CODE_NOT_YOUR_UNIT: StringName = &"not_your_unit"
const CODE_UNIT_NOT_ADJACENT: StringName = &"unit_not_adjacent"
const CODE_NOT_DIGGABLE: StringName = &"not_diggable"
const CODE_SITE_NOT_YOURS: StringName = &"site_not_yours"
const CODE_ALREADY_DIGGING: StringName = &"already_digging"
const CODE_DIG_SITE_FULL: StringName = &"dig_site_full"

const AUTHORED_CODES: Array[StringName] = [
	&"null_state",
	&"no_map",
	&"no_players",
	&"not_current_player",
	&"no_such_unit",
	&"not_your_unit",
	&"unit_not_adjacent",
	&"not_diggable",
	&"site_not_yours",
	&"already_digging",
	&"dig_site_full",
]

## §11.1 — tokens that would make the sim core engine-bound.
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
	"queue_free(",
]

## §11.1 "Renderer/UI subscribe; **the sim never calls them**".
const RENDERER_TOKENS: Array[String] = [
	"MapRenderer",
	"CameraRig",
	"HexPicker",
	"HexLayout",
	"MultiMesh",
	"Camera3D",
	"Node3D",
]

## §5.1's SEVEN resources. FORBIDDEN in the command: yield APPLICATION is §3.4 step 4 = SLICE 4,
## and resource ids are opaque data either way ((AU)(iv)).
const RESOURCE_IDS: Array[String] = [
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §12.7 line 1015's trait key, §5.2's housing cap and §7's four factions — all DATA/later slices.
const VOCABULARY_TOKENS: Array[String] = [
	"worker",
	"dig_mult",
	"housing",
	"dwarves",
	"elves",
	"goblins",
	"orcs",
]

## §13.6 — the printed §4.2/§5.2/§3.2 numbers the command must NOT contain. Only 0 and 1 may
## appear standalone; §4.1's fixed adjacency distance must be a NAMED private const (the (AJ)
## named-mathematical-const precedent), and every dig number comes from `DigRules` over §12.1.
const FORBIDDEN_NUMERALS: Array[String] = [
	"2", "3", "4", "10", "15", "25", "60", "120", "150", "250",
]
const PERMITTED_NUMERALS: Array[String] = ["0", "1"]

## Tokens the command MUST name: its injected dependency and the three `DigRules` accessors that
## make §13.6's "constants read from data, not code" true here.
const REQUIRED_TOKENS: Array[String] = [
	"DigRules", "is_diggable(", "max_diggers_per_hex(", "dig_turns_for("
]

## `DigRules` members that belong to LATER slices (§13.4 — invent nothing ahead of its milestone).
## `halve_remaining_turns` needs a "Dig 2x" ABILITY, which does not exist; the yield accessors are
## §3.4 step 4's completion, which is slice 4.
const PREMATURE_RULE_TOKENS: Array[String] = [
	"halve_remaining_turns",
	"yield_amount",
	"yield_resource_ids",
	"vein_resource_id",
]

## The COMPLETE public surface of DigHexCommand: SIX functions, ZERO public vars, ZERO public
## consts. `_init` is excluded by the leading underscore and is pinned by construction.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"player_index", "unit_id", "hex", "command_name", "validate", "apply"
]
const REQUIRED_PUBLIC_VARS: Array[String] = []
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## Doc-comment sections accepted by the S8 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§4.2", "§7.1", "§4.1", "§3.4"]

## Cached across tests: parsing `data/ruleset.json` once keeps this suite's runtime honest. The
## object is READ-ONLY (M2-T3: `DigRules` mutates nothing), so sharing it is safe.
var _rules_cache: DigRules = null


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Records every DigStartedEvent delivered, in delivery order.
class DigRecorder extends RefCounted:
	var calls: int = 0
	var events: Array[DigStartedEvent] = []

	func on_event(event: Event) -> void:
		calls += 1
		var started: DigStartedEvent = event as DigStartedEvent
		if started != null:
			events.append(started)


# =============================================================================================
# A. IDENTITY (§11.1 line 705: DigHex is one of the fourteen printed commands)
# =============================================================================================

## §11.1 — DigHexCommand IS a Command: it inherits `execute`, THE ONE GATE, so nothing can apply
## past validation. Asserted through the script's base script, never `is Node`.
func test_dig_hex_is_a_command_and_inherits_the_gate() -> void:
	var command: DigHexCommand = _command(0, 1, TARGET_HEX)
	var own_script: Script = command.get_script()
	assert_not_null(own_script, "sanity: the instance carries its script")
	if own_script == null:
		return
	var base_script: Script = own_script.get_base_script()
	assert_not_null(base_script, "§11.1: DigHexCommand extends the Command base")
	if base_script == null:
		return
	assert_eq(
		base_script.resource_path,
		COMMAND_PATH,
		"§11.1: DigHexCommand must extend %s so it inherits the validate/apply gate" % COMMAND_PATH
	)
	assert_true(command.has_method("execute"), "§11.1: the gate is inherited, not re-declared")


## §11.1 line 705 — the name is exactly `dig_hex`, and it is one of the FOURTEEN printed command
## names. The printed list lives here, never in engine code.
func test_the_command_name_is_dig_hex_and_is_one_of_the_printed_fourteen() -> void:
	assert_eq(
		PRINTED_COMMAND_NAMES.size(),
		14,
		"§11.1 line 705 prints exactly fourteen commands — this list must transcribe all of them"
	)
	var chosen: StringName = _command(0, 1, TARGET_HEX).command_name()
	assert_eq(chosen, &"dig_hex", "§11.1: the command name is exactly \"dig_hex\"")
	assert_true(
		PRINTED_COMMAND_NAMES.has(String(chosen)),
		"§11.1: \"%s\" must be one of the fourteen printed command names" % String(chosen)
	)
	assert_ne(chosen, EndTurnCommand.new(0).command_name(), "§11.1: each command has its own name")


## (AY) — the command is an IMMUTABLE value object: every parameter is read back unchanged.
func test_the_constructor_arguments_are_carried_verbatim() -> void:
	for index: int in [0, 1, MAX_PLAYERS, -1]:
		for id: int in [1, 7, NO_UNIT_ID, -3]:
			var command: DigHexCommand = _command(index, id, OTHER_TARGET_HEX)
			assert_eq(command.player_index(), index, "(AY): player_index() answers _init's %d" % index)
			assert_eq(command.unit_id(), id, "(AY): unit_id() answers _init's %d" % id)
			assert_eq(command.hex(), OTHER_TARGET_HEX, "(AY): hex() answers _init's target")


## §4.1 line 172 "Distance = cube distance. Neighbor order (fixed, index 0-5): E, NE, NW, W, SW,
## SE" — the fixture's own geometry, asserted rather than trusted, so a mis-transcribed constant
## below fails HERE with a clear message instead of corrupting every adjacency test.
func test_the_fixture_geometry_matches_section_four_one() -> void:
	assert_eq(HexMath.distance(TARGET_HEX, ADJACENT_HEX), 1, "§4.1: E of the target is adjacent")
	assert_eq(HexMath.distance(TARGET_HEX, SECOND_ADJACENT_HEX), 1, "§4.1: NE is adjacent")
	assert_eq(HexMath.distance(TARGET_HEX, THIRD_ADJACENT_HEX), 1, "§4.1: NW is adjacent")
	assert_eq(HexMath.distance(TARGET_HEX, FAR_HEX), 2, "§4.1: FAR_HEX is two hexes away")
	assert_eq(HexMath.distance(TARGET_HEX, TARGET_HEX), 0, "§4.1: a hex is distance 0 from itself")
	assert_eq(
		HexMath.distance(SECOND_ADJACENT_HEX, OTHER_TARGET_HEX),
		1,
		"§4.1: the NE hex is adjacent to BOTH targets — the one-job-per-unit fixture"
	)
	var map: HexMap = HexMap.new(MAP_RADIUS)
	for inside: Vector2i in [TARGET_HEX, ADJACENT_HEX, SECOND_ADJACENT_HEX, THIRD_ADJACENT_HEX]:
		assert_true(map.is_in_bounds(inside), "sanity: %s is on the radius-2 map" % str(inside))
	assert_true(map.is_in_bounds(OTHER_TARGET_HEX), "sanity: the second target is on the map")
	assert_true(map.is_in_bounds(EDGE_HEX), "sanity: the edge hex is on the map")
	assert_false(map.is_in_bounds(OFF_MAP_HEX), "sanity: OFF_MAP_HEX is off the radius-2 map")
	assert_eq(HexMath.distance(EDGE_HEX, OFF_MAP_HEX), 1, "§4.1: the edge hex is adjacent to it")


# =============================================================================================
# B. §4.2's DIG-TIME TABLE, REACHED ONLY THROUGH DigRules (lines 184-193)
# =============================================================================================

## §4.2 lines 184-193 — EVERY ONE of the nine printed Solid rows produces a site whose
## `total_turns` is that row's printed "Dig time (worker-turns)", and a fresh site has all of them
## remaining. The values are transcribed from the GDD table into this test; the COMMAND reads them
## from §12.1 through `DigRules` (scan S6 forbids every one of them as a literal there).
func test_every_printed_dig_time_reaches_the_new_site() -> void:
	assert_eq(DIG_TURNS.size(), SOLID_TERRAIN_IDS.size(), "sanity: all nine §4.2 rows are covered")
	for terrain_id: String in SOLID_TERRAIN_IDS:
		var expected: int = DIG_TURNS[terrain_id]
		assert_eq(
			_dig_rules().dig_turns_for(terrain_id, false),
			expected,
			"§4.2/§12.1: DigRules is the SOURCE of the %s dig time" % terrain_id
		)
		var state: GameState = _state_with(MIN_PLAYERS)
		_set_terrain(state, TARGET_HEX, terrain_id)
		var digger: int = _spawn(state, 0, ADJACENT_HEX)
		_accept(state, _command(0, digger, TARGET_HEX), "digging %s" % terrain_id)
		var site: DigSite = state.dig_site(TARGET_HEX)
		assert_not_null(site, "§4.2: digging %s creates a site" % terrain_id)
		if site == null:
			return
		assert_eq(
			site.total_turns(),
			expected,
			"§4.2: \"%s\" is %d worker-turns" % [terrain_id, expected]
		)
		assert_eq(
			site.remaining_turns(),
			site.total_turns(),
			"§4.2: \"Dig time is total worker-turns\" — a fresh site has all of them left"
		)


## §7.1 line 367 "**Enemies dig it in 3 turns; Dwarves clear their own in 1**" — the ONE row with
## an owner variant. THE SEAM RESOLVES TO "NOT THE OWNER" FOR EVERY PLAYER IN THIS SLICE: no hex
## anywhere carries a builder index, and §7.1's Raise Granite (the ONLY producer of Artificial
## Granite) is M3/M4, so the site must cost 3, never 1. Pinned for every roster index so a stray
## `player_index == 0` shortcut cannot pass.
func test_artificial_granite_costs_the_enemy_time_for_every_player() -> void:
	assert_eq(
		_dig_rules().dig_turns_for(OWNER_VARIANT_TERRAIN_ID, true),
		OWNER_VARIANT_TURNS,
		"§7.1: DigRules DOES know the owner variant — the bool is what selects it ((AW)(iii))"
	)
	for issuer: int in range(MAX_PLAYERS):
		var state: GameState = _state_with(MAX_PLAYERS)
		state.set_turn_position(1, issuer)
		_set_terrain(state, TARGET_HEX, OWNER_VARIANT_TERRAIN_ID)
		var digger: int = _spawn(state, issuer, ADJACENT_HEX)
		_accept(state, _command(issuer, digger, TARGET_HEX), "player %d digs granite" % issuer)
		var site: DigSite = state.dig_site(TARGET_HEX)
		assert_not_null(site, "sanity: the site exists")
		if site == null:
			return
		assert_eq(
			site.total_turns(),
			OWNER_VARIANT_ENEMY_TURNS,
			"§7.1 line 367: player %d is NOT the builder — \"Enemies dig it in 3 turns\"" % issuer
		)
		assert_ne(
			site.total_turns(),
			OWNER_VARIANT_TURNS,
			"§7.1/(AY): nothing in this slice can own Artificial Granite — the seam is deferred"
		)


# =============================================================================================
# C. §4.2 line 197 — ADJACENCY AND THE MAX-2-DIGGERS CAP
# =============================================================================================

## §4.2 line 197 "multiple workers **on adjacent hexes** may work the same target" + §4.1's fixed
## six-neighbour geometry — EVERY one of the six neighbours may dig, and the direction does not
## change the outcome.
func test_every_one_of_the_six_neighbours_may_dig_the_target() -> void:
	for dir: int in range(6):
		var where: Vector2i = TARGET_HEX + HexMath.DIRECTIONS[dir]
		assert_eq(HexMath.distance(TARGET_HEX, where), 1, "sanity: direction %d is adjacent" % dir)
		var state: GameState = _state_with(MIN_PLAYERS)
		_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
		var digger: int = _spawn(state, 0, where)
		_accept(
			state,
			_command(0, digger, TARGET_HEX),
			"§4.1 direction %d (%s)" % [dir, HexMath.DIRECTION_NAMES[dir]]
		)
		var site: DigSite = state.dig_site(TARGET_HEX)
		assert_not_null(site, "§4.2 line 197: an adjacent worker may dig from direction %d" % dir)
		if site == null:
			return
		assert_eq(site.digger_ids(), [digger] as Array[int], "(AY): the digger is assigned")


## §4.2 line 197 "on **adjacent** hexes" — a unit standing ON the target, or two hexes away, is
## rejected `unit_not_adjacent`. Distance must be EXACTLY 1 (§4.1 "Distance = cube distance").
func test_a_unit_that_is_not_exactly_one_hex_away_is_rejected() -> void:
	for where: Vector2i in [TARGET_HEX, FAR_HEX, Vector2i(-2, 0), Vector2i(0, 2)]:
		var gap: int = HexMath.distance(TARGET_HEX, where)
		assert_ne(gap, 1, "sanity: %s is not adjacent to the target (distance %d)" % [str(where), gap])
		var state: GameState = _state_with(MIN_PLAYERS)
		_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
		var digger: int = _spawn(state, 0, where)
		_reject(
			state,
			_command(0, digger, TARGET_HEX),
			CODE_UNIT_NOT_ADJACENT,
			"§4.2 line 197: a unit at distance %d may not dig the target" % gap
		)


## §4.2 line 197 "**max 2 simultaneous diggers per hex**", read from §12.1's
## `dig.max_diggers_per_hex` through `DigRules.max_diggers_per_hex()` ((AW)(i)). The first two
## assignments are accepted and the THIRD is rejected `dig_site_full`.
func test_the_third_simultaneous_digger_is_refused() -> void:
	assert_eq(
		_dig_rules().max_diggers_per_hex(),
		MAX_DIGGERS_PER_HEX,
		"§4.2 line 197/§12.1: the cap is DATA — DigRules is where the command reads it"
	)
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	var third: int = _spawn(state, 0, THIRD_ADJACENT_HEX)
	_accept(state, _command(0, first, TARGET_HEX), "the first digger")
	_accept(state, _command(0, second, TARGET_HEX), "the second digger")
	_reject(
		state,
		_command(0, third, TARGET_HEX),
		CODE_DIG_SITE_FULL,
		"§4.2 line 197: max %d simultaneous diggers per hex" % MAX_DIGGERS_PER_HEX
	)
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the site exists")
	if site == null:
		return
	assert_eq(
		site.digger_ids(),
		[first, second] as Array[int],
		"§4.2 line 197: the refused third digger was NOT assigned"
	)


# =============================================================================================
# D. THE REJECTION VOCABULARY AND ITS PRECEDENCE ((AY); §11.1 "validate(state) -> Error?")
#    Every case below also asserts: content_hash() byte-identical, NO event on a recording bus,
#    and no site created or changed (that is what `_reject` does).
# =============================================================================================

## (AY) 1 — a null state is rejected `null_state`, never a crash (the (B)/(L)/(AS) totality
## spirit), through `validate` directly AND through the gate.
func test_a_null_state_is_rejected() -> void:
	var rejection: CommandError = _command(0, 1, TARGET_HEX).validate(null)
	assert_not_null(rejection, "(AY): a null state is rejected, not applied")
	if rejection == null:
		return
	assert_eq(rejection.code, CODE_NULL_STATE, "(AY): the code is exactly \"null_state\"")
	assert_false(rejection.message.is_empty(), "(AY): every rejection carries a message")
	_reject(null, _command(0, 1, TARGET_HEX), CODE_NULL_STATE, "(AY) through the gate")


## (AY) 2 — a state with NO MAP is rejected `no_map`, BEFORE the unit is looked up: there is no
## terrain to read, so no dig can be legal. §11.1 permits a mapless GameState (resolution (AU)),
## which is exactly why this code has to exist.
func test_a_state_without_a_map_is_rejected_before_the_unit_is_looked_up() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	assert_null(state.map, "sanity: the fixture is mapless")
	assert_null(state.unit(1), "sanity: the roster is empty, so `no_such_unit` also applies")
	_reject(state, _command(0, 1, TARGET_HEX), CODE_NO_MAP, "(AY) 2 precedes (AY) 5")


## (AY) 3 — the EMPTY roster is rejected `no_players`, and it precedes `not_current_player`:
## `current_player_index()` still reads 0 on an empty roster, so issuer 0 would otherwise slip
## through into a state that owns nothing.
func test_an_empty_roster_is_rejected_before_the_current_player_check() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, HexMap.new(MAP_RADIUS), 0)
	assert_eq(state.player_count(), 0, "sanity: the roster is empty")
	assert_eq(state.current_player_index(), 0, "sanity: the empty roster still reads index 0")
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	for issuer: int in [0, 1, -1]:
		_reject(
			state,
			_command(issuer, 1, TARGET_HEX),
			CODE_NO_PLAYERS,
			"(AY) 3: issuer %d on the empty roster" % issuer
		)


## (AY) 4 / §3.4 step 9 "**Action phase:** the player issues commands until End Turn" — only the
## CURRENT player may issue a dig, and an OUT-OF-RANGE issuer rejects as `not_current_player` too
## (the (AV) reasoning: the current index is always in range, so an out-of-range index can never be
## the current one). It precedes `no_such_unit`: the unit named here is legal for its own owner.
func test_only_the_current_player_may_issue_a_dig() -> void:
	var state: GameState = _state_with(MAX_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	assert_eq(state.current_player_index(), 0, "sanity: a fresh state is on player 0")
	var theirs: int = _spawn(state, 1, ADJACENT_HEX)
	_reject(
		state,
		_command(1, theirs, TARGET_HEX),
		CODE_NOT_CURRENT_PLAYER,
		"§3.4 step 9: player 1 may not act during player 0's action phase"
	)
	for bad_issuer: int in [-1, -99, MAX_PLAYERS, 9999]:
		_reject(
			state,
			_command(bad_issuer, theirs, TARGET_HEX),
			CODE_NOT_CURRENT_PLAYER,
			"(AV)/(AY) 4: issuer %d is outside the roster and can never be current" % bad_issuer
		)


## (AY) 5 — `no_such_unit` covers 0 ("no unit"), a negative id, a never-minted id AND a REMOVED id.
## It precedes `not_your_unit` trivially (there is no owner to compare) and `unit_not_adjacent`.
func test_an_unknown_unit_id_is_rejected() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var minted: int = _spawn(state, 0, ADJACENT_HEX)
	assert_true(state.remove_unit(minted), "sanity: the unit is removed from the roster")
	for bad_id: int in [NO_UNIT_ID, -1, -99, minted, 9999]:
		_reject(
			state,
			_command(0, bad_id, TARGET_HEX),
			CODE_NO_SUCH_UNIT,
			"(AY) 5: id %d names no unit in the roster" % bad_id
		)


## (AY) 6 — a unit belonging to ANOTHER player is `not_your_unit`, and that precedes both
## `unit_not_adjacent` and `not_diggable`: whose unit it is is decided before where it stands.
func test_a_unit_owned_by_another_player_is_rejected() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var theirs: int = _spawn(state, 1, ADJACENT_HEX)
	_reject(
		state,
		_command(0, theirs, TARGET_HEX),
		CODE_NOT_YOUR_UNIT,
		"(AY) 6: player 0 may not order player 1's unit to dig"
	)

	var tangled: GameState = _state_with(MIN_PLAYERS)
	var far_theirs: int = _spawn(tangled, 1, FAR_HEX)
	_reject(
		tangled,
		_command(0, far_theirs, TARGET_HEX),
		CODE_NOT_YOUR_UNIT,
		"(AY): ownership (6) is decided before adjacency (7) and diggability (8)"
	)


## (AY) 7 precedes 8 — a unit that is BOTH too far away AND aimed at un-diggable terrain rejects
## as `unit_not_adjacent`, not `not_diggable`.
func test_adjacency_is_decided_before_diggability() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	assert_eq(state.map.get_terrain_type(TARGET_HEX), "", "sanity: the target terrain is unset")
	var digger: int = _spawn(state, 0, FAR_HEX)
	_reject(
		state,
		_command(0, digger, TARGET_HEX),
		CODE_UNIT_NOT_ADJACENT,
		"(AY): 7 precedes 8 — where the unit stands is decided before what it is digging"
	)


## (AY) 8 — `not_diggable` covers an UNSET hex, a Cave-table id and an OUT-OF-BOUNDS target (whose
## `get_terrain_type` is "" — there is deliberately NO separate out-of-bounds code). Diggability is
## `DigRules.is_diggable`, i.e. §12.1 data, never a terrain whitelist in the command.
func test_an_undiggable_or_off_map_target_is_rejected() -> void:
	var unset: GameState = _state_with(MIN_PLAYERS)
	assert_false(_dig_rules().is_diggable(""), "sanity: an unset hex is not a §4.2 Solid row")
	_reject(
		unset,
		_command(0, _spawn(unset, 0, ADJACENT_HEX), TARGET_HEX),
		CODE_NOT_DIGGABLE,
		"(AY) 8: an unset hex has no §4.2 Solid row"
	)

	var cave: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(cave, TARGET_HEX, CAVE_TERRAIN_ID)
	assert_false(
		_dig_rules().is_diggable(CAVE_TERRAIN_ID), "sanity: \"%s\" is not Solid" % CAVE_TERRAIN_ID
	)
	_reject(
		cave,
		_command(0, _spawn(cave, 0, ADJACENT_HEX), TARGET_HEX),
		CODE_NOT_DIGGABLE,
		"(AY) 8: a Cave hex is not diggable"
	)

	var edge: GameState = _state_with(MIN_PLAYERS)
	assert_eq(
		edge.map.get_terrain_type(OFF_MAP_HEX),
		"",
		"sanity: HexMap answers \"\" off the map (M1-T4)"
	)
	_reject(
		edge,
		_command(0, _spawn(edge, 0, EDGE_HEX), OFF_MAP_HEX),
		CODE_NOT_DIGGABLE,
		"(AY) 8: an OFF-MAP target is not_diggable — there is no separate out-of-bounds code"
	)


## (AY) 9 — ONE OWNER PER DIG SITE: a site already ordered by another player is `site_not_yours`,
## and that precedes `already_digging` (a unit busy elsewhere still may not touch a rival's site).
func test_a_site_ordered_by_another_player_may_not_be_joined() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	_set_terrain(state, OTHER_TARGET_HEX, FIXTURE_TERRAIN_ID)
	var mine: int = _spawn(state, 0, ADJACENT_HEX)
	var theirs: int = _spawn(state, 1, SECOND_ADJACENT_HEX)
	_accept(state, _command(0, mine, TARGET_HEX), "player 0 opens the site")

	state.set_turn_position(1, 1)
	_reject(
		state,
		_command(1, theirs, TARGET_HEX),
		CODE_SITE_NOT_YOURS,
		"(AY) 9: a dig site belongs to the player who ordered it"
	)

	_accept(state, _command(1, theirs, OTHER_TARGET_HEX), "player 1 opens their own site")
	_reject(
		state,
		_command(1, theirs, TARGET_HEX),
		CODE_SITE_NOT_YOURS,
		"(AY): 9 precedes 10 — a rival's site is refused before \"you are already digging\""
	)


## (AY) 10 — ONE JOB PER UNIT: a unit already assigned to ANY site may not take another order, at
## the SAME hex or at a different one. This is what makes slice 3b's cancel and slice 4's tick
## unambiguous — a unit's dig site is a function, not a relation.
func test_a_unit_may_hold_only_one_dig_job() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	_set_terrain(state, OTHER_TARGET_HEX, FIXTURE_TERRAIN_ID)
	var digger: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_accept(state, _command(0, digger, TARGET_HEX), "the first order")
	_reject(
		state,
		_command(0, digger, TARGET_HEX),
		CODE_ALREADY_DIGGING,
		"(AY) 10: re-ordering the SAME site is refused"
	)
	_reject(
		state,
		_command(0, digger, OTHER_TARGET_HEX),
		CODE_ALREADY_DIGGING,
		"(AY) 10: one job per unit — a second site is refused too"
	)
	assert_eq(
		state.dig_site_hexes(),
		[TARGET_HEX] as Array[Vector2i],
		"(AY): the refused orders created no second site"
	)


## (AY) 10 precedes 11 — a busy unit aimed at a FULL site rejects as `already_digging`, not
## `dig_site_full`: the unit's own state is decided before the target's.
func test_being_busy_is_decided_before_the_site_is_full() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	_set_terrain(state, OTHER_TARGET_HEX, FIXTURE_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, THIRD_ADJACENT_HEX)
	var busy: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_accept(state, _command(0, first, TARGET_HEX), "the first digger")
	_accept(state, _command(0, second, TARGET_HEX), "the second digger — the site is now full")
	_accept(state, _command(0, busy, OTHER_TARGET_HEX), "the third unit opens its own site")
	_reject(
		state,
		_command(0, busy, TARGET_HEX),
		CODE_ALREADY_DIGGING,
		"(AY): 10 precedes 11 — a busy unit is refused before the cap is consulted"
	)


## §11.1 — validate is a PURE PREDICATE: asking does not move the state, whatever the answer, for
## an ACCEPTED order as well as for a rejected one.
func test_validate_never_mutates_the_state() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var mine: int = _spawn(state, 0, ADJACENT_HEX)
	var theirs: int = _spawn(state, 1, SECOND_ADJACENT_HEX)
	var before: int = state.content_hash()
	assert_null(
		_command(0, mine, TARGET_HEX).validate(state), "§11.1: null means legal — this order is"
	)
	var probes: Array[DigHexCommand] = [
		_command(1, mine, TARGET_HEX),
		_command(0, NO_UNIT_ID, TARGET_HEX),
		_command(0, theirs, TARGET_HEX),
		_command(0, mine, FAR_HEX),
	]
	for command: DigHexCommand in probes:
		assert_not_null(command.validate(state), "sanity: this probe is rejected")
	assert_eq(state.content_hash(), before, "§11.1: validate is a predicate, never a mutation")
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "§11.1: validate creates no site")


# =============================================================================================
# E. SUCCESS SEMANTICS AND THE EMITTED EVENT ((AY); §13.6 "events emitted for every state change")
# =============================================================================================

## (AY)/§13.6 — the FIRST accepted order CREATES the site and emits EXACTLY ONE DigStartedEvent
## with `site_created == true`. This is the first M2 task where §13.6's events clause is LIVE
## rather than vacuous (M2-T3 and M2-T4 both recorded it as vacuous).
func test_the_first_order_creates_the_site_and_emits_one_event() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var digger: int = _spawn(state, 0, ADJACENT_HEX)
	var recorder: DigRecorder = _accept(state, _command(0, digger, TARGET_HEX), "the first order")

	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "(AY): the order created a dig site")
	if site == null:
		return
	assert_eq(site.hex(), TARGET_HEX, "(AY): the site is on the target hex")
	assert_eq(site.owner_index(), 0, "(AY): the site belongs to the ORDERING player")
	assert_eq(site.total_turns(), FIXTURE_TURNS, "§4.2: Hard Rock is 2 worker-turns")
	assert_eq(site.remaining_turns(), FIXTURE_TURNS, "§4.2: nothing has been dug yet")
	assert_eq(site.digger_ids(), [digger] as Array[int], "(AY): the ordered unit is assigned")
	assert_eq(
		state.dig_site_hexes(), [TARGET_HEX] as Array[Vector2i], "(AY): exactly one site exists"
	)
	assert_true(
		is_same(state.dig_site_of_digger(digger), site),
		"(AY): the unit's job is reachable from the roster side too"
	)

	assert_eq(recorder.calls, 1, "§13.6: exactly ONE event per accepted dig order")
	if recorder.events.is_empty():
		return
	var started: DigStartedEvent = recorder.events[0]
	assert_eq(started.type, DigStartedEvent.TYPE_NAME, "§11.1: the event's type is dig_started")
	assert_eq(started.player_index, 0, "(AY): the event carries the ordering player")
	assert_eq(started.unit_id, digger, "(AY): the event carries the assigned unit")
	assert_eq(started.hex, TARGET_HEX, "(AY): the event carries the target hex")
	assert_eq(started.remaining_turns, FIXTURE_TURNS, "§4.2: the event carries the work left")
	assert_true(started.site_created, "(AY): this order CREATED the site")


## §4.2 line 197 "multiple workers ... may work the same target" — a SECOND, different, adjacent
## unit of the SAME owner JOINS: no new site, the SAME object, `total_turns`/`remaining_turns`
## UNTOUCHED, and exactly one event with `site_created == false`. §13.6's clause is why the join
## emits at all: a second digger IS a state change.
func test_a_second_digger_joins_the_existing_site_and_emits_one_event() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_accept(state, _command(0, first, TARGET_HEX), "the first digger")
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the site exists")
	if site == null:
		return

	var recorder: DigRecorder = _accept(state, _command(0, second, TARGET_HEX), "the second digger")
	assert_true(
		is_same(state.dig_site(TARGET_HEX), site), "§4.2 line 197: the SAME site, not a new one"
	)
	assert_eq(
		state.dig_site_hexes(), [TARGET_HEX] as Array[Vector2i], "(AY): still exactly one site"
	)
	assert_eq(site.total_turns(), FIXTURE_TURNS, "§4.2: joining does not change the total")
	assert_eq(site.remaining_turns(), FIXTURE_TURNS, "§4.2: joining does not dig anything")
	assert_eq(
		site.digger_ids(), [first, second] as Array[int], "§11.1 line 707: ascending by unit id"
	)

	assert_eq(recorder.calls, 1, "§13.6: exactly ONE event for the join too")
	if recorder.events.is_empty():
		return
	var started: DigStartedEvent = recorder.events[0]
	assert_false(started.site_created, "(AY): the join did NOT create the site")
	assert_eq(started.unit_id, second, "(AY): the event names the JOINING unit")
	assert_eq(started.remaining_turns, FIXTURE_TURNS, "§4.2: the work left is unchanged")


## §11.1 line 707 "iterate collections in stable ID order" — the digger list is ASCENDING BY ID
## regardless of which unit was ordered first.
func test_the_digger_list_is_ascending_whichever_unit_was_ordered_first() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var lower: int = _spawn(state, 0, ADJACENT_HEX)
	var higher: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	assert_lt(lower, higher, "sanity: ids ascend in spawn order (AX)")
	_accept(state, _command(0, higher, TARGET_HEX), "the HIGHER id digs first")
	_accept(state, _command(0, lower, TARGET_HEX), "the lower id joins second")
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the site exists")
	if site == null:
		return
	assert_eq(
		site.digger_ids(),
		[lower, higher] as Array[int],
		"§11.1 line 707: ASCENDING by id, never assignment order"
	)


## (AY) — two sites on two different hexes COEXIST and are INDEPENDENT: each keeps its own §4.2
## total, its own diggers and its own owner.
func test_two_sites_on_two_hexes_coexist_independently() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	_set_terrain(state, OTHER_TARGET_HEX, "mithril_seam")
	var here: int = _spawn(state, 0, ADJACENT_HEX)
	var there: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_accept(state, _command(0, here, TARGET_HEX), "the Hard Rock order")
	_accept(state, _command(0, there, OTHER_TARGET_HEX), "the Mithril Seam order")

	var first: DigSite = state.dig_site(TARGET_HEX)
	var second: DigSite = state.dig_site(OTHER_TARGET_HEX)
	assert_not_null(first, "(AY): the first site exists")
	assert_not_null(second, "(AY): the second site exists")
	if first == null or second == null:
		return
	assert_false(is_same(first, second), "(AY): two hexes are two DISTINCT sites")
	assert_eq(first.total_turns(), DIG_TURNS[FIXTURE_TERRAIN_ID], "§4.2: Hard Rock is 2")
	assert_eq(second.total_turns(), DIG_TURNS["mithril_seam"], "§4.2: Mithril Seam is 4")
	assert_eq(first.digger_ids(), [here] as Array[int], "(AY): each site keeps its own digger")
	assert_eq(second.digger_ids(), [there] as Array[int], "(AY): each site keeps its own digger")
	assert_true(is_same(state.dig_site_of_digger(here), first), "(AY): one job per unit")
	assert_true(is_same(state.dig_site_of_digger(there), second), "(AY): one job per unit")


## §13.6 IN BOTH DIRECTIONS — "events emitted for **every** state change" AND never an event
## without one. `apply()` is called DIRECTLY here (bypassing the gate, which is why this is the one
## place it may be) with an UNCONFIGURED `DigRules`: the site cannot be sized, so NOTHING is
## created and an EMPTY event array comes back.
func test_apply_with_unconfigured_rules_changes_nothing_and_emits_nothing() -> void:
	assert_eq(
		DigRules.new(null).dig_turns_for(FIXTURE_TERRAIN_ID, false),
		0,
		"(AL): an unconfigured DigRules answers 0 — it invents no default"
	)
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var digger: int = _spawn(state, 0, ADJACENT_HEX)
	var before: int = state.content_hash()
	var command: DigHexCommand = DigHexCommand.new(0, digger, TARGET_HEX, DigRules.new(null))
	var events: Array[Event] = command.apply(state)
	assert_eq(events.size(), 0, "§13.6: no state change means NO event")
	assert_null(state.dig_site(TARGET_HEX), "§13.6: an unsizeable site is not created")
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "§13.6: no site was registered")
	assert_eq(state.content_hash(), before, "§11.1: the state is byte-identical")


## §11.1 "a match is fully described by (seed, command\_log)" — a Command is an IMMUTABLE value
## object. The SAME object executed twice gives the same FIRST result and a DETERMINISTIC second
## (`already_digging`), and `self` is never mutated by `validate`/`apply`.
func test_the_same_command_object_is_immutable_and_replays_deterministically() -> void:
	var digger_id: int = 1
	var command: DigHexCommand = _command(0, digger_id, TARGET_HEX)
	var first: GameState = _dug_state(digger_id)
	var second: GameState = _dug_state(digger_id)
	assert_null(command.execute(first, null), "sanity: the first execution is accepted")
	assert_null(command.execute(second, null), "sanity: the same object is accepted on a 2nd state")
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: the same command on two identical states yields the same state"
	)

	var repeat: CommandError = command.execute(first, null)
	assert_not_null(repeat, "(AY): re-issuing the same order is refused")
	if repeat == null:
		return
	assert_eq(repeat.code, CODE_ALREADY_DIGGING, "(AY): deterministically `already_digging`")
	assert_eq(command.player_index(), 0, "§11.1: validate/apply never mutate the command")
	assert_eq(command.unit_id(), digger_id, "§11.1: validate/apply never mutate the command")
	assert_eq(command.hex(), TARGET_HEX, "§11.1: validate/apply never mutate the command")


## §12.7 line 1015 NEGATIVE PIN — "worker | dig\_mult | Can Dig/Build; dig-speed multiplier" is
## DATA, and `data/units/*.json` is M6, so `type_id` is OPAQUE here and ANY unit type may be
## assigned. Pinned positively so nobody adds a `type_id == "worker"` whitelist (§13.5's canary).
func test_any_unit_type_may_be_ordered_to_dig() -> void:
	for type_id: String in [UNIT_TYPE_ID, OTHER_UNIT_TYPE_ID, "creep_rat", "x"]:
		var state: GameState = _state_with(MIN_PLAYERS)
		_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
		var spawned: UnitState = state.spawn_unit(0, type_id, ADJACENT_HEX, UNIT_MAX_HP)
		assert_not_null(spawned, "sanity: the spawn is accepted")
		if spawned == null:
			return
		_accept(
			state,
			_command(0, spawned.unit_id(), TARGET_HEX),
			"§12.7: worker-ness is a TRAIT (data) — \"%s\" may dig at this slice" % type_id
		)


# =============================================================================================
# F. §13.4 NEGATIVE PINS — what M2-T5 deliberately does NOT do
# =============================================================================================

## §3.4 step 4 NEGATIVE PIN — "Dig progress ticks; completed digs apply yields, then **Breach
## checks** (§4.6), then **Noise pings** (§4.8)" IS NOT IMPLEMENTED. After any number of accepted
## EndTurns every site's `remaining_turns()` is UNCHANGED, every stockpile is still EMPTY, the
## target hex still carries its §4.2 Solid terrain, and the one seeded stream has drawn NOTHING.
func test_ending_turns_ticks_no_dig_progress_and_applies_no_yield() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_accept(state, _command(0, first, TARGET_HEX), "the first digger")
	_accept(state, _command(0, second, TARGET_HEX), "the second digger")

	for k: int in range(3 * MIN_PLAYERS):
		var rejection: CommandError = EndTurnCommand.new(state.current_player_index()).execute(
			state, null
		)
		assert_null(rejection, "sanity: EndTurn %d is accepted" % k)

	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "§3.4 step 4 is SLICE 4 — the site is still there")
	if site == null:
		return
	assert_eq(
		site.remaining_turns(),
		FIXTURE_TURNS,
		"§3.4 step 4: the dig TICK is a LATER slice — no worker-turn has been spent"
	)
	assert_eq(
		site.digger_ids(), [first, second] as Array[int], "§3.4: the diggers are still assigned"
	)
	assert_eq(
		state.map.get_terrain_type(TARGET_HEX),
		FIXTURE_TERRAIN_ID,
		"§3.4 step 4: the hex-becomes-Cave transition is a LATER slice"
	)
	for index: int in range(MIN_PLAYERS):
		var holder: PlayerState = state.player(index)
		assert_not_null(holder, "sanity: player(%d) exists" % index)
		if holder == null:
			return
		assert_eq(
			holder.resource_ids(),
			[] as Array[String],
			"§3.4 step 4: yield APPLICATION is a LATER slice — player %d holds nothing" % index
		)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1: nothing in this slice is random — the single seeded stream must not advance"
	)


## §13.4 — M2-T5 adds EXACTLY ONE Command file, and CancelDig (§11.1 line 705's fifth printed name)
## is SLICE 3b. Pinned by enumerating `scripts/sim/commands/` and by a recursive scan of the whole
## `scripts/` tree for the token, so a stray half-built cancel cannot appear unremarked.
func test_no_cancel_dig_exists_anywhere_yet() -> void:
	assert_eq(
		_gd_files(COMMANDS_DIR),
		["command.gd", "command_error.gd", "dig_hex_command.gd", "end_turn_command.gd"] as Array[String],
		"§13.4: M2-T5 adds exactly ONE Command file — CancelDig is slice 3b"
	)
	var sources: Array[String] = []
	_gd_files_recursive(SCRIPTS_DIR, sources)
	assert_gt(sources.size(), 0, "sanity: the recursive source walk found files")
	for path: String in sources:
		assert_false(
			_code_text(path).contains("cancel_dig"),
			"§13.4: CancelDig is slice 3b — %s must not name it yet" % path
		)


## §13.4 — the `DigRules` members that belong to LATER slices are NOT called here: "Dig 2x" needs
## an ABILITY that does not exist, and the yield accessors are §3.4 step 4's completion (slice 4).
func test_the_command_calls_no_premature_rule() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	for banned: String in PREMATURE_RULE_TOKENS:
		assert_false(
			code.contains(banned),
			"§13.4: %s belongs to a LATER slice — %s must not call it" % [banned, DIG_HEX_PATH]
		)


# =============================================================================================
# G. MECHANICAL SOURCE SCANS on scripts/sim/commands/dig_hex_command.gd
#    Written FRESH for this file — it inherits NOTHING from the other scan suites. Comment
#    stripping is LOAD-BEARING: the header quotes §4.2's whole table and §7.1's "3 turns ... in 1".
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			DIG_HEX_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % DIG_HEX_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % DIG_HEX_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R), and "Renderer/UI subscribe;
## the sim never calls them".
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [DIG_HEX_PATH, banned]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [DIG_HEX_PATH, banned]
		)


## S3 M1-T9/(AY) — the command carries NO SECOND LOADER: `DigRules` is injected ALREADY-LOADED, so
## `RulesLoader`, `RulesError` and `load_file` must all be ABSENT (the M1-T9 no-second-loader rule;
## `RulesLoader` is also what would force a signature change on every `GameState.new` call site).
func test_source_declares_no_loader_and_overrides_no_native_method() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	for banned: String in ["RulesLoader", "RulesError", "load_file"]:
		assert_false(
			code.contains(banned),
			"M1-T9/(AY): DigRules is INJECTED already-loaded — %s must not name %s" % [
				DIG_HEX_PATH, banned
			]
		)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % DIG_HEX_PATH
	)


## S4 (AV)/(AU)(iv)/§13.5 — the Command authors its OWN eleven codes at its own call sites, authors
## no other command's, and there is NO enum and NO const list of codes anywhere in engine code.
func test_source_authors_exactly_its_own_rejection_codes() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	assert_eq(AUTHORED_CODES.size(), 11, "sanity: (AY) lists eleven codes in precedence order")
	for authored: StringName in AUTHORED_CODES:
		assert_true(
			code.contains(String(authored)),
			"(AY): %s authors \"%s\" at its own call site" % [DIG_HEX_PATH, String(authored)]
		)
	assert_false(
		code.contains("abstract_command"),
		"(AV): the base's own code belongs to the base — %s must not repeat it" % DIG_HEX_PATH
	)
	assert_false(code.contains("enum "), "(AV): rejection codes are never an enum")


## S5 (T)/(AH)/(AU)(iv)/§13.5 — NO RESOURCE, TRAIT, HOUSING OR FACTION WHITELIST, and — the point
## of the whole slice — NO §4.2 TERRAIN ID: diggability comes from `DigRules.is_diggable`, i.e.
## from §12.1 data, so adding a terrain type stays a DATA edit (§13.5's M6 canary). Run on the
## COMMENT-STRIPPED, lower-cased source (the (AX) incidental-substring lesson).
func test_source_carries_no_terrain_resource_or_trait_whitelist() -> void:
	var code: String = _code_text(DIG_HEX_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	for id: String in SOLID_TERRAIN_IDS:
		assert_false(
			code.contains(id),
			"(T)/(AH): §4.2's terrain ids live in data — %s must not name \"%s\"" % [DIG_HEX_PATH, id]
		)
	for id: String in RESOURCE_IDS:
		assert_false(
			code.contains(id),
			"(AU)(iv): resource ids are opaque data — %s must not name \"%s\"" % [DIG_HEX_PATH, id]
		)
	for token: String in VOCABULARY_TOKENS:
		assert_false(
			code.contains(token),
			"§12.7/§5.2/§7: traits, housing and factions are DATA — %s must not name \"%s\"" % [
				DIG_HEX_PATH, token
			]
		)


## S6 §13.6 "constants read from data, not code" — NOT ONE §4.2 dig number in the command. Every
## dig time, the max-digger cap and every yield come from `DigRules` over §12.1 data; §4.1's
## adjacency distance is the only number the rule owns, and it must be a NAMED PRIVATE const (the
## (AJ) named-mathematical-const precedent — §4.1's neighbour geometry is fixed, not tunable).
func test_source_hard_codes_no_dig_number_and_names_its_adjacency_constant() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)

	var forbidden: RegEx = RegEx.new()
	assert_eq(
		forbidden.compile("(?<![0-9A-Za-z._])(2|3|4|10|15|25|60|120|150|250)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the forbidden-numeral pattern compiles"
	)
	var hit: RegExMatch = forbidden.search(code)
	assert_null(
		hit,
		"§13.6: §4.2's numbers live in data/ruleset.json — %s must not hard-code %s" % [
			DIG_HEX_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(FORBIDDEN_NUMERALS.size(), 10, "sanity: every §4.2 dig/vein/cap numeral is covered")

	var numeral: RegEx = RegEx.new()
	assert_eq(
		numeral.compile("(?<![0-9A-Za-z._])([0-9]+)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the standalone-numeral pattern compiles"
	)
	for found: RegExMatch in numeral.search_all(code):
		assert_true(
			PERMITTED_NUMERALS.has(found.get_string()),
			"§13.6: only %s are permitted in %s — found \"%s\"" % [
				str(PERMITTED_NUMERALS), DIG_HEX_PATH, found.get_string()
			]
		)

	var named_const: RegEx = RegEx.new()
	assert_eq(
		named_const.compile("const\\s+_[A-Z][A-Z0-9_]*\\s*:\\s*int\\s*=\\s*1\\b"),
		OK,
		"sanity: the adjacency-const pattern compiles"
	)
	assert_not_null(
		named_const.search(code),
		(
			"(AJ)/§4.1: the adjacency distance must be a NAMED PRIVATE const "
			+ "(`const _ADJACENT_DISTANCE: int = 1`) in %s, never a bare literal" % DIG_HEX_PATH
		)
	)


## S7 (AW)(iii)/§13.6 — the command MUST reach §12.1 through `DigRules`, and THE §7.1 OWNERSHIP
## SEAM IS A SINGLE PRIVATE FUNCTION: `dig_turns_for(` appears EXACTLY ONCE in the whole file, so
## there is exactly one place the owner determination lives and exactly one place M3/M4's Raise
## Granite has to change.
func test_source_reads_the_table_through_dig_rules_at_exactly_one_seam() -> void:
	var code: String = _code_text(DIG_HEX_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_HEX_PATH)
	for token: String in REQUIRED_TOKENS:
		assert_true(
			code.contains(token),
			"§13.6: %s must read §4.2/§12.1 through DigRules — \"%s\" is missing" % [
				DIG_HEX_PATH, token
			]
		)
	assert_eq(
		code.count("dig_turns_for("),
		1,
		"(AW)(iii): the §7.1 ownership seam is ONE private function — `dig_turns_for(` must "
			+ "appear EXACTLY once in %s" % DIG_HEX_PATH
	)


## S8 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: a MISSING member fails
## instead of passing vacuously and an EXTRA member (a mutable setter, a `to_dict`, a public
## `dig_rules()` accessor, a `total_turns()` convenience) fails too. ZERO public vars and ZERO
## public consts: the command is an immutable value object and its one constant is private.
func test_public_api_is_exactly_the_six_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_HEX_PATH, public_functions, undocumented)

	var command: DigHexCommand = _command(0, 1, TARGET_HEX)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, DIG_HEX_PATH]
		)
		assert_true(
			command.has_method(required),
			"§11.2: %s must be callable on a DigHexCommand instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			DIG_HEX_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(DIG_HEX_PATH),
		REQUIRED_PUBLIC_VARS,
		"(AY): %s declares ZERO public vars — it is an immutable value object" % DIG_HEX_PATH
	)
	assert_eq(
		_collect_public_consts(DIG_HEX_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.6: %s declares ZERO public consts — its one constant is private" % DIG_HEX_PATH
	)


## S9 §11.1/§11.2 — DigHexCommand is a pure [RefCounted] in `scripts/sim/commands/`. Asserted
## through get_class() — `is Node` would be a PARSE ERROR here (M0-T2 item 11).
func test_dig_hex_command_is_a_pure_refcounted_in_scripts_sim_commands() -> void:
	assert_true(
		FileAccess.file_exists(DIG_HEX_PATH), "§11.2: DigHexCommand belongs at %s" % DIG_HEX_PATH
	)
	assert_eq(
		_command(0, 1, TARGET_HEX).get_class(),
		"RefCounted",
		"§11.1: DigHexCommand must be a pure RefCounted"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## The shipped ruleset, asserted loaded so a data failure reports once and clearly.
func _loaded() -> RulesLoader:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(RULESET_PATH)
	assert_true(ok, "§12.1: %s must load before DigRules can read it" % RULESET_PATH)
	if not ok:
		for err: RulesError in loader.errors:
			assert_false(true, "§12.1: %s" % err.format_for(RULESET_PATH))
	return loader


## The injected, already-loaded §4.2 dig table (M2-T3). Cached: it mutates nothing.
func _dig_rules() -> DigRules:
	if _rules_cache == null:
		_rules_cache = DigRules.new(_loaded())
	return _rules_cache


## A state on a radius-2 map with `count` players and an EMPTY roster of units and dig sites.
func _state_with(count: int) -> GameState:
	return GameState.new(GOLDEN_SEED, HexMap.new(MAP_RADIUS), count)


## Writes a §4.2 terrain id onto `where`, asserting it took (a silent out-of-bounds no-op here
## would make every later assertion meaningless).
func _set_terrain(state: GameState, where: Vector2i, terrain_id: String) -> void:
	assert_not_null(state.map, "sanity: the fixture carries a map")
	if state.map == null:
		return
	state.map.set_terrain_type(where, terrain_id)
	assert_eq(state.map.get_terrain_type(where), terrain_id, "fixture: %s is set" % str(where))


## Spawns one §12.2-shaped unit for `owner_index` at `where` and returns its minted id.
##
## TRAP measured live at M2-T4: `owner` and `name` are BASE-CLASS PROPERTIES of [Node], which
## `GutTest` extends, so a parameter named either is `shadowed_variable_base_class` = level 2 = a
## HARD ERROR that silently un-collects the whole test file.
func _spawn(state: GameState, owner_index: int, where: Vector2i) -> int:
	var spawned: UnitState = state.spawn_unit(owner_index, UNIT_TYPE_ID, where, UNIT_MAX_HP)
	assert_not_null(spawned, "sanity: the spawn for owner %d is accepted" % owner_index)
	if spawned == null:
		return NO_UNIT_ID
	return spawned.unit_id()


## A dig order with the shipped, already-loaded §4.2 table injected.
func _command(player_index: int, unit_id_value: int, where: Vector2i) -> DigHexCommand:
	return DigHexCommand.new(player_index, unit_id_value, where, _dig_rules())


## A radius-2 fixture whose FIRST minted unit id is `expected_id`, standing adjacent to a Hard Rock
## target — built identically every time so two of them must hash identically.
func _dug_state(expected_id: int) -> GameState:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	assert_eq(_spawn(state, 0, ADJACENT_HEX), expected_id, "fixture: the digger is id %d" % expected_id)
	return state


## Executes `command` through the ONE gate with a recording bus, asserting it is ACCEPTED, and
## hands the recorder back so the caller can pin the emitted event.
func _accept(state: GameState, command: DigHexCommand, why: String) -> DigRecorder:
	var bus: EventBus = EventBus.new()
	var recorder: DigRecorder = DigRecorder.new()
	bus.subscribe(DigStartedEvent.TYPE_NAME, recorder.on_event)
	var rejection: CommandError = command.execute(state, bus)
	assert_null(
		rejection,
		"%s: the order must be ACCEPTED (got \"%s\")" % [
			why, "" if rejection == null else String(rejection.code)
		]
	)
	return recorder


## Executes `command` through the ONE gate with a recording bus, asserting it is REJECTED with
## exactly `expected_code`, that it EMITS NOTHING, and that the state is byte-identical afterwards
## with no dig site created or changed. `state` may be null (the `null_state` probe).
func _reject(
	state: GameState,
	command: DigHexCommand,
	expected_code: StringName,
	why: String
) -> void:
	var before: int = 0
	var sites_before: Array[Vector2i] = []
	if state != null:
		before = state.content_hash()
		sites_before = state.dig_site_hexes()

	var bus: EventBus = EventBus.new()
	var recorder: DigRecorder = DigRecorder.new()
	bus.subscribe(DigStartedEvent.TYPE_NAME, recorder.on_event)
	var rejection: CommandError = command.execute(state, bus)

	assert_not_null(rejection, "%s: the order must be REJECTED" % why)
	if rejection == null:
		return
	assert_eq(
		rejection.code,
		expected_code,
		"%s: the code is exactly \"%s\"" % [why, String(expected_code)]
	)
	assert_false(rejection.message.is_empty(), "(AY): every rejection carries a message")
	assert_eq(recorder.calls, 0, "§13.6: a rejected order changes nothing, so it emits NOTHING")
	if state == null:
		return
	assert_eq(state.content_hash(), before, "§11.1: a rejected command leaves the state identical")
	assert_eq(state.dig_site_hexes(), sites_before, "(AY): a rejected order creates no site")


## Every `.gd` file directly in `directory`, ascending. `.gd.uid` sidecars are engine bookkeeping.
func _gd_files(directory: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			out.append(file_name)
	out.sort()
	return out


## Every `.gd` file under `directory`, recursively, as `res://` paths.
func _gd_files_recursive(directory: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			out.append("%s/%s" % [directory, file_name])
	for dir_name: String in DirAccess.get_directories_at(directory):
		_gd_files_recursive("%s/%s" % [directory, dir_name], out)


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


## Every top-level public `var` declared by a source file, in source order.
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


## Every top-level public `const` declared by a source file, in source order.
func _collect_public_consts(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with("const "):
			continue
		var rest: String = raw_line.substr(6)
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
