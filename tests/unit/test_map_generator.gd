## MapGenerator + data/mapgen/concentric_bowl.json — GDD §4.4 (Map Generation — the Concentric
## Bowl, **binding table**), §4.1 (map radii, "Elevation: integer 0-3 per hex"), §11.1 (sim core
## is engine-free, integer-only, deterministic), §11.2 (`scripts/sim/`), §11.3, §12.6 (a
## map/scenario references `"generator": "mapgen/concentric_bowl.json"`), §13.2 tier 1, §13.6,
## §14 M1.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §4.1 line 174: "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40
##                  (4,921)."
##   §4.1 line 173: "**Elevation:** integer 0-3 per hex."
##   §4.4 line 225: "Generated as a descending terraced bowl (elevation falls from Rim 2-3 to
##                  Core 0)."
##   §4.4 table (rows printed OUTER TO INNER, which is the order used everywhere below):
##                  "**Safe Rim** (outer 30%)" · "**Mid-Mantle** (middle 40%)" ·
##                  "**Deep Core** (inner 30%)".
##   §4.4 line 238: "Generator parameters (ring shares, vein densities, lair counts, seed) live
##                  in data/mapgen/*.json".
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §4.1 or §4.4**, so the printed text above governs unamended. §4.4 prints three share
## percentages and one prose sentence; it legislates **no per-hex formula**, so every boundary
## distance and every hex count below is DERIVED — and each was re-derived here, mechanically,
## from the printed shares alone (see
## `test_the_pinned_boundary_tables_are_re_derived_from_the_printed_section_4_4_shares`, which
## recomputes the whole table and would fail if any pinned constant in this file were a typo).
## That mechanical re-derivation is the M1-T1 item 3 / M1-T2 item 9 / M1-T3 item 8 standing rule
## made executable.
##
## §13.4 resolutions pinned here. The lettering continues M1-T1's (A)/(B), M1-T2's (C)-(G) and
## M1-T3's (H)-(L); `scripts/sim/map_generator.gd`'s header and docs/decisions.md reference it,
## so keep it stable:
##   (M) BAND RULE. `outer_pct[k]` = cumulative share at band k's OUTER edge, summed from the
##       innermost band, with bands listed outer to inner: safe_rim 100, mid_mantle 70,
##       deep_core 30. `band_index_at(d, R)` = the LAST (innermost) index k such that
##       `d * 100 <= outer_pct[k] * R`; 0 (safe_rim) if none qualifies. Pure integer
##       CROSS-MULTIPLICATION — no division, no rounding primitive, no float.
##   (N) TERRACE RULE. Terraces are `{from_share_pct, elevation}` rows listed outer to inner in
##       strictly decreasing `from_share_pct`: {85,3}, {70,2}, {30,1}, {0,0}.
##       `elevation_at(d, R)` = the elevation of the FIRST (outermost) row satisfying
##       `d * 100 > from_share_pct * R`; the innermost row's elevation (0) if none matches.
##       The comparison is STRICT ">" while (M)'s is "<=". **That complementarity is
##       load-bearing**: it is the only thing that makes terrace boundaries coincide exactly with
##       band boundaries at a shared percentage (30 and 70 appear in both tables). `>=` breaks
##       the alignment at every exact-multiple radius — pinned at R=40, d=28, where
##       70*40 == 2800 == 28*100 (see
##       `test_terrace_and_band_boundaries_coincide_at_the_exact_multiple_radius`).
##       **85 is NOT a GDD number**: it is the midpoint of the Safe Rim band (70 + 30/2), which
##       splits the rim into two equal terraces so that §4.4's "Rim 2-3" is realised as elevation
##       2 on the inner half and 3 on the outer half. It is TUNABLE CONTENT in the JSON (§4.4
##       line 238), never a code literal — `test_terrace_thresholds_are_read_from_data` proves it.
##   (P) LOAD CONTRACT. All errors are collected as [RulesError] (the existing §12.1 type — no
##       second error type is invented) with **1-based** lines; on ANY error the generator is
##       left UNCONFIGURED, so a half-valid params set can never be read (mirroring RulesLoader,
##       decisions.md M0-T2 item 4). **Line 0 stays RESERVED for missing/unreadable files**
##       (M0-T2 item 2) and may never be emitted for a schema error. A schema error is attributed
##       to the first line whose text carries the JSON key token of the offending TOP-LEVEL key,
##       falling back to line 1 — deliberately simpler than `RulesLoader._attribute_line`,
##       because the mapgen file has a different schema.
##   (Q) NO RNG AND NO GOLDEN IN THIS SLICE. The bowl skeleton is a pure function of distance, so
##       there is nothing to seed; terrain-type composition (§4.2), veins, features, lairs and
##       spawns — and the project's FIRST GOLDEN — are M1-T5. §13.6's
##       re-record-only-with-a-logged-reason rule starts applying from that moment, not before.
##
## §13.6 "events emitted for every state change" is VACUOUS here and deliberately so: this slice
## mutates no GameState and touches no EventBus. Goldens: none re-recorded — none exist yet.
##
## Godot 4.7 JSON facts this file depends on, already measured (decisions.md M0-T2 item 8, do not
## re-derive): `JSON.get_error_line()` is 0-BASED (the loader normalizes +1); the parser ACCEPTS
## trailing commas, so they are useless as a syntax-error fixture; EVERY JSON number arrives as
## TYPE_FLOAT, even `1` — so int validation is "accept an integral float, REJECT a fractional
## one", never truncate.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Non-Node-ness is asserted via get_class() ONLY.
extends GutTest

const MAP_GENERATOR_PATH: String = "res://scripts/sim/map_generator.gd"
const PARAMS_PATH: String = "res://data/mapgen/concentric_bowl.json"
const MISSING_PARAMS_PATH: String = "res://data/mapgen/__no_such_mapgen__.json"
const SOURCE: String = "concentric_bowl.json"

# ---------------------------------------------------------------------------------------------
# §4.1 line 174 and the §4.4 table, transcribed VERBATIM. These literals are allowed here and in
# data/mapgen/*.json — never in engine code (§13.6; scan S3 enforces it for map_generator.gd).
# ---------------------------------------------------------------------------------------------
const SIZE_IDS: Array[String] = ["small", "medium", "large"]
const RADII: Array[int] = [24, 32, 40]
const HEX_COUNTS: Array[int] = [1801, 3169, 4921]

## §4.4's three rows, in the order the table prints them (outer to inner).
const BAND_IDS: Array[String] = ["safe_rim", "mid_mantle", "deep_core"]
const BAND_SHARE_PCT: Array[int] = [30, 40, 30]
const SAFE_RIM: int = 0
const MID_MANTLE: int = 1
const DEEP_CORE: int = 2

## Resolution (N)'s terrace table, outer to inner. 70 and 30 are §4.4's own cumulative shares;
## 85 is the tunable mid-rim split that realises "Rim 2-3".
const TERRACE_FROM_PCT: Array[int] = [85, 70, 30, 0]
const TERRACE_ELEVATION: Array[int] = [3, 2, 1, 0]

# ---------------------------------------------------------------------------------------------
# DERIVED boundary tables, indexed by RADII. Every entry is re-derived mechanically from
# BAND_SHARE_PCT / TERRACE_FROM_PCT by the self-consistency test below — none is trusted as
# written. Boundaries are pinned as ADJACENT PAIRS (last inner d, first outer d) because a
# one-sided probe cannot see an off-by-one.
# ---------------------------------------------------------------------------------------------
const CORE_MAX_D: Array[int] = [7, 9, 12]
const MANTLE_MAX_D: Array[int] = [16, 22, 28]
const ELEV1_MIN_D: Array[int] = [8, 10, 13]
const ELEV2_MIN_D: Array[int] = [17, 23, 29]
const ELEV3_MIN_D: Array[int] = [21, 28, 35]

