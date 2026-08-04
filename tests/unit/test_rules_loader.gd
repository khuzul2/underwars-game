## RulesLoader + data/ruleset.json — GDD §12.1 (the ruleset constant set) and the still-open
## §14 M0 acceptance clause: "invalid ruleset rejected with a **line-numbered** error".
## §13.2 pyramid tier 1 (unit tests). Phase-1 substitute for tools/content_cli.gd (§13.1).
##
## Every §12.1 constant is asserted through the loader's typed accessors. This file is the only
## place those numbers may appear outside data/ruleset.json — its whole job is to prove the two
## agree, so that engine code never needs a literal (§11.3 "no magic numbers", §13.6 "constants
## read from data, not code").
##
## Line-number contract, probed empirically on the pinned Godot 4.7-stable build (2026-08-04):
##   - `JSON.get_error_line()` is **0-based** (a bad token on physical line 3 reports 2), so the
##     loader must normalize: RulesError.line is 1-based, first line of the document == 1.
##   - Godot's JSON parser **accepts** trailing commas, so a trailing comma is not a usable
##     syntax-error fixture — these tests plant an unquoted bareword value instead.
##   - Every JSON number parses as TYPE_FLOAT (even `1` and `250`), which is exactly why
##     test_reject_non_integral_value_where_int_required exists: the loader must accept a float
##     that is integral and reject one that is not, never silently truncate.
##
## Fixtures for the rejection cases are derived from the real data/ruleset.json (read here, in
## the test, and handed to load_text as a plain String — the loader itself stays filesystem-free
## per §11.1), then a single defect is planted on a located line. No expected line number is ever
## a magic constant: each test computes it from the fixture it just built.
extends GutTest

const RULESET_PATH: String = "res://data/ruleset.json"
const MISSING_PATH: String = "res://data/__no_such_ruleset__.json"
const MAPGEN_PATH: String = "res://data/mapgen/concentric_bowl.json"
const SOURCE: String = "ruleset.json"
const EPS: float = 1e-9

## M0-T2 item 7 — `data/ruleset.json`'s layout is load-bearing: line 1 is a lone `{` and each
## §12.1 top-level group sits entirely on one line. `dig_yields` is the fourth line (1-based:
## `{`, version, dig_turns, dig_yields), which is where M0-T2 item 3's forward-scan fallback
## attributes a missing dig_yields CHILD.
const DIG_YIELDS_LINE: int = 4

## §4.2's Solid-hex rows that carry a Stone/Food yield, in table order — which is also
## `dig_turns`'s key order in §12.1. `artificial_granite` is the M2-T1 addition (M0-T2 item 10).
const DIG_YIELD_KEYS: Array[String] = [
	"soft",
	"hard",
	"granite",
	"artificial_granite",
	"rubble",
]

## The exact JSON member M2-T1 inserts into `dig_yields` (§4.2: Artificial Granite yields
## \+2 Stone). Written with its trailing separator so removing it leaves valid JSON and an
## unchanged line count — the fixture for the missing-key rejection below. The `: {"stone": 2}`
## suffix is what makes it unambiguous: `dig_turns` also carries an `"artificial_granite"` key.
const ARTIFICIAL_GRANITE_YIELD: String = "\"artificial_granite\": {\"stone\": 2}, "

## M0-T2 item 7 layout, extended by M2-T3: the WHOLE new `dig` group sits on ONE line inserted
## immediately AFTER `dig_yields`, so `dig_yields` stays line 4 and `dig` is line 5. Every `dig`
## schema error is therefore attributed to this line by M0-T2 item 3's forward scan.
const DIG_LINE: int = 5

## §4.2 line 197 "max 2 simultaneous diggers per hex".
const MAX_DIGGERS_PER_HEX: int = 2

## §4.2's nine Solid terrain ids in TABLE ROW ORDER — the order `dig.profiles` is AUTHORED in.
const DIG_PROFILE_IDS_ROW_ORDER: Array[String] = [
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

## The same nine ids ASCENDING — the canonical order `get_keys` must answer in, and deliberately
## NOT the authored order above (which is what makes the map-kind ordering test meaningful).
const DIG_PROFILE_IDS_ASCENDING: Array[String] = [
	"artificial_granite",
	"dense_granite",
	"gold_vein",
	"hard_rock",
	"iron_vein",
	"magestone_crust",
	"mithril_seam",
	"rubble",
	"soft_dirt",
]

## The four string leaves every `dig.profiles.<id>` entry carries. "" means not-applicable.
const PROFILE_LEAVES: Array[String] = [
	"turns_key",
	"owner_turns_key",
	"yield_key",
	"vein_key",
]

## THE BINDING M2-T3 PUTS IN DATA: §4.2's terrain ids -> the §12.1 constant keys that govern them.
## Authored as [turns_key, owner_turns_key, yield_key, vein_key]. §4.2's ids (`soft_dirt`, ...) and
## §12.1's dig keys (`soft`, `hard`, `vein`, `mithril`, ...) are two DIFFERENT vocabularies with no
## binding anywhere in the repo before this task; keeping it in DATA is what keeps terrain ids out
## of engine code (the (T)/(AH)/(AU)(iv) no-whitelist rule) and what lets §13.5's M6
## zero-engine-change canary hold. The four vein rows read their lump from `vein_nodes.<vein_key>`,
## and `vein_key` doubles as the §5.1 resource id (gold/iron/magestone/mithril coincide in both).
const DIG_PROFILES: Dictionary = {
	"soft_dirt": ["soft", "", "soft", ""],
	"hard_rock": ["hard", "", "hard", ""],
	"dense_granite": ["granite", "", "granite", ""],
	"artificial_granite":
		["artificial_granite", "artificial_granite_owner", "artificial_granite", ""],
	"rubble": ["rubble", "", "rubble", ""],
	"gold_vein": ["vein", "", "", "gold"],
	"iron_vein": ["vein", "", "", "iron"],
	"magestone_crust": ["vein", "", "", "magestone"],
	"mithril_seam": ["mithril", "", "", "mithril"],
}

## The §12.1 group each profile leaf points into, in PROFILE_LEAVES order — used to prove every
## authored binding actually RESOLVES, so no §4.2 row can point at a key that does not exist.
const PROFILE_LEAF_GROUPS: Array[String] = [
	"dig_turns",
	"dig_turns",
	"dig_yields",
	"vein_nodes",
]


# ---------------------------------------------------------------------------------------------
# A. VALID LOAD — every §12.1 value, read through the accessors.
# ---------------------------------------------------------------------------------------------

## §14 (M0 deliverables) — the shipped ruleset loads clean; a successful load publishes rules.
func test_on_disk_ruleset_loads_without_errors() -> void:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(RULESET_PATH)
	assert_true(ok, "§14: %s must load successfully" % RULESET_PATH)
	assert_eq(_error_lines(loader), [] as Array[String], "§14: a valid ruleset yields no errors")
	assert_false(loader.rules.is_empty(), "§12.1: a successful load publishes the ruleset")


## §12.1 — the ruleset version string (§11.1 save/load stores it alongside seed + command log).
func test_version() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_string("version"), "2.0.0", "§12.1 version")


