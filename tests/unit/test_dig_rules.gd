## DigRules — §4.2's Solid-hex DIG TABLE, answered entirely from §12.1 data. GDD §4.2 (Hex Types,
## **the authority for every number below**), §12.1 (ruleset.json — where those numbers live),
## §5.2 (Extractors: what the vein node is FOR), §5.1 (the resource vocabulary), §7.1 (the
## Artificial-Granite owner variant), §11.1 (pure sim core, integer math, fresh canonical arrays),
## §11.2, §11.3, §13.2 tier 1, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md` §4.2 (lines 184-193 —
## "Solid type | Dig time (worker-turns) | Yield on dig | Notes"):
##   Soft Dirt          | 1        | \+1 Food (spores)          |
##   Hard Rock          | 2        | \+2 Stone                  |
##   Dense Granite      | 4        | \+4 Stone                  |
##   Artificial Granite | 3 (owner: 1) | \+2 Stone              | Dwarf-built; §7.1
##   Rubble             | 1        | \+1 Stone                  |
##   Gold Vein          | 2        | \+25 Gold lump + node      | Node: stock 250, 10/turn
##   Iron Vein          | 2        | \+10 Iron lump + node      | Node: stock 120, 6/turn
##   Magestone Crust    | 2        | \+15 Magestone lump + node | Node: stock 150, 6/turn
##   Mithril Seam       | 4        | \+10 Mithril lump + node   | Node: stock 60, 3/turn
## and §4.2 line 197 (prose): "Dig time is total worker-turns; multiple workers on adjacent hexes
## may work the same target (**max 2 simultaneous diggers per hex**). \"Dig 2x\" halves remaining
## time (round up)."
##   §7.1 (line 367): "Enemies dig it in 3 turns; Dwarves clear their own in 1." — the owner
##         variant, and the reason `dig_turns_for` takes a bool rather than deciding ownership.
##   §5.2 (line 292): "**Extractor** ... must be built *on* a vein node hex; yields the node's
##         rate per turn until stock exhausts" — what `vein_resource_id` is for. Vein-node STATE
##         (stock/rate) and Extractors are a LATER M2 slice and are pinned NEGATIVELY here.
##
## `docs/decisions.md` was re-scanned END TO END this iteration: the ONLY logged override touching
## §12.1 or §4.2 in the whole project is **(AU)(i)** (M2-T1, 2026-08-04) —
## `dig_yields.artificial_granite.stone = 2`, which merely transcribes §4.2's own "\+2 Stone" row
## into the §12.1 excerpt. Nothing overrides §4.2's dig times, §4.2 line 197, §5.1 or §5.2, so the
## printed tables govern unamended and every number below is the GDD's, not the code's.
##
## §4.2's terrain ids (`soft_dirt`, ...) and §12.1's dig keys (`soft`, `hard`, `vein`, ...) are two
## DIFFERENT vocabularies. The binding between them is DATA — `data/ruleset.json`'s new `dig`
## group — which is what keeps terrain ids out of engine code (the (T)/(AH)/(AU)(iv) no-whitelist
## rule) and what will let §13.5's M6 zero-engine-change canary hold. Scan S4 below enforces it.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via `get_class()` ONLY.
extends GutTest

const DIG_RULES_PATH: String = "res://scripts/sim/systems/dig_rules.gd"
const RULESET_PATH: String = "res://data/ruleset.json"
const MAPGEN_PATH: String = "res://data/mapgen/concentric_bowl.json"
const SOURCE: String = "ruleset.json"

## §4.2's nine Solid-hex rows, in TABLE ORDER (which is also `dig.profiles`' authored order).
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

## §4.2 column "Dig time (worker-turns)". Sourced in §12.1 from `dig_turns`
## (soft 1 · hard 2 · granite 4 · artificial_granite 3 · rubble 1 · vein 2 · mithril 4).
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

## §4.2 line 188 "Artificial Granite | **3 (owner: 1)**" / §7.1 line 367 "Enemies dig it in 3
## turns; Dwarves clear their own in 1". EXACTLY ONE row has an owner variant.
const OWNER_VARIANT_TERRAIN_ID: String = "artificial_granite"
const OWNER_VARIANT_TURNS: int = 1

## §4.2 column "Yield on dig" — the §5.1 resource each row yields, and how much.
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

## §4.2's "+ node" appears on EXACTLY these four rows; §5.2 line 292 is what will consume it.
const VEIN_RESOURCE: Dictionary = {
	"soft_dirt": "",
	"hard_rock": "",
	"dense_granite": "",
	"artificial_granite": "",
	"rubble": "",
	"gold_vein": "gold",
	"iron_vein": "iron",
	"magestone_crust": "magestone",
	"mithril_seam": "mithril",
}