const CORE_COUNTS: Array[int] = [169, 271, 469]
const MANTLE_COUNTS: Array[int] = [648, 1248, 1968]
const RIM_COUNTS: Array[int] = [984, 1650, 2484]
const ELEV0_COUNTS: Array[int] = [169, 271, 469]
const ELEV1_COUNTS: Array[int] = [648, 1248, 1968]
const ELEV2_COUNTS: Array[int] = [444, 750, 1134]
const ELEV3_COUNTS: Array[int] = [540, 900, 1350]

const MIN_ELEVATION: int = 0
const MAX_ELEVATION: int = 3

# ---------------------------------------------------------------------------------------------
# The canonical params document. Layout follows data/ruleset.json's LOAD-BEARING convention
# (decisions.md M0-T2 item 7): line 1 is a lone `{` and each top-level group occupies exactly ONE
# line, so a single-line defect is plantable and every expected error line is computed from the
# fixture instead of being a magic constant.
# ---------------------------------------------------------------------------------------------
const PARAMS_LINES: Array[String] = [
	'{',
	'  "id": "concentric_bowl",',
	'  "map_sizes": [{"id": "small", "radius": 24}, {"id": "medium", "radius": 32}, {"id": "large", "radius": 40}],',
	'  "bands": [{"id": "safe_rim", "share_pct": 30}, {"id": "mid_mantle", "share_pct": 40}, {"id": "deep_core", "share_pct": 30}],',
	'  "terraces": [{"from_share_pct": 85, "elevation": 3}, {"from_share_pct": 70, "elevation": 2}, {"from_share_pct": 30, "elevation": 1}, {"from_share_pct": 0, "elevation": 0}]',
	'}',
]

const TOP_LEVEL_KEYS: Array[String] = ["id", "map_sizes", "bands", "terraces"]

## §11.1 — tokens that would make the sim core engine-bound. FileAccess and JSON are permitted
## (scripts/sim/rules_loader.gd sets that precedent). NOTE FOR M1-T5: the composition slice needs
## seeded rolls through `state.rng` and must AMEND this scan with a logged reason, never delete
## it — resolution (Q): slice 1 uses no RNG at all, so no exception is carved today.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"Time.",
	"OS.",
]

const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface of MapGenerator (§13.4: invent nothing ahead of its
## milestone — no terrain-type, vein, feature, lair or spawn entry point until M1-T5).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"load_params_text",
	"load_params_file",
	"radius_for_size",
	"band_count",
	"band_id",
	"band_index_at",
	"elevation_at",
	"generate",
]

## The COMPLETE public field surface — the existing §12.1 error type, and nothing else.
const REQUIRED_PUBLIC_VARS: Array[String] = ["errors"]


# =============================================================================================
# A. THE PRINTED TABLES: TRANSCRIPTION INTO DATA, AND THE SELF-CHECK OF EVERY DERIVED NUMBER
# =============================================================================================

## The mechanical re-derivation demanded by the M1-T1 item 3 / M1-T2 item 9 / M1-T3 item 8
## standing rule: EVERY derived constant in this file is recomputed here from §4.4's three
## printed shares and resolution (N)'s terrace thresholds alone, using nothing from
## `map_generator.gd`. If a pinned boundary or count above were a typo, this test fails BEFORE any
## implementation is blamed for it.
func test_the_pinned_boundary_tables_are_re_derived_from_the_printed_section_4_4_shares() -> void:
	assert_eq(
		BAND_SHARE_PCT[SAFE_RIM] + BAND_SHARE_PCT[MID_MANTLE] + BAND_SHARE_PCT[DEEP_CORE],
		100,
		"§4.4: outer 30%% + middle 40%% + inner 30%% is the whole radius"
	)
	var outer_pct: Array[int] = _cumulative_outer_pct()
	assert_eq(outer_pct, [100, 70, 30] as Array[int], "(M): cumulative outer edges, outer to inner")

	for i: int in range(RADII.size()):
		var r: int = RADII[i]
		assert_eq(
			HEX_COUNTS[i],
			3 * r * (r + 1) + 1,
			"§4.1 line 174: the parenthesised count for radius %d is 3r(r+1)+1" % r
		)
		assert_eq(
			_last_distance_within(outer_pct[DEEP_CORE], r),
			CORE_MAX_D[i],
			"(M): Deep Core reaches d == %d at radius %d" % [CORE_MAX_D[i], r]
		)
		assert_eq(
			_last_distance_within(outer_pct[MID_MANTLE], r),
			MANTLE_MAX_D[i],
			"(M): Mid-Mantle reaches d == %d at radius %d" % [MANTLE_MAX_D[i], r]
		)
		assert_eq(
			_last_distance_within(outer_pct[SAFE_RIM], r),
			r,
			"(M): Safe Rim reaches the map edge at radius %d" % r
		)
		assert_eq(
			_first_distance_above(TERRACE_FROM_PCT[2], r),
			ELEV1_MIN_D[i],
			"(N): elevation 1 starts at d == %d at radius %d" % [ELEV1_MIN_D[i], r]
		)
		assert_eq(
			_first_distance_above(TERRACE_FROM_PCT[1], r),
			ELEV2_MIN_D[i],
			"(N): elevation 2 starts at d == %d at radius %d" % [ELEV2_MIN_D[i], r]
		)
		assert_eq(
			_first_distance_above(TERRACE_FROM_PCT[0], r),
			ELEV3_MIN_D[i],
			"(N): elevation 3 starts at d == %d at radius %d" % [ELEV3_MIN_D[i], r]
		)

		# Counts, via differences of the closed form 3d(d+1)+1 — never hard-coded a second way.
		assert_eq(CORE_COUNTS[i], _disc(CORE_MAX_D[i]), "Deep Core hex count at radius %d" % r)
		assert_eq(
			MANTLE_COUNTS[i],
			_disc(MANTLE_MAX_D[i]) - _disc(CORE_MAX_D[i]),
			"Mid-Mantle hex count at radius %d" % r
		)
		assert_eq(
			RIM_COUNTS[i],
			_disc(r) - _disc(MANTLE_MAX_D[i]),
			"Safe Rim hex count at radius %d" % r
		)
		assert_eq(
			CORE_COUNTS[i] + MANTLE_COUNTS[i] + RIM_COUNTS[i],
			HEX_COUNTS[i],
			"§4.1/§4.4: the three bands partition the radius-%d map exactly" % r
		)
		assert_eq(ELEV0_COUNTS[i], _disc(ELEV1_MIN_D[i] - 1), "elevation 0 count at radius %d" % r)
		assert_eq(
			ELEV1_COUNTS[i],
			_disc(ELEV2_MIN_D[i] - 1) - _disc(ELEV1_MIN_D[i] - 1),
			"elevation 1 count at radius %d" % r
		)
		assert_eq(
			ELEV2_COUNTS[i],
			_disc(ELEV3_MIN_D[i] - 1) - _disc(ELEV2_MIN_D[i] - 1),
			"elevation 2 count at radius %d" % r
		)
		assert_eq(
			ELEV3_COUNTS[i],
			_disc(r) - _disc(ELEV3_MIN_D[i] - 1),
			"elevation 3 count at radius %d" % r
		)
		assert_eq(
			ELEV0_COUNTS[i] + ELEV1_COUNTS[i] + ELEV2_COUNTS[i] + ELEV3_COUNTS[i],
			HEX_COUNTS[i],
			"§4.1: the four terraces partition the radius-%d map exactly" % r
		)
		# (M)/(N) complementarity: the shared percentages 30 and 70 make band and terrace
		# boundaries coincide, so Deep Core == elevation 0 and Mid-Mantle == elevation 1 exactly.
		assert_eq(ELEV0_COUNTS[i], CORE_COUNTS[i], "(M)/(N): Deep Core is exactly elevation 0")
		assert_eq(ELEV1_COUNTS[i], MANTLE_COUNTS[i], "(M)/(N): Mid-Mantle is exactly elevation 1")
		assert_eq(
			ELEV2_COUNTS[i] + ELEV3_COUNTS[i],
			RIM_COUNTS[i],
			"(M)/(N): §4.4's 'Rim 2-3' is exactly the Safe Rim band"
		)


