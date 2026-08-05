## DigTick — GDD §3.4 step 4, the rule that finally MOVES a dig number. §3.4 (Order of Operations,
## **binding; implement exactly**), §4.2 (Hex Types — the dig-time and yield table), §5.1
## (stockpiles), §11.1 (Layered Design, **binding**), §11.2, §11.3, §12.1, §13.2 tier 1, §13.4,
## §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §3.4  (line 148, step 4): "Dig progress ticks; completed digs apply yields, then **Breach
##         checks** (§4.6), then **Noise pings** (§4.8)." — under the heading "**Per player, at
##         start of their turn:**" (line 141).
##   §4.2  (lines 184–193) the Solid table, column by column — `Solid type | Dig time
##         (worker-turns) | Yield on dig`:
##             Soft Dirt          | 1 | +1 Food (spores)
##             Hard Rock          | 2 | +2 Stone
##             Dense Granite      | 4 | +4 Stone
##             Artificial Granite | 3 (owner: 1) | +2 Stone
##             Rubble             | 1 | +1 Stone
##             Gold Vein          | 2 | +25 Gold lump + node   (Node: stock 250, 10/turn)
##             Iron Vein          | 2 | +10 Iron lump + node   (Node: stock 120, 6/turn)
##             Magestone Crust    | 2 | +15 Magestone lump + node (Node: stock 150, 6/turn)
##             Mithril Seam       | 4 | +10 Mithril lump + node (Node: stock 60, 3/turn)
##   §4.2  (line 197): "Dig time is **total worker-turns**; multiple workers on adjacent hexes may
##         work the same target (**max 2 simultaneous diggers per hex**). \"Dig 2×\" halves
##         remaining time (round up)." — "TOTAL worker-turns" is why N diggers spend N per tick.
##   §4.2  (Cave hexes table, first row): "Plain floor | —" — the Cave feature a completed dig
##         leaves behind, and therefore the value of the new §12.1 leaf `dig.cave_terrain_id`.
##   §5.1  (line 288): "No storage caps. Stockpiles are **per-player integers**."
##   §11.1 (line 703): "**Sim Core** ... **No Node, no Scene Tree, no engine singletons, no
##         rendering, no** **randi()** — the core must run headless byte-identically."
##
## `docs/decisions.md` was re-scanned this iteration: the only logged §12.1/§4.2 overrides are
## **(AU)(i)** (`dig_yields.artificial_granite.stone = 2`, which AGREES with §4.2's printed
## "+2 Stone" row and is transcribed as 2 below) and **(AW)(i)** (the `dig` group binding terrain
## ids to §12.1 keys). **No logged override moves any printed §4.2 dig time or yield**, so the
## printed table governs unamended. Binding prior resolutions: **(AY)** (the injected `DigRules`,
## the §7.1 ownership seam answering false, one owner per site), **(AZ)** (a site with no digger
## left is removed by the CANCEL rule, which is why zero-digger sites are unreachable in practice
## but still pinned here for totality), **(AX)** (unit ids from 1, never reused).
##
## The rules §4.2 does NOT print, resolved here and to be lettered **(BA)** by Land ((AU)–(AZ) are
## cross-referenced by many files and must NOT be renumbered):
##   (BA)(i)   step 4 runs inside `EndTurnCommand.apply()` AFTER the §3.3 rotation, for the
##             INCOMING player — the only existing trigger, and "at start of their turn" read
##             literally. Player 0's FIRST turn of a match therefore runs no start-of-turn steps.
##   (BA)(ii)  only sites whose `owner_index()` equals the incoming player tick, so each site
##             ticks exactly once per full round.
##   (BA)(iii) a site spends `digger_ids().size()` worker-turns per tick (§4.2 line 197's TOTAL
##             worker-turns), clamped at 0 by `DigSite.set_remaining_turns`.
##   (BA)(iv)  completion = remaining reaches 0 after the decrement: the yield goes to the SITE'S
##             OWNER, the hex becomes `dig.cave_terrain_id`, the site is removed and its diggers
##             are freed IMPLICITLY (assignment IS site membership — no `UnitState` is mutated).
##   (BA)(v)   TWO events, `dig_progressed` then `dig_completed`, the completion carrying the
##             yielded ids+amounts, the freed diggers and the new terrain id so each sub-change is
##             observable (§13.6) without three redundant events.
##   (BA)(vi)  an unconfigured/absent `DigRules` runs NO step-4 pass (the `DigHexCommand`
##             unconfigured precedent), pinned in BOTH directions.
##   (BA)(vii) vein NODE state (stock/rate) and Extractors stay deferred ((AW) item 4): the LUMP
##             applies and the node is dropped when the hex flips to plain floor.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/systems/dig_tick.gd`.
extends GutTest

const DIG_TICK_PATH: String = "res://scripts/sim/systems/dig_tick.gd"
const RULESET_PATH: String = "res://data/ruleset.json"

## §12.6's example seed, so this file's seed comes from the GDD rather than from invention.
const GOLDEN_SEED: int = 1337

## §4.1 — a small disc; the real radii (24/32/40) live in `data/mapgen/*.json` and never here.
const MAP_RADIUS: int = 2

## §4.1 "axial coordinates (q, r)". The target and two of its six neighbours (E and NE).
const TARGET: Vector2i = Vector2i(0, 0)
const DIGGER_HEX_A: Vector2i = Vector2i(1, 0)
const DIGGER_HEX_B: Vector2i = Vector2i(1, -1)

## Three sites laid out so the CANONICAL order (r ascending, then q ascending) differs from
## `Vector2i`'s default `<` (which sorts q/x first):
##   canonical: (-1,0), (1,0), (0,1)      default `<`: (-1,0), (0,1), (1,0)
const ORDER_SITE_1: Vector2i = Vector2i(-1, 0)
const ORDER_SITE_2: Vector2i = Vector2i(1, 0)
const ORDER_SITE_3: Vector2i = Vector2i(0, 1)
const CANONICAL_ORDER: Array[Vector2i] = [ORDER_SITE_1, ORDER_SITE_2, ORDER_SITE_3]

## §4.2's nine Solid rows in TABLE ROW ORDER. The ids are the data ids `data/ruleset.json`'s
## `dig.profiles` and `data/mapgen/concentric_bowl.json` author; the numbers are transcribed from
## the printed table above and are NEVER read back from `DigRules`.
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

## §4.2 column "Dig time (worker-turns)". Artificial Granite's printed "3 (owner: 1)" is 3 here:
## the §7.1 ownership seam `DigHexCommand._digs_own_terrain` still answers FALSE for every player
## (no hex carries a builder index; Raise Granite is M3/M4), so no site is ever sized at 1.
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

## §4.2 column "Yield on dig" — the ONE §5.1 resource each row produces.
const YIELD_RESOURCE: Dictionary = {
	"soft_dirt": "food",
	"hard_rock": "stone",
	"dense_granite": "stone",
	"artificial_granite": "stone",
	"rubble": "stone",
	"gold_vein": "gold",
	"iron_vein": "iron",
	"magestone_crust": "magestone",
	"mithril_seam": "mithril",
}

