## CancelDigCommand — the THIRD of §11.1 line 705's fourteen printed commands, and a PURE CONSUMER
## of what M2-T5 landed (`DigSite.remove_digger`, `GameState.remove_dig_site`,
## `GameState.dig_site_of_digger`). GDD §11.1 (Layered Design, **binding**), §4.2 (Hex Types — the
## dig table the cancelled order was sized from), §4.1 (hex geometry), §3.4 (Order of Operations —
## step 4's tick is SLICE 4 and is pinned NEGATIVELY here), §1.1 (Design Pillars), §5.3 (Mining
## Zones), §12.1, §12.7, §11.2, §11.3, §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 705): "**Commands** (command pattern): MoveUnit, AttackUnit, AttackHex, DigHex,
##         **CancelDig**, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein,
##         SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -> Error? and
##         apply(state) -> Array[Event]. **Every mutation of GameState goes through a Command**."
##   §4.2  (line 186, "Solid type | Dig time (worker-turns)"): "Dense Granite | **4** | \+4 Stone".
##         The fixture terrain, chosen because 4 is the largest printed dig time, so "progress is
##         LOST" and "progress is UNCHANGED" are maximally distinguishable.
##   §4.2  (line 188): "Artificial Granite | **3 (owner: 1)**" — by (AY)(ii) the §7.1 owner variant
##         is NOT reachable in this milestone, so artificial granite is 3, never 1.
##   §4.2  (line 197): "Dig time is total worker-turns; multiple workers on adjacent hexes may work
##         the same target (**max 2 simultaneous diggers per hex**)." — the cap the C4 round trip
##         proves a cancel really frees a slot in, read from §12.1 through `DigRules`.
##   §3.4  (step 4): "Dig progress ticks; completed digs apply yields, then **Breach checks**
##         (§4.6), then **Noise pings** (§4.8)." — SLICE 4, pinned NEGATIVELY below.
##   §3.4  (step 9): "**Action phase:** the player issues commands until End Turn." — why a cancel
##         issued out of turn is rejected at all.
##   §1.1  (pillar 1): "**Carve Your Own Battlefield.** Exploration *is* excavation." — the pillar
##         that decides a cancelled dig LOSES its progress: a dig is a commitment, not a free undo.
##   §5.3  (line 299): "**Mining Zone:** drag-select a 3D box of Solid hexes -> the TurnManager
##         auto-assigns idle workers (nearest-first, reachable-only), **generating ordinary Dig
##         commands each turn**. Zones are UI/AI conveniences that create commands; they add
##         **zero** sim rules." — the reason an ownerless orphan site would be a DEADLOCK.
##   §12.7 (line 1015): "worker | dig\_mult | Can Dig/Build; dig-speed multiplier" — worker-ness is
##         a TRAIT, i.e. DATA, and `data/units/*.json` is M6, so ANY unit type may be cancelled in
##         this slice and `worker`/`dig_mult` are FORBIDDEN tokens in the command source.
##
## `docs/decisions.md` was re-scanned END TO END this iteration: the only logged §12.1/§4.2
## overrides in the whole project are **(AU)(i)** (`dig_yields.artificial_granite.stone = 2`, a
## transcription of §4.2's own "\+2 Stone") and **(AW)(i)** (the top-level `dig` group binding §4.2
## terrain ids to §12.1 dig keys — no numeric value moved). NEITHER touches anything this file
## pins, so every printed §4.2 value below governs AS PRINTED.
##
## §4.2 PRINTS NOTHING ABOUT CANCEL SEMANTICS, so the four rules below are §13.4 judgment calls to
## be logged by Land as **(AZ)** ((AU)/(AV)/(AW)/(AX)/(AY) are cross-referenced by many files and
## suites — do NOT renumber any of them):
##   (AZ)(i)   CANCEL IS UNIT-TARGETED, NOT HEX-TARGETED. `_init(player_index, unit_id)` — no hex
##             parameter and no `DigRules` parameter, because (AY)(iv)'s ONE JOB PER UNIT makes
##             `dig_site_of_digger(unit_id)` total and unambiguous, and because cancel is the exact
##             inverse of `DigHexCommand`, which assigns exactly ONE unit.
##   (AZ)(ii)  THE LAST DIGGER LEAVING REMOVES THE SITE, AND ITS PROGRESS IS LOST. An ownerless
##             site that kept its progress would be permanently un-startable by anyone else
##             (`DigHexCommand` rejects `site_not_yours` on an owner mismatch) and §5.3's Mining
##             Zones re-issue "ordinary Dig commands each turn", so an orphan site is a DEADLOCK.
##             Losing the progress also keeps §1.1 pillar 1 honest: §4.2 line 197's "total
##             worker-turns" is a property of the ORDER, and the order is gone.
##   (AZ)(iii) A NON-LAST CANCEL LEAVES `remaining_turns` UNCHANGED and the site alive.
##   (AZ)(iv)  `no_map` IS DELIBERATELY NOT A CODE HERE: a cancel reads no terrain, so `validate`
##             must not consult `state.map` at all. Pinned POSITIVELY — a mapless state cancels.
##   (AZ)(v)   THE REJECTION VOCABULARY IS SIX OPAQUE `StringName`s IN A FIXED PRECEDENCE, each
##             authored at its OWN call site (no enum, no const list, no whitelist in engine code):
##             `null_state` -> `no_players` -> `not_current_player` -> `no_such_unit` ->
##             `not_your_unit` -> `not_digging`.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY; the base class through `get_base_script()`.
##
## The source scans at the bottom are written FRESH for `scripts/sim/commands/cancel_dig_command.gd`.
extends GutTest

const CANCEL_DIG_PATH: String = "res://scripts/sim/commands/cancel_dig_command.gd"
const COMMAND_PATH: String = "res://scripts/sim/commands/command.gd"
const EVENT_PATH: String = "res://scripts/core/event.gd"
const EVENT_BUS_PATH: String = "res://scripts/core/event_bus.gd"
const RULESET_PATH: String = "res://data/ruleset.json"

## §12.6's example seed, so this file's seed comes from the GDD rather than from invention.
const GOLDEN_SEED: int = 1337

## §3.1 line 118 "Skirmish: 2–4 players".
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

## Big enough that every neighbour of the origin is in bounds; §4.1's real radii (24/32/40) live in
## data/mapgen/*.json.
const MAP_RADIUS: int = 2

## §4.1 "axial coordinates (q, r)" — the target and the hexes the diggers stand on. ADJACENT_HEX,
## SECOND_ADJACENT_HEX and THIRD_ADJACENT_HEX are `HexMath.DIRECTIONS` 0, 1 and 2 (E, NE, NW) from
## TARGET_HEX; the fixture asserts their distances rather than trusting the transcription.
const TARGET_HEX: Vector2i = Vector2i(0, 0)
const ADJACENT_HEX: Vector2i = Vector2i(1, 0)
const SECOND_ADJACENT_HEX: Vector2i = Vector2i(1, -1)
const THIRD_ADJACENT_HEX: Vector2i = Vector2i(0, -1)

## A SECOND diggable target, adjacent to SECOND_ADJACENT_HEX, so two independent sites can exist.
const OTHER_TARGET_HEX: Vector2i = Vector2i(2, -2)

## §4.2 line 186 "Dense Granite | **4** | \+4 Stone" — the row every cancel fixture digs. Four is
## the largest printed dig time, which is what makes "progress LOST" and "progress UNCHANGED"
## maximally distinguishable.
const FIXTURE_TERRAIN_ID: String = "dense_granite"
const FIXTURE_TURNS: int = 4

## §4.2 line 185 "Hard Rock | 2 | \+2 Stone | Baseline" — the SECOND site's row, so the two sites
## in the independence fixture are distinguishable by their §4.2 totals alone.
const OTHER_TERRAIN_ID: String = "hard_rock"
const OTHER_TURNS: int = 2