## §12.1 — dig_turns (turns to dig each material).
func test_dig_turns() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("dig_turns.soft"), 1, "§12.1 dig_turns.soft")
	assert_eq(loader.get_int("dig_turns.hard"), 2, "§12.1 dig_turns.hard")
	assert_eq(loader.get_int("dig_turns.granite"), 4, "§12.1 dig_turns.granite")
	assert_eq(loader.get_int("dig_turns.artificial_granite"), 3, "§12.1 dig_turns.artificial_granite")
	assert_eq(
		loader.get_int("dig_turns.artificial_granite_owner"),
		1,
		"§12.1 dig_turns.artificial_granite_owner"
	)
	assert_eq(loader.get_int("dig_turns.rubble"), 1, "§12.1 dig_turns.rubble")
	assert_eq(loader.get_int("dig_turns.vein"), 2, "§12.1 dig_turns.vein")
	assert_eq(loader.get_int("dig_turns.mithril"), 4, "§12.1 dig_turns.mithril")


## §12.1 + §5.1 — dig_yields, keyed by the §5.1 resource names.
##
## M2-T1 CLOSES THE M0-T2 item-10 CROSS-TABLE GAP. §4.2's Solid-hex table (line 185) prints
## "Artificial Granite | 3 (owner: 1) | **\\+2 Stone**", but the §12.1 `dig_yields` excerpt
## omitted `artificial_granite` entirely — recorded by M0-T2 item 10 as a known gap and
## explicitly deferred to M2 ("M2 (Dig & Economy) must add it with its own decisions.md entry").
## The value below is transcribed from the §4.2 row, and the §12.1 line is amended to match in
## the same commit as the decisions.md entry (CLAUDE.md: only the Land stage edits the GDD).
## Every unchanged neighbour is re-asserted so the edit cannot drift the rest of the group.
func test_dig_yields() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("dig_yields.soft.food"), 1, "§12.1/§5.1 dig_yields.soft.food")
	assert_eq(loader.get_int("dig_yields.hard.stone"), 2, "§12.1/§5.1 dig_yields.hard.stone")
	assert_eq(loader.get_int("dig_yields.granite.stone"), 4, "§12.1/§5.1 dig_yields.granite.stone")
	assert_eq(
		loader.get_int("dig_yields.artificial_granite.stone"),
		2,
		"§4.2 (Artificial Granite yields \\+2 Stone) / §12.1 dig_yields.artificial_granite.stone"
	)
	assert_eq(loader.get_int("dig_yields.rubble.stone"), 1, "§12.1/§5.1 dig_yields.rubble.stone")


## §12.1 + §4.2 — the (AU)(i) key is REQUIRED by the schema, not merely present in the shipped
## file: deleting it must be rejected with a line-numbered error (§14 M0's still-binding
## acceptance clause) and the ruleset must stay unpublished.
##
## THE EXPECTED LINE MOVED FROM 4 TO 5 AT M2-T3, and the reason is a VOCABULARY COLLISION, not a
## loader bug — flagged here because it is the one landed assertion this task changes. Until M2-T3
## the deletion left NO `"artificial_granite"` token at or after the `"dig_yields"` line
## (`dig_turns` sits ABOVE it), so M0-T2 item 3's forward-scan FALLBACK fired and attributed the
## error to the group line, 4. M2-T3's `dig` group sits on line 5 and its profile map is keyed by
## §4.2's TERRAIN ids — one of which is literally `artificial_granite` — so the forward scan now
## finds a real token on line 5 and the fallback no longer fires. The layout is the one the task
## mandates (`dig_yields` stays line 4; the whole `dig` group is line 5), the loader's documented
## algorithm is unchanged, and every OTHER attribution is unaffected because `dig` sits BELOW
## `dig_yields` and ABOVE nothing that shares a key name.
func test_reject_missing_dig_yields_artificial_granite() -> void:
	var text: String = _ruleset_text()
	var present: bool = text.contains(ARTIFICIAL_GRANITE_YIELD)
	assert_true(
		present,
		"§4.2/§12.1: data/ruleset.json must carry `%s` inside dig_yields (Artificial Granite "
		% ARTIFICIAL_GRANITE_YIELD
		+ "yields \\+2 Stone), inserted between \"granite\" and \"rubble\""
	)
	if not present:
		return
	var patched: String = text.replace(ARTIFICIAL_GRANITE_YIELD, "")
	assert_ne(patched, text, "fixture: the planted defect must actually change the document")
	if not _require_parses(patched):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(patched, SOURCE)
	assert_false(ok, "§12.1: dig_yields.artificial_granite is REQUIRED, not optional")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_eq(loader.errors.size(), 1, "§12.1: exactly one leaf is missing, so exactly one error")
	if loader.errors.is_empty():
		return
	var err: RulesError = loader.errors[0]
	assert_true(
		err.path == "dig_yields.artificial_granite"
		or err.path == "dig_yields.artificial_granite.stone",
		"§12.1: the error names the missing dotted path (got \"%s\")" % err.path
	)
	var patched_lines: PackedStringArray = patched.split("\n")
	assert_gte(patched_lines.size(), DIG_LINE, "fixture: the document still reaches the dig line")
	if patched_lines.size() >= DIG_LINE:
		assert_true(
			patched_lines[DIG_LINE - 1].contains("\"artificial_granite\""),
			"§4.2/§12.1: dig.profiles is keyed by TERRAIN ids, so line %d re-uses the name" % DIG_LINE
		)
	assert_eq(
		err.line,
		DIG_LINE,
		"§14/M0-T2 item 3: the forward scan finds the terrain-id token on the `dig` group line"
	)
	assert_true(
		err.message.contains("artificial_granite"), "§12.1: the message names the missing key"
	)


## §12.1 layout — M0-T2 item 7 made `data/ruleset.json`'s pretty-printing LOAD-BEARING (line 1 is
## a lone `{`; each top-level group sits entirely on one line) so single-line defects are
## plantable and expected line numbers are derivable. The new `dig_yields` member must therefore
## be inserted INTO the existing line, in §4.2 row order (which is also `dig_turns`'s key order):
## soft, hard, granite, artificial_granite, rubble.
func test_ruleset_layout_keeps_the_whole_dig_yields_group_on_one_line() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	assert_gte(lines.size(), DIG_YIELDS_LINE, "fixture: the document reaches the dig_yields line")
	if lines.size() < DIG_YIELDS_LINE:
		return
	assert_eq(lines[0].strip_edges(), "{", "M0-T2 item 7: line 1 of the ruleset is a lone `{`")

	var group: String = lines[DIG_YIELDS_LINE - 1]
	assert_true(
		group.contains("\"dig_yields\""),
		"M0-T2 item 7: the dig_yields group must stay on line %d" % DIG_YIELDS_LINE
	)
	for key: String in DIG_YIELD_KEYS:
		assert_true(
			group.contains("\"%s\"" % key),
			"§4.2/§12.1: dig_yields.%s must sit on the same line as its group" % key
		)
	assert_lt(
		group.find("\"granite\""),
		group.find("\"artificial_granite\""),
		"§4.2 row order: artificial_granite follows granite"
	)
	assert_lt(
		group.find("\"artificial_granite\""),
		group.find("\"rubble\""),
		"§4.2 row order: artificial_granite precedes rubble"
	)