## §4.2 column "Yield on dig" — the AMOUNT. The four vein rows carry their LUMP, never the node's
## stock or rate ((BA)(vii)).
const YIELD_AMOUNT: Dictionary = {
	"soft_dirt": 1,
	"hard_rock": 2,
	"dense_granite": 4,
	"artificial_granite": 2,
	"rubble": 1,
	"gold_vein": 25,
	"iron_vein": 10,
	"magestone_crust": 15,
	"mithril_seam": 10,
}

## §4.2 Cave-hex table, row "Plain floor" — the terrain id a completed dig leaves, and the value of
## the new §12.1 leaf `dig.cave_terrain_id`. Written here as a LITERAL so the suite pins the DATA
## value rather than agreeing with whatever `DigRules` happens to answer.
const CAVE_TERRAIN_ID: String = "plain_floor"

## §5.1's six printed player resources (Scrap is Goblin-only and death-driven, never a dig yield).
const RESOURCE_IDS: Array[String] = ["food", "gold", "iron", "magestone", "mithril", "stone"]

## §4.2's vein NODE numbers — deferred ((AW) item 4 / (BA)(vii)) and pinned NEGATIVELY: none of
## them may ever reach a stockpile in this slice.
const VEIN_NODE_STOCKS: Array[int] = [250, 120, 150, 60]

## §12.2's printed example definition id and `"hp": 70`. §12.7's `worker` trait is DATA and
## `data/units/*.json` is M6, so the type stays OPAQUE here.
const UNIT_TYPE_ID: String = "dwarf_crossbow"
const UNIT_MAX_HP: int = 70

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

## (T)/(AH)/(AU)(iv) THE NO-WHITELIST RULE — every §4.2 terrain id, the Cave id, and every §5.1
## resource id is DATA and must not appear in the rule file.
const FORBIDDEN_VOCABULARY: Array[String] = [
	"soft_dirt",
	"hard_rock",
	"dense_granite",
	"artificial_granite",
	"rubble",
	"gold_vein",
	"iron_vein",
	"magestone_crust",
	"mithril_seam",
	"plain_floor",
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §4.2's Cave-hex vocabulary is forbidden as a VALUE — as the quoted literal — rather than as a
## bare substring, because the rule legitimately CALLS `DigRules.cave_terrain_id()`, which is a
## §12.1 SCHEMA name and not a terrain id. Naming the accessor is the whole point; naming the value
## is the violation.
const FORBIDDEN_QUOTED: Array[String] = ["\"cave\"", "\"plain_floor\""]

## §12.1 — the dotted schema paths belong to [DigRules] ALONE. The tick reaches every number
## through an accessor, so a second reader of `data/ruleset.json` cannot grow here.
const FORBIDDEN_SCHEMA_PATHS: Array[String] = [
	"dig.cave_terrain_id",
	"dig.profiles",
	"dig.max_diggers_per_hex",
	"dig_turns.",
	"dig_yields.",
	"vein_nodes.",
]

## §13.6 "constants read from data, not code" — the dig times (1/2/3/4), the yields
## (1/2/4/10/15/25), the vein node numbers and §3.2's turn limit are all DATA. Only 0 and 1 may
## appear standalone in the rule file (loop bases and the "no diggers" comparison).
const FORBIDDEN_NUMERALS: Array[String] = [
	"2", "3", "4", "10", "15", "25", "60", "120", "150", "200", "250",
]
const PERMITTED_NUMERALS: Array[String] = ["0", "1"]

## §4.1 line 174's three map sizes — never a literal in engine code.
const MAP_SIZE_LITERALS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public surface of DigTick: ONE function, ZERO public vars, ZERO public consts.
## `_init` is excluded by the leading underscore and is pinned by construction.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["tick_digs"]
const REQUIRED_PUBLIC_VARS: Array[String] = []
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§3.4", "§4.2", "§5.1", "§11.1", "§12.1"]

## Cached across tests: `data/ruleset.json` is parsed once and `DigRules` mutates nothing (M2-T3).
var _rules_cache: DigRules = null


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Records the canonical serialization of every event delivered, in order.
class StreamRecorder extends RefCounted:
	var lines: Array[String] = []
	var types: Array[String] = []

	func on_event(event: Event) -> void:
		types.append(String(event.type))
		var serialized: Dictionary = event.to_dict()
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in serialized.keys():
			parts.append("%s=%s" % [str(key), str(serialized[key])])
		lines.append("|".join(parts))


# =============================================================================================
# A. TICK ARITHMETIC (§4.2 line 197 "Dig time is TOTAL worker-turns" — N diggers spend N per tick)
# =============================================================================================

## §4.2 line 197 / (BA)(iii) — ONE digger on "Hard Rock | 2" spends ONE worker-turn per tick: the
## first tick moves 2 -> 1 and completes NOTHING (site alive, terrain unchanged, stockpile empty);
## the second reaches 0 and completes. A rule that decremented by a fixed 1 and one that decremented
## by the digger count agree here — which is why test A2/A3 below exist.
func test_one_digger_on_hard_rock_takes_two_ticks() -> void:
	var state: GameState = _one_site_state("hard_rock", 0, 1)
	var events: Array[Event] = _tick().tick_digs(state, 0)

	var site: DigSite = state.dig_site(TARGET)
	assert_not_null(site, "§4.2: after ONE worker-turn of a 2-turn dig the site is still standing")
	if site == null:
		return
	assert_eq(site.remaining_turns(), 1, "§4.2 line 197: 2 total worker-turns - 1 digger = 1")
	assert_eq(
		state.map.get_terrain_type(TARGET),
		"hard_rock",
		"§3.4 step 4: a PARTIAL tick never flips the hex"
	)
	assert_eq(
		state.player(0).resource_ids(),
		[] as Array[String],
		"§3.4 step 4: yields apply on COMPLETION only"
	)
	assert_eq(_types_of(events), ["dig_progressed"] as Array[String], "§13.6: progress, no completion")

	var second: Array[Event] = _tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "§4.2: the second worker-turn completes the dig")
	assert_eq(
		state.player(0).amount_of("stone"), 2, "§4.2: \"Hard Rock | 2 | \\+2 Stone\""
	)
	assert_eq(
		_types_of(second),
		["dig_progressed", "dig_completed"] as Array[String],
		"§13.6/(BA)(v): the completing tick emits progress FIRST, then completion"
	)


## §4.2 line 197 — TWO diggers on "Hard Rock | 2" spend TWO worker-turns in ONE tick and finish it,
## yielding +2 Stone EXACTLY ONCE. This is the assertion a fixed-1 decrement cannot pass.
func test_two_diggers_finish_hard_rock_in_one_tick() -> void:
	var state: GameState = _one_site_state("hard_rock", 0, 2)
	var events: Array[Event] = _tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "§4.2 line 197: 2 diggers spend 2 worker-turns in one tick")
	assert_eq(state.player(0).amount_of("stone"), 2, "§4.2: \"+2 Stone\", credited exactly once")
	assert_eq(
		state.player(0).resource_ids(),
		["stone"] as Array[String],
		"§4.2: a Hard Rock row yields stone and nothing else"
	)
	assert_eq(
		_types_of(events),
		["dig_progressed", "dig_completed"] as Array[String],
		"§13.6: exactly one progress and one completion"
	)