## §4.2 line 197 "max 2 simultaneous diggers per hex", read from §12.1's `dig.max_diggers_per_hex`
## through `DigRules.max_diggers_per_hex()` ((AW)(i)). The literal must NOT appear in the command.
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
## `tests/unit/test_dig_hex_command.gd` lines 163-178.
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

## The THREE of the fourteen that exist after this slice — every other printed name is still
## unbuilt (§13.4: invent nothing ahead of its milestone).
const BUILT_COMMAND_NAMES: Array[String] = ["dig_hex", "cancel_dig", "end_turn"]

## (AZ)(v) — the SIX rejection codes this Command authors, IN PRECEDENCE ORDER.
const CODE_NULL_STATE: StringName = &"null_state"
const CODE_NO_PLAYERS: StringName = &"no_players"
const CODE_NOT_CURRENT_PLAYER: StringName = &"not_current_player"
const CODE_NO_SUCH_UNIT: StringName = &"no_such_unit"
const CODE_NOT_YOUR_UNIT: StringName = &"not_your_unit"
const CODE_NOT_DIGGING: StringName = &"not_digging"

const AUTHORED_CODES: Array[StringName] = [
	&"null_state",
	&"no_players",
	&"not_current_player",
	&"no_such_unit",
	&"not_your_unit",
	&"not_digging",
]

## (AZ)(iv) + (AY)(v) — codes that belong to `DigHexCommand` ALONE and must NOT be re-authored
## here. `no_map` heads the list: a cancel reads no terrain, so consulting the map at all would be
## a rule this task did not sanction.
const FOREIGN_CODES: Array[String] = [
	"no_map",
	"unit_not_adjacent",
	"not_diggable",
	"site_not_yours",
	"already_digging",
	"dig_site_full",
	"abstract_command",
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
	"Input.",
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

## §4.2's nine Solid-hex terrain ids. FORBIDDEN: a cancel reads NO terrain at all, and the
## vocabulary is DATA either way ((T)/(AH), §13.5's M6 canary).
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

## §5.1's SEVEN resources. FORBIDDEN: yield APPLICATION is §3.4 step 4 = SLICE 4, and a CANCEL
## never pays anything back ((AZ)(ii): the progress is LOST, not refunded).
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

## (AZ)(i)/(AZ)(iv) — the tokens that prove the command reads NEITHER §12.1 data NOR the map: it
## takes no `DigRules`, loads nothing, and never touches `state.map`.
const FORBIDDEN_DEPENDENCY_TOKENS: Array[String] = [
	"DigRules",
	"RulesLoader",
	"RulesError",
	"load_file",
	"state.map",
	"HexMap",
	"get_terrain_type",
	"HexMath",
	"dig_turns_for",
	"is_diggable",
	"max_diggers_per_hex",
	"halve_remaining_turns",
	"yield_amount",
	"yield_resource_ids",
	"vein_resource_id",
]

## §13.6 — the printed §4.2/§5.2/§3.2 numbers the command must NOT contain. Only 0 and 1 may
## appear standalone; not one §4.2 dig number and not the max-digger cap may reach engine code
## ((AY)(vi)).
const FORBIDDEN_NUMERALS: Array[String] = [
	"2", "3", "4", "10", "15", "25", "60", "120", "150", "250",
]
const PERMITTED_NUMERALS: Array[String] = ["0", "1"]

## The COMPLETE public surface of CancelDigCommand: FIVE functions (plus `_init` and the INHERITED
## `execute`), ZERO public vars, ZERO public consts. A MISSING member fails and an EXTRA one
## (a `hex()` accessor, a `to_dict`, a public constant) fails too — the standing (AX)(xi)/(AY)(xi)
## exact-surface rule.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"player_index", "unit_id", "command_name", "validate", "apply"
]
const REQUIRED_PUBLIC_VARS: Array[String] = []
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## §11.1 — `GameState`'s EXACT public surface, UNCHANGED by this slice: nineteen members, two vars
## and seventeen functions. M2-T6 adds NO `GameState` function ((AY)(xi) grew the list 14 -> 19 and
## this slice must leave it at 19).
const GAME_STATE_PATH: String = "res://scripts/sim/game_state.gd"
const GAME_STATE_PUBLIC_VARS: Array[String] = ["map", "rng"]
const GAME_STATE_PUBLIC_FUNCTIONS: Array[String] = [
	"player_count",
	"player",
	"turn",
	"current_player_index",
	"set_turn_position",
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
	"content_hash",
]

## §11.1 — `DigSite`'s EXACT public surface, UNCHANGED by this slice: nine functions ((AY)(xi)).
const DIG_SITE_PATH: String = "res://scripts/sim/dig_site.gd"
const DIG_SITE_PUBLIC_FUNCTIONS: Array[String] = [
	"hex",
	"owner_index",
	"total_turns",
	"remaining_turns",
	"set_remaining_turns",
	"digger_ids",
	"add_digger",
	"remove_digger",
	"content_hash",
]

## Doc-comment sections accepted by the S8 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§4.2", "§4.1", "§3.4", "§1.1", "§5.3"]

## Cached across tests: parsing `data/ruleset.json` once keeps this suite's runtime honest. The
## object is READ-ONLY (M2-T3: `DigRules` mutates nothing), so sharing it is safe. It is used ONLY
## to place the dig orders this suite then cancels — `CancelDigCommand` itself must never see it.
var _rules_cache: DigRules = null


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Records EVERY event delivered on EVERY subscribed type, so "exactly one DigCancelledEvent and
## NOTHING else on the bus" is checkable in one object.
class BusRecorder extends RefCounted:
	var calls: int = 0
	var types: Array[String] = []
	var cancelled: Array[DigCancelledEvent] = []

	func on_event(event: Event) -> void:
		calls += 1
		types.append(String(event.type))
		var cancel_event: DigCancelledEvent = event as DigCancelledEvent
		if cancel_event != null:
			cancelled.append(cancel_event)


# =============================================================================================
# A. IDENTITY AND SURFACE (§11.1 line 705, §11.3)
# =============================================================================================

## §11.1 — CancelDigCommand IS a Command: it inherits `execute`, THE ONE GATE, so nothing can apply
## past validation. Asserted through the script's base script, never `is Node`.
func test_cancel_dig_is_a_command_and_inherits_the_gate() -> void:
	var command: CancelDigCommand = CancelDigCommand.new(0, 1)
	var own_script: Script = command.get_script()
	assert_not_null(own_script, "sanity: the instance carries its script")
	if own_script == null:
		return
	var base_script: Script = own_script.get_base_script()
	assert_not_null(base_script, "§11.1: CancelDigCommand extends the Command base")
	if base_script == null:
		return
	assert_eq(
		base_script.resource_path,
		COMMAND_PATH,
		"§11.1: CancelDigCommand must extend %s so it inherits the validate/apply gate" % COMMAND_PATH
	)
	assert_true(command.has_method("execute"), "§11.1: the gate is inherited, not re-declared")


## §11.1 line 705 — the name is exactly `cancel_dig`, and it is one of the FOURTEEN printed command
## names. The printed list lives HERE, never in engine code. `end_turn`, `dig_hex` and `cancel_dig`
## are now the THREE of fourteen that exist.
func test_the_command_name_is_cancel_dig_and_is_one_of_the_printed_fourteen() -> void:
	assert_eq(
		PRINTED_COMMAND_NAMES.size(),
		14,
		"§11.1 line 705 prints exactly fourteen commands — this list must transcribe all of them"
	)
	var chosen: StringName = CancelDigCommand.new(0, 1).command_name()
	assert_eq(chosen, &"cancel_dig", "§11.1: the command name is exactly \"cancel_dig\"")
	assert_true(
		PRINTED_COMMAND_NAMES.has(String(chosen)),
		"§11.1: \"%s\" must be one of the fourteen printed command names" % String(chosen)
	)
	assert_ne(
		chosen,
		DigHexCommand.new(0, 1, TARGET_HEX, _dig_rules()).command_name(),
		"§11.1: each command has its OWN name"
	)
	assert_ne(chosen, EndTurnCommand.new(0).command_name(), "§11.1: each command has its OWN name")
	for built: String in BUILT_COMMAND_NAMES:
		assert_true(
			PRINTED_COMMAND_NAMES.has(built),
			"§11.1: \"%s\" is one of the printed fourteen" % built
		)
	assert_eq(BUILT_COMMAND_NAMES.size(), 3, "§13.4: three of the fourteen exist after this slice")