## §12.6 — a map/scenario references `"generator": "mapgen/concentric_bowl.json"`, so the bowl is
## a DATA FILE loaded through the one generator class. The shipped file must load clean.
func test_the_shipped_params_file_loads_clean() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var ok: bool = generator.load_params_file(PARAMS_PATH)
	assert_true(ok, "§12.6: %s must load successfully" % PARAMS_PATH)
	assert_eq(_error_lines(generator), [] as Array[String], "(P): a valid params file yields no errors")


## §4.4 line 238 / §13.6 — the printed tables must appear VERBATIM in the shipped JSON, because
## that file (not the code) is where the numbers live. Parsed here directly, independently of
## MapGenerator, so a generator bug cannot mask a content typo.
func test_the_shipped_params_file_transcribes_the_gdd_tables_verbatim() -> void:
	var root: Dictionary = _parsed_shipped_params()
	if root.is_empty():
		return
	assert_true(root.has("id"), "§12.6: the params document carries an id")

	var sizes: Array = root.get("map_sizes", [])
	assert_eq(sizes.size(), SIZE_IDS.size(), "§4.1 line 174 lists exactly three map sizes")
	for i: int in range(mini(sizes.size(), SIZE_IDS.size())):
		var entry: Dictionary = _as_dictionary(sizes[i])
		assert_eq(str(entry.get("id", "")), SIZE_IDS[i], "§4.1: map size %d id" % i)
		assert_eq(_integral(entry.get("radius", -1)), RADII[i], "§4.1 line 174: %s radius" % SIZE_IDS[i])

	var bands: Array = root.get("bands", [])
	assert_eq(bands.size(), BAND_IDS.size(), "§4.4 prints exactly three rings")
	var share_total: int = 0
	for i: int in range(mini(bands.size(), BAND_IDS.size())):
		var entry: Dictionary = _as_dictionary(bands[i])
		assert_eq(
			str(entry.get("id", "")),
			BAND_IDS[i],
			"§4.4: band %d is %s (rows listed outer to inner)" % [i, BAND_IDS[i]]
		)
		var share: int = _integral(entry.get("share_pct", -1))
		assert_eq(share, BAND_SHARE_PCT[i], "§4.4: %s share of radius" % BAND_IDS[i])
		share_total += share
	assert_eq(share_total, 100, "§4.4: the three ring shares cover the whole radius")

	var terraces: Array = root.get("terraces", [])
	assert_eq(terraces.size(), TERRACE_FROM_PCT.size(), "(N): four terraces realise 'Rim 2-3 to Core 0'")
	var previous: int = 101
	for i: int in range(mini(terraces.size(), TERRACE_FROM_PCT.size())):
		var entry: Dictionary = _as_dictionary(terraces[i])
		var from_pct: int = _integral(entry.get("from_share_pct", -1))
		var elevation: int = _integral(entry.get("elevation", -1))
		assert_eq(from_pct, TERRACE_FROM_PCT[i], "(N): terrace %d from_share_pct" % i)
		assert_eq(elevation, TERRACE_ELEVATION[i], "(N): terrace %d elevation" % i)
		assert_true(from_pct < previous, "(N): terraces are strictly decreasing, outer to inner")
		previous = from_pct
		assert_between(
			elevation,
			MIN_ELEVATION,
			MAX_ELEVATION,
			"§4.1 line 173: elevation is an integer 0-3"
		)


## decisions.md M0-T2 item 7, applied to the new file: line 1 is a lone `{` and each top-level
## group occupies exactly ONE line, so schema-error line attribution is meaningful and the load
## tests below can compute their expected line numbers from the document itself.
func test_the_shipped_params_file_layout_is_line_addressable() -> void:
	var lines: PackedStringArray = _shipped_params_text().replace("\r\n", "\n").split("\n")
	assert_true(lines.size() > TOP_LEVEL_KEYS.size(), "sanity: %s is non-trivial" % PARAMS_PATH)
	assert_eq(lines[0].strip_edges(), "{", "M0-T2 item 7: line 1 is a lone opening brace")
	for key: String in TOP_LEVEL_KEYS:
		var hits: int = 0
		for line: String in lines:
			# Anchored at the line's own start (after indentation), not a bare `contains`: the
			# "id" key is also a NESTED field inside every map_sizes/bands array entry (e.g.
			# `{"id": "small", ...}`), so an unanchored substring search overcounts "id" on the
			# map_sizes and bands lines too. A top-level group's line always begins, once
			# indentation is stripped, with its own `"key":` token (M0-T2 item 7's one-line-per-
			# group convention); a nested key of the same name never sits at that position.
			if line.strip_edges().begins_with('"%s":' % key):
				hits += 1
		assert_eq(hits, 1, "M0-T2 item 7: top-level key %s occupies exactly one line" % key)


# =============================================================================================
# B. THE TWO RULE FUNCTIONS — §4.1 radii, §4.4 bands, resolution (M) and resolution (N)
# =============================================================================================

## §4.1 line 174 — the three radii come from data, and each agrees with the parenthesised hex
## count three ways: the closed form, HexMath, and an actually generated map.
func test_map_radii_and_hex_counts_match_the_section_4_1_table() -> void:
	var generator: MapGenerator = _loaded()
	for i: int in range(SIZE_IDS.size()):
		var r: int = RADII[i]
		assert_eq(
			generator.radius_for_size(SIZE_IDS[i]),
			r,
			"§4.1 line 174: %s is hex radius %d" % [SIZE_IDS[i], r]
		)
		assert_eq(
			HexMath.hex_count_for_radius(r),
			HEX_COUNTS[i],
			"§4.1 line 174: radius %d is %d hexes" % [r, HEX_COUNTS[i]]
		)
		assert_eq(
			generator.generate(r).hex_count(),
			HEX_COUNTS[i],
			"§4.4: generate(%d) produces exactly %d in-bounds hexes" % [r, HEX_COUNTS[i]]
		)


## (P)/§13.4 totality — an unknown size id is 0, never a crash and never a silently wrong radius.
func test_radius_for_an_unknown_size_id_is_zero() -> void:
	var generator: MapGenerator = _loaded()
	for unknown: String in ["", "SMALL", "huge", "medium "]:
		assert_eq(
			generator.radius_for_size(unknown),
			0,
			"(P): radius_for_size(%s) is 0 for an unknown id" % [unknown]
		)