## §4.2 — TWO diggers on "Dense Granite | 4" need TWO ticks: 4 -> 2 (no completion, NO yield) ->
## 0 (completes, +4 Stone). Pins the intermediate step, where a rule that completed on `remaining
## <= total/2` or on any non-zero remainder would already have paid out.
func test_two_diggers_on_dense_granite_take_two_ticks() -> void:
	var state: GameState = _one_site_state("dense_granite", 0, 2)
	_tick().tick_digs(state, 0)
	var site: DigSite = state.dig_site(TARGET)
	assert_not_null(site, "§4.2: 4 worker-turns - 2 diggers = 2 remaining, so the site stands")
	if site == null:
		return
	assert_eq(site.remaining_turns(), 2, "§4.2: \"Dense Granite | 4\" minus two worker-turns")
	assert_eq(
		state.player(0).resource_ids(), [] as Array[String], "§3.4 step 4: no yield until zero"
	)

	_tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "§4.2: the second tick finishes the granite")
	assert_eq(state.player(0).amount_of("stone"), 4, "§4.2: \"Dense Granite | 4 | \\+4 Stone\"")


## §4.2 — "Soft Dirt | 1 | \+1 Food (spores)": one digger, one tick, done.
func test_one_digger_finishes_soft_dirt_in_one_tick() -> void:
	var state: GameState = _one_site_state("soft_dirt", 0, 1)
	_tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "§4.2: \"Soft Dirt | 1\" is one worker-turn")
	assert_eq(state.player(0).amount_of("food"), 1, "§4.2: \"\\+1 Food (spores)\"")


## §4.2 / (BA)(iii) OVERSHOOT — two diggers on a 1-worker-turn row spend 2 against a remainder of 1.
## `DigSite.set_remaining_turns` CLAMPS into [0, total], so the site lands on exactly 0 and yields
## EXACTLY +1 Food: never +2 (a yield scaled by the overshoot), never twice (a completion loop), and
## never a negative remainder that a later `< 0` check would miss.
func test_overshooting_the_last_worker_turn_clamps_and_yields_once() -> void:
	var state: GameState = _one_site_state("soft_dirt", 0, 2)
	var events: Array[Event] = _tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "§4.2: the overshot site completes")
	assert_eq(state.player(0).amount_of("food"), 1, "§4.2: \"\\+1 Food\" — the overshoot yields no more")
	assert_eq(
		state.player(0).resource_ids(), ["food"] as Array[String], "§4.2: and nothing else at all"
	)
	assert_eq(
		_types_of(events),
		["dig_progressed", "dig_completed"] as Array[String],
		"§13.6: one completion, not two"
	)
	var completed: DigCompletedEvent = _first_completed(events)
	assert_not_null(completed, "§13.6: the completion is announced")
	if completed == null:
		return
	assert_eq(completed.amounts, [1] as Array[int], "§4.2: the announced amount is the PRINTED +1")


## §13.4 TOTALITY — a site with ZERO diggers does not move and emits NOTHING. Unreachable through
## the Commands today ((AZ)(ii): the last digger leaving REMOVES the site), which is exactly why it
## is pinned: a rule that decremented unconditionally would silently finish abandoned sites.
func test_a_site_with_no_diggers_does_not_move_and_emits_nothing() -> void:
	var state: GameState = _empty_state()
	state.map.set_terrain_type(TARGET, "hard_rock")
	var site: DigSite = state.add_dig_site(TARGET, 0, DIG_TURNS["hard_rock"])
	assert_not_null(site, "fixture: the crewless site is registered")
	if site == null:
		return
	var before: int = state.content_hash()

	var events: Array[Event] = _tick().tick_digs(state, 0)
	assert_eq(events.size(), 0, "§13.6: no state change, so NO event")
	assert_eq(site.remaining_turns(), DIG_TURNS["hard_rock"], "§4.2: zero diggers spend zero turns")
	assert_eq(state.content_hash(), before, "§11.1: the state is byte-identical")


# =============================================================================================
# B. THE YIELD COLUMN, ROW BY ROW (§4.2 "Yield on dig"; §5.1 per-player integer stockpiles)
# =============================================================================================

## §4.2 — EVERY printed Solid row, one assertion each: the site is sized at the row's printed dig
## time, ticked to completion, and the row's printed resource lands in the SITE OWNER's stockpile at
## the printed amount — and NOTHING else does. The numbers are the hand-written literals above, not
## values read back from `DigRules`.
func test_every_solid_row_yields_its_printed_resource_and_amount() -> void:
	for terrain_id: String in SOLID_TERRAIN_IDS:
		var total: int = DIG_TURNS[terrain_id]
		var resource_id: String = YIELD_RESOURCE[terrain_id]
		var amount: int = YIELD_AMOUNT[terrain_id]
		var state: GameState = _one_site_state(terrain_id, 0, 1)
		var site: DigSite = state.dig_site(TARGET)
		assert_not_null(site, "fixture: %s has a site" % terrain_id)
		if site == null:
			return
		assert_eq(
			site.total_turns(),
			total,
			"§4.2: \"%s\" is sized at its printed %d worker-turns" % [terrain_id, total]
		)
		for tick: int in range(total):
			_tick().tick_digs(state, 0)
		assert_null(state.dig_site(TARGET), "§4.2: %s completes after %d ticks" % [terrain_id, total])
		assert_eq(
			state.player(0).amount_of(resource_id),
			amount,
			"§4.2: \"%s\" yields +%d %s" % [terrain_id, amount, resource_id]
		)
		assert_eq(
			state.player(0).resource_ids(),
			[resource_id] as Array[String],
			"§4.2: \"%s\" yields exactly ONE resource" % terrain_id
		)


## §7.1 line 367 / §4.2 — "Artificial Granite | 3 (owner: 1) | \+2 Stone". The OWNER variant is NOT
## reachable in this slice: no hex carries a builder index and §7.1's Raise Granite is M3/M4, so the
## §7.1 seam `_digs_own_terrain` answers false and the row costs THREE worker-turns, not one — while
## its yield is the printed +2 Stone, NOT the +4 of Dense Granite.
func test_artificial_granite_costs_three_worker_turns_and_yields_two_stone() -> void:
	var state: GameState = _one_site_state("artificial_granite", 0, 1)
	_tick().tick_digs(state, 0)
	_tick().tick_digs(state, 0)
	assert_not_null(
		state.dig_site(TARGET),
		"§4.2/§7.1: the row is 3 worker-turns for a non-owner, so two ticks do not finish it"
	)
	_tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "§4.2: the third worker-turn completes it")
	assert_eq(state.player(0).amount_of("stone"), 2, "§4.2/(AU)(i): \"\\+2 Stone\", not 4")


## §5.1 line 288 "Stockpiles are **per-player integers**" / (BA)(iv) — THE YIELD GOES TO THE SITE'S
## OWNER. Player 1 owns the site; player 0's stockpile stays completely EMPTY, so a rule that
## credited "the current player" (or player 0, or every player) is caught.
func test_the_yield_is_credited_to_the_site_owner_and_to_nobody_else() -> void:
	var state: GameState = _one_site_state("gold_vein", 1, 1)
	_tick().tick_digs(state, 1)
	_tick().tick_digs(state, 1)
	assert_null(state.dig_site(TARGET), "§4.2: \"Gold Vein | 2\" completes after two worker-turns")
	assert_eq(state.player(1).amount_of("gold"), 25, "§4.2: \"\\+25 Gold lump\" to the site's OWNER")
	assert_eq(
		state.player(0).resource_ids(),
		[] as Array[String],
		"§5.1: the other player's stockpile is untouched"
	)