## (AZ)(i) — the command is an IMMUTABLE value object built from exactly TWO parameters: the
## issuing player and the unit whose job is being cancelled. There is NO hex parameter (a unit has
## at most one dig site — (AY)(iv)) and NO `DigRules` parameter (a cancel reads no data).
func test_the_constructor_arguments_are_carried_verbatim() -> void:
	for index: int in [0, 1, MAX_PLAYERS, -1]:
		for id: int in [1, 7, NO_UNIT_ID, -3]:
			var command: CancelDigCommand = CancelDigCommand.new(index, id)
			assert_eq(command.player_index(), index, "(AZ)(i): player_index() answers _init's %d" % index)
			assert_eq(command.unit_id(), id, "(AZ)(i): unit_id() answers _init's %d" % id)


## §4.1 line 172 "Distance = cube distance. Neighbor order (fixed, index 0-5): E, NE, NW, W, SW,
## SE" — the fixture's own geometry, asserted rather than trusted, so a mis-transcribed constant
## fails HERE with a clear message instead of corrupting every dig fixture below.
func test_the_fixture_geometry_matches_section_four_one() -> void:
	assert_eq(HexMath.distance(TARGET_HEX, ADJACENT_HEX), 1, "§4.1: E of the target is adjacent")
	assert_eq(HexMath.distance(TARGET_HEX, SECOND_ADJACENT_HEX), 1, "§4.1: NE is adjacent")
	assert_eq(HexMath.distance(TARGET_HEX, THIRD_ADJACENT_HEX), 1, "§4.1: NW is adjacent")
	assert_eq(
		HexMath.distance(SECOND_ADJACENT_HEX, OTHER_TARGET_HEX),
		1,
		"§4.1: the NE hex is adjacent to BOTH targets — the two-site fixture"
	)
	var map: HexMap = HexMap.new(MAP_RADIUS)
	for inside: Vector2i in [
		TARGET_HEX, ADJACENT_HEX, SECOND_ADJACENT_HEX, THIRD_ADJACENT_HEX, OTHER_TARGET_HEX
	]:
		assert_true(map.is_in_bounds(inside), "sanity: %s is on the radius-2 map" % str(inside))


## §4.2 lines 186 and 185 — the two dig times this suite hand-transcribes are exactly what §12.1
## data answers through `DigRules`, so every later assertion about 4 (and 2) is grounded in the
## GDD table rather than in this file's opinion.
func test_the_fixture_dig_times_match_the_printed_table() -> void:
	assert_eq(
		_dig_rules().dig_turns_for(FIXTURE_TERRAIN_ID, false),
		FIXTURE_TURNS,
		"§4.2 line 186: \"Dense Granite | 4\" worker-turns"
	)
	assert_eq(
		_dig_rules().dig_turns_for(OTHER_TERRAIN_ID, false),
		OTHER_TURNS,
		"§4.2 line 185: \"Hard Rock | 2\" worker-turns"
	)
	assert_eq(
		_dig_rules().dig_turns_for("artificial_granite", false),
		3,
		"§4.2 line 188/(AY)(ii): the §7.1 owner variant is NOT reachable — granite is 3, never 1"
	)
	assert_eq(
		_dig_rules().max_diggers_per_hex(),
		MAX_DIGGERS_PER_HEX,
		"§4.2 line 197/§12.1: the cap is DATA — DigRules is where a Command reads it"
	)


## §13.4/(AY)(xi) — this slice adds NO `GameState` function and NO `DigSite` function: it is a PURE
## CONSUMER of what M2-T5 landed. Both exact public surfaces are pinned NEGATIVELY, and
## `scripts/core/event.gd` / `scripts/core/event_bus.gd` are pinned free of the new vocabulary
## (M0-T3 (f): the base holds no event names).
func test_the_consumed_surfaces_are_unchanged_by_this_slice() -> void:
	var state_functions: Array[String] = []
	var state_undocumented: Array[String] = []
	_collect_public_functions(GAME_STATE_PATH, state_functions, state_undocumented)
	assert_eq(
		state_functions,
		GAME_STATE_PUBLIC_FUNCTIONS,
		"(AY)(xi): GameState's public function list stays at seventeen — M2-T6 adds none"
	)
	assert_eq(
		_collect_public_vars(GAME_STATE_PATH),
		GAME_STATE_PUBLIC_VARS,
		"(AY)(xi): GameState's public vars stay exactly [map, rng]"
	)

	var site_functions: Array[String] = []
	var site_undocumented: Array[String] = []
	_collect_public_functions(DIG_SITE_PATH, site_functions, site_undocumented)
	assert_eq(
		site_functions,
		DIG_SITE_PUBLIC_FUNCTIONS,
		"(AY)(xi): DigSite's public function list stays at nine — M2-T6 adds none"
	)
	assert_eq(
		_collect_public_vars(DIG_SITE_PATH), [] as Array[String], "(AY)(xi): DigSite has no public var"
	)

	for banned: String in ["dig_cancelled", "DigCancelled", "cancel_dig", "CancelDig"]:
		assert_false(
			_code_text(EVENT_PATH).contains(banned),
			"M0-T3 (f): the Event base declares no vocabulary — it must not name %s" % banned
		)
		assert_false(
			_code_text(EVENT_BUS_PATH).contains(banned),
			"M0-T3 (f): the EventBus declares no vocabulary — it must not name %s" % banned
		)


# =============================================================================================
# B. THE REJECTION VOCABULARY AND ITS PRECEDENCE ((AZ)(v); §11.1 "validate(state) -> Error?")
#    Every case below also asserts: content_hash() byte-identical, NOTHING on a recording bus, and
#    the dig-site registry untouched down to each site's diggers (that is what `_reject` does).
# =============================================================================================

## (AZ)(v) 1 — a null state is rejected `null_state`, never a crash (the (B)/(L)/(AS) totality
## spirit), through `validate` directly AND through the gate.
func test_a_null_state_is_rejected() -> void:
	var rejection: CommandError = CancelDigCommand.new(0, 1).validate(null)
	assert_not_null(rejection, "(AZ)(v): a null state is rejected, not applied")
	if rejection == null:
		return
	assert_eq(rejection.code, CODE_NULL_STATE, "(AZ)(v): the code is exactly \"null_state\"")
	assert_false(rejection.message.is_empty(), "(AZ)(v): every rejection carries a message")
	_reject(null, CancelDigCommand.new(0, 1), CODE_NULL_STATE, "(AZ)(v) through the gate")


## (AZ)(v) 2 — THE EMPTY ROSTER IS REJECTED `no_players`, AND THAT ORDERING IS LOAD-BEARING:
## `current_player_index()` still reads 0 on an empty roster, so a weaker precedence would let a
## 0-player state through into a state that owns nothing. (The (AV)/(AY)(v) reasoning, reproduced
## for the third command that needs it.)
func test_an_empty_roster_is_rejected_before_the_current_player_check() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, HexMap.new(MAP_RADIUS), 0)
	assert_eq(state.player_count(), 0, "sanity: the roster is empty")
	assert_eq(state.current_player_index(), 0, "sanity: the empty roster still reads index 0")
	for issuer: int in [0, 1, -1]:
		_reject(
			state,
			CancelDigCommand.new(issuer, 1),
			CODE_NO_PLAYERS,
			"(AZ)(v) 2: issuer %d on the empty roster" % issuer
		)