## §4.4 — the band table, in the order §4.4 prints it (outer to inner), read from data.
func test_band_table_matches_section_4_4() -> void:
	var generator: MapGenerator = _loaded()
	assert_eq(generator.band_count(), BAND_IDS.size(), "§4.4 prints exactly three rings")
	assert_eq(generator.band_id(SAFE_RIM), BAND_IDS[SAFE_RIM], "§4.4: band 0 is the Safe Rim")
	assert_eq(generator.band_id(MID_MANTLE), BAND_IDS[MID_MANTLE], "§4.4: band 1 is the Mid-Mantle")
	assert_eq(generator.band_id(DEEP_CORE), BAND_IDS[DEEP_CORE], "§4.4: band 2 is the Deep Core")
	for out_of_range: int in [-1, 3, 99]:
		assert_eq(
			generator.band_id(out_of_range),
			"",
			"(P): band_id(%d) is out of range and returns the empty id" % out_of_range
		)


## (M) — the band boundaries at every map size, pinned as ADJACENT PAIRS: the last distance
## inside a band and the first distance outside it. A single-sided probe cannot see an off-by-one.
func test_band_boundaries_are_pinned_as_adjacent_pairs_on_every_map_size() -> void:
	var generator: MapGenerator = _loaded()
	for i: int in range(RADII.size()):
		var r: int = RADII[i]
		var core_max: int = CORE_MAX_D[i]
		var mantle_max: int = MANTLE_MAX_D[i]
		assert_eq(generator.band_index_at(core_max, r), DEEP_CORE, "(M): R=%d d=%d is Deep Core" % [r, core_max])
		assert_eq(
			generator.band_index_at(core_max + 1, r),
			MID_MANTLE,
			"(M): R=%d d=%d is Mid-Mantle (one step out of the Core)" % [r, core_max + 1]
		)
		assert_eq(
			generator.band_index_at(mantle_max, r),
			MID_MANTLE,
			"(M): R=%d d=%d is Mid-Mantle" % [r, mantle_max]
		)
		assert_eq(
			generator.band_index_at(mantle_max + 1, r),
			SAFE_RIM,
			"(M): R=%d d=%d is the Safe Rim (one step out of the Mantle)" % [r, mantle_max + 1]
		)


## (M)/(N) endpoints — the centre is Deep Core at §4.4's "Core 0", the map edge is Safe Rim at
## the top of §4.4's "Rim 2-3".
func test_centre_and_edge_endpoints_match_section_4_4() -> void:
	var generator: MapGenerator = _loaded()
	for r: int in RADII:
		assert_eq(generator.band_index_at(0, r), DEEP_CORE, "(M): the centre of an R=%d map is Deep Core" % r)
		assert_eq(generator.band_index_at(r, r), SAFE_RIM, "(M): the edge of an R=%d map is Safe Rim" % r)
		assert_eq(generator.elevation_at(0, r), 0, "§4.4: 'elevation falls ... to Core 0' at R=%d" % r)
		assert_eq(
			generator.elevation_at(r, r),
			MAX_ELEVATION,
			"§4.4: the outermost ring of an R=%d map is the top of 'Rim 2-3'" % r
		)


## (N) — the terrace boundaries at every map size, again as ADJACENT PAIRS.
func test_terrace_boundaries_are_pinned_as_adjacent_pairs_on_every_map_size() -> void:
	var generator: MapGenerator = _loaded()
	for i: int in range(RADII.size()):
		var r: int = RADII[i]
		var mins: Array[int] = [ELEV1_MIN_D[i], ELEV2_MIN_D[i], ELEV3_MIN_D[i]]
		for step: int in range(mins.size()):
			var first_out: int = mins[step]
			assert_eq(
				generator.elevation_at(first_out - 1, r),
				step,
				"(N): R=%d d=%d is still elevation %d" % [r, first_out - 1, step]
			)
			assert_eq(
				generator.elevation_at(first_out, r),
				step + 1,
				"(N): R=%d d=%d steps up to elevation %d" % [r, first_out, step + 1]
			)


## (N), THE PIN THE WHOLE RESOLUTION TURNS ON. At R=40 the shared 70% boundary is an EXACT
## multiple: 70 * 40 == 2800 == 28 * 100. (M) uses "<=" so d=28 is still Mid-Mantle; (N) uses a
## STRICT ">" so d=28 is still elevation 1. A ">=" in the terrace rule would put d=28 at elevation
## 2 while its band is Mid-Mantle, silently breaking the band/terrace alignment — and NO
## hand-picked mid-band case can see it. Same story at 30% (d=12).
func test_terrace_and_band_boundaries_coincide_at_the_exact_multiple_radius() -> void:
	var generator: MapGenerator = _loaded()
	var r: int = RADII[2]
	assert_eq(28 * 100, 70 * r, "sanity: 70%% of radius 40 is the exact integer distance 28")
	assert_eq(generator.band_index_at(28, r), MID_MANTLE, "(M): R=40 d=28 is Mid-Mantle ('<=')")
	assert_eq(generator.elevation_at(28, r), 1, "(N): R=40 d=28 is elevation 1 (STRICT '>')")
	assert_eq(generator.band_index_at(29, r), SAFE_RIM, "(M): R=40 d=29 is the Safe Rim")
	assert_eq(generator.elevation_at(29, r), 2, "(N): R=40 d=29 steps up to elevation 2")
	assert_eq(12 * 100, 30 * r, "sanity: 30%% of radius 40 is the exact integer distance 12")
	assert_eq(generator.band_index_at(12, r), DEEP_CORE, "(M): R=40 d=12 is Deep Core ('<=')")
	assert_eq(generator.elevation_at(12, r), 0, "(N): R=40 d=12 is elevation 0 (STRICT '>')")
	assert_eq(generator.band_index_at(13, r), MID_MANTLE, "(M): R=40 d=13 is Mid-Mantle")
	assert_eq(generator.elevation_at(13, r), 1, "(N): R=40 d=13 steps up to elevation 1")


## P5 PARTITION — walking d from 0 to R, the band sequence is three CONTIGUOUS, non-overlapping
## runs covering exactly 0..R, and the terrace sequence four. Compared as whole arrays against
## sequences built from the independently re-derived boundaries, so a gap, an overlap or a
## reordered run all fail.
func test_band_and_terrace_spans_are_contiguous_partitions_of_zero_to_radius() -> void:
	var generator: MapGenerator = _loaded()
	for i: int in range(RADII.size()):
		var r: int = RADII[i]
		var bands: Array[int] = []
		var elevations: Array[int] = []
		for d: int in range(r + 1):
			bands.append(generator.band_index_at(d, r))
			elevations.append(generator.elevation_at(d, r))
		assert_eq(bands, _expected_band_sequence(i), "(M): the band spans of an R=%d map" % r)
		assert_eq(elevations, _expected_elevation_sequence(i), "(N): the terrace spans of an R=%d map" % r)


## P1 RANGE + P2 MONOTONICITY (§4.1 line 173 "integer 0-3"; §4.4 "a DESCENDING terraced bowl").
## Elevation never increases inward: swept over EVERY ordered pair of distances on all three map
## sizes, not sampled.
func test_elevation_is_in_range_and_never_increases_inward() -> void:
	var generator: MapGenerator = _loaded()
	for i: int in range(RADII.size()):
		var r: int = RADII[i]
		var out_of_range: Array[String] = []
		var band_out_of_range: Array[String] = []
		var inversions: Array[String] = []
		for d: int in range(r + 1):
			var e: int = generator.elevation_at(d, r)
			var b: int = generator.band_index_at(d, r)
			if e < MIN_ELEVATION or e > MAX_ELEVATION:
				out_of_range.append("R=%d d=%d -> %d" % [r, d, e])
			if b < SAFE_RIM or b > DEEP_CORE:
				band_out_of_range.append("R=%d d=%d -> %d" % [r, d, b])
			for nearer: int in range(d):
				if generator.elevation_at(nearer, r) > e:
					inversions.append("R=%d d=%d(%d) > d=%d(%d)" % [
						r, nearer, generator.elevation_at(nearer, r), d, e
					])
		assert_eq(out_of_range.size(), 0, "§4.1 line 173: elevation stays 0-3; %s" % [
			str(out_of_range.slice(0, 5))
		])
		assert_eq(band_out_of_range.size(), 0, "§4.4: the band index stays 0-2; %s" % [
			str(band_out_of_range.slice(0, 5))
		])
		assert_eq(inversions.size(), 0, "§4.4: the bowl DESCENDS inward; %s" % [
			str(inversions.slice(0, 5))
		])