# =============================================================================================
# C. THE HEX BECOMES CAVE, AND THE SITE GOES (§4.2 Cave hexes; §12.1 dig.cave_terrain_id)
# =============================================================================================

## §4.2 / §12.1 — on completion the hex carries `DigRules.cave_terrain_id()`, which is the DATA
## value "plain_floor" (§4.2's Cave-hex row "Plain floor"), and it is NO LONGER the Solid id it had.
func test_a_completed_dig_turns_the_hex_into_the_cave_terrain() -> void:
	assert_eq(
		_dig_rules().cave_terrain_id(),
		CAVE_TERRAIN_ID,
		"§12.1: dig.cave_terrain_id is the §4.2 Cave row \"Plain floor\""
	)
	var state: GameState = _one_site_state("rubble", 0, 1)
	_tick().tick_digs(state, 0)
	assert_eq(
		state.map.get_terrain_type(TARGET),
		_dig_rules().cave_terrain_id(),
		"§4.2: a completed dig leaves the Cave terrain the ruleset names"
	)
	assert_eq(
		state.map.get_terrain_type(TARGET), CAVE_TERRAIN_ID, "§4.2: and that value is \"plain_floor\""
	)
	assert_ne(state.map.get_terrain_type(TARGET), "rubble", "§4.2: the Solid hex is GONE")


## (AY)/(BA)(iv) — the completed site is removed from the registry: `dig_site(hex)` answers null and
## the hex is absent from `dig_site_hexes()`, so a Mining Zone re-issuing Dig commands next turn
## cannot rejoin a finished dig.
func test_a_completed_site_is_removed_from_the_registry() -> void:
	var state: GameState = _one_site_state("soft_dirt", 0, 1)
	assert_eq(state.dig_site_hexes(), [TARGET] as Array[Vector2i], "fixture: one registered site")
	_tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "(BA)(iv): the completed site is removed")
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "(BA)(iv): and the registry is empty")


## (BA)(iv) — THE DIGGERS ARE FREED IMPLICITLY: assignment IS site membership, so removing the site
## frees them without touching a single [UnitState]. Each unit still exists, on the same hex, with
## the same hp — a completion is not a casualty.
func test_completion_frees_the_diggers_without_mutating_a_unit() -> void:
	var state: GameState = _one_site_state("hard_rock", 0, 2)
	var ids: Array[int] = state.unit_ids()
	assert_eq(ids.size(), 2, "fixture: two diggers")
	var before: Array[String] = _unit_fingerprints(state)

	_tick().tick_digs(state, 0)
	assert_null(state.dig_site(TARGET), "sanity: the dig completed")
	for id: int in ids:
		assert_null(
			state.dig_site_of_digger(id), "(BA)(iv): unit %d holds no dig job afterwards" % id
		)
		assert_not_null(state.unit(id), "(BA)(iv): unit %d is still on the roster" % id)
	assert_eq(
		_unit_fingerprints(state),
		before,
		"(BA)(iv): no UnitState is mutated by a completion — hp and hex are untouched"
	)


## §3.4 step 4 — a PARTIAL tick flips NOTHING: the hex still carries its Solid id and the site is
## still registered with the same owner and total.
func test_a_partial_tick_leaves_the_hex_and_the_site_alone() -> void:
	var state: GameState = _one_site_state("mithril_seam", 0, 1)
	_tick().tick_digs(state, 0)
	assert_eq(
		state.map.get_terrain_type(TARGET), "mithril_seam", "§3.4 step 4: no flip before completion"
	)
	var site: DigSite = state.dig_site(TARGET)
	assert_not_null(site, "§4.2: \"Mithril Seam | 4\" survives one worker-turn")
	if site == null:
		return
	assert_eq(site.remaining_turns(), 3, "§4.2: 4 total worker-turns minus one digger")
	assert_eq(site.total_turns(), DIG_TURNS["mithril_seam"], "§4.2: the total never moves")
	assert_eq(site.owner_index(), 0, "(AY): one owner per site, and it never changes")


# =============================================================================================
# D. TURN PLACEMENT (§3.4 "Per player, at start of their turn"; §3.3's rotation)
# =============================================================================================

## §3.4 / (BA)(i)(ii) — ONLY THE INCOMING PLAYER'S SITES TICK. Player 0 and player 1 each own a
## site; one EndTurn by player 0 rotates to player 1 and moves ONLY player 1's site. The round trip
## then moves each exactly once.
func test_only_the_incoming_players_sites_tick() -> void:
	var state: GameState = _two_owner_state()
	var mine: DigSite = state.dig_site(ORDER_SITE_1)
	var theirs: DigSite = state.dig_site(ORDER_SITE_2)
	assert_not_null(mine, "fixture: player 0 owns a site")
	assert_not_null(theirs, "fixture: player 1 owns a site")
	if mine == null or theirs == null:
		return

	assert_null(_ticking_end_turn(state), "§3.3: player 0 ends their turn")
	assert_eq(state.current_player_index(), 1, "§3.3: player 1 is now the incoming player")
	assert_eq(mine.remaining_turns(), DIG_TURNS["dense_granite"], "(BA)(ii): player 0's site is idle")
	assert_eq(theirs.remaining_turns(), DIG_TURNS["dense_granite"] - 1, "(BA)(ii): player 1's ticked")

	assert_null(_ticking_end_turn(state), "§3.3: player 1 ends their turn")
	assert_eq(state.current_player_index(), 0, "§3.3: back to player 0")
	assert_eq(mine.remaining_turns(), DIG_TURNS["dense_granite"] - 1, "(BA)(ii): now player 0's ticked")
	assert_eq(theirs.remaining_turns(), DIG_TURNS["dense_granite"] - 1, "(BA)(ii): and player 1's did not")


## (BA)(i) — PLAYER 0'S FIRST TURN OF THE MATCH RUNS NO START-OF-TURN STEPS: nothing has ended a
## turn yet, and §3.4 step 4 is triggered only by the rotation. A fresh state with a fully-crewed
## site is byte-identical until somebody ends a turn.
func test_the_first_turn_of_the_match_runs_no_step_four() -> void:
	var state: GameState = _one_site_state("soft_dirt", 0, 1)
	var before: int = state.content_hash()
	assert_eq(state.turn(), 1, "§3.3: a fresh match is on turn 1")
	assert_eq(state.current_player_index(), 0, "§3.3: player 0 opens the match")
	assert_eq(
		state.content_hash(), before, "(BA)(i): no start-of-turn step has run for player 0 yet"
	)
	var site: DigSite = state.dig_site(TARGET)
	assert_not_null(site, "fixture: the site exists before any EndTurn")
	if site == null:
		return
	assert_eq(site.remaining_turns(), DIG_TURNS["soft_dirt"], "(BA)(i): and it has not ticked")