## (AZ)(v) 3 / §3.4 step 9 "**Action phase:** the player issues commands until End Turn" — only the
## CURRENT player may cancel, swept over §3.1's whole "2–4 players" band. An OUT-OF-RANGE issuer is
## `not_current_player` too, never a new code (the (AV) reasoning: the current index is always in
## range, so an out-of-range index can never be the current one). It precedes `no_such_unit`,
## `not_your_unit` AND `not_digging`: the unit named here is a legal, actively digging unit of the
## issuer's own.
func test_only_the_current_player_may_cancel_a_dig() -> void:
	for count: int in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		var state: GameState = _state_with(count)
		_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
		var theirs: int = _spawn(state, 1, ADJACENT_HEX)
		state.set_turn_position(1, 1)
		_dig(state, 1, theirs, TARGET_HEX)
		state.set_turn_position(1, 0)
		assert_eq(state.current_player_index(), 0, "sanity: the action phase belongs to player 0")
		assert_not_null(
			state.dig_site_of_digger(theirs), "sanity: player 1's unit really is digging"
		)
		_reject(
			state,
			CancelDigCommand.new(1, theirs),
			CODE_NOT_CURRENT_PLAYER,
			"§3.4 step 9: player 1 may not act during player 0's action phase (%d players)" % count
		)
		for bad_issuer: int in [-1, -99, count, 9999]:
			_reject(
				state,
				CancelDigCommand.new(bad_issuer, theirs),
				CODE_NOT_CURRENT_PLAYER,
				"(AV)/(AZ)(v) 3: issuer %d is outside the %d-player roster" % [bad_issuer, count]
			)


## (AZ)(v) 4 — `no_such_unit` covers 0 ("no unit" — (AX)(ii)), a negative id, a never-minted id AND
## a REMOVED id. It precedes `not_your_unit` trivially (there is no owner to compare) and
## `not_digging` (there is no job to look up).
func test_an_unknown_unit_id_is_rejected() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var minted: int = _spawn(state, 0, ADJACENT_HEX)
	assert_true(state.remove_unit(minted), "sanity: the unit is removed from the roster")
	for bad_id: int in [NO_UNIT_ID, -1, -99, minted, 9999]:
		_reject(
			state,
			CancelDigCommand.new(0, bad_id),
			CODE_NO_SUCH_UNIT,
			"(AZ)(v) 4: id %d names no unit in the roster" % bad_id
		)


## (AZ)(v) 5 — A UNIT BELONGING TO ANOTHER PLAYER IS `not_your_unit`, AND THAT ORDERING IS
## LOAD-BEARING IN BOTH DIRECTIONS: an enemy unit that is NOT digging must still be told
## `not_your_unit` (a weaker precedence would leak "that unit is idle" to its opponent), and an
## enemy unit that IS digging must be told `not_your_unit` rather than having its job cancelled.
func test_a_unit_owned_by_another_player_is_rejected() -> void:
	var idle: GameState = _state_with(MIN_PLAYERS)
	var their_idle_unit: int = _spawn(idle, 1, ADJACENT_HEX)
	assert_null(idle.dig_site_of_digger(their_idle_unit), "sanity: the enemy unit is NOT digging")
	_reject(
		idle,
		CancelDigCommand.new(0, their_idle_unit),
		CODE_NOT_YOUR_UNIT,
		"(AZ)(v): 5 precedes 6 — whose unit it is is decided before whether it is digging"
	)

	var busy: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(busy, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var their_digger: int = _spawn(busy, 1, ADJACENT_HEX)
	busy.set_turn_position(1, 1)
	_dig(busy, 1, their_digger, TARGET_HEX)
	busy.set_turn_position(1, 0)
	_reject(
		busy,
		CancelDigCommand.new(0, their_digger),
		CODE_NOT_YOUR_UNIT,
		"(AZ)(v) 5: player 0 may not cancel player 1's dig"
	)


## (AZ)(v) 6 — `not_digging` is THE ONE GENUINELY NEW CODE, and it is the exact inverse of
## `DigHexCommand`'s `already_digging`: the issuer's own unit is assigned to NO site
## (`dig_site_of_digger` is null). It also fires on a SECOND cancel of the same unit, which is what
## makes a replayed command log deterministic (§11.1).
func test_a_unit_that_is_not_digging_is_rejected() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var idle: int = _spawn(state, 0, ADJACENT_HEX)
	var digger: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	assert_null(state.dig_site_of_digger(idle), "sanity: the unit holds no dig job")
	_reject(
		state,
		CancelDigCommand.new(0, idle),
		CODE_NOT_DIGGING,
		"(AZ)(v) 6: a unit with no dig job has nothing to cancel"
	)

	_dig(state, 0, digger, TARGET_HEX)
	_accept(state, CancelDigCommand.new(0, digger), "the first cancel")
	_reject(
		state,
		CancelDigCommand.new(0, digger),
		CODE_NOT_DIGGING,
		"(AZ)(v) 6: a SECOND cancel of the same unit is deterministically refused"
	)


## §11.1 — validate is a PURE PREDICATE: asking does not move the state, whatever the answer, for
## an ACCEPTED cancel as well as for a rejected one.
func test_validate_never_mutates_the_state() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var mine: int = _spawn(state, 0, ADJACENT_HEX)
	var idle: int = _spawn(state, 0, THIRD_ADJACENT_HEX)
	var theirs: int = _spawn(state, 1, SECOND_ADJACENT_HEX)
	_dig(state, 0, mine, TARGET_HEX)
	var before: int = state.content_hash()
	var registry_before: String = _registry_signature(state)

	assert_null(
		CancelDigCommand.new(0, mine).validate(state), "§11.1: null means legal — this cancel is"
	)
	var probes: Array[CancelDigCommand] = [
		CancelDigCommand.new(1, mine),
		CancelDigCommand.new(0, NO_UNIT_ID),
		CancelDigCommand.new(0, theirs),
		CancelDigCommand.new(0, idle),
	]
	for command: CancelDigCommand in probes:
		assert_not_null(command.validate(state), "sanity: this probe is rejected")
	assert_eq(state.content_hash(), before, "§11.1: validate is a predicate, never a mutation")
	assert_eq(
		_registry_signature(state),
		registry_before,
		"§11.1: validate unassigns no digger and removes no site"
	)


## (AZ)(iv) — `no_map` IS DELIBERATELY NOT A CODE HERE, PINNED POSITIVELY. A cancel reads no
## terrain, so a mapless `GameState` (legal — §11.1/(AU); `add_dig_site` validates nothing about
## the map, (AY)(viii)) whose unit is assigned to a site CANCELS SUCCESSFULLY and emits its event.
## Its negative twin is scan S7, which forbids the tokens `no_map` and `state.map` outright.
func test_a_mapless_state_cancels_successfully() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MIN_PLAYERS)
	assert_null(state.map, "sanity: the fixture is mapless")
	var digger: int = _spawn(state, 0, ADJACENT_HEX)
	var site: DigSite = state.add_dig_site(TARGET_HEX, 0, FIXTURE_TURNS)
	assert_not_null(site, "(AY)(viii): the registry validates nothing about the map")
	if site == null:
		return
	assert_true(site.add_digger(digger), "fixture: the unit is assigned to the mapless site")

	var recorder: BusRecorder = _accept(
		state, CancelDigCommand.new(0, digger), "(AZ)(iv): a mapless cancel"
	)
	assert_eq(recorder.calls, 1, "§13.6: the mapless cancel emits exactly one event")
	assert_null(state.dig_site(TARGET_HEX), "(AZ)(ii): the last digger left, so the site is gone")


# =============================================================================================
# C. THE ACCEPTED PATH — the four rules §4.2 does not print ((AZ)(i)–(iv))
# =============================================================================================