## (P)/§13.4 totality — a degenerate map radius must not crash or divide by zero. Both rule
## functions answer 0 for R <= 0.
func test_rule_functions_are_total_on_a_degenerate_radius() -> void:
	var generator: MapGenerator = _loaded()
	for r: int in [0, -1, -40]:
		assert_eq(generator.band_index_at(0, r), 0, "(P): band_index_at(0, %d) is 0" % r)
		assert_eq(generator.band_index_at(5, r), 0, "(P): band_index_at(5, %d) is 0" % r)
		assert_eq(generator.elevation_at(0, r), 0, "(P): elevation_at(0, %d) is 0" % r)
		assert_eq(generator.elevation_at(5, r), 0, "(P): elevation_at(5, %d) is 0" % r)


# =============================================================================================
# C. generate() — the whole §4.4 bowl, swept hex by hex
# =============================================================================================

## §4.4 line 225 ("a descending terraced bowl, elevation falls from Rim 2-3 to Core 0") plus
## §4.1 line 173 and line 174, asserted over EVERY hex of ALL THREE map sizes in one pass:
## the hex count, the 0-3 range, agreement with `elevation_at`, both extremes attained, the
## per-band and per-elevation populations, and the (M)/(N) alignment property
## (Deep Core <=> 0, Mid-Mantle <=> 1, Safe Rim <=> {2,3}).
func test_generate_fills_the_descending_terraced_bowl_on_every_map_size() -> void:
	var generator: MapGenerator = _loaded()
	for i: int in range(RADII.size()):
		var r: int = RADII[i]
		var map: HexMap = generator.generate(r)
		assert_eq(map.radius, r, "§4.4: generate(%d) returns a radius-%d map" % [r, r])
		assert_eq(map.hex_count(), HEX_COUNTS[i], "§4.1 line 174: radius %d holds %d hexes" % [r, HEX_COUNTS[i]])

		var band_counts: Array[int] = [0, 0, 0]
		var elevation_counts: Array[int] = [0, 0, 0, 0]
		var out_of_range: Array[String] = []
		var rule_breaks: Array[String] = []
		var misaligned: Array[String] = []
		for hex: Vector2i in map.hexes():
			var d: int = HexMath.distance(Vector2i.ZERO, hex)
			var e: int = map.get_elevation(hex)
			var b: int = generator.band_index_at(d, r)
			if e < MIN_ELEVATION or e > MAX_ELEVATION:
				out_of_range.append("%s(d=%d) -> %d" % [hex, d, e])
			else:
				elevation_counts[e] += 1
			if e != generator.elevation_at(d, r):
				rule_breaks.append("%s(d=%d) -> %d, rule says %d" % [
					hex, d, e, generator.elevation_at(d, r)
				])
			if b >= SAFE_RIM and b <= DEEP_CORE:
				band_counts[b] += 1
			if not _aligned(b, e):
				misaligned.append("%s(d=%d) band %d elevation %d" % [hex, d, b, e])

		assert_eq(out_of_range.size(), 0, "§4.1 line 173: every hex is elevation 0-3; %s" % [
			str(out_of_range.slice(0, 5))
		])
		assert_eq(rule_breaks.size(), 0, "§4.4: every hex matches elevation_at(distance); %s" % [
			str(rule_breaks.slice(0, 5))
		])
		assert_eq(misaligned.size(), 0, "(M)/(N): band and terrace must coincide; %s" % [
			str(misaligned.slice(0, 5))
		])
		assert_eq(band_counts[DEEP_CORE], CORE_COUNTS[i], "§4.4: Deep Core population at R=%d" % r)
		assert_eq(band_counts[MID_MANTLE], MANTLE_COUNTS[i], "§4.4: Mid-Mantle population at R=%d" % r)
		assert_eq(band_counts[SAFE_RIM], RIM_COUNTS[i], "§4.4: Safe Rim population at R=%d" % r)
		assert_eq(elevation_counts[0], ELEV0_COUNTS[i], "§4.4: elevation-0 population at R=%d" % r)
		assert_eq(elevation_counts[1], ELEV1_COUNTS[i], "§4.4: elevation-1 population at R=%d" % r)
		assert_eq(elevation_counts[2], ELEV2_COUNTS[i], "§4.4: elevation-2 population at R=%d" % r)
		assert_eq(elevation_counts[3], ELEV3_COUNTS[i], "§4.4: elevation-3 population at R=%d" % r)
		assert_true(elevation_counts[0] > 0, "§4.1: elevation 0 is attained on an R=%d map" % r)
		assert_true(elevation_counts[3] > 0, "§4.1: elevation 3 is attained on an R=%d map" % r)
		assert_true(elevation_counts[2] > 0, "§4.4: 'Rim 2-3' means elevation 2 is attained at R=%d" % r)


## P3 RADIAL SYMMETRY — elevation depends ONLY on cube distance, so every hex of a ring carries
## the identical elevation. Grouped over the whole disc WITHOUT consulting `elevation_at`, so it
## is genuinely independent of the rule function: this is the sweep that catches a q/r-asymmetric
## index bug, the analogue of the M1-T3 asymmetric-cap probe that only the symmetry sweep saw.
func test_elevation_is_constant_on_every_ring() -> void:
	var generator: MapGenerator = _loaded()
	for r: int in [RADII[0], RADII[1]]:
		var map: HexMap = generator.generate(r)
		var by_distance: Dictionary = {}
		var breaks: Array[String] = []
		for hex: Vector2i in map.hexes():
			var d: int = HexMath.distance(Vector2i.ZERO, hex)
			var e: int = map.get_elevation(hex)
			if by_distance.has(d):
				if int(by_distance[d]) != e:
					breaks.append("R=%d ring %d: %s is %d, expected %d" % [
						r, d, hex, e, int(by_distance[d])
					])
			else:
				by_distance[d] = e
		assert_eq(by_distance.size(), r + 1, "sanity: an R=%d map has rings 0..%d" % [r, r])
		assert_eq(breaks.size(), 0, "§4.4: elevation is a function of cube distance alone; %s" % [
			str(breaks.slice(0, 5))
		])


## P6 DETERMINISM (§11.1 "the core must run headless byte-identically"). There is NO RNG in this
## slice at all (resolution (Q)), so this holds trivially TODAY — the test exists so that the
## M1-T5 composition pass cannot silently make it false.
func test_two_independent_generators_produce_identical_maps() -> void:
	var first: MapGenerator = _loaded()
	var second: MapGenerator = _loaded()
	for r: int in [RADII[0], RADII[1]]:
		var a: PackedInt32Array = _elevation_sequence(first.generate(r))
		var b: PackedInt32Array = _elevation_sequence(second.generate(r))
		assert_eq(a.size(), HexMath.hex_count_for_radius(r), "sanity: the R=%d sequence is complete" % r)
		assert_eq(a, b, "§11.1: two fresh generators must produce byte-identical R=%d maps" % r)
		assert_eq(
			_elevation_sequence(first.generate(r)),
			a,
			"§11.1: regenerating on the SAME generator reproduces the R=%d map" % r
		)


