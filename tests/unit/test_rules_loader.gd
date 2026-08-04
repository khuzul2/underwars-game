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


## §12.1 + §4.2 — the new key is REQUIRED by the schema, not merely present in the shipped file:
## deleting it must be rejected with a line-numbered error (§14 M0's still-binding acceptance
## clause), the ruleset must stay unpublished, and the error must be attributed to the
## `dig_yields` group line. That attribution is M0-T2 item 3's forward-scan fallback in action:
## with the pair gone, no `"artificial_granite"` token exists at or after the `"dig_yields"` line
## (`dig_turns` sits ABOVE it), so the walk falls back to the last segment it did find.
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
	assert_eq(
		err.line,
		DIG_YIELDS_LINE,
		"§14/M0-T2 item 3: the missing child is attributed to the dig_yields group line"
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