## §12.1 + §5.2 — vein nodes: immediate lump, total stock, per-turn extractor rate.
func test_vein_nodes() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("vein_nodes.gold.lump"), 25, "§12.1 vein_nodes.gold.lump")
	assert_eq(loader.get_int("vein_nodes.gold.stock"), 250, "§12.1 vein_nodes.gold.stock")
	assert_eq(loader.get_int("vein_nodes.gold.rate"), 10, "§12.1 vein_nodes.gold.rate")
	assert_eq(loader.get_int("vein_nodes.iron.lump"), 10, "§12.1 vein_nodes.iron.lump")
	assert_eq(loader.get_int("vein_nodes.iron.stock"), 120, "§12.1 vein_nodes.iron.stock")
	assert_eq(loader.get_int("vein_nodes.iron.rate"), 6, "§12.1 vein_nodes.iron.rate")
	assert_eq(loader.get_int("vein_nodes.magestone.lump"), 15, "§12.1 vein_nodes.magestone.lump")
	assert_eq(loader.get_int("vein_nodes.magestone.stock"), 150, "§12.1 vein_nodes.magestone.stock")
	assert_eq(loader.get_int("vein_nodes.magestone.rate"), 6, "§12.1 vein_nodes.magestone.rate")
	assert_eq(loader.get_int("vein_nodes.mithril.lump"), 10, "§12.1 vein_nodes.mithril.lump")
	assert_eq(loader.get_int("vein_nodes.mithril.stock"), 60, "§12.1 vein_nodes.mithril.stock")
	assert_eq(loader.get_int("vein_nodes.mithril.rate"), 3, "§12.1 vein_nodes.mithril.rate")


## §12.1 + §6.1/§6.2 — damage formula constants: ARM*10, the [0, 200] clamp, the 75% counter,
## and the min-1 damage floor.
func test_combat_constants() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("combat.armor_factor"), 10, "§12.1/§6.1 combat.armor_factor")
	var clamp_range: Array[int] = loader.get_int_array("combat.effective_armor_clamp")
	assert_eq(clamp_range.size(), 2, "§12.1/§6.1 effective_armor_clamp is [min, max]")
	if clamp_range.size() == 2:
		assert_eq(clamp_range[0], 0, "§12.1/§6.1 effective_armor_clamp min")
		assert_eq(clamp_range[1], 200, "§12.1/§6.1 effective_armor_clamp max")
	assert_almost_eq(
		loader.get_float("combat.counter_ratio"), 0.75, EPS, "§12.1/§6.2 combat.counter_ratio"
	)
	assert_eq(loader.get_int("combat.min_damage"), 1, "§12.1/§6.1 combat.min_damage")


## §12.1 + §6.3 — positional modifiers (elevation, dark, cover/trench ARM bonuses).
func test_modifiers() -> void:
	var loader: RulesLoader = _loaded()
	assert_almost_eq(
		loader.get_float("modifiers.elevation_per_level"),
		0.15,
		EPS,
		"§12.1/§6.3 modifiers.elevation_per_level"
	)
	assert_almost_eq(
		loader.get_float("modifiers.elevation_max"), 0.30, EPS, "§12.1/§6.3 modifiers.elevation_max"
	)
	assert_almost_eq(
		loader.get_float("modifiers.dark_penalty"), 0.30, EPS, "§12.1/§6.3 modifiers.dark_penalty"
	)
	assert_eq(loader.get_int("modifiers.cover_arm"), 2, "§12.1/§6.3 modifiers.cover_arm")
	assert_eq(loader.get_int("modifiers.trench_arm"), 2, "§12.1/§6.3 modifiers.trench_arm")


## §12.1 + §4.7 — light emitter radii (BFS through cave hexes).
func test_light_radii() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("light.brazier_radius"), 2, "§12.1/§4.7 light.brazier_radius")
	assert_eq(loader.get_int("light.hq_radius"), 3, "§12.1/§4.7 light.hq_radius")
	assert_eq(loader.get_int("light.torch_radius"), 1, "§12.1/§4.7 light.torch_radius")


## §12.1 + §4.5 — structural integrity: support BFS radius, stress threshold, collapse odds
## and collapse (true) damage.
func test_structure_constants() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("structure.support_radius"), 2, "§12.1/§4.5 structure.support_radius")
	assert_eq(
		loader.get_int("structure.stress_collapse_threshold"),
		3,
		"§12.1/§4.5 structure.stress_collapse_threshold"
	)
	assert_almost_eq(
		loader.get_float("structure.collapse_chance"),
		0.25,
		EPS,
		"§12.1/§4.5 structure.collapse_chance"
	)
	assert_eq(loader.get_int("structure.collapse_damage"), 120, "§12.1/§4.5 structure.collapse_damage")


## §12.1 + §4.8 — Noise budgets and per-hex propagation costs.
func test_noise_constants() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("noise.dig"), 8, "§12.1/§4.8 noise.dig")
	assert_eq(loader.get_int("noise.blast"), 16, "§12.1/§4.8 noise.blast")
	assert_eq(loader.get_int("noise.cave_cost"), 1, "§12.1/§4.8 noise.cave_cost")
	assert_eq(loader.get_int("noise.solid_cost"), 2, "§12.1/§4.8 noise.solid_cost")


## §12.1 — Wrath of the Deep meter: accrual sources, decay, wave thresholds and post-wave reset.
func test_wrath_constants() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("wrath.mithril_per_turn"), 1, "§12.1 wrath.mithril_per_turn")
	assert_eq(loader.get_int("wrath.blast"), 5, "§12.1 wrath.blast")
	assert_eq(loader.get_int("wrath.wonder_start"), 15, "§12.1 wrath.wonder_start")
	assert_eq(loader.get_int("wrath.wonder_done"), 25, "§12.1 wrath.wonder_done")
	assert_eq(loader.get_int("wrath.throne_per_turn"), 2, "§12.1 wrath.throne_per_turn")
	assert_eq(loader.get_int("wrath.decay"), 1, "§12.1 wrath.decay")
	assert_eq(loader.get_int("wrath.reset"), 25, "§12.1 wrath.reset")
	var thresholds: Array[int] = loader.get_int_array("wrath.thresholds")
	assert_eq(thresholds.size(), 3, "§12.1 wrath.thresholds has three tiers")
	if thresholds.size() == 3:
		assert_eq(thresholds[0], 30, "§12.1 wrath.thresholds[0]")
		assert_eq(thresholds[1], 60, "§12.1 wrath.thresholds[1]")
		assert_eq(thresholds[2], 90, "§12.1 wrath.thresholds[2]")