## §11.1 line 707 / (AY) — THE ITERATION ORDER IS `dig_site_hexes()`'s canonical order (r ascending,
## then q ascending), filtered by owner and SNAPSHOTTED before any removal. The three fixture sites
## are laid out so this differs from `Vector2i`'s default `<` (which sorts q first), so an
## implementation that sorted the wrong way — or iterated the Dictionary's insertion order — is
## caught by the EVENT ORDER.
func test_sites_tick_in_the_canonical_r_then_q_order() -> void:
	var state: GameState = _three_site_state()
	var events: Array[Event] = _tick().tick_digs(state, 0)
	var hexes: Array[Vector2i] = []
	for event: Event in events:
		var progressed: DigProgressedEvent = event as DigProgressedEvent
		if progressed != null:
			hexes.append(progressed.hex)
	assert_eq(
		hexes,
		CANONICAL_ORDER,
		"§11.1 line 707: sites tick in r-ascending-then-q-ascending order"
	)
	var default_sorted: Array[Vector2i] = CANONICAL_ORDER.duplicate()
	default_sorted.sort()
	assert_ne(
		default_sorted,
		CANONICAL_ORDER,
		"fixture: the canonical order really does differ from Vector2i's default `<`"
	)


# =============================================================================================
# E. §13.6 EVENTS, PINNED IN BOTH DIRECTIONS (the (AY)/(AZ) standard)
# =============================================================================================

## §13.6 — EXACTLY ONE [DigProgressedEvent] per site that actually moved, carrying the ticking
## player, the hex, the digger count (the worker-turns spent) and the remaining turns AFTER the tick.
func test_one_progress_event_per_moved_site_with_the_post_tick_remainder() -> void:
	var state: GameState = _one_site_state("dense_granite", 0, 2)
	var events: Array[Event] = _tick().tick_digs(state, 0)
	assert_eq(events.size(), 1, "§13.6: one moved site, one event")
	if events.size() != 1:
		return
	var progressed: DigProgressedEvent = events[0] as DigProgressedEvent
	assert_not_null(progressed, "§13.6: the emitted event is a DigProgressedEvent")
	if progressed == null:
		return
	assert_eq(progressed.player_index, 0, "§13.6: the player whose turn ticked it")
	assert_eq(progressed.hex, TARGET, "§4.1: the hex that progressed")
	assert_eq(progressed.digger_count, 2, "§4.2 line 197: two worker-turns were spent")
	assert_eq(progressed.remaining_turns, 2, "§4.2: 4 - 2 = 2 remaining AFTER the tick")


## §13.6 — EXACTLY ONE [DigCompletedEvent] per completed site, carrying the OWNER index, the hex,
## the freed digger ids ASCENDING, the yielded resource ids ASCENDING with their amounts, and the
## NEW terrain id — so the yield AND the terrain flip are both observable in the stream.
func test_one_completion_event_carrying_the_yield_the_diggers_and_the_new_terrain() -> void:
	var state: GameState = _one_site_state("magestone_crust", 1, 2)
	var events: Array[Event] = _tick().tick_digs(state, 1)
	var completed: DigCompletedEvent = _first_completed(events)
	assert_not_null(completed, "§13.6: the completion is announced")
	if completed == null:
		return
	assert_eq(completed.player_index, 1, "(BA)(iv): the SITE'S OWNER is credited and announced")
	assert_eq(completed.hex, TARGET, "§4.1: the hex that finished")
	assert_eq(completed.digger_ids, [1, 2] as Array[int], "(AY): the freed diggers, ASCENDING")
	assert_eq(
		completed.resource_ids,
		["magestone"] as Array[String],
		"§4.2: \"Magestone Crust | 2 | \\+15 Magestone lump\""
	)
	assert_eq(completed.amounts, [15] as Array[int], "§4.2: the printed lump, aligned with its id")
	assert_eq(completed.terrain_id, CAVE_TERRAIN_ID, "§4.2: the Cave terrain the hex became")


## §13.6/(BA)(v) — a COMPLETING site emits BOTH its progress event and its completion event, and
## the PROGRESS comes FIRST: the renderer sees the last worker-turn spent before the hex changes.
func test_a_completing_site_emits_progress_then_completion() -> void:
	var state: GameState = _one_site_state("soft_dirt", 0, 1)
	var events: Array[Event] = _tick().tick_digs(state, 0)
	assert_eq(
		_types_of(events),
		["dig_progressed", "dig_completed"] as Array[String],
		"(BA)(v): progress FIRST, then completion"
	)


## §13.6 THE NEGATIVE DIRECTION — an EndTurn with NO dig sites emits ONLY the TurnEndedEvent, and
## the content hash after the step-4 pass is byte-identical to the hash before it.
func test_an_end_turn_with_no_dig_sites_emits_only_the_turn_event() -> void:
	var state: GameState = _empty_state()
	var bus: EventBus = EventBus.new()
	var recorder: StreamRecorder = StreamRecorder.new()
	_subscribe_all(bus, recorder)
	var before: int = state.content_hash()
	assert_null(EndTurnCommand.new(0, _dig_rules()).execute(state, bus), "§3.3: accepted")
	assert_eq(
		recorder.types, ["turn_ended"] as Array[String], "§13.6: nothing dug, so nothing is announced"
	)
	var positioned: GameState = _empty_state()
	positioned.set_turn_position(1, 1)
	assert_eq(
		state.content_hash(),
		positioned.content_hash(),
		"§13.6: the step-4 pass over an empty registry changes nothing but the turn position"
	)
	assert_ne(state.content_hash(), before, "sanity: the rotation itself IS a change")


## §11.1/§3.3 — the [TurnEndedEvent] stays FIRST in the returned array and the step-4 events follow
## it: the rotation happens, then the incoming player's turn starts.
func test_the_turn_ended_event_stays_first_and_the_tick_events_follow() -> void:
	var state: GameState = _two_owner_state()
	var events: Array[Event] = EndTurnCommand.new(0, _dig_rules()).apply(state)
	assert_gte(events.size(), 2, "§13.6: the rotation event plus at least one tick event")
	if events.size() < 2:
		return
	assert_eq(String(events[0].type), "turn_ended", "§3.3: the rotation is announced FIRST")
	for index: int in range(1, events.size()):
		assert_ne(
			String(events[index].type),
			"turn_ended",
			"§3.3: exactly one rotation event, and the step-4 events follow it"
		)


## §11.1 line 708 "save = JSON snapshot" — both new events serialize base-FIRST ("type" leading),
## flatten the axial hex into `hex_q`/`hex_r`, and carry only JSON-safe values (scalars, or arrays
## of scalars). A raw `Vector2i` in a payload survives `to_dict()` and dies at the JSON boundary.
func test_both_new_events_serialize_to_json_safe_dictionaries() -> void:
	var state: GameState = _one_site_state("iron_vein", 0, 2)
	var events: Array[Event] = _tick().tick_digs(state, 0)
	assert_eq(events.size(), 2, "sanity: an iron vein with two diggers finishes in one tick")
	if events.size() != 2:
		return
	for event: Event in events:
		var serialized: Dictionary = event.to_dict()
		assert_eq(
			str(serialized.keys()[0]), "type", "§11.1: to_dict() calls the base FIRST"
		)
		assert_true(serialized.has("hex_q"), "§11.1 line 708: the hex is flattened to hex_q")
		assert_true(serialized.has("hex_r"), "§11.1 line 708: the hex is flattened to hex_r")
		assert_false(serialized.has("hex"), "§11.1 line 708: a raw Vector2i is not JSON")
		for key: Variant in serialized.keys():
			assert_true(
				_is_json_safe(serialized[key]),
				"§11.1 line 708: \"%s\" must be a JSON scalar or an array of them" % str(key)
			)
		var parsed: Variant = JSON.parse_string(JSON.stringify(serialized, "", false))
		assert_eq(typeof(parsed), TYPE_DICTIONARY, "§11.1 line 708: the payload IS valid JSON")