## (AZ)(ii) — THE LAST DIGGER LEAVING REMOVES THE SITE, AND ITS PROGRESS IS LOST. §4.2 line 186's
## Dense Granite site is created at 4 total / 4 remaining worker-turns; cancelling its ONLY digger
## removes the site from the registry entirely, so `dig_site`, `dig_site_hexes` and
## `dig_site_of_digger` all agree that nothing is left. Recorded reasoning (Land logs it as (AZ)):
## an ownerless site that KEPT its progress would be permanently un-startable by any other player
## (`DigHexCommand` rejects `site_not_yours` on an owner mismatch) and §5.3's Mining Zones re-issue
## "ordinary Dig commands each turn", so an orphan site is a DEADLOCK; §1.1 pillar 1 ("Exploration
## IS excavation") wants a dig to be a commitment, not a free undo.
func test_cancelling_the_only_digger_removes_the_site_and_loses_its_progress() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var digger: int = _spawn(state, 0, ADJACENT_HEX)
	_dig(state, 0, digger, TARGET_HEX)

	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the dig order created a site")
	if site == null:
		return
	assert_eq(site.total_turns(), FIXTURE_TURNS, "§4.2 line 186: \"Dense Granite | 4\"")
	assert_eq(site.remaining_turns(), FIXTURE_TURNS, "§4.2: a fresh site has all four left")

	var recorder: BusRecorder = _accept(state, CancelDigCommand.new(0, digger), "the only digger")
	assert_null(state.dig_site(TARGET_HEX), "(AZ)(ii): the last digger left — the site is REMOVED")
	assert_eq(
		state.dig_site_hexes(),
		[] as Array[Vector2i],
		"(AZ)(ii): the registry holds no site at all afterwards"
	)
	assert_null(
		state.dig_site_of_digger(digger), "(AZ)(ii): the unit holds no dig job afterwards"
	)
	assert_eq(
		state.map.get_terrain_type(TARGET_HEX),
		FIXTURE_TERRAIN_ID,
		"§3.4 step 4: a cancel NEVER turns a hex into Cave — that is SLICE 4"
	)

	assert_eq(recorder.calls, 1, "§13.6: exactly ONE event per accepted cancel")
	assert_eq(recorder.cancelled.size(), 1, "§13.6: and it is a DigCancelledEvent")
	if recorder.cancelled.is_empty():
		return
	var cancelled: DigCancelledEvent = recorder.cancelled[0]
	assert_eq(cancelled.type, DigCancelledEvent.TYPE_NAME, "§11.1: the type is dig_cancelled")
	assert_eq(cancelled.player_index, 0, "(AZ)(i): the event carries the cancelling player")
	assert_eq(cancelled.unit_id, digger, "(AZ)(i): the event carries the unassigned unit")
	assert_eq(cancelled.hex, TARGET_HEX, "(AZ)(i): the event carries the site's hex")
	assert_eq(
		cancelled.remaining_turns,
		FIXTURE_TURNS,
		"(AZ)(ii): the work that was LOST — the site's remaining worker-turns at cancellation"
	)
	assert_true(cancelled.site_removed, "(AZ)(ii): the last digger left, so the site was removed")


## (AZ)(iii) — A NON-LAST CANCEL LEAVES THE SITE ALIVE AND ITS PROGRESS UNCHANGED. §4.2 line 197
## permits two simultaneous diggers; cancelling one of them removes exactly that one assignment and
## touches nothing else — the owner, the §4.2 total and the remaining worker-turns are all still 4,
## and `digger_ids()` is a fresh ASCENDING list holding only the survivor (§11.1 line 707).
func test_cancelling_one_of_two_diggers_leaves_the_site_and_its_progress_untouched() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	assert_lt(first, second, "sanity: ids ascend in spawn order (AX)")
	_dig(state, 0, first, TARGET_HEX)
	_dig(state, 0, second, TARGET_HEX)
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the site exists")
	if site == null:
		return
	assert_eq(site.digger_ids(), [first, second] as Array[int], "sanity: both units are assigned")

	var recorder: BusRecorder = _accept(state, CancelDigCommand.new(0, first), "the first digger")
	assert_true(
		is_same(state.dig_site(TARGET_HEX), site), "(AZ)(iii): the SAME site object survives"
	)
	assert_eq(
		state.dig_site_hexes(), [TARGET_HEX] as Array[Vector2i], "(AZ)(iii): the site is still there"
	)
	assert_eq(site.digger_ids(), [second] as Array[int], "(AZ)(iii): exactly ONE digger left")
	assert_eq(site.owner_index(), 0, "(AZ)(iii): the ordering player is unchanged")
	assert_eq(site.total_turns(), FIXTURE_TURNS, "(AZ)(iii): §4.2's total is unchanged")
	assert_eq(
		site.remaining_turns(),
		FIXTURE_TURNS,
		"(AZ)(iii): a PARTIAL cancel spends and refunds nothing — the progress is UNCHANGED"
	)
	assert_null(state.dig_site_of_digger(first), "(AZ)(iii): the cancelled unit is free")
	assert_true(
		is_same(state.dig_site_of_digger(second), site), "(AZ)(iii): the survivor still digs here"
	)

	assert_eq(recorder.cancelled.size(), 1, "§13.6: exactly ONE event for the partial cancel too")
	if recorder.cancelled.is_empty():
		return
	var cancelled: DigCancelledEvent = recorder.cancelled[0]
	assert_eq(cancelled.unit_id, first, "(AZ)(iii): the event names the CANCELLED unit")
	assert_eq(cancelled.hex, TARGET_HEX, "(AZ)(iii): the event names the site's hex")
	assert_eq(cancelled.remaining_turns, FIXTURE_TURNS, "(AZ)(iii): the work left is unchanged")
	assert_false(cancelled.site_removed, "(AZ)(iii): the site SURVIVED — a digger remains")

	_accept(state, CancelDigCommand.new(0, second), "the last digger")
	assert_null(state.dig_site(TARGET_HEX), "(AZ)(ii): now the LAST digger left — the site is gone")


## §4.2 line 197 "**max 2 simultaneous diggers per hex**" — THE CAP ROUND TRIP. Two diggers fill
## the site, a third `DigHex` is refused `dig_site_full`, a cancel frees the slot, and the third
## order is then ACCEPTED and JOINS (`site_created == false`). This proves a cancel really releases
## a slot AND that the cap is still read from §12.1 data through `DigRules` on both sides.
func test_cancelling_frees_a_slot_under_the_max_digger_cap() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	var third: int = _spawn(state, 0, THIRD_ADJACENT_HEX)
	_dig(state, 0, first, TARGET_HEX)
	_dig(state, 0, second, TARGET_HEX)

	var full: CommandError = DigHexCommand.new(0, third, TARGET_HEX, _dig_rules()).execute(
		state, null
	)
	assert_not_null(full, "§4.2 line 197: the third simultaneous digger is refused")
	if full == null:
		return
	assert_eq(
		full.code,
		&"dig_site_full",
		"§4.2 line 197: max %d simultaneous diggers per hex" % MAX_DIGGERS_PER_HEX
	)

	_accept(state, CancelDigCommand.new(0, first), "the cancel that frees a slot")

	var bus: EventBus = EventBus.new()
	var recorder: BusRecorder = _subscribed(bus)
	var joined: CommandError = DigHexCommand.new(0, third, TARGET_HEX, _dig_rules()).execute(
		state, bus
	)
	assert_null(joined, "(AZ)(iii): the freed slot lets the third unit join")
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the site is still there")
	if site == null:
		return
	assert_eq(
		site.digger_ids(),
		[second, third] as Array[int],
		"§11.1 line 707: the diggers are the survivor and the newcomer, ASCENDING"
	)
	assert_eq(
		site.remaining_turns(), FIXTURE_TURNS, "(AZ)(iii): the round trip changed no progress"
	)
	assert_eq(recorder.calls, 1, "§13.6: the join emits exactly one event")
	assert_eq(recorder.types, ["dig_started"] as Array[String], "§13.6: and it is a dig_started")