## §12.1 + §5.2 — upkeep deficit bleed, HQ housing, per-tier train turns and tech costs.
## §5.2's prose ("takes 1–3 turns by tier") is superseded by its own parenthetical and by the
## §12.1 table: T1:1, T2:2, T3:3, T4:4 (tables win — CLAUDE.md / §0.3).
func test_upkeep_housing_training_and_tech_costs() -> void:
	var loader: RulesLoader = _loaded()
	assert_almost_eq(
		loader.get_float("upkeep_deficit_hp_pct"), 0.10, EPS, "§12.1 upkeep_deficit_hp_pct"
	)
	assert_eq(loader.get_int("housing.hq"), 6, "§12.1/§5.2 housing.hq (HQ +6)")
	var train_turns: Array[int] = loader.get_int_array("train_turns_by_tier")
	assert_eq(train_turns.size(), 4, "§12.1/§5.2 train_turns_by_tier covers T1-T4")
	if train_turns.size() == 4:
		assert_eq(train_turns[0], 1, "§12.1/§5.2 train_turns_by_tier T1")
		assert_eq(train_turns[1], 2, "§12.1/§5.2 train_turns_by_tier T2")
		assert_eq(train_turns[2], 3, "§12.1/§5.2 train_turns_by_tier T3")
		assert_eq(train_turns[3], 4, "§12.1/§5.2 train_turns_by_tier T4")
	var tech_costs: Array[int] = loader.get_int_array("tech_cost_by_tier")
	assert_eq(tech_costs.size(), 4, "§12.1 tech_cost_by_tier covers T1-T4")
	if tech_costs.size() == 4:
		assert_eq(tech_costs[0], 30, "§12.1 tech_cost_by_tier T1")
		assert_eq(tech_costs[1], 60, "§12.1 tech_cost_by_tier T2")
		assert_eq(tech_costs[2], 120, "§12.1 tech_cost_by_tier T3")
		assert_eq(tech_costs[3], 240, "§12.1 tech_cost_by_tier T4")


## §12.1 + §3.2 — victory conditions: throne hold, wonder survival, turn limit.
func test_victory_constants() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(loader.get_int("victory.throne_hold_turns"), 10, "§12.1/§3.2 victory.throne_hold_turns")
	assert_eq(
		loader.get_int("victory.wonder_survive_turns"), 8, "§12.1/§3.2 victory.wonder_survive_turns"
	)
	assert_eq(loader.get_int("victory.turn_limit"), 200, "§12.1/§3.2 victory.turn_limit")


## §12.1 — has() answers for present and absent dotted paths (the guard every rule function
## uses instead of hard-coding a fallback).
func test_has_resolves_dotted_paths() -> void:
	var loader: RulesLoader = _loaded()
	assert_true(loader.has("dig_turns.soft"), "§12.1: has() finds a nested constant")
	assert_true(loader.has("vein_nodes.gold.rate"), "§12.1: has() walks three levels")
	assert_true(loader.has("upkeep_deficit_hp_pct"), "§12.1: has() finds a top-level constant")
	assert_false(loader.has("dig_turns.obsidian"), "§12.1: has() rejects an unknown leaf")
	assert_false(loader.has("not_a_group"), "§12.1: has() rejects an unknown group")


# ---------------------------------------------------------------------------------------------
# B. REJECTION WITH A LINE-NUMBERED ERROR — the open §14 M0 acceptance clause.
# ---------------------------------------------------------------------------------------------

## §14 M0 — a JSON syntax error is reported with a 1-based line number pointing at the offending
## line, no key path, and a non-empty message. (Fixture: an unquoted bareword value. A trailing
## comma cannot be used — Godot's parser accepts it; probed 2026-08-04.)
func test_reject_json_syntax_error_with_1_based_line() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"light\"", 0)
	if not _require_anchor(idx, "\"light\""):
		return
	lines[idx] = _replace_value(lines[idx], "light", "oops")
	var text: String = "\n".join(lines)
	if not _require_syntax_error(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§14: a malformed ruleset must be rejected")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_gt(loader.errors.size(), 0, "§14: rejection must produce at least one error")
	if loader.errors.is_empty():
		return
	var err: RulesError = loader.errors[0]
	assert_eq(err.line, idx + 1, "§14: line is 1-based and points at the malformed line")
	assert_eq(err.path, "", "§14: a syntax error has no key path")
	assert_ne(err.message, "", "§14: the error must say what is wrong")


## §14 M0 + §12.1 — a missing required top-level group is caught, named by path, and attributed
## to a real line of the document (never the file-level 0).
func test_reject_missing_required_top_level_key() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"combat\"", 0)
	if not _require_anchor(idx, "\"combat\""):
		return
	assert_true(
		lines[idx].contains("\"armor_factor\""),
		"fixture: data/ruleset.json must keep each §12.1 group on ONE line so line attribution "
		+ "is meaningful (dropping the \"combat\" line must drop the whole group)"
	)
	lines.remove_at(idx)
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1: a ruleset missing a required group must be rejected")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_gt(loader.errors.size(), 0, "§12.1: the missing group must be reported")
	if loader.errors.is_empty():
		return
	var err: RulesError = loader.errors[0]
	assert_eq(err.path, "combat", "§12.1: the error names the missing key path")
	assert_true(err.message.contains("combat"), "§12.1: the message names the missing key")
	assert_gt(err.line, 0, "§14: a document-level error still points at a real (1-based) line")
	assert_lte(err.line, lines.size(), "§14: the reported line exists in the document")


## §14 M0 + §12.1 — a leaf of the wrong type is caught, with the dotted path, the line holding
## that key, and a message naming the expected type.
func test_reject_wrong_leaf_type() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"dig_turns\"", 0)
	if not _require_anchor(idx, "\"dig_turns\""):
		return
	assert_true(
		lines[idx].contains("\"soft\""),
		"fixture: \"dig_turns\" and its children must share one line (see §12.1 excerpt layout)"
	)
	lines[idx] = _replace_value(lines[idx], "soft", "\"one\"")
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1: dig_turns.soft is an integer, not a string")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_gt(loader.errors.size(), 0, "§12.1: the type error must be reported")
	if loader.errors.is_empty():
		return
	var err: RulesError = loader.errors[0]
	assert_eq(err.path, "dig_turns.soft", "§12.1: the error names the offending dotted path")
	assert_eq(err.line, idx + 1, "§14: the error points at the line holding that key (1-based)")
	assert_true(
		err.message.to_lower().contains("int"), "§12.1: the message names the expected type"
	)


## §14 M0 + §12.1 — every JSON number arrives as a float on this engine (probed), so an int
## constant given a fractional value must be REJECTED, never silently truncated.
func test_reject_non_integral_value_where_int_required() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"dig_turns\"", 0)
	if not _require_anchor(idx, "\"dig_turns\""):
		return
	lines[idx] = _replace_value(lines[idx], "soft", "1.5")
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1: dig_turns.soft = 1.5 is not an integer and must be rejected")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_gt(loader.errors.size(), 0, "§12.1: the non-integral value must be reported")
	if loader.errors.is_empty():
		return
	assert_eq(loader.errors[0].path, "dig_turns.soft", "§12.1: the error names the dotted path")
	assert_eq(loader.errors[0].line, idx + 1, "§14: 1-based line of the offending key")


## §14 M0 + §12.1 — fixed-length arrays are shape-checked: effective_armor_clamp is [min, max].
func test_reject_wrong_array_shape_for_armor_clamp() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"combat\"", 0)
	if not _require_anchor(idx, "\"combat\""):
		return
	lines[idx] = _replace_value(lines[idx], "effective_armor_clamp", "[0]")
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1/§6.1: effective_armor_clamp must hold exactly two numbers")
	assert_gt(loader.errors.size(), 0, "§12.1: the shape error must be reported")
	if loader.errors.is_empty():
		return
	assert_eq(
		loader.errors[0].path,
		"combat.effective_armor_clamp",
		"§12.1: the error names the offending array"
	)
	assert_eq(loader.errors[0].line, idx + 1, "§14: 1-based line of the offending key")