## §5.1's SEVEN resources (lines 277-284). Used to prove a yield is exactly one resource and zero
## for every other, and as FORBIDDEN tokens in the source scan.
const RESOURCE_IDS: Array[String] = [
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §4.2 line 197 "max 2 simultaneous diggers per hex", read from `dig.max_diggers_per_hex`.
const MAX_DIGGERS_PER_HEX: int = 2

## §4.2 line 197 "\"Dig 2x\" halves remaining time (**round up**)" = ceil(n/2). ceil and §11.1's
## round-half-up COINCIDE here: halving an integer leaves a fraction of only ever 0 or 0.5, and
## round-half-up on 0.5 rounds away from zero — the same answer ceil gives on a non-negative n.
const HALVED: Dictionary = {0: 0, 1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 8: 4, 9: 5}

## (E) totality — ids that are NOT §4.2 Solid rows (Cave features per §4.2's second table, plus
## garbage). None of them may tear down a headless run.
const UNKNOWN_TERRAIN_IDS: Array[String] = ["", "cave", "plain_floor", "not_a_type"]

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

## (J) NEGATIVE PIN — this slice rides NO part of the (AV) command spine: DigRules mutates no
## state, emits nothing and constructs no Command.
const SPINE_TOKENS: Array[String] = ["GameState", "Command", "Event", "EventBus"]

## §13.6 "constants read from data, not code" — the §4.2/§12.1 table numerals are FORBIDDEN as
## standalone numbers in `dig_rules.gd`. 0, 1 and 2 are permitted: 0/1 are totality sentinels and
## the ceil's +1, and 2 is the halving divisor (a NAMED private const — scan S5).
const FORBIDDEN_NUMERALS: Array[String] = ["3", "4", "10", "15", "25", "60", "120", "150", "250"]

## The §12.1 schema paths and leaf names DigRules is EXPECTED to name — they are its CONTRACT with
## data, exactly as `RulesLoader._spec()` already holds them. Their presence is what proves the
## numbers really flow loader -> profile -> §12.1 key rather than being typed into the file.
const REQUIRED_SCHEMA_TOKENS: Array[String] = [
	"dig.profiles",
	"dig.max_diggers_per_hex",
	"dig_turns",
	"dig_yields",
	"vein_nodes",
	"turns_key",
	"owner_turns_key",
	"yield_key",
	"vein_key",
	"lump",
]

## The COMPLETE public surface of DigRules. `_init` is excluded from the collected list by the
## leading underscore and is pinned separately by construction. If the implementation genuinely
## needs a different member, this list is updated in the SAME commit (the standing PROGRESS rule).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"is_diggable",
	"dig_turns_for",
	"yield_resource_ids",
	"yield_amount",
	"vein_resource_id",
	"max_diggers_per_hex",
	"halve_remaining_turns",
]
const REQUIRED_PUBLIC_VARS: Array[String] = []
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§4.2", "§12.1", "§5.2", "§11.1"]


# =============================================================================================
# A. DIG TIMES (§4.2 column "Dig time (worker-turns)"; §7.1 line 367 for the owner variant)
# =============================================================================================

## §4.2 — the whole "Dig time (worker-turns)" column, row by row, for a NON-owner digger.
func test_dig_time_for_every_solid_row() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		var expected: int = DIG_TURNS[terrain_id]
		assert_eq(
			rules.dig_turns_for(terrain_id, false),
			expected,
			"§4.2: %s costs %d worker-turns to dig" % [terrain_id, expected]
		)


## §4.2 line 188 / §7.1 line 367 — THE OWNER VARIANT. "Artificial Granite | 3 (owner: 1)":
## "Enemies dig it in 3 turns; Dwarves clear their own in 1."
func test_the_owner_digs_artificial_granite_in_one_turn() -> void:
	var rules: DigRules = _dig_rules()
	assert_eq(
		rules.dig_turns_for(OWNER_VARIANT_TERRAIN_ID, false),
		DIG_TURNS[OWNER_VARIANT_TERRAIN_ID],
		"§4.2/§7.1: an ENEMY digs Artificial Granite in 3"
	)
	assert_eq(
		rules.dig_turns_for(OWNER_VARIANT_TERRAIN_ID, true),
		OWNER_VARIANT_TURNS,
		"§4.2/§7.1: the OWNER clears their own Artificial Granite in 1"
	)


## §4.2 — the owner variant exists for EXACTLY ONE row. `by_owner = true` must change NOTHING for
## the other eight: an implementation that applied an owner discount broadly passes nothing here.
func test_the_owner_flag_changes_nothing_for_the_other_eight_rows() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		if terrain_id == OWNER_VARIANT_TERRAIN_ID:
			continue
		assert_eq(
			rules.dig_turns_for(terrain_id, true),
			rules.dig_turns_for(terrain_id, false),
			"§4.2: only Artificial Granite has an owner variant — %s must not" % terrain_id
		)
		var expected: int = DIG_TURNS[terrain_id]
		assert_eq(
			rules.dig_turns_for(terrain_id, true),
			expected,
			"§4.2: %s costs the same to its owner" % terrain_id
		)