## (P)/§13.4 totality — a degenerate radius produces a degenerate map, never a crash.
func test_generate_is_total_on_degenerate_radii() -> void:
	var generator: MapGenerator = _loaded()
	for negative: int in [-1, -40]:
		var empty: HexMap = generator.generate(negative)
		assert_eq(empty.hex_count(), 0, "(P): generate(%d) is the empty map" % negative)
		assert_true(empty.hexes().is_empty(), "(P): generate(%d) has no hexes" % negative)
	var single: HexMap = generator.generate(0)
	assert_eq(single.hex_count(), 1, "(P): generate(0) is the single origin hex")
	assert_eq(single.get_elevation(Vector2i.ZERO), 0, "§4.4: the centre sits at 'Core 0'")


# =============================================================================================
# D. THE LOAD CONTRACT — resolution (P), mirroring RulesLoader (decisions.md M0-T2)
# =============================================================================================

## M0-T2 item 2 — line 0 is RESERVED for missing/unreadable files, and a missing file yields
## EXACTLY one error.
func test_a_missing_params_file_is_one_file_level_error_on_line_zero() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var ok: bool = generator.load_params_file(MISSING_PARAMS_PATH)
	assert_false(ok, "(P): a missing params file must not load")
	assert_eq(generator.errors.size(), 1, "(P): a missing file is exactly one error: %s" % [
		str(_error_lines(generator))
	])
	if generator.errors.size() == 1:
		assert_eq(
			generator.errors[0].line,
			0,
			"M0-T2 item 2: line 0 is reserved for missing/unreadable files"
		)


## (P) — the canonical params text is accepted by load_params_text, so every rejection fixture
## below differs from a VALID document by exactly one planted defect.
func test_the_canonical_params_text_is_accepted() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var ok: bool = generator.load_params_text(_params_text(), SOURCE)
	assert_true(ok, "(P): the canonical params text must load: %s" % [str(_error_lines(generator))])
	assert_eq(_error_lines(generator), [] as Array[String], "(P): a valid document yields no errors")
	assert_eq(generator.radius_for_size("medium"), RADII[1], "sanity: the canonical text configures")


## (P)/§4.4 — the three ring shares must cover the whole radius. 30 + 40 + 30 == 100 is the
## table's own arithmetic, so a params file whose shares do not sum to 100 is not the §4.4 bowl.
func test_reject_bands_whose_shares_do_not_sum_to_one_hundred() -> void:
	_assert_rejected(
		_mutated('"share_pct": 30}, {"id": "mid_mantle"', '"share_pct": 31}, {"id": "mid_mantle"'),
		"bands",
		"§4.4: ring shares must sum to 100"
	)


## (P) — every band needs its id; §4.4's rows are named rings, not anonymous slices.
func test_reject_a_band_without_an_id() -> void:
	_assert_rejected(
		_mutated('{"id": "safe_rim", "share_pct": 30}', '{"share_pct": 30}'),
		"bands",
		"§4.4: every ring carries its id"
	)


## (P) + decisions.md M0-T2 item 8 — every JSON number arrives as TYPE_FLOAT, so an int leaf must
## ACCEPT an integral float and REJECT a fractional one, never truncate. The two fractional shares
## below still sum to 100, which isolates the integrality rule from the sum rule.
func test_reject_a_fractional_share_percentage() -> void:
	var text: String = _mutated('{"id": "safe_rim", "share_pct": 30}', '{"id": "safe_rim", "share_pct": 29.5}')
	text = text.replace('{"id": "deep_core", "share_pct": 30}', '{"id": "deep_core", "share_pct": 30.5}')
	_assert_rejected(text, "bands", "M0-T2 item 8: a fractional share_pct is rejected, never truncated")


## (P)/§4.1 line 173 — "Elevation: integer 0-3 per hex" is binding on the content too.
func test_reject_a_terrace_elevation_outside_zero_to_three() -> void:
	_assert_rejected(
		_mutated('"from_share_pct": 85, "elevation": 3', '"from_share_pct": 85, "elevation": 4'),
		"terraces",
		"§4.1 line 173: elevation is an integer 0-3"
	)


## (N) — terraces are listed outer to inner in STRICTLY DECREASING from_share_pct; any other
## order makes "the first row satisfying d * 100 > from_share_pct * R" ambiguous.
func test_reject_terraces_that_are_not_strictly_decreasing() -> void:
	var text: String = _mutated('"from_share_pct": 85, "elevation": 3', '"from_share_pct": 70, "elevation": 3')
	text = text.replace('"from_share_pct": 70, "elevation": 2', '"from_share_pct": 85, "elevation": 2')
	_assert_rejected(text, "terraces", "(N): terraces must strictly decrease outer to inner")


## (P)/§4.1 line 174 — a map size must have a usable radius; 0 or negative is not a map.
func test_reject_a_map_size_with_a_non_positive_radius() -> void:
	_assert_rejected(
		_mutated('{"id": "small", "radius": 24}', '{"id": "small", "radius": 0}'),
		"map_sizes",
		"§4.1 line 174: a map size needs a positive hex radius"
	)


## (P) — a JSON syntax error is still an error with a 1-based line (M0-T2 item 8: Godot's
## `get_error_line()` is 0-based and must be normalized). A trailing comma is useless as a
## fixture on this engine, so an unquoted bareword is planted instead.
func test_reject_malformed_json_with_a_one_based_line() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var lines: Array[String] = []
	for line: String in PARAMS_LINES:
		lines.append(line)
	lines[1] = '  "id": concentric_bowl,'
	var ok: bool = generator.load_params_text(_joined(lines), SOURCE)
	assert_false(ok, "(P): malformed JSON must not load")
	assert_true(generator.errors.size() >= 1, "(P): malformed JSON reports at least one error")
	if generator.errors.size() >= 1:
		assert_true(
			generator.errors[0].line >= 1,
			"M0-T2 item 2/8: a syntax error carries a 1-based line, never the reserved 0 (got %d)" % [
				generator.errors[0].line
			]
		)
		assert_true(
			generator.errors[0].format_for(SOURCE).begins_with("%s:" % SOURCE),
			"M0-T2 item 6: errors render as '<source>:<line>: <message>'"
		)


# =============================================================================================
# E. §13.6 "constants read from data, not code" — proven by MUTATING THE DATA
# =============================================================================================

## P10 — change a radius in the params TEXT and the generator must follow. This is the mechanical
## form of the data-vs-code line drawn by decisions.md M1-T1 item 4: if 32 were shadowed by a code
## literal, the mutated document would still answer 32.
func test_map_radii_are_read_from_data() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var ok: bool = generator.load_params_text(
		_mutated('{"id": "medium", "radius": 32}', '{"id": "medium", "radius": 30}'),
		SOURCE
	)
	assert_true(ok, "sanity: the mutated params text is still valid: %s" % [str(_error_lines(generator))])
	assert_eq(generator.radius_for_size("medium"), 30, "§13.6: the radius comes from data")
	assert_eq(
		generator.generate(30).hex_count(),
		HexMath.hex_count_for_radius(30),
		"§13.6: the generated map follows the data-supplied radius"
	)