## §13.6/(AY)(x) — EXACTLY ONE `DigCancelledEvent` PER ACCEPTED CANCEL AND NOTHING ELSE ON THE BUS
## (the recorder is subscribed to `dig_cancelled`, `dig_started` AND `turn_ended`), `execute`
## returns null on success, and `execute(state, null)` is a legal SILENT headless drop.
func test_exactly_one_event_reaches_the_bus_and_a_null_bus_is_legal() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var digger: int = _spawn(state, 0, ADJACENT_HEX)
	_dig(state, 0, digger, TARGET_HEX)

	var bus: EventBus = EventBus.new()
	var recorder: BusRecorder = _subscribed(bus)
	var rejection: CommandError = CancelDigCommand.new(0, digger).execute(state, bus)
	assert_null(rejection, "§11.1: an accepted command returns null from the gate")
	assert_eq(recorder.calls, 1, "§13.6: exactly one event, and NOTHING else, reaches the bus")
	assert_eq(
		recorder.types,
		["dig_cancelled"] as Array[String],
		"§13.6: the ONLY event this Command emits is dig_cancelled"
	)

	var headless: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(headless, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var quiet_digger: int = _spawn(headless, 0, ADJACENT_HEX)
	_dig(headless, 0, quiet_digger, TARGET_HEX)
	assert_null(
		CancelDigCommand.new(0, quiet_digger).execute(headless, null),
		"(AV): `bus == null` is a legal, silent, headless drop"
	)
	assert_null(headless.dig_site(TARGET_HEX), "(AZ)(ii): the cancel still happened")


## (AZ)(iii) — TWO SITES ARE INDEPENDENT: cancelling a digger on one site touches neither the other
## site's diggers nor its §4.2 total or remaining worker-turns.
func test_cancelling_on_one_site_leaves_the_other_untouched() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	_set_terrain(state, OTHER_TARGET_HEX, OTHER_TERRAIN_ID)
	var here: int = _spawn(state, 0, ADJACENT_HEX)
	var there: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_dig(state, 0, here, TARGET_HEX)
	_dig(state, 0, there, OTHER_TARGET_HEX)

	_accept(state, CancelDigCommand.new(0, here), "the cancel on the first site")
	assert_null(state.dig_site(TARGET_HEX), "(AZ)(ii): the cancelled site is gone")
	var survivor: DigSite = state.dig_site(OTHER_TARGET_HEX)
	assert_not_null(survivor, "(AZ)(iii): the other site is untouched")
	if survivor == null:
		return
	assert_eq(survivor.total_turns(), OTHER_TURNS, "§4.2 line 185: \"Hard Rock | 2\" is unchanged")
	assert_eq(survivor.remaining_turns(), OTHER_TURNS, "(AZ)(iii): its progress is unchanged")
	assert_eq(survivor.digger_ids(), [there] as Array[int], "(AZ)(iii): its digger is unchanged")
	assert_eq(
		state.dig_site_hexes(),
		[OTHER_TARGET_HEX] as Array[Vector2i],
		"(AY)(viii): exactly one site remains, in the canonical order"
	)


## §12.7 line 1015 NEGATIVE PIN — "worker | dig\_mult | Can Dig/Build; dig-speed multiplier" is
## DATA and `data/units/*.json` is M6, so `type_id` is OPAQUE here and ANY unit type may be
## cancelled. Pinned positively so nobody adds a `type_id == "worker"` whitelist (§13.5's canary).
func test_any_unit_type_may_be_cancelled() -> void:
	for type_id: String in [UNIT_TYPE_ID, OTHER_UNIT_TYPE_ID, "creep_rat", "x"]:
		var state: GameState = _state_with(MIN_PLAYERS)
		_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
		var spawned: UnitState = state.spawn_unit(0, type_id, ADJACENT_HEX, UNIT_MAX_HP)
		assert_not_null(spawned, "sanity: the spawn is accepted")
		if spawned == null:
			return
		_dig(state, 0, spawned.unit_id(), TARGET_HEX)
		_accept(
			state,
			CancelDigCommand.new(0, spawned.unit_id()),
			"§12.7: worker-ness is a TRAIT (data) — \"%s\" may cancel at this slice" % type_id
		)


## §11.1 "a match is fully described by (seed, command\_log)" — a Command is an IMMUTABLE value
## object. The SAME object executed on two identically-built states yields identical hashes, the
## second execution on the same state is deterministically `not_digging`, and `self` is unchanged.
func test_the_same_command_object_is_immutable_and_replays_deterministically() -> void:
	var digger_id: int = 1
	var command: CancelDigCommand = CancelDigCommand.new(0, digger_id)
	var first: GameState = _dug_state(digger_id)
	var second: GameState = _dug_state(digger_id)
	assert_eq(
		first.content_hash(), second.content_hash(), "sanity: the two fixtures start identical"
	)
	assert_null(command.execute(first, null), "sanity: the first execution is accepted")
	assert_null(command.execute(second, null), "sanity: the same object is accepted on a 2nd state")
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: the same command on two identical states yields the same state"
	)

	var repeat: CommandError = command.execute(first, null)
	assert_not_null(repeat, "(AZ)(v) 6: re-issuing the same cancel is refused")
	if repeat == null:
		return
	assert_eq(repeat.code, CODE_NOT_DIGGING, "(AZ)(v) 6: deterministically `not_digging`")
	assert_eq(command.player_index(), 0, "§11.1: validate/apply never mutate the command")
	assert_eq(command.unit_id(), digger_id, "§11.1: validate/apply never mutate the command")


## §11.1 line 707 — A CANCEL IS NOT AN ERASER: a state that dug and then cancelled everything
## hashes like a state that never dug at all, because (AY)(ix) records that a dig site has NO
## dangling identity beyond its hex, and (AZ)(ii) throws the progress away. Asserted POSITIVELY so
## the divergence from (AX)'s `_next_unit_id` cannot drift silently.
func test_dig_then_cancel_everything_hashes_like_never_dug() -> void:
	var dug: GameState = _undug_state(1)
	var untouched: GameState = _undug_state(1)
	var before: int = untouched.content_hash()
	assert_eq(dug.content_hash(), before, "sanity: the two fixtures start identical")
	_dig(dug, 0, 1, TARGET_HEX)
	assert_ne(dug.content_hash(), before, "§11.1: ordering a dig IS a state change")
	assert_null(CancelDigCommand.new(0, 1).execute(dug, null), "sanity: the cancel is accepted")
	assert_eq(
		dug.content_hash(),
		before,
		"(AY)(ix)/(AZ)(ii): add-then-remove-every-site hashes like never-added — a dig site has "
			+ "no identity beyond its hex, and the cancelled progress is LOST"
	)


# =============================================================================================
# D. §13.6's EVENTS CLAUSE, PINNED IN BOTH DIRECTIONS (LIVE, as (AY)(x) established)
# =============================================================================================

## §13.6 IN BOTH DIRECTIONS — "events emitted for **every** state change" AND never an event
## without one. `apply()` is called DIRECTLY here (bypassing the gate, which is why this is the one
## place it may be) on a unit assigned to NO site: nothing changes and the returned `Array[Event]`
## is EMPTY.
func test_apply_on_a_unit_with_no_site_changes_nothing_and_emits_nothing() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	var idle: int = _spawn(state, 0, ADJACENT_HEX)
	var digger: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_dig(state, 0, digger, TARGET_HEX)
	var before: int = state.content_hash()
	var registry_before: String = _registry_signature(state)

	var events: Array[Event] = CancelDigCommand.new(0, idle).apply(state)
	assert_eq(events.size(), 0, "§13.6: no state change means NO event")
	assert_eq(state.content_hash(), before, "§11.1: the state is byte-identical")
	assert_eq(
		_registry_signature(state),
		registry_before,
		"§13.6: the other site's diggers and progress are untouched"
	)

	var unknown: Array[Event] = CancelDigCommand.new(0, 9999).apply(state)
	assert_eq(unknown.size(), 0, "§13.6: an unknown unit changes nothing, so it emits nothing")
	assert_eq(state.content_hash(), before, "§11.1: still byte-identical")