## §14 M0 + §12.1 — the per-tier tables are 4 long and wrath.thresholds is 3 long; any other
## length is rejected and named.
func test_reject_wrong_array_shape_for_tier_tables() -> void:
	_assert_shape_rejected("\"train_turns_by_tier\"", "train_turns_by_tier", "[1, 2, 3]")
	_assert_shape_rejected("\"tech_cost_by_tier\"", "tech_cost_by_tier", "[30, 60, 120, 240, 480]")
	_assert_shape_rejected("\"wrath\"", "thresholds", "[30, 60]", "wrath.thresholds")


## §14 M0 + §12.1 — a scalar where a group is required is rejected and named.
func test_reject_wrong_container_type() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"light\"", 0)
	if not _require_anchor(idx, "\"light\""):
		return
	lines[idx] = _replace_value(lines[idx], "light", "3")
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1/§4.7: \"light\" is a group of radii, not a number")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_gt(loader.errors.size(), 0, "§12.1: the container-type error must be reported")
	if loader.errors.is_empty():
		return
	assert_eq(loader.errors[0].path, "light", "§12.1: the error names the offending group")
	assert_eq(loader.errors[0].line, idx + 1, "§14: 1-based line of the offending key")


## §14 M0 — a file-level failure (missing file) is the ONLY case allowed to carry line 0
## ("no line"), and it must name the path it tried.
func test_reject_missing_file_with_no_line() -> void:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(MISSING_PATH)
	assert_false(ok, "§14: a missing ruleset file must be rejected")
	assert_true(loader.rules.is_empty(), "§14: nothing is published when the file is missing")
	assert_eq(loader.errors.size(), 1, "§14: a missing file is exactly one error")
	if loader.errors.size() != 1:
		return
	assert_eq(loader.errors[0].line, 0, "§14: 0 means 'no line' and is reserved for file errors")
	assert_true(
		loader.errors[0].message.contains(MISSING_PATH), "§14: the message names the path it tried"
	)


## §14 M0 — the rendered error is human-actionable: "<source>:<line>: <message>".
func test_error_renders_source_line_and_message() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, "\"dig_turns\"", 0)
	if not _require_anchor(idx, "\"dig_turns\""):
		return
	lines[idx] = _replace_value(lines[idx], "soft", "\"one\"")

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text("\n".join(lines), SOURCE)
	assert_false(ok, "§14: the fixture must be rejected before its rendering can be checked")
	assert_gt(loader.errors.size(), 0, "§14: rejection must produce an error to render")
	if loader.errors.is_empty():
		return
	var err: RulesError = loader.errors[0]
	var rendered: String = err.format_for(SOURCE)
	assert_true(rendered.begins_with(SOURCE + ":"), "§14: the rendering leads with the source")
	assert_true(rendered.contains(":%d:" % err.line), "§14: the rendering carries the line number")
	assert_eq(
		rendered,
		"%s:%d: %s" % [SOURCE, err.line, err.message],
		"§14: the rendering is exactly \"<source>:<line>: <message>\""
	)


# ---------------------------------------------------------------------------------------------
# C. DETERMINISM (§11.1) and D. PURITY (§11.1/§11.3).
# ---------------------------------------------------------------------------------------------

## §11.1 — validation is deterministic: the same document produces the same errors, in the same
## order, twice. Order follows the loader's own §12.1 spec order (dig_turns before victory),
## never the parse result's Dictionary key order.
func test_error_list_is_deterministic_and_in_spec_order() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var early: int = _find_line(lines, "\"dig_turns\"", 0)
	var late: int = _find_line(lines, "\"victory\"", 0)
	if not _require_anchor(early, "\"dig_turns\"") or not _require_anchor(late, "\"victory\""):
		return
	lines[early] = _replace_value(lines[early], "soft", "\"one\"")
	lines[late] = _replace_value(lines[late], "turn_limit", "\"never\"")
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var first: RulesLoader = RulesLoader.new()
	var second: RulesLoader = RulesLoader.new()
	assert_false(first.load_text(text, SOURCE), "§12.1: two bad leaves must be rejected")
	assert_false(second.load_text(text, SOURCE), "§12.1: two bad leaves must be rejected")
	assert_gte(first.errors.size(), 2, "§12.1: every defect is collected, not just the first")
	assert_eq(
		_error_lines(first), _error_lines(second), "§11.1: identical input ⇒ identical error list"
	)
	if first.errors.is_empty():
		return
	assert_eq(
		first.errors[0].path,
		"dig_turns.soft",
		"§11.1/§12.1: the first error is the earliest in §12.1 spec order"
	)


## §11.1/§11.3 — the validator is engine-free: pure RefCounted, never a Node, and load_text
## works on a String with no filesystem involvement (the test does the reading).
func test_loader_and_error_are_pure_refcounted() -> void:
	# get_class() reports the NATIVE base, so this pins "extends RefCounted" and "is not a Node"
	# in one assertion. (`loader is Node` cannot be written: GDScript rejects a statically
	# impossible cast at parse time, which would silently un-collect this whole script.)
	var loader: RulesLoader = RulesLoader.new()
	assert_eq(
		loader.get_class(),
		"RefCounted",
		"§11.1: sim-core classes extend RefCounted — never Node/SceneTree"
	)
	var err: RulesError = RulesError.new()
	assert_eq(
		err.get_class(), "RefCounted", "§11.1: RulesError extends RefCounted — never Node/SceneTree"
	)

	var text: String = _ruleset_text()
	if text.is_empty():
		assert_false(true, "fixture: %s must exist" % RULESET_PATH)
		return
	assert_true(loader.load_text(text, SOURCE), "§11.1: a whole ruleset validates from a String")
	assert_eq(_error_lines(loader), [] as Array[String], "§11.1: the valid document has no errors")


# ---------------------------------------------------------------------------------------------
# E. FORWARD COMPATIBILITY — §12.1 is explicitly an "excerpt".
# ---------------------------------------------------------------------------------------------

## §12.1 — the section is an excerpt, so an unknown top-level key is NOT an error; only missing
## or malformed required keys are. (This is what lets later milestones add constants without
## breaking older loaders.)
func test_unknown_top_level_key_is_accepted() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	assert_eq(lines[0].strip_edges(), "{", "fixture: the ruleset opens with a lone brace")
	lines.insert(1, "  \"a_future_group\": {\"not_yet_specified\": 1},")
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_true(ok, "§12.1: §12.1 is an excerpt — unknown keys must not be rejected")
	assert_eq(_error_lines(loader), [] as Array[String], "§12.1: unknown keys produce no errors")
	assert_eq(loader.get_int("dig_turns.soft"), 1, "§12.1: known constants still read correctly")