## §4.2 — `is_diggable` is true for EXACTLY the nine printed Solid rows.
func test_every_solid_row_is_diggable() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		assert_true(rules.is_diggable(terrain_id), "§4.2: %s is a Solid hex and is dug" % terrain_id)
	assert_eq(SOLID_TERRAIN_IDS.size(), 9, "§4.2: the Solid table has exactly nine rows")


# =============================================================================================
# B. DIG YIELDS (§4.2 column "Yield on dig"; §5.1's resource vocabulary)
# =============================================================================================

## §4.2 — every row yields EXACTLY ONE §5.1 resource, and `yield_resource_ids` names it.
func test_each_solid_row_yields_exactly_one_resource() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		var resource_id: String = YIELD_RESOURCE[terrain_id]
		var expected: Array[String] = [resource_id]
		assert_eq(
			rules.yield_resource_ids(terrain_id),
			expected,
			"§4.2/§5.1: digging %s yields %s" % [terrain_id, resource_id]
		)


## §4.2 — the whole "Yield on dig" column, row by row. The vein rows' lumps are §12.1's
## `vein_nodes.<id>.lump` (gold 25 · iron 10 · magestone 15 · mithril 10); `artificial_granite`'s
## +2 Stone is the (AU)(i) amendment, whose AUTHORITY is §4.2's own row.
func test_yield_amount_for_every_solid_row() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		var resource_id: String = YIELD_RESOURCE[terrain_id]
		var expected: int = YIELD_AMOUNT[terrain_id]
		assert_eq(
			rules.yield_amount(terrain_id, resource_id),
			expected,
			"§4.2: digging %s yields \\+%d %s" % [terrain_id, expected, resource_id]
		)


## §4.2/§5.1 — a row yields its OWN resource and nothing else: every other §5.1 id answers 0.
func test_a_row_yields_no_other_resource() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		for resource_id: String in RESOURCE_IDS:
			if resource_id == YIELD_RESOURCE[terrain_id]:
				continue
			assert_eq(
				rules.yield_amount(terrain_id, resource_id),
				0,
				"§4.2: digging %s yields no %s" % [terrain_id, resource_id]
			)


## §5.1 — the seven-resource vocabulary is transcribed in full, so the sweep above is exhaustive.
func test_the_resource_vocabulary_is_the_seven_printed_ones() -> void:
	assert_eq(RESOURCE_IDS.size(), 7, "§5.1: Food, Gold, Stone, Iron, Magestone, Mithril, Scrap")


# =============================================================================================
# C. VEIN NODES (§4.2's "+ node"; §5.2 line 292 is what will consume them)
# =============================================================================================

## §4.2/§5.2 — "+ node" is printed on EXACTLY the four vein rows; the other five leave nothing.
func test_vein_resource_id_for_every_solid_row() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		var expected: String = VEIN_RESOURCE[terrain_id]
		assert_eq(
			rules.vein_resource_id(terrain_id),
			expected,
			(
				"§4.2/§5.2: %s leaves %s"
				% [terrain_id, "no node" if expected.is_empty() else "a %s node" % expected]
			)
		)


## §4.2 — exactly four rows carry a node, and each node's resource is also its lump's resource
## (§12.1's `vein_nodes` keys and §5.1's resource ids coincide for gold/iron/magestone/mithril).
func test_exactly_four_rows_leave_a_vein_node() -> void:
	var rules: DigRules = _dig_rules()
	var with_node: Array[String] = []
	for terrain_id: String in SOLID_TERRAIN_IDS:
		if not rules.vein_resource_id(terrain_id).is_empty():
			with_node.append(terrain_id)
	assert_eq(
		with_node,
		["gold_vein", "iron_vein", "magestone_crust", "mithril_seam"] as Array[String],
		"§4.2: Gold Vein, Iron Vein, Magestone Crust and Mithril Seam are the four \"+ node\" rows"
	)
	for terrain_id: String in with_node:
		var lump_resource_id: String = YIELD_RESOURCE[terrain_id]
		assert_eq(
			rules.vein_resource_id(terrain_id),
			lump_resource_id,
			"§4.2: %s's node and its lump are the same resource" % terrain_id
		)