# =============================================================================================
# F. UNCONFIGURED AND TOTAL (§13.4; the DigHexCommand unconfigured precedent)
# =============================================================================================

## (BA)(vi) — `EndTurnCommand.new(i)` with NO [DigRules] runs NO step-4 pass. This RE-SCOPES the
## negative pins M2-T2/M2-T5/M2-T6 wrote: after any number of such EndTurns every surviving site's
## remaining turns are UNCHANGED, every stockpile is EMPTY and the terrain is UNCHANGED.
func test_an_end_turn_without_dig_rules_ticks_nothing() -> void:
	var state: GameState = _two_owner_state()
	var before_first: int = state.dig_site(ORDER_SITE_1).remaining_turns()
	var before_second: int = state.dig_site(ORDER_SITE_2).remaining_turns()
	for k: int in range(6):
		assert_null(
			EndTurnCommand.new(state.current_player_index()).execute(state, null),
			"§3.3: the current player's EndTurn is accepted"
		)
	assert_eq(
		state.dig_site(ORDER_SITE_1).remaining_turns(),
		before_first,
		"(BA)(vi): an unconfigured EndTurn spends no worker-turn"
	)
	assert_eq(
		state.dig_site(ORDER_SITE_2).remaining_turns(),
		before_second,
		"(BA)(vi): on either player's site"
	)
	for index: int in range(2):
		assert_eq(
			state.player(index).resource_ids(),
			[] as Array[String],
			"(BA)(vi): and credits player %d nothing" % index
		)
	assert_eq(
		state.map.get_terrain_type(ORDER_SITE_1), "dense_granite", "(BA)(vi): no terrain flip either"
	)


## (BA)(vi) THE POSITIVE COUNTERPART — the SAME log with a configured [DigRules] injected DOES tick.
## Without this the pin above would be satisfied by a rule that never ticks at all.
func test_the_same_end_turns_with_dig_rules_do_tick() -> void:
	var state: GameState = _two_owner_state()
	# 8 EndTurns at 2 players = FOUR start-of-turn ticks each, which is exactly §4.2's
	# "Dense Granite | 4" worker-turns for a single digger.
	for k: int in range(8):
		assert_null(_ticking_end_turn(state), "§3.3: the current player's EndTurn is accepted")
	assert_null(
		state.dig_site(ORDER_SITE_1),
		"§4.2: \"Dense Granite | 4\" finishes on its owner's FOURTH start-of-turn tick"
	)
	assert_null(state.dig_site(ORDER_SITE_2), "§4.2: and so does the other player's")
	assert_eq(state.player(0).amount_of("stone"), 4, "§4.2: \"\\+4 Stone\" to player 0")
	assert_eq(state.player(1).amount_of("stone"), 4, "§4.2: \"\\+4 Stone\" to player 1")


## (BA)(vi)/(AL) — a [DigTick] built on an UNCONFIGURED [DigRules] completes nothing and, above all,
## never writes the EMPTY cave terrain id over a real hex.
func test_an_unconfigured_dig_rules_ticks_nothing_and_writes_no_empty_terrain() -> void:
	var rules: DigRules = DigRules.new(null)
	assert_eq(rules.cave_terrain_id(), "", "(AL): an unconfigured DigRules names no cave terrain")
	var state: GameState = _one_site_state("soft_dirt", 0, 1)
	var before: int = state.content_hash()
	var events: Array[Event] = DigTick.new(rules).tick_digs(state, 0)
	assert_eq(events.size(), 0, "(BA)(vi): an unconfigured tick announces nothing")
	assert_not_null(state.dig_site(TARGET), "(BA)(vi): and completes nothing")
	assert_eq(
		state.map.get_terrain_type(TARGET), "soft_dirt", "(BA)(vi): the hex is NEVER written to \"\""
	)
	assert_eq(state.content_hash(), before, "§11.1: the state is byte-identical")


## §13.4 TOTALITY — a null state and a MAPLESS state both tick nothing rather than crashing. §11.1
## line 708's replay reads a mapless `GameState` in `tests/sim/test_turn_replay.gd`, so a configured
## EndTurn must survive one.
func test_a_null_or_mapless_state_ticks_nothing() -> void:
	assert_eq(
		_tick().tick_digs(null, 0).size(), 0, "§13.4: a null state is total, not a crash"
	)
	var mapless: GameState = GameState.new(GOLDEN_SEED, null, 2)
	assert_eq(_tick().tick_digs(mapless, 0).size(), 0, "§13.4: a mapless state ticks nothing")
	var before: int = mapless.content_hash()
	assert_null(EndTurnCommand.new(0, _dig_rules()).execute(mapless, null), "§3.3: accepted")
	var positioned: GameState = GameState.new(GOLDEN_SEED, null, 2)
	positioned.set_turn_position(1, 1)
	assert_eq(
		mapless.content_hash(),
		positioned.content_hash(),
		"§13.4: a mapless EndTurn is exactly the rotation"
	)
	assert_ne(mapless.content_hash(), before, "sanity: the rotation IS a change")


# =============================================================================================
# G. DETERMINISM AND THE DEFERRALS (§11.1; §13.4 "invent nothing ahead of its milestone")
# =============================================================================================

## §11.1 "no randi()" / §3.4 step 4 — the Breach checks (§4.6) and Noise pings (§4.8) that step 4
## also prints are M5 and are pinned NEGATIVELY: after any number of ticks and completions the one
## seeded stream is still at position 0.
func test_the_tick_draws_no_random_roll() -> void:
	var state: GameState = _three_site_state()
	for k: int in range(8):
		_tick().tick_digs(state, 0)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1/§3.4: Breach (§4.6) and Noise (§4.8) are M5 — the seeded stream must not advance"
	)


## (AW) item 4 / (BA)(vii) — NO VEIN NODE IS CREATED. Digging "Gold Vein" applies the +25 LUMP and
## nothing else: the node's printed stock 250 and rate 10 reach no stockpile, no second resource
## appears, and the hex is plain floor rather than a node hex. Asserted POSITIVELY — the ONLY
## differences from the pre-tick state are the terrain, the stockpile and the site registry.
func test_digging_a_vein_applies_the_lump_and_creates_no_node() -> void:
	var state: GameState = _one_site_state("gold_vein", 0, 2)
	var units_before: Array[String] = _unit_fingerprints(state)
	var terrain_before: Array[String] = _terrain_fingerprints(state)
	_tick().tick_digs(state, 0)

	assert_eq(state.player(0).amount_of("gold"), 25, "§4.2: the printed \\+25 Gold LUMP")
	for stock: int in VEIN_NODE_STOCKS:
		assert_ne(
			state.player(0).amount_of("gold"),
			stock,
			"(BA)(vii): a node's stock is NOT a stockpile credit"
		)
	assert_eq(
		state.player(0).resource_ids(), ["gold"] as Array[String], "(BA)(vii): no second resource"
	)
	assert_eq(state.unit_ids().size(), 2, "(BA)(vii): no Extractor, no unit is created")
	assert_eq(_unit_fingerprints(state), units_before, "(BA)(vii): and no unit is mutated")
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "(BA)(iv): the site is gone")

	var terrain_after: Array[String] = _terrain_fingerprints(state)
	var changed: Array[String] = []
	for index: int in range(terrain_after.size()):
		if terrain_after[index] != terrain_before[index]:
			changed.append(terrain_after[index])
	assert_eq(changed.size(), 1, "(BA)(vii): EXACTLY ONE hex changed terrain")
	assert_eq(
		state.map.get_terrain_type(TARGET),
		CAVE_TERRAIN_ID,
		"(BA)(vii): the vein hex is plain floor, not a node hex"
	)