# ---------------------------------------------------------------------------------------------
# F. THE M2-T3 `dig` GROUP — §12.1's newest group and the loader's new "map" spec kind.
#
# §4.2's Solid table names TERRAIN types (soft_dirt, hard_rock, ...); §12.1's `dig_turns` /
# `dig_yields` / `vein_nodes` name CONSTANT KEYS (soft, hard, granite, vein, mithril, gold, ...).
# Nothing in the repo bound the two vocabularies together before M2-T3. `dig` is that binding, and
# it lives in DATA precisely so terrain ids never enter engine code ((T)/(AH)/(AU)(iv)) — which is
# also why `dig.profiles` cannot be a fixed spec node: its KEYS are content. Hence the new "map"
# spec kind (an object with author-chosen keys, every value validated against ONE shared entry
# spec) and the new `get_keys` accessor.
# ---------------------------------------------------------------------------------------------

## §4.2 line 197 + §12.1 — the shipped ruleset carries the digger cap, and it is exactly 2.
func test_dig_group_carries_the_max_diggers_per_hex_cap() -> void:
	var loader: RulesLoader = _loaded()
	assert_true(loader.has("dig.max_diggers_per_hex"), "§12.1: the `dig` group is REQUIRED")
	assert_eq(
		loader.get_int("dig.max_diggers_per_hex"),
		MAX_DIGGERS_PER_HEX,
		"§4.2 line 197: max 2 simultaneous diggers per hex"
	)


## §11.1 "iterate collections in stable ID order" — `get_keys` answers ASCENDING, never the parse
## result's key order (which is §4.2's row order, deliberately different).
func test_get_keys_answers_the_nine_dig_profiles_ascending() -> void:
	var loader: RulesLoader = _loaded()
	assert_eq(
		loader.get_keys("dig.profiles"),
		DIG_PROFILE_IDS_ASCENDING,
		"§11.1/§12.1: dig.profiles' keys come back ascending"
	)
	assert_eq(
		loader.get_keys("dig"),
		["max_diggers_per_hex", "profiles"] as Array[String],
		"§11.1: get_keys is ascending at every level"
	)
	assert_eq(
		DIG_PROFILE_IDS_ASCENDING.size(),
		DIG_PROFILE_IDS_ROW_ORDER.size(),
		"§4.2: the same nine Solid rows, in two different orders"
	)
	assert_ne(
		DIG_PROFILE_IDS_ASCENDING,
		DIG_PROFILE_IDS_ROW_ORDER,
		"fixture: sorted order really does differ from §4.2's row order — otherwise this test is"
		+ " vacuous"
	)


## §12.1 — `get_keys` is TOTAL: a missing path and a non-object leaf both answer an EMPTY array,
## never null and never a crash (the (B)/(L)/(AU) totality spirit).
func test_get_keys_is_empty_for_a_missing_path_or_a_non_object_leaf() -> void:
	var loader: RulesLoader = _loaded()
	for dotted_path: String in [
		"",
		"not_a_group",
		"dig.not_a_key",
		"dig.profiles.not_a_terrain",
		"version",
		"dig.max_diggers_per_hex",
		"train_turns_by_tier",
		"dig.profiles.soft_dirt.turns_key",
	]:
		assert_eq(
			loader.get_keys(dotted_path),
			[] as Array[String],
			"§12.1: get_keys(\"%s\") has no keys to answer" % dotted_path
		)


## §11.1 — `get_keys` hands back a FRESH array every call. The `is_same()` IDENTITY assertion is
## the load-bearing half (M1-T9 item 6: a self-clearing member cache passes the weaker
## "pollution does not survive" shape while aliasing every caller).
func test_get_keys_returns_a_fresh_array_every_call() -> void:
	var loader: RulesLoader = _loaded()
	var first: Array[String] = loader.get_keys("dig.profiles")
	var twin: Array[String] = loader.get_keys("dig.profiles")
	assert_false(is_same(first, twin), "§11.1: get_keys never hands out a shared array")
	assert_eq(first, twin, "§11.1: two calls agree on the contents")
	first.append("polluted")
	first.clear()
	assert_eq(
		loader.get_keys("dig.profiles"),
		DIG_PROFILE_IDS_ASCENDING,
		"§11.1: a caller's mutation cannot corrupt the next call"
	)


## §12.1/§4.2 — every one of the 36 authored profile leaves reads back verbatim. This is THE
## binding: `soft_dirt -> soft`, `artificial_granite -> artificial_granite` plus the owner key
## `artificial_granite_owner`, the three "vein" rows -> `dig_turns.vein` with the lump coming from
## `vein_nodes.<vein_key>`, and `mithril_seam -> mithril` for BOTH its turns and its vein.
func test_every_dig_profile_binds_the_section_twelve_one_keys_as_authored() -> void:
	var loader: RulesLoader = _loaded()
	for terrain_id: String in DIG_PROFILE_IDS_ROW_ORDER:
		assert_true(
			DIG_PROFILES.has(terrain_id), "fixture: %s is transcribed above" % terrain_id
		)
		var authored: Array = DIG_PROFILES[terrain_id]
		for i: int in range(PROFILE_LEAVES.size()):
			var leaf: String = PROFILE_LEAVES[i]
			var expected: String = authored[i]
			assert_eq(
				loader.get_string("dig.profiles.%s.%s" % [terrain_id, leaf]),
				expected,
				"§12.1: dig.profiles.%s.%s == \"%s\"" % [terrain_id, leaf, expected]
			)


## §12.1/§4.2 INTEGRITY — every non-empty binding must RESOLVE, so no §4.2 row can point at a
## §12.1 key that does not exist; and every row must yield something (a `yield_key` OR a
## `vein_key`), because §4.2's "Yield on dig" column has no blank cell.
func test_every_dig_profile_binding_resolves_in_the_ruleset() -> void:
	var loader: RulesLoader = _loaded()
	for terrain_id: String in DIG_PROFILE_IDS_ROW_ORDER:
		var yields_something: bool = false
		for i: int in range(PROFILE_LEAVES.size()):
			var leaf: String = PROFILE_LEAVES[i]
			var group: String = PROFILE_LEAF_GROUPS[i]
			var key: String = loader.get_string("dig.profiles.%s.%s" % [terrain_id, leaf])
			if key.is_empty():
				continue
			assert_true(
				loader.has("%s.%s" % [group, key]),
				"§12.1: dig.profiles.%s.%s points at %s.%s, which must exist" % [
					terrain_id, leaf, group, key
				]
			)
			if leaf == "yield_key" or leaf == "vein_key":
				yields_something = true
		assert_true(
			yields_something,
			"§4.2: every Solid row yields something — %s binds neither a yield nor a vein" % [
				terrain_id
			]
		)
		var turns_key: String = loader.get_string("dig.profiles.%s.turns_key" % terrain_id)
		assert_false(
			turns_key.is_empty(), "§4.2: every Solid row has a dig time — %s" % terrain_id
		)


## §14 M0 + §12.1 — `dig.max_diggers_per_hex` is REQUIRED, not merely present: deleting it is one
## line-numbered error, attributed to the `dig` group line, and the ruleset stays unpublished.
func test_reject_missing_max_diggers_per_hex() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_dig_line(lines):
		return
	lines[DIG_LINE - 1] = _delete_member(lines[DIG_LINE - 1], "max_diggers_per_hex")
	_assert_dig_rejection(lines, "dig.max_diggers_per_hex", "a missing digger cap")