## §5.2 NEGATIVE PIN — the vein NODE's stock/rate and the Extractor are a LATER M2 slice. DigRules
## answers the node's RESOURCE only; it exposes no stock, no rate and no Extractor rule, so a
## later slice cannot claim they were forgotten (§13.4). §12.1's `vein_nodes.<id>.stock`/`rate`
## stay reachable through the loader and are pinned by `tests/unit/test_rules_loader.gd`.
func test_dig_rules_exposes_no_vein_node_state_yet() -> void:
	var rules: DigRules = _dig_rules()
	for banned: String in ["stock", "rate", "node_stock", "node_rate", "extractor", "deplete"]:
		assert_false(
			rules.has_method(banned),
			"§5.2: vein-node STATE and Extractors are a later M2 slice — %s must not exist" % banned
		)


# =============================================================================================
# D. §4.2 LINE 197's TWO PROSE RULES — and both of their numbers are 2
# =============================================================================================

## §4.2 line 197 — "max 2 simultaneous diggers per hex", read from `dig.max_diggers_per_hex`.
func test_max_two_simultaneous_diggers_per_hex() -> void:
	assert_eq(
		_dig_rules().max_diggers_per_hex(),
		MAX_DIGGERS_PER_HEX,
		"§4.2 line 197: max 2 simultaneous diggers per hex"
	)


## §13.6 "constants read from data, not code" — PROVED BY MUTATION (the established pattern):
## patching the ruleset TEXT to 3 and reloading must move the answer to 3. A hard-coded 2 passes
## the test above and fails here. `data/ruleset.json` itself is never edited.
func test_the_digger_cap_is_read_from_data_not_hard_coded() -> void:
	var patched: RulesLoader = _loader_with_digger_cap(3)
	if patched == null:
		return
	assert_eq(
		DigRules.new(patched).max_diggers_per_hex(),
		3,
		"§13.6: the digger cap must come from dig.max_diggers_per_hex, never from a literal"
	)


## §4.2 line 197 — "\"Dig 2x\" halves remaining time (round up)" = ceil(n/2), hand-computed.
## THE TRAP: §4.2 line 197's two numbers are BOTH 2, so an implementation that read the halving
## divisor out of `dig.max_diggers_per_hex` passes every case here — which is exactly what the
## next test exists to catch.
func test_dig_two_x_halves_the_remaining_time_rounding_up() -> void:
	var rules: DigRules = _dig_rules()
	for remaining: int in HALVED.keys():
		var expected: int = HALVED[remaining]
		assert_eq(
			rules.halve_remaining_turns(remaining),
			expected,
			"§4.2 line 197: halving %d remaining turns (round up) gives %d" % [remaining, expected]
		)


## §4.2 line 197 + §13.6 — THE DIVISOR IS A MATHEMATICAL CONSTANT, NOT THE DIGGER CAP. Under a
## ruleset patched so `dig.max_diggers_per_hex` is 3, the halving must be UNCHANGED: 3 -> 2. An
## implementation that divided by the constant it read from data answers 1 here.
func test_halving_is_unaffected_by_the_digger_cap_constant() -> void:
	var patched: RulesLoader = _loader_with_digger_cap(3)
	if patched == null:
		return
	var rules: DigRules = DigRules.new(patched)
	assert_eq(rules.max_diggers_per_hex(), 3, "fixture: the patched cap really is 3")
	for remaining: int in HALVED.keys():
		var expected: int = HALVED[remaining]
		assert_eq(
			rules.halve_remaining_turns(remaining),
			expected,
			"§4.2 line 197: the halving divisor is a constant of the rule, not the digger cap"
		)


## §11.1 totality — a negative remaining time is meaningless, so it answers 0 rather than a
## negative or a crash (the (B)/(L)/(AU) spirit).
func test_halving_a_negative_remaining_time_answers_zero() -> void:
	var rules: DigRules = _dig_rules()
	for remaining: int in [-1, -2, -7, -100]:
		assert_eq(
			rules.halve_remaining_turns(remaining),
			0,
			"§11.1: a negative remaining time answers 0, never a negative (%d)" % remaining
		)


## §4.2 line 197 — halving is MONOTONE NON-INCREASING, never negative, and from ANY positive
## remaining time it converges to exactly 1 and STAYS there, because ceil(1/2) == 1. That fixed
## point is a real consequence of the printed rule and worth pinning: "Dig 2x" speeds a dig up but
## can NEVER finish it — the last worker-turn always has to be worked. (An implementation using
## floor instead of round-up would drive 1 to 0 and let a stacked Dig 2x complete a dig for free.)
func test_repeated_halving_converges_to_one_and_never_finishes_a_dig() -> void:
	var rules: DigRules = _dig_rules()
	for start: int in [1, 2, 3, 4, 5, 8, 9, 25]:
		var remaining: int = start
		for step: int in range(16):
			var next_value: int = rules.halve_remaining_turns(remaining)
			assert_lte(next_value, remaining, "§4.2: halving never grows the remaining time")
			assert_gte(
				next_value, 1, "§4.2 line 197: round-up means halving never finishes a dig"
			)
			remaining = next_value
		assert_eq(remaining, 1, "§4.2 line 197: repeated halving converges to 1 from %d" % start)
	assert_eq(rules.halve_remaining_turns(0), 0, "§4.2: a finished dig stays finished")