# =============================================================================================
# E. §3.4 NEGATIVE PINS — step 4's tick is SLICE 4 and must NOT be pulled forward
# =============================================================================================

## §3.4 step 4 NEGATIVE PIN — "Dig progress ticks; completed digs apply yields, then **Breach
## checks** (§4.6), then **Noise pings** (§4.8)" IS STILL NOT IMPLEMENTED. After any number of
## accepted EndTurns AND cancels, every surviving site's `remaining_turns()` is UNCHANGED, every
## `resource_ids()` is still EMPTY, the target hex still carries its §4.2 Solid terrain (a cancel
## NEVER turns a hex into Cave) and the one seeded stream has drawn NOTHING.
func test_ending_turns_and_cancelling_ticks_nothing_and_applies_no_yield() -> void:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	_set_terrain(state, OTHER_TARGET_HEX, OTHER_TERRAIN_ID)
	var first: int = _spawn(state, 0, ADJACENT_HEX)
	var second: int = _spawn(state, 0, SECOND_ADJACENT_HEX)
	_dig(state, 0, first, TARGET_HEX)
	_dig(state, 0, second, TARGET_HEX)

	for k: int in range(3 * MIN_PLAYERS):
		var rejection: CommandError = EndTurnCommand.new(state.current_player_index()).execute(
			state, null
		)
		assert_null(rejection, "sanity: EndTurn %d is accepted" % k)

	_accept(state, CancelDigCommand.new(0, first), "a cancel between EndTurn rounds")

	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "(AZ)(iii): one digger remains, so the site remains")
	if site == null:
		return
	assert_eq(
		site.remaining_turns(),
		FIXTURE_TURNS,
		"§3.4 step 4: the dig TICK is a LATER slice — no worker-turn has been spent"
	)
	assert_eq(site.digger_ids(), [second] as Array[int], "(AZ)(iii): only the cancelled unit left")
	assert_eq(
		state.map.get_terrain_type(TARGET_HEX),
		FIXTURE_TERRAIN_ID,
		"§3.4 step 4: the hex-becomes-Cave transition is a LATER slice"
	)
	assert_eq(
		state.map.get_terrain_type(OTHER_TARGET_HEX),
		OTHER_TERRAIN_ID,
		"§3.4 step 4: and a cancel changes no terrain anywhere"
	)
	for index: int in range(MIN_PLAYERS):
		var holder: PlayerState = state.player(index)
		assert_not_null(holder, "sanity: player(%d) exists" % index)
		if holder == null:
			return
		assert_eq(
			holder.resource_ids(),
			[] as Array[String],
			"§3.4 step 4: a cancel refunds NOTHING — player %d still holds nothing" % index
		)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1: nothing in this slice is random — the single seeded stream must not advance"
	)


# =============================================================================================
# F. MECHANICAL SOURCE SCANS on scripts/sim/commands/cancel_dig_command.gd
#    Written FRESH for this file — it inherits NOTHING from the other scan suites. Comment
#    stripping is LOAD-BEARING: the header quotes §4.2's numbers and the rules it implements.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			CANCEL_DIG_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % CANCEL_DIG_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % CANCEL_DIG_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R), and "Renderer/UI subscribe;
## the sim never calls them".
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				CANCEL_DIG_PATH, banned
			]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [
				CANCEL_DIG_PATH, banned
			]
		)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % CANCEL_DIG_PATH
	)


## S3 (AZ)(i)/(AZ)(iv) — THE COMMAND READS NEITHER DATA NOR THE MAP. It takes no `DigRules` (a
## cancel needs no dig time, no yield and no cap), loads nothing (the M1-T9 no-second-loader rule),
## and never consults `state.map` — which is exactly why `no_map` is NOT one of its codes. Calling
## a premature `DigRules` member (the "Dig 2x" halving, the yield accessors) is forbidden too.
func test_source_reads_neither_the_rules_nor_the_map() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
	for banned: String in FORBIDDEN_DEPENDENCY_TOKENS:
		assert_false(
			code.contains(banned),
			"(AZ)(i)/(AZ)(iv): a cancel reads no data and no terrain — %s must not name %s" % [
				CANCEL_DIG_PATH, banned
			]
		)


## S4 (AZ)(i) — `_init` TAKES EXACTLY TWO PARAMETERS: the issuing player and the unit. A hex
## parameter would contradict (AY)(iv)'s one-job-per-unit, and a `DigRules` parameter would
## contradict S3.
func test_the_constructor_takes_exactly_two_parameters() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
	var signature: RegEx = RegEx.new()
	assert_eq(
		signature.compile("func\\s+_init\\s*\\(([^)]*)\\)"),
		OK,
		"sanity: the constructor-signature pattern compiles"
	)
	var found: RegExMatch = signature.search(code)
	assert_not_null(found, "(AZ)(i): %s must declare an _init" % CANCEL_DIG_PATH)
	if found == null:
		return
	var parameters: PackedStringArray = found.get_string(1).split(",", false)
	assert_eq(
		parameters.size(),
		2,
		"(AZ)(i): _init takes exactly (player_index, unit_id) — found \"%s\"" % found.get_string(1)
	)


## S5 (AV)/(AU)(iv)/§13.5 — the Command authors its OWN six codes at its own call sites, authors NO
## other command's, and there is NO enum and NO const list of codes anywhere in engine code.
func test_source_authors_exactly_its_own_six_rejection_codes() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
	assert_eq(AUTHORED_CODES.size(), 6, "sanity: (AZ)(v) lists six codes in precedence order")
	for authored: StringName in AUTHORED_CODES:
		assert_true(
			code.contains(String(authored)),
			"(AZ)(v): %s authors \"%s\" at its own call site" % [CANCEL_DIG_PATH, String(authored)]
		)
	for foreign: String in FOREIGN_CODES:
		assert_false(
			code.contains(foreign),
			"(AZ)(v): \"%s\" belongs to another Command — %s must not author it" % [
				foreign, CANCEL_DIG_PATH
			]
		)
	assert_false(code.contains("enum "), "(AV): rejection codes are never an enum")
	assert_false(
		code.contains("dig_hex"),
		"(AU)(iv): the printed command list lives in the TEST — %s names no other command" % [
			CANCEL_DIG_PATH
		]
	)
	assert_false(
		code.contains("end_turn"),
		"(AU)(iv): the printed command list lives in the TEST — %s names no other command" % [
			CANCEL_DIG_PATH
		]
	)


## S6 (T)/(AH)/(AU)(iv)/§13.5 — NO TERRAIN, RESOURCE, TRAIT, HOUSING OR FACTION WHITELIST. Adding
## content must stay a DATA edit (§13.5's M6 canary). Run on the COMMENT-STRIPPED, lower-cased
## source (the (AX) incidental-substring lesson).
func test_source_carries_no_terrain_resource_or_trait_whitelist() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
	for id: String in SOLID_TERRAIN_IDS:
		assert_false(
			code.contains(id),
			"(T)/(AH): §4.2's terrain ids live in data — %s must not name \"%s\"" % [
				CANCEL_DIG_PATH, id
			]
		)
	for id: String in RESOURCE_IDS:
		assert_false(
			code.contains(id),
			"(AU)(iv): resource ids are opaque data — %s must not name \"%s\"" % [
				CANCEL_DIG_PATH, id
			]
		)
	for token: String in VOCABULARY_TOKENS:
		assert_false(
			code.contains(token),
			"§12.7/§5.2/§7: traits, housing and factions are DATA — %s must not name \"%s\"" % [
				CANCEL_DIG_PATH, token
			]
		)