## §14 M0 + §12.1 — the "map" kind validates EVERY entry against one shared spec, so a profile
## leaf of the wrong type is caught and named by its full dotted path (terrain id included).
func test_reject_non_string_profile_leaf() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_dig_line(lines):
		return
	# `_replace_value` rewrites the FIRST match on the line, which is §4.2's first row, soft_dirt.
	# ("owner_turns_key" cannot be hit by accident: the pattern is anchored on the opening quote.)
	lines[DIG_LINE - 1] = _replace_value(lines[DIG_LINE - 1], "turns_key", "1")
	_assert_dig_rejection(lines, "dig.profiles.soft_dirt.turns_key", "a non-string profile leaf")


## §14 M0 + §12.1 — the map itself is shape-checked: a scalar where the profile map belongs is
## rejected, and the loader does NOT descend into it.
func test_reject_non_object_dig_profiles() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_dig_line(lines):
		return
	lines[DIG_LINE - 1] = _replace_value(lines[DIG_LINE - 1], "profiles", "3")
	_assert_dig_rejection(lines, "dig.profiles", "a scalar where the profile map belongs")


## §14 M0 + §12.1 — AN EMPTY MAP IS REJECTED, deliberately and not by accident: a ruleset with no
## profiles would silently make EVERY hex undiggable, which is a content bug that must fail loud
## at load rather than quietly at turn 20 (§13.4 — pick the interpretation that cannot fail
## silently).
func test_reject_empty_dig_profiles() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_dig_line(lines):
		return
	lines[DIG_LINE - 1] = _replace_value(lines[DIG_LINE - 1], "profiles", "{}")
	_assert_dig_rejection(lines, "dig.profiles", "an empty profile map")


## §11.1 — THE MAP KIND'S ORDERING CONTRACT: its errors come back sorted by ASCENDING KEY, never
## in the parse result's key order. The class header has promised exactly this since M0-T2
## ("never the parse result's key order"), and for a fixed spec it is free; for an author-keyed
## map it has to be DONE. The two defects below are planted in entries whose document order
## (soft_dirt first, artificial_granite fourth) is the REVERSE of their sorted order, so an
## implementation that simply iterated the parsed Dictionary answers them the other way round.
func test_map_kind_errors_are_ordered_by_ascending_key() -> void:
	var probe: JSON = JSON.new()
	var text: String = _ruleset_text()
	assert_eq(probe.parse(text), OK, "fixture: the shipped ruleset must parse")
	var data: Variant = probe.data
	if not (data is Dictionary):
		assert_false(true, "fixture: the ruleset root is an object")
		return
	var root: Dictionary = data as Dictionary
	var profiles: Dictionary = _profiles_of(root)
	if profiles.is_empty():
		return
	for terrain_id: String in ["soft_dirt", "artificial_granite"]:
		if not profiles.has(terrain_id):
			assert_false(true, "§12.1: dig.profiles must carry \"%s\"" % terrain_id)
			return
		var entry: Dictionary = profiles[terrain_id]
		entry["turns_key"] = 1

	# `sort_keys` DEFAULTS TO TRUE on JSON.stringify (measured live this iteration on the pinned
	# 4.7 build): the default would alphabetize the document and destroy this fixture's whole
	# premise, since the point is that DOCUMENT order differs from SORTED order.
	var patched: String = JSON.stringify(root, "", false)
	var profiles_at: int = patched.find("\"profiles\"")
	assert_gt(profiles_at, 0, "fixture: the re-serialized document keeps the profile map")
	assert_lt(
		patched.find("\"soft_dirt\"", profiles_at),
		patched.find("\"artificial_granite\"", profiles_at),
		"fixture: document order must be soft_dirt BEFORE artificial_granite — the REVERSE of"
		+ " sorted order, or this test proves nothing"
	)

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(patched, SOURCE)
	assert_false(ok, "§12.1: two non-string profile leaves must be rejected")
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_eq(
		_error_paths(loader),
		[
			"dig.profiles.artificial_granite.turns_key",
			"dig.profiles.soft_dirt.turns_key",
		] as Array[String],
		"§11.1: map-kind errors are ordered by ASCENDING KEY, never by parse order"
	)


## M0-T2 item 7 (still load-bearing) — `data/ruleset.json`'s layout: line 1 is a lone `{`,
## `dig_yields` is still line 4, and the WHOLE `dig` group sits on ONE line, line 5. That is what
## makes the four rejections above plantable and their expected line number derivable.
func test_ruleset_layout_keeps_the_whole_dig_group_on_one_line() -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	assert_eq(lines[0].strip_edges(), "{", "M0-T2 item 7: line 1 of the ruleset is a lone `{`")
	assert_gte(lines.size(), DIG_LINE, "fixture: the document reaches the dig line")
	if lines.size() < DIG_LINE:
		return
	assert_true(
		lines[DIG_YIELDS_LINE - 1].contains("\"dig_yields\""),
		"M0-T2 item 7: dig_yields stays on line %d — `dig` is inserted AFTER it" % DIG_YIELDS_LINE
	)
	var group: String = lines[DIG_LINE - 1]
	assert_true(
		group.contains("\"dig\""),
		"M0-T2 item 7: the whole `dig` group must sit on line %d" % DIG_LINE
	)
	assert_true(
		group.contains("\"max_diggers_per_hex\""),
		"§4.2 line 197: dig.max_diggers_per_hex sits on the group line"
	)
	assert_true(group.contains("\"profiles\""), "§12.1: dig.profiles sits on the group line")
	for terrain_id: String in DIG_PROFILE_IDS_ROW_ORDER:
		assert_true(
			group.contains("\"%s\"" % terrain_id),
			"§4.2/§12.1: dig.profiles.%s must sit on the same line as its group" % terrain_id
		)
	for i: int in range(DIG_PROFILE_IDS_ROW_ORDER.size() - 1):
		assert_lt(
			group.find("\"%s\"" % DIG_PROFILE_IDS_ROW_ORDER[i]),
			group.find("\"%s\"" % DIG_PROFILE_IDS_ROW_ORDER[i + 1]),
			"§4.2 row order: %s precedes %s" % [
				DIG_PROFILE_IDS_ROW_ORDER[i], DIG_PROFILE_IDS_ROW_ORDER[i + 1]
			]
		)


## §4.4/§13.6 CROSS-DATA INTEGRITY — every terrain type `data/mapgen/concentric_bowl.json` can
## place must have a `dig.profiles` entry, or a generated map would contain hexes no worker could
## ever remove. That file is READ here and NEVER edited (the M1-T5 golden 0xcad24923 hashes what
## it produces).
func test_every_generated_terrain_type_has_a_dig_profile() -> void:
	var loader: RulesLoader = _loaded()
	var profile_ids: Array[String] = loader.get_keys("dig.profiles")
	var generated: Array[String] = _generated_terrain_types()
	assert_gt(generated.size(), 0, "fixture: %s must declare composition weights" % MAPGEN_PATH)
	for terrain_id: String in generated:
		assert_true(
			profile_ids.has(terrain_id),
			"§4.4/§13.6: %s can place \"%s\" — dig.profiles must bind it" % [
				MAPGEN_PATH, terrain_id
			]
		)


# ---------------------------------------------------------------------------------------------
# Helpers (not tests — GUT only collects `test_`-prefixed methods).
# ---------------------------------------------------------------------------------------------