# =============================================================================================
# E. TOTALITY (§13.4 / the M1-T1 (B), M1-T3 (L), (AU) spirit) and the UNCONFIGURED state
# =============================================================================================

## §13.4 — an unknown or empty terrain id must never tear down a headless run: it is simply not
## diggable, and every accessor answers its zero/empty value for BOTH owner flags.
func test_an_unknown_terrain_id_is_not_diggable_and_answers_nothing() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in UNKNOWN_TERRAIN_IDS:
		assert_false(
			rules.is_diggable(terrain_id), "§4.2: \"%s\" is not a Solid row" % terrain_id
		)
		assert_eq(
			rules.dig_turns_for(terrain_id, false),
			0,
			"§13.4: \"%s\" has no dig time" % terrain_id
		)
		assert_eq(
			rules.dig_turns_for(terrain_id, true),
			0,
			"§13.4: \"%s\" has no owner dig time either" % terrain_id
		)
		assert_eq(
			rules.yield_resource_ids(terrain_id),
			[] as Array[String],
			"§13.4: \"%s\" yields nothing" % terrain_id
		)
		assert_eq(
			rules.vein_resource_id(terrain_id), "", "§13.4: \"%s\" leaves no node" % terrain_id
		)
		for resource_id: String in RESOURCE_IDS:
			assert_eq(
				rules.yield_amount(terrain_id, resource_id),
				0,
				"§13.4: \"%s\" yields no %s" % [terrain_id, resource_id]
			)


## §13.4 — an unknown RESOURCE id is equally harmless, on a real Solid row.
func test_an_unknown_resource_id_yields_zero() -> void:
	var rules: DigRules = _dig_rules()
	for terrain_id: String in SOLID_TERRAIN_IDS:
		for resource_id: String in ["", "obsidian", "not_a_resource"]:
			assert_eq(
				rules.yield_amount(terrain_id, resource_id),
				0,
				"§13.4: %s yields no \"%s\"" % [terrain_id, resource_id]
			)


## (AL) UNCONFIGURED PRECEDENT — a DigRules built on a NULL loader answers the unconfigured value
## everywhere, including `max_diggers_per_hex() == 0`. It must never crash and never invent a
## default: an absent ruleset is a data failure the loader already reported.
func test_a_null_loader_leaves_dig_rules_unconfigured() -> void:
	_assert_unconfigured(DigRules.new(null), "a null loader")


## (AL) — a loader whose load FAILED leaves `rules` EMPTY, and DigRules must read that as
## unconfigured too, not as "the ruleset says 0 turns".
func test_a_failed_loader_leaves_dig_rules_unconfigured() -> void:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text("{\"version\": \"2.0.0\"}", SOURCE)
	assert_false(ok, "fixture: a ruleset missing every required group must be rejected")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset is never published")
	_assert_unconfigured(DigRules.new(loader), "a failed load")


# =============================================================================================
# F. FRESHNESS (§11.1 "iterate collections in stable ID order"; the M1-T9 item 6 lesson)
# =============================================================================================

## §11.1 — `yield_resource_ids` hands back a FRESH Array[String] every call. The `is_same()`
## IDENTITY assertion is the load-bearing half: M1-T9 item 6 measured that a SELF-CLEARING member
## cache passes the weaker "pollution does not survive" shape while aliasing every caller.
func test_yield_resource_ids_returns_a_fresh_array_every_call() -> void:
	var rules: DigRules = _dig_rules()
	var first: Array[String] = rules.yield_resource_ids("hard_rock")
	var twin: Array[String] = rules.yield_resource_ids("hard_rock")
	assert_false(
		is_same(first, twin), "§11.1: every call returns its own array, never a shared member"
	)
	assert_eq(first, twin, "§11.1: two calls agree on the contents")
	first.append("polluted")
	first.clear()
	assert_eq(
		rules.yield_resource_ids("hard_rock"),
		["stone"] as Array[String],
		"§11.1: a caller's mutation cannot corrupt the next call"
	)


# =============================================================================================
# G. CROSS-DATA INTEGRITY — no generated hex may be undiggable by omission
# =============================================================================================