## P10 — change the §4.4 ring shares in the params TEXT and the band boundaries must move with
## them. Re-derived here from the mutated shares (deep_core 50, mid_mantle 40, safe_rim 10, so
## outer_pct becomes 50 / 90 / 100): at R=24 the Core reaches d=12 (1200 <= 1200) and the Mantle
## d=21 (2100 <= 2160, while 2200 > 2160).
func test_band_shares_are_read_from_data() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var text: String = _mutated('{"id": "safe_rim", "share_pct": 30}', '{"id": "safe_rim", "share_pct": 10}')
	text = text.replace('{"id": "deep_core", "share_pct": 30}', '{"id": "deep_core", "share_pct": 50}')
	var ok: bool = generator.load_params_text(text, SOURCE)
	assert_true(ok, "sanity: 10 + 40 + 50 still sums to 100: %s" % [str(_error_lines(generator))])
	var r: int = RADII[0]
	assert_eq(generator.band_index_at(12, r), DEEP_CORE, "§13.6: a 50%% Core reaches d=12 at R=24")
	assert_eq(generator.band_index_at(13, r), MID_MANTLE, "§13.6: and stops there")
	assert_eq(generator.band_index_at(21, r), MID_MANTLE, "§13.6: the Mantle now reaches d=21 at R=24")
	assert_eq(generator.band_index_at(22, r), SAFE_RIM, "§13.6: and the thin Rim starts at d=22")


## P10 — resolution (N)'s 85 is CONTENT, not a GDD number and not a code literal. Raising it to 90
## must move where elevation 3 begins: at R=24, 90 * 24 == 2160, so d=21 (2100) stays at 2 and
## d=22 (2200) becomes 3.
func test_terrace_thresholds_are_read_from_data() -> void:
	var generator: MapGenerator = MapGenerator.new()
	var ok: bool = generator.load_params_text(
		_mutated('"from_share_pct": 85, "elevation": 3', '"from_share_pct": 90, "elevation": 3'),
		SOURCE
	)
	assert_true(ok, "sanity: the mutated terrace table is still valid: %s" % [str(_error_lines(generator))])
	var r: int = RADII[0]
	assert_eq(generator.elevation_at(21, r), 2, "§13.6: a 90%% split leaves d=21 at elevation 2")
	assert_eq(generator.elevation_at(22, r), 3, "§13.6: and starts elevation 3 at d=22")


# =============================================================================================
# F. MECHANICAL SOURCE SCANS ON scripts/sim/map_generator.gd (§11.1, §11.2, §11.3, §13.6)
#    Written FRESH for this file — `test_hex_math.gd`, `test_los.gd` and `test_hex_map.gd` each
#    scan their own file only, and a new file inherits NOTHING.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)". Both rule functions
## are integer CROSS-MULTIPLICATION (`d * 100 <= outer_pct * R`, `d * 100 > from_pct * R`), so
## there is no division at all and no `@warning_ignore("integer_division")` may appear.
##
## THE SCAN IS DELIBERATELY NARROWED FOR THIS FILE, and the exception is stated rather than the
## scan dropped: Godot 4.7 parses EVERY JSON number as TYPE_FLOAT (decisions.md M0-T2 item 8), so
## the decode boundary CANNOT validate integral-vs-fractional without naming the `float` type. The
## token is therefore permitted only inside PRIVATE helpers (`_is_integral` / `_as_int` and the
## like); no float LITERAL is permitted anywhere, and no public rule function may name the type.
func test_source_contains_no_float_literal_and_confines_float_to_private_helpers() -> void:
	var code: String = _code_text(MAP_GENERATOR_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % MAP_GENERATOR_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			MAP_GENERATOR_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("integer_division"),
		"(M)/(N): the rules are cross-multiplication — %s needs no integer division" % MAP_GENERATOR_PATH
	)

	var token: RegEx = RegEx.new()
	assert_eq(token.compile("\\bfloat\\b"), OK, "sanity: the float-token pattern compiles")
	var offenders: Array[String] = []
	var current: String = ""
	for line: String in code.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			var name_at: int = stripped.find("func ") + 5
			var paren_at: int = stripped.find("(", name_at)
			current = "" if paren_at == -1 else stripped.substr(name_at, paren_at - name_at)
		if token.search(line) == null:
			continue
		if not current.begins_with("_"):
			offenders.append("%s: %s" % ["<module scope>" if current.is_empty() else current, stripped])
	assert_eq(
		offenders.size(),
		0,
		"§11.1: the `float` token is confined to the private JSON-decode helpers; found %s" % [
			str(offenders.slice(0, 5))
		]
	)


## S2 §11.1 "the core must run headless byte-identically". FileAccess and JSON are permitted here
## — `scripts/sim/rules_loader.gd` sets that precedent — but nothing else may bind the engine.
func test_source_is_engine_free() -> void:
	var code: String = _code_text(MAP_GENERATOR_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % MAP_GENERATOR_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim core must be engine-free — %s contains %s" % [MAP_GENERATOR_PATH, banned]
		)