## Loads the shipped ruleset, asserting the load itself succeeded so a failure reports once,
## clearly, in every §12.1 value test.
func _loaded() -> RulesLoader:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(RULESET_PATH)
	assert_true(ok, "§12.1: %s must load before its constants can be read" % RULESET_PATH)
	return loader


## Raw ruleset text, newline-normalized so line indices are stable on any checkout.
func _ruleset_text() -> String:
	if not FileAccess.file_exists(RULESET_PATH):
		return ""
	return FileAccess.get_file_as_string(RULESET_PATH).replace("\r\n", "\n")


func _ruleset_lines() -> PackedStringArray:
	return _ruleset_text().split("\n")


## Renders the loader's errors as comparable strings — used both to assert "no errors" with a
## readable diff and to compare two runs for determinism (§11.1).
func _error_lines(loader: RulesLoader) -> Array[String]:
	var out: Array[String] = []
	for err: RulesError in loader.errors:
		out.append("%d|%s|%s" % [err.line, err.path, err.message])
	return out


func _require_fixture(lines: PackedStringArray) -> bool:
	var ok: bool = lines.size() > 2
	assert_true(
		ok,
		"fixture: %s must exist and be pretty-printed across lines (§12.1 excerpt layout)"
		% RULESET_PATH
	)
	return ok


func _require_anchor(index: int, token: String) -> bool:
	assert_gte(index, 0, "fixture: %s must appear in %s (§12.1)" % [token, RULESET_PATH])
	return index >= 0


## Precondition for the schema-error fixtures: the planted defect must be a SCHEMA defect, so
## the document still has to parse as JSON.
func _require_parses(text: String) -> bool:
	var probe: JSON = JSON.new()
	var err: int = probe.parse(text)
	assert_eq(err, OK, "fixture: the schema-error fixture must still be valid JSON")
	return err == OK


## Precondition for the syntax-error fixture: it must really be unparseable.
func _require_syntax_error(text: String) -> bool:
	var probe: JSON = JSON.new()
	var err: int = probe.parse(text)
	assert_ne(err, OK, "fixture: the syntax-error fixture must fail to parse")
	return err != OK


## Replaces `key`'s JSON value inside a single line, leaving the line count untouched so planted
## line numbers stay computable.
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
	assert_ne(patched, line, "fixture: %s must appear on the anchored line (§12.1 layout)" % key)
	return patched


## Shared body for the fixed-length-array shape cases (§12.1).
func _assert_shape_rejected(
	anchor: String, key: String, bad_value: String, expected_path: String = ""
) -> void:
	var lines: PackedStringArray = _ruleset_lines()
	if not _require_fixture(lines):
		return
	var idx: int = _find_line(lines, anchor, 0)
	if not _require_anchor(idx, anchor):
		return
	lines[idx] = _replace_value(lines[idx], key, bad_value)
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return

	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1: %s has a fixed length; %s must be rejected" % [key, bad_value])
	assert_gt(loader.errors.size(), 0, "§12.1: the shape error for %s must be reported" % key)
	if loader.errors.is_empty():
		return
	var wanted: String = expected_path if not expected_path.is_empty() else key
	assert_eq(loader.errors[0].path, wanted, "§12.1: the error names %s" % wanted)
	assert_eq(loader.errors[0].line, idx + 1, "§14: 1-based line of the offending key")


## First line index at or after `from_index` containing `token`, or -1.
func _find_line(lines: PackedStringArray, token: String, from_index: int) -> int:
	for i: int in range(from_index, lines.size()):
		if lines[i].contains(token):
			return i
	return -1


## Every error's dotted path, in the loader's own order — the comparable form for the map kind's
## ordering contract.
func _error_paths(loader: RulesLoader) -> Array[String]:
	var out: Array[String] = []
	for err: RulesError in loader.errors:
		out.append(err.path)
	return out


## Precondition for the four `dig` rejection fixtures: the M2-T3 group must be on its line. The
## `dig` group IS the deliverable, so its absence must report as itself, not as a helper crash.
func _require_dig_line(lines: PackedStringArray) -> bool:
	if not _require_fixture(lines):
		return false
	var ok: bool = (
		lines.size() >= DIG_LINE
		and lines[DIG_LINE - 1].contains("\"dig\"")
		and lines[DIG_LINE - 1].contains("\"profiles\"")
	)
	assert_true(
		ok,
		"§12.1/M2-T3: %s must carry the whole `dig` group on line %d" % [RULESET_PATH, DIG_LINE]
	)
	return ok


## Shared body for the four `dig` rejection cases: the patched document must still PARSE, must be
## rejected with EXACTLY ONE error naming `expected_path` at the `dig` group line, and must leave
## `rules` EMPTY (§14: a rejected ruleset is never published).
func _assert_dig_rejection(
	lines: PackedStringArray, expected_path: String, what: String
) -> void:
	var text: String = "\n".join(lines)
	if not _require_parses(text):
		return
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_text(text, SOURCE)
	assert_false(ok, "§12.1: %s must be rejected" % what)
	assert_true(loader.rules.is_empty(), "§14: a rejected ruleset must not be published")
	assert_eq(loader.errors.size(), 1, "§12.1: %s is exactly one error" % what)
	if loader.errors.size() != 1:
		return
	assert_eq(loader.errors[0].path, expected_path, "§12.1: the error names the dotted path")
	assert_eq(
		loader.errors[0].line,
		DIG_LINE,
		"§14/M0-T2 item 3: a `dig` defect is attributed to the group line (%d)" % DIG_LINE
	)
	assert_false(loader.errors[0].message.is_empty(), "§14: the error must say what is wrong")


## Deletes `key` and its JSON value (plus a following comma, if any) from a single line, leaving
## the line count untouched so planted line numbers stay computable.
func _delete_member(line: String, key: String) -> String:
	var re: RegEx = RegEx.new()
	var pattern: String = (
		"\"%s\"\\s*:\\s*(\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}|\\[[^\\]]*\\]|\"[^\"]*\"|-?[0-9]+(?:\\.[0-9]+)?)\\s*,?\\s*"
		% key
	)
	var compiled: int = re.compile(pattern)
	assert_eq(compiled, OK, "fixture helper: the deletion pattern for %s must compile" % key)
	if compiled != OK:
		return line
	var patched: String = re.sub(line, "", false)
	assert_ne(patched, line, "fixture: %s must appear on the anchored line" % key)
	return patched


## `dig.profiles` out of an already-parsed ruleset Dictionary, or an empty Dictionary (having
## reported why) when the M2-T3 group is absent.
func _profiles_of(root: Dictionary) -> Dictionary:
	if not root.has("dig"):
		assert_false(true, "§12.1/M2-T3: %s must carry the `dig` group" % RULESET_PATH)
		return {}
	var dig_group: Variant = root["dig"]
	if not (dig_group is Dictionary):
		assert_false(true, "§12.1: `dig` is a group")
		return {}
	var profiles: Variant = (dig_group as Dictionary).get("profiles", null)
	if not (profiles is Dictionary):
		assert_false(true, "§12.1: `dig.profiles` is a map of terrain id -> constant keys")
		return {}
	return profiles as Dictionary


## Every terrain type `data/mapgen/concentric_bowl.json` can place, in document order (READ ONLY).
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