## §4.4/§13.6 — every terrain type the map generator can place (data/mapgen/concentric_bowl.json's
## `composition[].weights[].type`) must be diggable, or a generated map would contain hexes no
## worker could ever remove. That file is READ here and NEVER edited: the M1-T5 golden
## (`content_hash 0xcad24923`) hashes exactly what it produces.
func test_every_generated_terrain_type_is_diggable() -> void:
	var generated: Array[String] = _generated_terrain_types()
	assert_gt(generated.size(), 0, "fixture: %s must declare composition weights" % MAPGEN_PATH)
	var rules: DigRules = _dig_rules()
	for terrain_id: String in generated:
		assert_true(
			SOLID_TERRAIN_IDS.has(terrain_id),
			"§4.2: the generator may only place printed Solid rows (found \"%s\")" % terrain_id
		)
		assert_true(
			rules.is_diggable(terrain_id),
			"§4.4/§13.6: %s can place \"%s\" — it must be diggable" % [MAPGEN_PATH, terrain_id]
		)
		assert_gt(
			rules.dig_turns_for(terrain_id, false),
			0,
			"§4.2: a placeable terrain type needs a dig time (\"%s\")" % terrain_id
		)


# =============================================================================================
# H. MECHANICAL SOURCE SCANS on scripts/sim/systems/dig_rules.gd
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(DIG_RULES_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			DIG_RULES_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % DIG_RULES_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R) + "the sim never calls the
## renderer".
func test_source_is_engine_free_and_never_names_the_renderer() -> void:
	var code: String = _code_text(DIG_RULES_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core is engine-free — %s contains %s" % [DIG_RULES_PATH, banned]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [
				DIG_RULES_PATH, banned
			]
		)


## S3 (AV)/M1-T9 — DigRules CONSUMES an already-loaded RulesLoader; it loads no document, so
## `RulesError` must be ABSENT (a second loader must not be able to grow here) and it must not
## override `Object.hash()` (native_method_override is level 2 = a hard error).
func test_source_declares_no_second_loader_and_overrides_no_native_method() -> void:
	var code: String = _code_text(DIG_RULES_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	assert_false(
		code.contains("RulesError"),
		"M1-T9: %s reads a loaded ruleset — it must not carry the document error type" % [
			DIG_RULES_PATH
		]
	)
	assert_false(
		code.contains("load_text"),
		"M1-T9: %s must not load a document — RulesLoader is the one validator" % DIG_RULES_PATH
	)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			DIG_RULES_PATH
		]
	)
	assert_true(
		code.contains("RulesLoader"),
		"§12.1: %s reaches every constant through the one loader" % DIG_RULES_PATH
	)