## §11.1 line 708 — the tick is REPLAYABLE: two identically-built states ticked the same number of
## times agree on `content_hash()` at every step, and a third run agrees again.
func test_the_tick_is_replayable_across_fresh_states() -> void:
	var runs: Array = []
	for run: int in range(3):
		var state: GameState = _three_site_state()
		var hashes: Array = []
		for k: int in range(5):
			_tick().tick_digs(state, 0)
			hashes.append(state.content_hash())
		runs.append(hashes)
	for run: int in range(1, 3):
		assert_eq(runs[run], runs[0], "§11.1: tick run %d diverged from run 0" % run)


## §13.4 — the tick is IDEMPOTENT ON AN EMPTY REGISTRY: once every site of a player has completed,
## further ticks change nothing and announce nothing (no second yield, no re-flip).
func test_ticking_after_everything_completed_changes_nothing() -> void:
	var state: GameState = _one_site_state("rubble", 0, 1)
	_tick().tick_digs(state, 0)
	var settled: int = state.content_hash()
	for k: int in range(4):
		assert_eq(_tick().tick_digs(state, 0).size(), 0, "§13.6: nothing changed, nothing announced")
	assert_eq(state.content_hash(), settled, "§13.4: a finished dig is never paid twice")
	assert_eq(state.player(0).amount_of("stone"), 1, "§4.2: \"Rubble | 1 | \\+1 Stone\", once")


# =============================================================================================
# J. MECHANICAL SOURCE SCANS ON scripts/sim/systems/dig_tick.gd
#    Written FRESH for this file — it inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(DIG_TICK_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_TICK_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			DIG_TICK_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % DIG_TICK_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R); the sim never calls the
## renderer, so the EventBus -> MapRenderer seam (M2-T8) must not be reached from inside the rule.
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(DIG_TICK_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_TICK_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [DIG_TICK_PATH, banned]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [DIG_TICK_PATH, banned]
		)


## S3 (T)/(AH)/(AU)(iv) THE NO-WHITELIST RULE — not one §4.2 terrain id, not the Cave id, not one
## §5.1 resource id. Every one of them is DATA reached through [DigRules]; §13.5's M6 canary says
## adding content must be a data edit.
func test_source_names_no_terrain_id_and_no_resource_id() -> void:
	var lowered: String = _code_text(DIG_TICK_PATH).to_lower()
	assert_false(lowered.is_empty(), "sanity: %s must be readable and non-empty" % DIG_TICK_PATH)
	for banned: String in FORBIDDEN_VOCABULARY:
		assert_false(
			lowered.contains(banned),
			"(T)/(AH)/(AU)(iv): terrain and resource ids are DATA — %s must not name \"%s\"" % [
				DIG_TICK_PATH, banned
			]
		)
	for banned: String in FORBIDDEN_QUOTED:
		assert_false(
			lowered.contains(banned),
			"(T)/(AH): the Cave terrain is a VALUE in data — %s must not spell %s" % [
				DIG_TICK_PATH, banned
			]
		)
	for banned: String in FORBIDDEN_SCHEMA_PATHS:
		assert_false(
			lowered.contains(banned),
			"§12.1: only DigRules names a schema path — %s must not read \"%s\"" % [
				DIG_TICK_PATH, banned
			]
		)
	assert_false(lowered.contains("enum "), "(AU)(iv): the vocabulary is never an enum")