## S3 §4.4 line 238 / §13.6 — THE central data-vs-code pin of this task: the generator READS the
## §4.1 radii from data/mapgen/*.json and must never re-type one.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(MAP_GENERATOR_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % MAP_GENERATOR_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"),
		OK,
		"sanity: the map-size pattern compiles"
	)
	var found: RegExMatch = number.search(code)
	assert_null(
		found,
		"§4.4/§13.6: map sizes live in data/mapgen/*.json — %s must not hard-code %s" % [
			MAP_GENERATOR_PATH, "" if found == null else found.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S4 §11.3 "public rule functions documented with the GDD section they implement", tightened the
## M1-T2 item 11 / M1-T3 item 13 way: the expected public surface is listed explicitly, so a
## MISSING member fails instead of passing vacuously and an EXTRA member (a vein or terrain-type
## entry point pre-empting M1-T5) fails too. The generator must also DELEGATE distance to
## `HexMath.distance(`, never re-derive the metric.
func test_public_api_is_exactly_the_eight_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(MAP_GENERATOR_PATH, public_functions, undocumented)

	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2/§4.4: %s must be a public function of %s" % [required, MAP_GENERATOR_PATH]
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			MAP_GENERATOR_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public rule function needs a '## §4.1'/'## §4.4' doc comment; missing on: %s" % [
			str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(MAP_GENERATOR_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public field surface of %s is exactly %s" % [
			MAP_GENERATOR_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)
	assert_true(
		_code_text(MAP_GENERATOR_PATH).contains("HexMath.distance("),
		"§4.1: the band/terrace rules key off cube distance — call HexMath.distance(), never re-implement it"
	)


## S5 §11.1 "pure GDScript RefCounted classes" + §11.2 (`scripts/sim/` holds GameState and its
## systems). Asserted through get_class() — `is Node` is a PARSE ERROR here, not a failure.
func test_map_generator_is_a_pure_refcounted_in_scripts_sim() -> void:
	assert_true(
		FileAccess.file_exists(MAP_GENERATOR_PATH),
		"§11.2: MapGenerator lives at %s" % MAP_GENERATOR_PATH
	)
	var instance: MapGenerator = MapGenerator.new()
	assert_eq(instance.get_class(), "RefCounted", "§11.1: MapGenerator must be a pure RefCounted")
	assert_true(FileAccess.file_exists(PARAMS_PATH), "§4.4 line 238: the params file lives at %s" % PARAMS_PATH)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A generator configured from the SHIPPED params file, so every rule assertion above is a
## content-drives-code proof rather than a test-fixture proof.
func _loaded() -> MapGenerator:
	var generator: MapGenerator = MapGenerator.new()
	var ok: bool = generator.load_params_file(PARAMS_PATH)
	assert_true(ok, "§12.6: %s must load: %s" % [PARAMS_PATH, str(_error_lines(generator))])
	return generator


## Runs one rejection fixture end to end: a document that differs from a VALID one by exactly one
## planted defect must be rejected with at least one 1-based error attributed to the offending
## top-level key's line, must never emit the reserved line 0, and must leave the generator
## UNCONFIGURED even though it had just loaded successfully.
func _assert_rejected(text: String, key: String, label: String) -> void:
	var generator: MapGenerator = MapGenerator.new()
	var configured: bool = generator.load_params_text(_params_text(), SOURCE)
	assert_true(configured, "sanity [%s]: the un-mutated document loads first" % label)

	var ok: bool = generator.load_params_text(text, SOURCE)
	assert_false(ok, "(P) [%s]: the defect must be rejected" % label)
	assert_true(generator.errors.size() >= 1, "(P) [%s]: rejection reports at least one error" % label)

	var expected_line: int = _line_of(text, key)
	var lines: PackedStringArray = text.split("\n")
	var zero_lines: int = 0
	var off_document: int = 0
	var at_key: int = 0
	for error: RulesError in generator.errors:
		if error.line == 0:
			zero_lines += 1
		if error.line < 0 or error.line > lines.size():
			off_document += 1
		if error.line == expected_line:
			at_key += 1
	assert_eq(zero_lines, 0, "M0-T2 item 2 [%s]: line 0 is reserved for missing files" % label)
	assert_eq(off_document, 0, "(P) [%s]: every error line is inside the document" % label)
	assert_true(
		at_key >= 1,
		"(P) [%s]: an error must point at line %d (the \"%s\" line); got %s" % [
			label, expected_line, key, str(_error_lines(generator))
		]
	)
	assert_eq(
		generator.radius_for_size("medium"),
		0,
		"(P) [%s]: a rejected document leaves the generator UNCONFIGURED" % label
	)
	assert_eq(
		generator.generate(RADII[1]).hex_count(),
		0,
		"(P) [%s]: an unconfigured generator produces the empty map" % label
	)


## The canonical params document as one string.
func _params_text() -> String:
	return _joined(PARAMS_LINES)


## Joins source lines with newlines through a PackedStringArray, which is what String.join takes.
func _joined(source_lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in source_lines:
		packed.append(line)
	return "\n".join(packed)


## The canonical document with exactly one substring replaced — one planted defect per fixture.
func _mutated(from_text: String, to_text: String) -> String:
	var text: String = _params_text()
	assert_true(text.contains(from_text), "sanity: the fixture contains %s" % from_text)
	return text.replace(from_text, to_text)


## 1-based line number of the first line carrying the JSON key token `"key"` — never a magic
## constant (decisions.md M0-T2 item 7).
func _line_of(text: String, key: String) -> int:
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	for i: int in range(lines.size()):
		if lines[i].contains('"%s"' % key):
			return i + 1
	return 1


## Rendered errors, for readable failure messages.
func _error_lines(generator: MapGenerator) -> Array[String]:
	var out: Array[String] = []
	for error: RulesError in generator.errors:
		out.append(error.format_for(SOURCE))
	return out


## §4.4 cumulative share at each band's OUTER edge, summed from the innermost band, with bands
## listed outer to inner — resolution (M), computed from the printed shares alone.
func _cumulative_outer_pct() -> Array[int]:
	var out: Array[int] = []
	for k: int in range(BAND_SHARE_PCT.size()):
		var total: int = 0
		for j: int in range(k, BAND_SHARE_PCT.size()):
			total += BAND_SHARE_PCT[j]
		out.append(total)
	return out


## The largest distance d in 0..radius with `d * 100 <= pct * radius` — resolution (M)'s "<=".
func _last_distance_within(pct: int, radius: int) -> int:
	var last: int = 0
	for d: int in range(radius + 1):
		if d * 100 <= pct * radius:
			last = d
	return last


## The smallest distance d in 0..radius with `d * 100 > pct * radius` — resolution (N)'s STRICT
## ">". Returns radius + 1 when no distance qualifies.
func _first_distance_above(pct: int, radius: int) -> int:
	for d: int in range(radius + 1):
		if d * 100 > pct * radius:
			return d
	return radius + 1


## §4.1's closed form for the number of hexes within distance d of the centre.
func _disc(d: int) -> int:
	if d < 0:
		return 0
	return 3 * d * (d + 1) + 1


## The expected band index for every distance 0..radius, built from the re-derived boundaries.
func _expected_band_sequence(size_index: int) -> Array[int]:
	var out: Array[int] = []
	for d: int in range(RADII[size_index] + 1):
		if d <= CORE_MAX_D[size_index]:
			out.append(DEEP_CORE)
		elif d <= MANTLE_MAX_D[size_index]:
			out.append(MID_MANTLE)
		else:
			out.append(SAFE_RIM)
	return out


## The expected elevation for every distance 0..radius, built from the re-derived boundaries.
func _expected_elevation_sequence(size_index: int) -> Array[int]:
	var out: Array[int] = []
	for d: int in range(RADII[size_index] + 1):
		if d >= ELEV3_MIN_D[size_index]:
			out.append(3)
		elif d >= ELEV2_MIN_D[size_index]:
			out.append(2)
		elif d >= ELEV1_MIN_D[size_index]:
			out.append(1)
		else:
			out.append(0)
	return out


## (M)/(N) alignment: Deep Core is exactly elevation 0, Mid-Mantle exactly 1, and §4.4's
## "Rim 2-3" exactly the Safe Rim.
func _aligned(band: int, elevation: int) -> bool:
	if band == DEEP_CORE:
		return elevation == 0
	if band == MID_MANTLE:
		return elevation == 1
	if band == SAFE_RIM:
		return elevation == 2 or elevation == 3
	return false


## Every elevation of a map in HexMap's canonical order — the sequence the M1-T5 golden will
## hash, and the thing determinism is compared over.
func _elevation_sequence(map: HexMap) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for hex: Vector2i in map.hexes():
		out.append(map.get_elevation(hex))
	return out


## The shipped params file as raw text.
func _shipped_params_text() -> String:
	var file: FileAccess = FileAccess.open(PARAMS_PATH, FileAccess.READ)
	assert_not_null(file, "§4.4 line 238: %s must exist and be readable" % PARAMS_PATH)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## The shipped params file, parsed independently of MapGenerator. Empty when unreadable or
## malformed, which the caller reports rather than crashing on.
func _parsed_shipped_params() -> Dictionary:
	var text: String = _shipped_params_text()
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	var parsed: Error = json.parse(text)
	assert_eq(parsed, OK, "§12.6: %s must be valid JSON" % PARAMS_PATH)
	if parsed != OK:
		return {}
	var data: Variant = json.data
	assert_true(data is Dictionary, "§12.6: the params document root is a JSON object")
	if not (data is Dictionary):
		return {}
	return data


## A parsed JSON array element as a Dictionary, through a typed local (a Variant handed straight
## to a typed parameter is a hard parse error — the trap recorded in docs/PROGRESS.md).
func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## An integral JSON number as an int. Godot parses every JSON number as TYPE_FLOAT, so this also
## asserts the value has no fractional part rather than truncating it (M0-T2 item 8).
func _integral(value: Variant) -> int:
	var number: float = 0.0
	if value is float:
		number = value
	elif value is int:
		number = float(value)
	else:
		assert_true(false, "§12.6: expected a JSON number, got %s" % [value])
		return -1
	var truncated: int = int(number)
	assert_eq(number, float(truncated), "M0-T2 item 8: %s must be an integral JSON number" % [value])
	return truncated


## Walks a source file and fills `public_functions` with every public function name (in source
## order) and `undocumented` with those whose preceding comment block cites neither §4.1 nor §4.4.
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
		if not (doc_block.contains("§4.1") or doc_block.contains("§4.4")):
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