## S7 §13.6 "constants read from data, not code" — NOT ONE §4.2 NUMBER IN THE COMMAND. The only
## standalone numerals permitted are 0 and 1; 2, 3, 4, 10, 15, 25, 60, 120, 150 and 250 are all
## forbidden, so neither a dig time nor §4.2 line 197's max-digger cap can appear here ((AY)(vi)).
func test_source_hard_codes_no_gdd_number() -> void:
	var code: String = _code_text(CANCEL_DIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % CANCEL_DIG_PATH)
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
			CANCEL_DIG_PATH, "" if hit == null else hit.get_string()
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
				str(PERMITTED_NUMERALS), CANCEL_DIG_PATH, found.get_string()
			]
		)


## S8 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: a MISSING member fails
## instead of passing vacuously and an EXTRA member (a `hex()` accessor, a `to_dict`, a mutable
## setter) fails too. ZERO public vars and ZERO public consts, and every declaration in the file is
## statically typed `var x: T = ...` (§11.3 "static typing everywhere").
func test_public_api_is_exactly_the_five_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(CANCEL_DIG_PATH, public_functions, undocumented)

	var command: CancelDigCommand = CancelDigCommand.new(0, 1)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, CANCEL_DIG_PATH]
		)
		assert_true(
			command.has_method(required),
			"§11.2: %s must be callable on a CancelDigCommand instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			CANCEL_DIG_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(CANCEL_DIG_PATH),
		REQUIRED_PUBLIC_VARS,
		"(AZ)(i): %s declares ZERO public vars — it is an immutable value object" % CANCEL_DIG_PATH
	)
	assert_eq(
		_collect_public_consts(CANCEL_DIG_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.6: %s declares ZERO public consts" % CANCEL_DIG_PATH
	)
	assert_eq(
		_untyped_declarations(CANCEL_DIG_PATH),
		[] as Array[String],
		"§11.3: static typing everywhere — every `var` in %s must be `var x: T = ...`" % [
			CANCEL_DIG_PATH
		]
	)


## S9 §11.1/§11.2 — CancelDigCommand is a pure [RefCounted] in `scripts/sim/commands/`. Asserted
## through get_class() — `is Node` would be a PARSE ERROR here (M0-T2 item 11).
func test_cancel_dig_command_is_a_pure_refcounted_in_scripts_sim_commands() -> void:
	assert_true(
		FileAccess.file_exists(CANCEL_DIG_PATH),
		"§11.2: CancelDigCommand belongs at %s" % CANCEL_DIG_PATH
	)
	assert_eq(
		CancelDigCommand.new(0, 1).get_class(),
		"RefCounted",
		"§11.1: CancelDigCommand must be a pure RefCounted"
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


## The injected, already-loaded §4.2 dig table (M2-T3), used ONLY to place the dig orders this
## suite then cancels. `CancelDigCommand` itself must never see it ((AZ)(i), scan S3).
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


## Places a dig order through THE ONE GATE (M2-T5's `DigHexCommand`), asserting it is accepted, so
## every cancel fixture in this suite is built the way a real match builds one.
func _dig(state: GameState, player: int, digger: int, where: Vector2i) -> void:
	var rejection: CommandError = DigHexCommand.new(player, digger, where, _dig_rules()).execute(
		state, null
	)
	assert_null(
		rejection,
		"fixture: the dig order must be accepted (got \"%s\")" % [
			"" if rejection == null else String(rejection.code)
		]
	)


## A radius-2 fixture whose FIRST minted unit id is `expected_id`, standing adjacent to a §4.2
## Dense Granite target, with NO dig ordered yet — built identically every time, so two of them
## must hash identically.
func _undug_state(expected_id: int) -> GameState:
	var state: GameState = _state_with(MIN_PLAYERS)
	_set_terrain(state, TARGET_HEX, FIXTURE_TERRAIN_ID)
	assert_eq(
		_spawn(state, 0, ADJACENT_HEX), expected_id, "fixture: the digger is id %d" % expected_id
	)
	return state


## [method _undug_state] with the dig order already placed through the ONE gate.
func _dug_state(expected_id: int) -> GameState:
	var state: GameState = _undug_state(expected_id)
	_dig(state, 0, expected_id, TARGET_HEX)
	return state


## Subscribes a fresh recorder to ALL THREE concrete event types, so "exactly one DigCancelledEvent
## and NOTHING else" is checkable rather than assumed.
func _subscribed(bus: EventBus) -> BusRecorder:
	var recorder: BusRecorder = BusRecorder.new()
	bus.subscribe(DigCancelledEvent.TYPE_NAME, recorder.on_event)
	bus.subscribe(DigStartedEvent.TYPE_NAME, recorder.on_event)
	bus.subscribe(TurnEndedEvent.TYPE_NAME, recorder.on_event)
	return recorder


## Executes `command` through the ONE gate with a recording bus, asserting it is ACCEPTED, and
## hands the recorder back so the caller can pin the emitted event.
func _accept(state: GameState, command: CancelDigCommand, why: String) -> BusRecorder:
	var bus: EventBus = EventBus.new()
	var recorder: BusRecorder = _subscribed(bus)
	var rejection: CommandError = command.execute(state, bus)
	assert_null(
		rejection,
		"%s: the cancel must be ACCEPTED (got \"%s\")" % [
			why, "" if rejection == null else String(rejection.code)
		]
	)
	return recorder


## Executes `command` through the ONE gate with a recording bus, asserting it is REJECTED with
## exactly `expected_code`, that it EMITS NOTHING, and that the state is byte-identical afterwards
## with the whole dig-site registry (sites, owners, totals, progress and diggers) untouched.
## `state` may be null (the `null_state` probe).
func _reject(
	state: GameState,
	command: CancelDigCommand,
	expected_code: StringName,
	why: String
) -> void:
	var before: int = 0
	var registry_before: String = ""
	if state != null:
		before = state.content_hash()
		registry_before = _registry_signature(state)

	var bus: EventBus = EventBus.new()
	var recorder: BusRecorder = _subscribed(bus)
	var rejection: CommandError = command.execute(state, bus)

	assert_not_null(rejection, "%s: the cancel must be REJECTED" % why)
	if rejection == null:
		return
	assert_eq(
		rejection.code, expected_code, "%s: the code is exactly \"%s\"" % [why, String(expected_code)]
	)
	assert_false(rejection.message.is_empty(), "(AZ)(v): every rejection carries a message")
	assert_eq(recorder.calls, 0, "§13.6: a rejected cancel changes nothing, so it emits NOTHING")
	if state == null:
		return
	assert_eq(state.content_hash(), before, "§11.1: a rejected command leaves the state identical")
	assert_eq(
		_registry_signature(state),
		registry_before,
		"(AZ)(v): a rejected cancel removes no site and unassigns no digger"
	)


## The WHOLE dig-site registry as one comparable String, in `dig_site_hexes()`'s canonical order:
## per site the hex, the owner, the §4.2 total, the remaining worker-turns and the ascending digger
## ids. Anything a cancel could touch is in here.
func _registry_signature(state: GameState) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for where: Vector2i in state.dig_site_hexes():
		var site: DigSite = state.dig_site(where)
		if site == null:
			parts.append("%s=missing" % str(where))
			continue
		parts.append(
			"%s:o%d:t%d:r%d:%s" % [
				str(where),
				site.owner_index(),
				site.total_turns(),
				site.remaining_turns(),
				str(site.digger_ids()),
			]
		)
	return "|".join(parts)


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


## Every `var` declaration in a source file that is NOT of the form `var name: Type = ...`
## (§11.3 "static typing everywhere" — the `untyped_declaration`/`inferred_declaration` gate).
func _untyped_declarations(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _code_text(path).split("\n"):
		var stripped: String = raw_line.strip_edges()
		if not stripped.begins_with("var "):
			continue
		var colon_at: int = stripped.find(":")
		var equals_at: int = stripped.find("=")
		if colon_at == -1 or equals_at == -1 or colon_at > equals_at or equals_at == colon_at + 1:
			out.append(stripped)
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