## S4 §13.6 "constants read from data, not code" — §4.2's nine dig times and nine yields, the vein
## node numbers and §3.2's turn limit 200 ((AV) item 3) are all DATA. Only 0 and 1 may appear
## standalone in the rule, and no §4.1 map-size literal may appear at all.
func test_source_hard_codes_no_gdd_number() -> void:
	var code: String = _code_text(DIG_TICK_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_TICK_PATH)
	var numeral: RegEx = RegEx.new()
	assert_eq(
		numeral.compile("(?<![0-9A-Za-z._])([0-9]+)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the standalone-numeral pattern compiles"
	)
	var standalone: Array[String] = []
	for found: RegExMatch in numeral.search_all(code):
		standalone.append(found.get_string())
		assert_true(
			PERMITTED_NUMERALS.has(found.get_string()),
			"§13.6: only %s are permitted in %s — found \"%s\"" % [
				str(PERMITTED_NUMERALS), DIG_TICK_PATH, found.get_string()
			]
		)
	for banned: String in MAP_SIZE_LITERALS:
		assert_false(
			standalone.has(banned),
			"§4.1 line 174: map sizes live in data — %s must not carry the literal %s" % [
				DIG_TICK_PATH, banned
			]
		)
	for banned: String in FORBIDDEN_NUMERALS:
		assert_false(
			standalone.has(banned),
			"§13.6: §4.2/§3.2 numbers are DATA — %s must not carry the literal %s" % [
				DIG_TICK_PATH, banned
			]
		)
	assert_eq(FORBIDDEN_NUMERALS.size(), 11, "sanity: every §4.2/§3.2 numeral is covered")


## S5 (AV)/M1-T9 — the tick is a RULE, not a loader and not a Command: `RulesError`/`RulesLoader`
## must be ABSENT (a second source of dig numbers must not grow here), it authors no rejection code
## (rejection is `validate`'s job, and the tick runs only after one), and it overrides no native
## method.
func test_source_declares_no_loader_and_authors_no_rejection_code() -> void:
	var code: String = _code_text(DIG_TICK_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_TICK_PATH)
	for banned: String in ["RulesError", "RulesLoader", "CommandError", "extends Command"]:
		assert_false(
			code.contains(banned),
			"M1-T9/(AV): %s is a RULE module, not a loader or a Command — it must not name %s" % [
				DIG_TICK_PATH, banned
			]
		)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % DIG_TICK_PATH
	)


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: a MISSING member fails
## instead of passing vacuously and an EXTRA one (a second entry point, a cached site list, a
## public counter) fails too. ZERO public vars and ZERO public consts.
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_TICK_PATH, public_functions, undocumented)

	var tick: DigTick = _tick()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, DIG_TICK_PATH]
		)
		assert_true(
			tick.has_method(required), "§11.2: %s must be callable on a DigTick instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			DIG_TICK_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(DIG_TICK_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: %s declares ZERO public vars" % DIG_TICK_PATH
	)
	assert_eq(
		_collect_public_consts(DIG_TICK_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.4: %s declares ZERO public consts" % DIG_TICK_PATH
	)
	assert_eq(
		_untyped_declarations(DIG_TICK_PATH),
		[] as Array[String],
		"§11.3: static typing everywhere — every `var` in %s must be `var x: T = ...`" % DIG_TICK_PATH
	)


## S7 §11.1/§11.2 — DigTick is a pure [RefCounted] in `scripts/sim/systems/` (§11.2 line 724 prints
## that directory verbatim). Asserted through get_class() — `is Node` would be a PARSE ERROR here.
func test_dig_tick_is_a_pure_refcounted_in_scripts_sim_systems() -> void:
	assert_true(
		FileAccess.file_exists(DIG_TICK_PATH), "§11.2: DigTick belongs at %s" % DIG_TICK_PATH
	)
	assert_eq(_tick().get_class(), "RefCounted", "§11.1: DigTick must be a pure RefCounted")


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


## The injected, already-loaded §4.2 dig table (M2-T3).
func _dig_rules() -> DigRules:
	if _rules_cache == null:
		_rules_cache = DigRules.new(_loaded())
	return _rules_cache


## A fresh [DigTick] over the shipped table.
func _tick() -> DigTick:
	return DigTick.new(_dig_rules())


## A two-player state on a radius-2 map with no dig site at all.
func _empty_state() -> GameState:
	return GameState.new(GOLDEN_SEED, HexMap.new(MAP_RADIUS), 2)


## A two-player state carrying ONE dig site on [constant TARGET]: `terrain_id` on the hex, the site
## owned by `owner_index` and sized at §4.2's PRINTED dig time for that row (never a value read back
## from `DigRules`), with `digger_count` of the owner's units assigned. Unit ids are minted 1, 2 in
## that order ((AX)).
func _one_site_state(terrain_id: String, owner_index: int, digger_count: int) -> GameState:
	var state: GameState = _empty_state()
	state.map.set_terrain_type(TARGET, terrain_id)
	var site: DigSite = state.add_dig_site(TARGET, owner_index, DIG_TURNS[terrain_id])
	assert_not_null(site, "fixture: the site on %s is registered" % terrain_id)
	if site == null:
		return state
	var hexes: Array[Vector2i] = [DIGGER_HEX_A, DIGGER_HEX_B]
	for index: int in range(digger_count):
		var unit: UnitState = state.spawn_unit(
			owner_index, UNIT_TYPE_ID, hexes[index % hexes.size()], UNIT_MAX_HP
		)
		assert_not_null(unit, "fixture: digger %d is spawned" % index)
		if unit != null:
			site.add_digger(unit.unit_id())
	return state


## A two-player state where player 0 and player 1 each own ONE "Dense Granite | 4" site with ONE
## digger, so "only the incoming player's sites tick" is observable in both directions.
func _two_owner_state() -> GameState:
	var state: GameState = _empty_state()
	var owners: Array[int] = [0, 1]
	var hexes: Array[Vector2i] = [ORDER_SITE_1, ORDER_SITE_2]
	for index: int in range(owners.size()):
		state.map.set_terrain_type(hexes[index], "dense_granite")
		var site: DigSite = state.add_dig_site(
			hexes[index], owners[index], DIG_TURNS["dense_granite"]
		)
		assert_not_null(site, "fixture: player %d's site is registered" % owners[index])
		if site == null:
			continue
		var unit: UnitState = state.spawn_unit(owners[index], UNIT_TYPE_ID, TARGET, UNIT_MAX_HP)
		assert_not_null(unit, "fixture: player %d's digger is spawned" % owners[index])
		if unit != null:
			site.add_digger(unit.unit_id())
	return state


## A two-player state where player 0 owns THREE "Dense Granite | 4" sites, one digger each, laid out
## so the canonical order differs from `Vector2i`'s default `<`. The diggers all stand on
## [constant TARGET] — the roster stacks freely (§6.4's stacking legality is M4) and the tick never
## consults a digger's position.
func _three_site_state() -> GameState:
	var state: GameState = _empty_state()
	for hex: Vector2i in CANONICAL_ORDER:
		state.map.set_terrain_type(hex, "dense_granite")
		var site: DigSite = state.add_dig_site(hex, 0, DIG_TURNS["dense_granite"])
		assert_not_null(site, "fixture: the site on %s is registered" % str(hex))
		if site == null:
			continue
		var unit: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, TARGET, UNIT_MAX_HP)
		assert_not_null(unit, "fixture: a digger for %s is spawned" % str(hex))
		if unit != null:
			site.add_digger(unit.unit_id())
	return state


## Ends the CURRENT player's turn with a CONFIGURED [DigRules] injected, through the ONE gate.
func _ticking_end_turn(state: GameState) -> CommandError:
	return EndTurnCommand.new(state.current_player_index(), _dig_rules()).execute(state, null)


## The type names of an event array, in order.
func _types_of(events: Array[Event]) -> Array[String]:
	var out: Array[String] = []
	for event: Event in events:
		out.append(String(event.type))
	return out


## The first [DigCompletedEvent] in an array, or null.
func _first_completed(events: Array[Event]) -> DigCompletedEvent:
	for event: Event in events:
		var completed: DigCompletedEvent = event as DigCompletedEvent
		if completed != null:
			return completed
	return null


## Subscribes one recorder to all five concrete event types, so "only the turn event fired" is
## measured rather than assumed.
func _subscribe_all(bus: EventBus, recorder: StreamRecorder) -> void:
	bus.subscribe(TurnEndedEvent.TYPE_NAME, recorder.on_event)
	bus.subscribe(DigStartedEvent.TYPE_NAME, recorder.on_event)
	bus.subscribe(DigCancelledEvent.TYPE_NAME, recorder.on_event)
	bus.subscribe(DigProgressedEvent.TYPE_NAME, recorder.on_event)
	bus.subscribe(DigCompletedEvent.TYPE_NAME, recorder.on_event)


## Every unit rendered as "id:owner:type:q,r:hp/max", ascending by id — so "no UnitState was
## mutated" is one comparison rather than a field-by-field sweep.
func _unit_fingerprints(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for id: int in state.unit_ids():
		var unit: UnitState = state.unit(id)
		if unit == null:
			continue
		out.append(
			"%d:%d:%s:%d,%d:%d/%d" % [
				unit.unit_id(),
				unit.owner_index(),
				unit.type_id(),
				unit.hex().x,
				unit.hex().y,
				unit.hp(),
				unit.max_hp(),
			]
		)
	return out


## Every hex's terrain id in [method HexMap.hexes] canonical order.
func _terrain_fingerprints(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for hex: Vector2i in state.map.hexes():
		out.append(state.map.get_terrain_type(hex))
	return out


## True for a JSON-safe serialized value: a scalar, or an array whose entries are all scalars
## (§11.1 line 708 — "save = JSON snapshot").
func _is_json_safe(value: Variant) -> bool:
	var kind: int = typeof(value)
	if kind == TYPE_STRING or kind == TYPE_INT or kind == TYPE_BOOL:
		return true
	if kind == TYPE_ARRAY or kind == TYPE_PACKED_INT32_ARRAY or kind == TYPE_PACKED_STRING_ARRAY:
		for entry: Variant in value:
			var entry_kind: int = typeof(entry)
			if entry_kind != TYPE_STRING and entry_kind != TYPE_INT and entry_kind != TYPE_BOOL:
				return false
		return true
	return false


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
## (§11.3 "static typing everywhere").
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