## S4 (T)/(AH)/(AU)(iv)/§13.5 — NO VOCABULARY WHITELIST IN ENGINE CODE. §4.2's nine terrain ids
## and §5.1's seven resource ids are DATA: the terrain-id -> §12.1-key binding lives in
## `data/ruleset.json`'s `dig.profiles`, which is what will let M6's zero-engine-change canary
## hold. Scanned case-insensitively on COMMENT-STRIPPED source (the doc blocks legitimately quote
## the whole §4.2 table).
func test_source_carries_no_terrain_or_resource_id_whitelist() -> void:
	var code: String = _code_text(DIG_RULES_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	for terrain_id: String in SOLID_TERRAIN_IDS:
		assert_false(
			code.contains(terrain_id),
			"(T)/(AH): terrain ids are opaque data — %s must not name \"%s\"" % [
				DIG_RULES_PATH, terrain_id
			]
		)
	for resource_id: String in RESOURCE_IDS:
		assert_false(
			code.contains(resource_id),
			"(AU)(iv): resource ids are opaque data — %s must not name \"%s\"" % [
				DIG_RULES_PATH, resource_id
			]
		)
	assert_false(code.contains("enum "), "(AU)(iv): the vocabulary is never an enum")


## S5 §13.6 "constants read from data, not code" — NOT ONE §4.2/§12.1 dig number may appear in
## `dig_rules.gd`. 0, 1 and 2 are permitted (totality sentinels, the ceil's +1, and the halving
## divisor), and the divisor must be a NAMED PRIVATE const so it reads as a constant of the RULE
## rather than as a stray literal (the M1-T8 (AJ) precedent). §4.2 line 197 must be cited in the
## file's comments — which is also why this scan runs on comment-stripped source.
func test_source_hard_codes_no_table_number() -> void:
	var code: String = _code_text(DIG_RULES_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("(?<![0-9._])(3|4|10|15|25|60|120|150|250)(?![0-9._])"),
		OK,
		"sanity: the table-numeral pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(
		hit,
		"§13.6: dig constants live in data/ruleset.json — %s must not hard-code %s" % [
			DIG_RULES_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(FORBIDDEN_NUMERALS.size(), 9, "sanity: every §4.2/§12.1 dig numeral is covered")

	var named_divisor: RegEx = RegEx.new()
	assert_eq(
		named_divisor.compile("const\\s+_[A-Z][A-Z0-9_]*\\s*:\\s*int\\s*=\\s*2\\b"),
		OK,
		"sanity: the named-divisor pattern compiles"
	)
	assert_not_null(
		named_divisor.search(code),
		(
			"§4.2 line 197/(AJ): the halving divisor must be a NAMED PRIVATE const "
			+ "(`const _SOME_NAME: int = 2`) in %s, never a bare literal" % DIG_RULES_PATH
		)
	)
	assert_true(
		_raw_text(DIG_RULES_PATH).contains("§4.2"),
		"§11.3: %s must cite the section it implements" % DIG_RULES_PATH
	)


## S6 §13.6 — the numbers must FLOW: loader -> `dig.profiles.<id>` -> the §12.1 key. The schema
## paths and profile leaf names below are DigRules' CONTRACT with data (exactly as
## `RulesLoader._spec()` already holds them), so their presence is what makes S5's absence of
## every table numeral mean "read from data" rather than "not implemented".
func test_source_reads_every_value_through_the_section_twelve_one_schema() -> void:
	var code: String = _code_text(DIG_RULES_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	for token: String in REQUIRED_SCHEMA_TOKENS:
		assert_true(
			code.contains(token),
			"§12.1/§13.6: %s must reach its constants through \"%s\"" % [DIG_RULES_PATH, token]
		)


## S7 (J) NEGATIVE PIN — this slice rides NO part of the (AV) command spine. DigRules is a pure
## lookup over loaded data: it mutates no GameState, constructs no Command and emits no Event, so
## §13.6's "events emitted for every state change" is VACUOUS here. The FIRST dig-side consumer of
## the spine is the NEXT slice's DigHexCommand.
func test_source_adds_no_command_and_no_state_mutation() -> void:
	var code: String = _code_text(DIG_RULES_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_RULES_PATH)
	for banned: String in SPINE_TOKENS:
		assert_false(
			code.contains(banned),
			"(J): DigRules answers questions, it never mutates — %s must not name %s" % [
				DIG_RULES_PATH, banned
			]
		)


## S8 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (a setter, a vein-node accessor, a dig-site
## state field) fails too. ZERO public vars and ZERO public consts: DigRules is a lookup, and
## every number it knows belongs to data.
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_RULES_PATH, public_functions, undocumented)

	var rules: DigRules = _dig_rules()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, DIG_RULES_PATH]
		)
		assert_true(
			rules.has_method(required),
			"§11.2: %s must be callable on a DigRules instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			DIG_RULES_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(DIG_RULES_PATH),
		REQUIRED_PUBLIC_VARS,
		"§11.3: %s declares ZERO public vars — it is an immutable lookup" % DIG_RULES_PATH
	)
	assert_eq(
		_collect_public_consts(DIG_RULES_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.6: %s declares ZERO public consts — its numbers live in data" % DIG_RULES_PATH
	)


## S9 §11.1/§11.2 — DigRules is a pure [RefCounted] living in `scripts/sim/systems/`, the
## directory §11.2 line 724 prints verbatim ("systems/ (economy, breach, escalation, victory)").
## Asserted through get_class() — `is Node` would be a PARSE ERROR here.
func test_dig_rules_is_a_pure_refcounted_in_scripts_sim_systems() -> void:
	assert_true(
		FileAccess.file_exists(DIG_RULES_PATH),
		"§11.2: DigRules belongs at %s" % DIG_RULES_PATH
	)
	assert_eq(
		DigRules.new(null).get_class(),
		"RefCounted",
		"§11.1: DigRules must be a pure RefCounted — never Node/SceneTree"
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


func _dig_rules() -> DigRules:
	return DigRules.new(_loaded())


## Every accessor of an UNCONFIGURED DigRules answers its zero/empty value (the (AL) CameraRig
## precedent): no crash, no invented default.
func _assert_unconfigured(rules: DigRules, why: String) -> void:
	assert_eq(rules.max_diggers_per_hex(), 0, "(AL): %s leaves the digger cap unconfigured" % why)
	var probed: Array[String] = []
	probed.append_array(SOLID_TERRAIN_IDS)
	probed.append_array(UNKNOWN_TERRAIN_IDS)
	for terrain_id: String in probed:
		assert_false(rules.is_diggable(terrain_id), "(AL): %s makes nothing diggable" % why)
		assert_eq(rules.dig_turns_for(terrain_id, false), 0, "(AL): %s has no dig times" % why)
		assert_eq(rules.dig_turns_for(terrain_id, true), 0, "(AL): %s has no owner times" % why)
		assert_eq(
			rules.yield_resource_ids(terrain_id),
			[] as Array[String],
			"(AL): %s yields nothing" % why
		)
		assert_eq(rules.vein_resource_id(terrain_id), "", "(AL): %s leaves no node" % why)
		assert_eq(rules.yield_amount(terrain_id, "stone"), 0, "(AL): %s yields no amount" % why)
	for remaining: int in HALVED.keys():
		var expected: int = HALVED[remaining]
		assert_eq(
			rules.halve_remaining_turns(remaining),
			expected,
			"§4.2 line 197: halving is arithmetic and survives %s" % why
		)


## A loader over the shipped ruleset TEXT with `dig.max_diggers_per_hex` patched to `cap`. Returns
## null (having reported why) when the fixture cannot be built — the `dig` group is the M2-T3
## deliverable, so its absence is the point of the RED.
func _loader_with_digger_cap(cap: int) -> RulesLoader:
	var lines: PackedStringArray = _ruleset_lines()
	var idx: int = _find_line(lines, "\"max_diggers_per_hex\"", 0)
	assert_gte(
		idx,
		0,
		"§4.2 line 197/§12.1: %s must carry dig.max_diggers_per_hex" % RULESET_PATH
	)
	if idx < 0:
		return null
	lines[idx] = _replace_value(lines[idx], "max_diggers_per_hex", str(cap))
	var text: String = "\n".join(lines)
	var probe: JSON = JSON.new()
	assert_eq(probe.parse(text), OK, "fixture: the patched ruleset must still be valid JSON")
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_true(ok, "fixture: a ruleset with cap %d must still validate" % cap)
	if not ok:
		return null
	return loader


## Every terrain type `data/mapgen/concentric_bowl.json` can place, in document order (READ ONLY —
## the M1-T5 golden 0xcad24923 hashes what that file produces).
func _generated_terrain_types() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(MAPGEN_PATH):
		assert_false(true, "fixture: %s must exist" % MAPGEN_PATH)
		return out
	var parsed: JSON = JSON.new()
	assert_eq(
		parsed.parse(FileAccess.get_file_as_string(MAPGEN_PATH)),
		OK,
		"fixture: %s must be valid JSON" % MAPGEN_PATH
	)
	var data: Variant = parsed.data
	if not (data is Dictionary):
		return out
	var composition: Variant = (data as Dictionary).get("composition", [])
	if not (composition is Array):
		return out
	for band: Variant in (composition as Array):
		if not (band is Dictionary):
			continue
		var weights: Variant = (band as Dictionary).get("weights", [])
		if not (weights is Array):
			continue
		for weight: Variant in (weights as Array):
			if not (weight is Dictionary):
				continue
			var terrain_id: Variant = (weight as Dictionary).get("type", "")
			if terrain_id is String and not out.has(terrain_id):
				out.append(terrain_id)
	return out


## Raw ruleset text, newline-normalized so line indices are stable on any checkout.
func _ruleset_text() -> String:
	if not FileAccess.file_exists(RULESET_PATH):
		return ""
	return FileAccess.get_file_as_string(RULESET_PATH).replace("\r\n", "\n")


func _ruleset_lines() -> PackedStringArray:
	return _ruleset_text().split("\n")


## First line index at or after `from_index` containing `token`, or -1.
func _find_line(lines: PackedStringArray, token: String, from_index: int) -> int:
	for i: int in range(from_index, lines.size()):
		if lines[i].contains(token):
			return i
	return -1


## Replaces `key`'s JSON value inside a single line, leaving the line count untouched.
func _replace_value(line: String, key: String, new_value: String) -> String:
	var re: RegEx = RegEx.new()
	var pattern: String = (
		"\"%s\"\\s*:\\s*(\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}|\\[[^\\]]*\\]|\"[^\"]*\"|-?[0-9]+(?:\\.[0-9]+)?)"
		% key
	)
	var compiled: int = re.compile(pattern)
	assert_eq(compiled, OK, "fixture helper: the value pattern for %s must compile" % key)
	if compiled != OK:
		return line
	var patched: String = re.sub(line, "\"%s\": %s" % [key, new_value], false)
	assert_ne(patched, line, "fixture: %s must appear on the anchored line" % key)
	return patched


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
	return _collect_declarations(path, "var ")


## Every top-level public `const` declared by a source file, in source order.
func _collect_public_consts(path: String) -> Array[String]:
	return _collect_declarations(path, "const ")


func _collect_declarations(path: String, keyword: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with(keyword):
			continue
		var rest: String = raw_line.substr(keyword.length())
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
## tripped by a doc comment that quotes the very table being enforced.
func _code_text(path: String) -> String:
	var code_lines: PackedStringArray = PackedStringArray()
	for raw_line: String in _raw_text(path).split("\n"):
		var comment_at: int = raw_line.find("#")
		code_lines.append(raw_line if comment_at == -1 else raw_line.substr(0, comment_at))
	return "\n".join(code_lines)
