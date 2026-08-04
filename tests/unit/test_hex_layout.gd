## HexLayout + data/render/greybox.json — GDD §4.1 ("**Flat-top hexes, axial coordinates (q, r)**";
## "Elevation: integer 0-3 per hex"; the map-size table), §1.2 ("Hex scale ~ 15-20 m (cosmetic
## only)"), §10 ("Rock rendered as chunked MultiMeshInstance3D (per-instance custom data =
## type/tint); dirty-chunk rebuilds on dig"), §11.1 (data -> Sim Core -> EventBus -> Renderer/UI;
## the sim never calls the renderer), §11.2 (`scripts/render/`), §11.3, §13.2 tier 1, §13.6,
## §14 M1 ("chunked MultiMesh renderer").
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §4.1 line 171: "**Flat-top hexes, axial coordinates (q, r)**; cube coordinates for
##                  algorithms. Distance = cube distance. Neighbor order (fixed, index 0-5): E,
##                  NE, NW, W, SW, SE."
##   §4.1 line 173: "**Elevation:** integer 0-3 per hex."
##   §4.1 line 174: "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40
##                  (4,921)." — used here ONLY as a test fixture for the partition sweeps.
##   §1.2 line 41:  "Hex scale ~ 15-20 m (cosmetic only)." — a RANGE, not a value.
##   §10 line 680:  "Rock rendered as chunked MultiMeshInstance3D (per-instance custom data =
##                  type/tint); dirty-chunk rebuilds on dig. Target: Medium map at 60 fps on
##                  mid-range hardware; SDFGI off." — mandates CHUNKING, prints no chunk size.
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §4.1, §1.2 or §10**, so the printed text above governs unamended. FLAT-TOP is the only screen
## orientation §4.1 states; §4.1's neighbour NAMES (E, NE, NW, W, SW, SE) are pointy-top naming
## and were already settled by **decisions.md M1-T1 resolution (A)** as INDEX LABELS ONLY, with
## screen orientation explicitly deferred to "the later M1 renderer/camera task, which changes no
## sim value". **This is that task, and NO sim value changes here.**
##
## §4.1 prints no placement formula, §1.2 prints a range rather than a number and §10 prints no
## chunk size, so every value below is either DERIVED from the printed text or is NEW TUNABLE
## CONTENT that must live in `data/render/greybox.json`. The §13.4 resolutions this file pins
## continue M1-T5's lettering at (V) — keep it stable:
##   (V) FLAT-TOP IS THE RENDERER'S SCREEN ORIENTATION, because §4.1's bolded "Flat-top hexes" is
##       the only orientation the GDD states. Consequence: index 0 ("E") points 30 degrees south
##       of screen-east. The direction NAMES remain pure index labels (M1-T1 (A)); no sim value
##       moves.
##   (W) LAYOUT FORMULA, UNITS AND ORIGIN. Hexes lie on the XZ ground plane with +Y up and hex
##       (0, 0) at the world origin. With circumradius `R = hex_width_m / 2`:
##           world.x = 1.5 * R * q
##           world.z = SQRT_3 * R * (r + 0.5 * q)
##           world.y = elevation * elevation_step_m
##   (X) CHUNK PARTITION. Chunks are axial squares of `chunk_hexes` edge:
##       `chunk_of(h) == Vector2i(floor_div(h.x, chunk_hexes), floor_div(h.y, chunk_hexes))` with
##       a TRUE floor, never GDScript's truncating int/int. `chunk_keys(hexes)` returns the
##       DISTINCT chunk coordinates sorted ascending by chunk-r (y) then chunk-q (x) — the same
##       (r, then q) ordering as HexMap's canonical order (decisions.md M1-T4 (O)). `partition`
##       returns index buckets parallel to `chunk_keys`, each in input order.
##   (Y) LOAD CONTRACT, mirroring MapGenerator's resolution (P) exactly and REUSING `RulesError`
##       from a render-side file rather than inventing a second line-numbered error type. All
##       errors collected, 1-based lines, line 0 RESERVED for missing/unreadable files, error
##       order follows the loader's own declared key-spec order (never the parsed Dictionary's),
##       and ANY error leaves the layout UNCONFIGURED — including a failed load after a
##       successful one.
##
## SHIPPED CONTENT (all three numbers are NEW tunable content, logged in decisions.md):
##   `hex_width_m` 18 sits inside §1.2's printed 15-20 range; `elevation_step_m` 3 and
##   `chunk_hexes` 8 have no printed counterpart at all (§4.1/§10 give neither).
##
## SCOPE: this suite pins the PURE half of the renderer only. No Node, no `.tscn`, no mesh,
## material or MultiMesh is created or asserted here — measured this iteration, the headless dummy
## renderer does not store MultiMesh instance data at all (a `set_instance_transform` reads back as
## the identity), so per-instance placement can only ever be verified through plain values. The
## Node half is M1-T7 (§13.4: invent nothing ahead of its milestone).
##
## §13.6 clauses that are VACUOUS here, stated rather than assumed: `HexLayout` mutates no
## GameState and touches no EventBus, so "events emitted for every state change" has no subject
## matter. This task reads **zero** §12.1 constants and `data/ruleset.json` gains no key — the
## greybox tunables are a different schema with their own loader. Goldens: none re-recorded; the
## project's single golden (`tests/golden/mapgen_concentric_bowl_small_seed1337.json`) is not
## touched, and nothing here can move it because no sim value changes.
##
## Godot 4.7 JSON facts this file depends on, already measured (decisions.md M0-T2 item 8, do not
## re-derive): `JSON.get_error_line()` is 0-BASED (the loader normalizes +1); the parser ACCEPTS
## trailing commas, so they are useless as a syntax-error fixture (pinned below); EVERY JSON number
## arrives as TYPE_FLOAT, even `8` — so an int leaf must ACCEPT an integral float and REJECT a
## fractional one, never truncate.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Non-Node-ness is asserted via get_class() ONLY.
##
## HARNESS TRAP (decisions.md M1-T5 item 9, standing rule): `tools/run_tests.sh` greps the WHOLE
## run output for "Nothing was run" / "does not exist" / "have not been imported" / "Failed to load
## script" / "Ignoring script". No failure message in this file may contain any of them — this file
## says "is MISSING".
##
## The source scans below are written FRESH for `scripts/render/hex_layout.gd` and are the MIRROR
## IMAGE of the sim scans: they inherit NOTHING from `test_hex_math.gd`, `test_los.gd`,
## `test_hex_map.gd`, `test_map_generator.gd` or `test_rng.gd`. Floats ARE expected here (renderer
## geometry is not a §11.1 rule surface), so the no-float scan is deliberately NOT copied.
extends GutTest

const LAYOUT_PATH: String = "res://scripts/render/hex_layout.gd"
const GREYBOX_PATH: String = "res://data/render/greybox.json"
const MISSING_GREYBOX_PATH: String = "res://data/render/__no_such_greybox__.json"
const SOURCE: String = "greybox.json"

# ---------------------------------------------------------------------------------------------
# The shipped tunables and the geometry derived from them. Every derived number is re-checked
# against the formula in `test_the_pinned_geometry_is_re_derived_from_the_printed_gdd_text`, the
# M1-T1 item 3 / M1-T2 item 9 / M1-T3 item 8 standing rule made executable: if a pinned decimal
# below were a typo, that test fails BEFORE any implementation is blamed for it.
# ---------------------------------------------------------------------------------------------

## Mathematical constant, transcribed independently of `hex_layout.gd`.
const SQRT_3: float = 1.7320508075688772

const HEX_WIDTH_M: float = 18.0
const ELEVATION_STEP_M: float = 3.0
const CHUNK_HEXES: int = 8

## (W) — circumradius: half the corner-to-corner width of a flat-top hex.
const CIRCUMRADIUS_M: float = 9.0

## §1.2 line 41 — "Hex scale ~ 15-20 m (cosmetic only)": the printed RANGE the shipped width sits
## inside. These two are the only §1.2 numbers; 18 is content chosen within them.
const SCALE_MIN_M: float = 15.0
const SCALE_MAX_M: float = 20.0

## Column pitch `1.5 * R` and row pitch `SQRT_3 * R` for the shipped width.
const COLUMN_STEP: float = 13.5
const ROW_STEP: float = 15.588457268119896
const HALF_ROW_STEP: float = 7.794228634059948

const TOL: float = 0.000001

## §4.1 line 173 — "Elevation: integer 0-3 per hex". All four values are pinned.
const MIN_ELEVATION: int = 0
const MAX_ELEVATION: int = 3

## (W) — world.y for elevations 0, 1, 2, 3 at the shipped step. Re-derived in the self-check test.
const PINNED_ELEVATION_Y: Array[float] = [0.0, 3.0, 6.0, 9.0]

## (W) — the hand-walked placement table. Parallel arrays: hex, expected world.x, expected world.z
## (at elevation 0). The seven middle entries are the origin's six §4.1 neighbours plus the origin.
const PLACEMENT_HEXES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(2, 3),
	Vector2i(-3, -2),
]
const PLACEMENT_X: Array[float] = [
	0.0,
	13.5,
	13.5,
	0.0,
	-13.5,
	-13.5,
	0.0,
	27.0,
	-40.5,
]
const PLACEMENT_Z: Array[float] = [
	0.0,
	7.794228634059948,
	-7.794228634059948,
	-15.588457268119896,
	-7.794228634059948,
	7.794228634059948,
	15.588457268119896,
	62.35382907247958,
	-54.55960043841964,
]

## (X) — the chunk-assignment table. The negatives ARE the trap: a truncating `int / int` collapses
## the four chunks around the origin into one 15x15 super-chunk.
const CHUNK_PROBE_HEXES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(7, 7),
	Vector2i(8, 7),
	Vector2i(7, 8),
	Vector2i(-1, -1),
	Vector2i(-8, -8),
	Vector2i(-9, -9),
	Vector2i(24, -24),
	Vector2i(-24, 24),
	Vector2i(-17, 16),
]
const CHUNK_PROBE_EXPECTED: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, -1),
	Vector2i(-1, -1),
	Vector2i(-2, -2),
	Vector2i(3, -3),
	Vector2i(-3, 3),
	Vector2i(-3, 2),
]

## §4.1 line 174 — map radii used ONLY as partition fixtures (the six literals are forbidden in
## `hex_layout.gd` by source scan).
const SMALL_RADIUS: int = 24
const MEDIUM_RADIUS: int = 32
const SMALL_HEX_COUNT: int = 1801
const MEDIUM_HEX_COUNT: int = 3169

## The two map sizes every partition sweep runs over, as a typed array.
const FIXTURE_RADII: Array[int] = [SMALL_RADIUS, MEDIUM_RADIUS]
const FIXTURE_HEX_COUNTS: Array[int] = [SMALL_HEX_COUNT, MEDIUM_HEX_COUNT]

## The four hexes straddling the origin — one per quadrant, each just inside its own chunk. A
## truncating `int / int` collapses all four into chunk (0, 0).
const ORIGIN_QUADRANT_HEXES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)
]

## The two whole chunk squares walked cell by cell (one positive, one negative).
const CHUNK_SQUARE_BASES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, -1)]

## A finer chunk size used to prove `chunk_hexes` is genuinely read from data.
const FINE_CHUNK_HEXES: int = 4

## Stride of the deterministic (RNG-free, §11.1) input shuffle. Coprime with both fixture sizes,
## which the helper re-checks by asserting the result is a permutation.
const SHUFFLE_STRIDE: int = 977

# ---------------------------------------------------------------------------------------------
# The canonical greybox document. Layout follows data/ruleset.json's LOAD-BEARING convention
# (decisions.md M0-T2 item 7): line 1 is a lone `{` and each top-level key occupies exactly ONE
# line, so a single-line defect is plantable and every expected error line is computed from the
# fixture instead of being a magic constant.
# ---------------------------------------------------------------------------------------------
const GREYBOX_LINES: Array[String] = [
	'{',
	'  "id": "greybox",',
	'  "hex_width_m": 18,',
	'  "elevation_step_m": 3,',
	'  "chunk_hexes": 8',
	'}',
]

## The three required keys, in the order the loader's own key-spec table must walk them.
const TUNABLE_KEYS: Array[String] = ["hex_width_m", "elevation_step_m", "chunk_hexes"]

## A document that presents the three keys in the OPPOSITE order and breaks all three, so error
## ORDER can only come from the loader's declared spec table, never from the parsed Dictionary.
const SCRAMBLED_LINES: Array[String] = [
	'{',
	'  "chunk_hexes": "eight",',
	'  "elevation_step_m": -1,',
	'  "hex_width_m": 0',
	'}',
]

# ---------------------------------------------------------------------------------------------
# Source-scan vocabularies (§11.1, §11.2, §11.3, §13.6).
# ---------------------------------------------------------------------------------------------

## §11.1 — HexLayout is a pure [RefCounted]; the Node arrives at M1-T7. `RandomNumberGenerator`
## stays forbidden project-wide outside `scripts/core/rng.gd` (decisions.md M1-T5 (R)).
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

## §11.1 — the MIRROR-IMAGE half, replacing the sim suites' purity assertions: the renderer never
## names a sim class and never mutates sim state. `RulesError` is EXPLICITLY ALLOWED (it is the
## project's shared line-numbered error value type) and is asserted PRESENT below, not forbidden.
const SIM_BOUNDARY_TOKENS: Array[String] = [
	"HexMap",
	"MapGenerator",
	"Rng",
	"set_elevation(",
	"set_terrain_type(",
]

## §4.1's radii and hex counts are tunable content in data/, never in engine code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## §13.6 — the three shipped tunables must come from `data/render/greybox.json`, so none of them
## may appear as a bare numeric literal in the source.
const DATA_DRIVEN_TOKENS: Array[String] = ["18", "3", "8"]

## The COMPLETE public function surface of HexLayout (§13.4: invent nothing ahead of its
## milestone — no mesh builder, no MultiMesh helper, no camera or picking entry point).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"load_params_text",
	"load_params_file",
	"hex_width_m",
	"elevation_step_m",
	"chunk_hexes",
	"hex_to_world",
	"chunk_of",
	"chunk_keys",
	"partition",
]

## The COMPLETE public field surface — the existing shared error type, and nothing else.
const REQUIRED_PUBLIC_VARS: Array[String] = ["errors"]

## Doc-comment sections accepted by the §11.3 scan for this file.
const DOC_SECTIONS: Array[String] = ["§4.1", "§1.2", "§10", "§11.2"]


# =============================================================================================
# A. THE PRINTED GDD TEXT, THE SHIPPED CONTENT, AND THE SELF-CHECK OF EVERY DERIVED NUMBER
# =============================================================================================

## The mechanical re-derivation demanded by the M1-T1 item 3 / M1-T2 item 9 / M1-T3 item 8
## standing rule: every derived decimal pinned in this file is recomputed here from SQRT_3 and the
## shipped width alone, using nothing from `hex_layout.gd`.
func test_the_pinned_geometry_is_re_derived_from_the_printed_gdd_text() -> void:
	assert_almost_eq(SQRT_3 * SQRT_3, 3.0, TOL, "sanity: SQRT_3 squared is 3")
	assert_almost_eq(
		CIRCUMRADIUS_M,
		HEX_WIDTH_M / 2.0,
		TOL,
		"(W): the circumradius is half the corner-to-corner hex width"
	)
	assert_almost_eq(COLUMN_STEP, 1.5 * CIRCUMRADIUS_M, TOL, "(W): column pitch is 1.5 * R")
	assert_almost_eq(ROW_STEP, SQRT_3 * CIRCUMRADIUS_M, TOL, "(W): row pitch is SQRT_3 * R")
	assert_almost_eq(HALF_ROW_STEP, ROW_STEP / 2.0, TOL, "(W): the half-row offset is ROW_STEP / 2")

	assert_eq(PLACEMENT_HEXES.size(), PLACEMENT_X.size(), "sanity: the placement table is parallel")
	assert_eq(PLACEMENT_HEXES.size(), PLACEMENT_Z.size(), "sanity: the placement table is parallel")
	var wrong: Array[String] = []
	for i: int in range(PLACEMENT_HEXES.size()):
		var hex: Vector2i = PLACEMENT_HEXES[i]
		var expected_x: float = 1.5 * CIRCUMRADIUS_M * float(hex.x)
		var expected_z: float = SQRT_3 * CIRCUMRADIUS_M * (float(hex.y) + 0.5 * float(hex.x))
		if absf(PLACEMENT_X[i] - expected_x) > TOL:
			wrong.append("%s x pinned %f vs derived %f" % [str(hex), PLACEMENT_X[i], expected_x])
		if absf(PLACEMENT_Z[i] - expected_z) > TOL:
			wrong.append("%s z pinned %f vs derived %f" % [str(hex), PLACEMENT_Z[i], expected_z])
	assert_eq(wrong.size(), 0, "(W): every pinned placement is the formula's own answer; %s" % [
		str(wrong)
	])

	assert_eq(
		CHUNK_PROBE_HEXES.size(),
		CHUNK_PROBE_EXPECTED.size(),
		"sanity: the chunk table is parallel"
	)
	var chunk_wrong: Array[String] = []
	for i: int in range(CHUNK_PROBE_HEXES.size()):
		var hex: Vector2i = CHUNK_PROBE_HEXES[i]
		var derived: Vector2i = Vector2i(
			_floor_div(hex.x, CHUNK_HEXES), _floor_div(hex.y, CHUNK_HEXES)
		)
		if derived != CHUNK_PROBE_EXPECTED[i]:
			chunk_wrong.append("%s pinned %s vs derived %s" % [
				str(hex), str(CHUNK_PROBE_EXPECTED[i]), str(derived)
			])
	assert_eq(chunk_wrong.size(), 0, "(X): every pinned chunk is true floor division; %s" % [
		str(chunk_wrong)
	])

	assert_eq(
		HexMath.hex_count_for_radius(SMALL_RADIUS),
		SMALL_HEX_COUNT,
		"§4.1 line 174: Small radius 24 is 1,801 hexes"
	)
	assert_eq(
		HexMath.hex_count_for_radius(MEDIUM_RADIUS),
		MEDIUM_HEX_COUNT,
		"§4.1 line 174: Medium radius 32 is 3,169 hexes"
	)

	assert_eq(
		PINNED_ELEVATION_Y.size(),
		MAX_ELEVATION - MIN_ELEVATION + 1,
		"§4.1 line 173: all four elevation levels 0-3 are pinned"
	)
	var elevation_wrong: Array[String] = []
	for elevation: int in range(MIN_ELEVATION, MAX_ELEVATION + 1):
		var derived: float = ELEVATION_STEP_M * float(elevation)
		if absf(PINNED_ELEVATION_Y[elevation] - derived) > TOL:
			elevation_wrong.append("elevation %d pinned %f vs derived %f" % [
				elevation, PINNED_ELEVATION_Y[elevation], derived
			])
	assert_eq(elevation_wrong.size(), 0, "(W): world.y is elevation * elevation_step_m; %s" % [
		str(elevation_wrong)
	])


## §1.2 line 41 — "Hex scale ~ 15-20 m (cosmetic only)" is a RANGE, so the test pins BOTH that the
## shipped width satisfies it AND the exact shipped value, which is new tunable content.
func test_the_shipped_hex_width_sits_inside_the_printed_section_1_2_range() -> void:
	assert_true(
		HEX_WIDTH_M >= SCALE_MIN_M,
		"§1.2: the hex scale is at least %f m (got %f)" % [SCALE_MIN_M, HEX_WIDTH_M]
	)
	assert_true(
		HEX_WIDTH_M <= SCALE_MAX_M,
		"§1.2: the hex scale is at most %f m (got %f)" % [SCALE_MAX_M, HEX_WIDTH_M]
	)
	var layout: HexLayout = _loaded()
	assert_almost_eq(
		layout.hex_width_m(),
		HEX_WIDTH_M,
		TOL,
		"§1.2/(W): the shipped greybox hex width"
	)


## §13.6 — the shipped content file carries exactly the three tunables, transcribed here from the
## file itself rather than from the loader, so a content edit is caught even if the loader agrees
## with it.
func test_the_shipped_greybox_file_transcribes_the_pinned_tunables() -> void:
	var root: Dictionary = _parsed_shipped_greybox()
	assert_true(root.has("hex_width_m"), "§13.6: the greybox file carries hex_width_m")
	assert_true(root.has("elevation_step_m"), "§13.6: the greybox file carries elevation_step_m")
	assert_true(root.has("chunk_hexes"), "§13.6: the greybox file carries chunk_hexes")
	assert_almost_eq(
		_numeric(root.get("hex_width_m", null)),
		HEX_WIDTH_M,
		TOL,
		"§1.2: the shipped hex_width_m"
	)
	assert_almost_eq(
		_numeric(root.get("elevation_step_m", null)),
		ELEVATION_STEP_M,
		TOL,
		"(W): the shipped elevation_step_m"
	)
	assert_almost_eq(
		_numeric(root.get("chunk_hexes", null)),
		float(CHUNK_HEXES),
		TOL,
		"§10/(X): the shipped chunk_hexes"
	)


## decisions.md M0-T2 item 7 — the layout of the shipped file is LOAD-BEARING, not cosmetic: line 1
## is a lone `{` and every top-level key sits at the start of exactly one line, which is the only
## reason schema-error line attribution is meaningful.
func test_the_shipped_greybox_file_layout_is_line_addressable() -> void:
	var lines: PackedStringArray = _shipped_greybox_text().replace("\r\n", "\n").split("\n")
	assert_true(lines.size() >= 3, "M0-T2 item 7: the greybox file has a line-addressable layout")
	assert_eq(lines[0].strip_edges(), "{", "M0-T2 item 7: line 1 is a lone opening brace")
	for key: String in TUNABLE_KEYS:
		var hits: int = 0
		for line: String in lines:
			if line.strip_edges().begins_with('"%s":' % key):
				hits += 1
		assert_eq(hits, 1, "M0-T2 item 7: \"%s\" starts exactly one line of %s" % [key, GREYBOX_PATH])


## The in-file fixture and the shipped content are the same document, so every rejection fixture
## below really is "the shipped file plus exactly one planted defect".
func test_the_canonical_fixture_matches_the_shipped_greybox_file() -> void:
	assert_eq(
		_shipped_greybox_text().replace("\r\n", "\n").strip_edges(),
		_greybox_text().strip_edges(),
		"the GREYBOX_LINES fixture must equal the shipped %s" % GREYBOX_PATH
	)


## (Y) — the shipped file loads clean and configures all three accessors.
func test_the_shipped_greybox_file_loads_clean() -> void:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_file(GREYBOX_PATH)
	assert_true(ok, "(Y): %s must load: %s" % [GREYBOX_PATH, str(_error_lines(layout))])
	assert_eq(_error_lines(layout), [] as Array[String], "(Y): a valid document yields no errors")
	assert_almost_eq(layout.hex_width_m(), HEX_WIDTH_M, TOL, "(Y): hex_width_m is configured")
	assert_almost_eq(
		layout.elevation_step_m(),
		ELEVATION_STEP_M,
		TOL,
		"(Y): elevation_step_m is configured"
	)
	assert_eq(layout.chunk_hexes(), CHUNK_HEXES, "(Y): chunk_hexes is configured")


# =============================================================================================
# B. THE LAYOUT FORMULA — resolution (W), §4.1 + §1.2
# =============================================================================================

## (W) — hex (0, 0) sits at the world origin at elevation 0. Everything else is measured from here.
func test_the_origin_hex_sits_at_the_world_origin() -> void:
	var layout: HexLayout = _loaded()
	assert_eq(
		layout.hex_to_world(Vector2i.ZERO, MIN_ELEVATION),
		Vector3.ZERO,
		"(W): hex (0, 0) at elevation 0 is the world origin"
	)


## (W) — the hand-walked placement table, component by component. These nine values are the whole
## formula: a wrong pitch, a wrong axis or a missing half-row offset fails here immediately.
func test_hex_to_world_matches_the_pinned_flat_top_placement_table() -> void:
	var layout: HexLayout = _loaded()
	for i: int in range(PLACEMENT_HEXES.size()):
		var hex: Vector2i = PLACEMENT_HEXES[i]
		var world: Vector3 = layout.hex_to_world(hex, MIN_ELEVATION)
		assert_almost_eq(world.x, PLACEMENT_X[i], TOL, "(W): world.x of %s" % str(hex))
		assert_almost_eq(world.y, 0.0, TOL, "(W): elevation 0 lies on the ground plane at %s" % str(hex))
		assert_almost_eq(world.z, PLACEMENT_Z[i], TOL, "(W): world.z of %s" % str(hex))


## (W)/(V) — under a FLAT-TOP layout `world.x` is a function of `q` ALONE. Under pointy-top it
## depends on both axes, so this property is one half of the orientation discriminator.
func test_world_x_depends_only_on_q() -> void:
	var layout: HexLayout = _loaded()
	var breaks: Array[String] = []
	for q: int in range(-4, 5):
		var reference: float = layout.hex_to_world(Vector2i(q, 0), MIN_ELEVATION).x
		for r: int in range(-4, 5):
			var observed: float = layout.hex_to_world(Vector2i(q, r), MIN_ELEVATION).x
			if absf(observed - reference) > TOL:
				breaks.append("q=%d r=%d gave x=%f, expected %f" % [q, r, observed, reference])
		if absf(reference - COLUMN_STEP * float(q)) > TOL:
			breaks.append("column q=%d is at x=%f, not %f" % [q, reference, COLUMN_STEP * float(q)])
	assert_eq(breaks.size(), 0, "(V)/(W): flat-top columns — world.x depends on q alone; %s" % [
		str(breaks.slice(0, 5))
	])


## §4.1 line 173 ("Elevation: integer 0-3 per hex") — the Y axis is a LINEAR function of that
## integer, all four values pinned, and it is the only component elevation touches.
func test_elevation_is_a_linear_y_axis_over_the_printed_zero_to_three_range() -> void:
	var layout: HexLayout = _loaded()
	var ground: Vector3 = layout.hex_to_world(Vector2i(2, 3), MIN_ELEVATION)
	for elevation: int in range(MIN_ELEVATION, MAX_ELEVATION + 1):
		var world: Vector3 = layout.hex_to_world(Vector2i(2, 3), elevation)
		assert_almost_eq(
			world.y,
			PINNED_ELEVATION_Y[elevation],
			TOL,
			"§4.1/(W): elevation %d stands %f m above the floor" % [
				elevation, PINNED_ELEVATION_Y[elevation]
			]
		)
		assert_almost_eq(world.x, ground.x, TOL, "(W): elevation never moves world.x")
		assert_almost_eq(world.z, ground.z, TOL, "(W): elevation never moves world.z")
	assert_almost_eq(
		layout.hex_to_world(Vector2i.ZERO, MAX_ELEVATION).y,
		PINNED_ELEVATION_Y[MAX_ELEVATION],
		TOL,
		"§4.1/(W): the printed maximum elevation 3 is the top terrace"
	)


# =============================================================================================
# C. THE ORIENTATION DISCRIMINATOR — resolution (V), the load-bearing half of this task
#    Equidistance ALONE cannot tell flat-top from pointy-top: both layouts place all six
#    neighbours at exactly SQRT_3 * R. Only the per-direction assertions below separate them,
#    which is why both directions of the discriminator are asserted.
# =============================================================================================

## §4.1 — all six neighbours of a hex sit at exactly one row pitch, in every direction. True of
## BOTH orientations, so this is the sanity half, not the discriminating half.
func test_all_six_neighbours_are_equidistant_at_one_row_step() -> void:
	var layout: HexLayout = _loaded()
	var centre: Vector3 = layout.hex_to_world(Vector2i.ZERO, MIN_ELEVATION)
	var wrong: Array[String] = []
	for dir: int in range(HexMath.DIRECTIONS.size()):
		var neighbour: Vector2i = HexMath.neighbor(Vector2i.ZERO, dir)
		var offset: Vector3 = layout.hex_to_world(neighbour, MIN_ELEVATION) - centre
		if absf(offset.length() - ROW_STEP) > TOL:
			wrong.append("dir %d (%s) is %f from centre" % [dir, str(neighbour), offset.length()])
	assert_eq(HexMath.DIRECTIONS.size(), 6, "sanity: §4.1 fixes six directions")
	assert_eq(wrong.size(), 0, "(W): every neighbour sits at one row pitch (%f); %s" % [
		ROW_STEP, str(wrong)
	])


## (V) — THE DISCRIMINATOR. Under FLAT-TOP, §4.1 index 2 (0,-1) and index 5 (0,+1) run straight
## along -Z / +Z with world.x EXACTLY 0, while index 0 (+1,0) has BOTH components non-zero. Under
## POINTY-TOP these invert (index 0 would be (SQRT_3*R, 0) and index 2 (-0.5*SQRT_3*R, -1.5*R)),
## so both directions are asserted. The direction NAMES stay pure index labels — decisions.md
## M1-T1 resolution (A); no sim value changes here.
func test_the_layout_is_flat_top_and_not_pointy_top() -> void:
	var layout: HexLayout = _loaded()

	var north: Vector3 = layout.hex_to_world(HexMath.neighbor(Vector2i.ZERO, 2), MIN_ELEVATION)
	var south: Vector3 = layout.hex_to_world(HexMath.neighbor(Vector2i.ZERO, 5), MIN_ELEVATION)
	assert_eq(north.x, 0.0, "(V): flat-top — §4.1 index 2 (0,-1) runs straight along -Z")
	assert_eq(south.x, 0.0, "(V): flat-top — §4.1 index 5 (0,+1) runs straight along +Z")
	assert_almost_eq(north.z, -ROW_STEP, TOL, "(V): index 2 is one full row pitch toward -Z")
	assert_almost_eq(south.z, ROW_STEP, TOL, "(V): index 5 is one full row pitch toward +Z")

	var east: Vector3 = layout.hex_to_world(HexMath.neighbor(Vector2i.ZERO, 0), MIN_ELEVATION)
	assert_almost_eq(east.x, COLUMN_STEP, TOL, "(V): index 0 (+1,0) advances one column pitch")
	assert_almost_eq(east.z, HALF_ROW_STEP, TOL, "(V): index 0 is offset half a row — 30 deg off +X")
	assert_true(
		absf(east.x) > TOL and absf(east.z) > TOL,
		"(V)/M1-T1 (A): flat-top — index 0 has BOTH components non-zero, got (%f, %f)" % [
			east.x, east.z
		]
	)
	assert_true(
		absf(east.x - ROW_STEP) > TOL,
		"(V)/M1-T1 (A): this is NOT pointy-top — index 0 must not lie at (SQRT_3*R, 0)"
	)
	assert_true(
		absf(north.x) < TOL,
		"(V)/M1-T1 (A): this is NOT pointy-top — index 2 must not carry a horizontal component"
	)


## (V)/(W) — every one of §4.1's six fixed direction deltas, resolved to its exact world offset.
## The fixed index order is M1-T1 resolution (A) and is load-bearing for the renderer too.
func test_every_direction_offset_matches_the_fixed_section_4_1_order() -> void:
	var layout: HexLayout = _loaded()
	var expected_x: Array[float] = [
		COLUMN_STEP, COLUMN_STEP, 0.0, -COLUMN_STEP, -COLUMN_STEP, 0.0
	]
	var expected_z: Array[float] = [
		HALF_ROW_STEP, -HALF_ROW_STEP, -ROW_STEP, -HALF_ROW_STEP, HALF_ROW_STEP, ROW_STEP
	]
	for dir: int in range(HexMath.DIRECTIONS.size()):
		var neighbour: Vector2i = HexMath.neighbor(Vector2i.ZERO, dir)
		var world: Vector3 = layout.hex_to_world(neighbour, MIN_ELEVATION)
		assert_almost_eq(world.x, expected_x[dir], TOL, "(W): world.x of direction %d (%s)" % [
			dir, HexMath.DIRECTION_NAMES[dir]
		])
		assert_almost_eq(world.z, expected_z[dir], TOL, "(W): world.z of direction %d (%s)" % [
			dir, HexMath.DIRECTION_NAMES[dir]
		])


# =============================================================================================
# D. CHUNK ASSIGNMENT — resolution (X), §10 ("chunked MultiMeshInstance3D")
# =============================================================================================

## (X) — the hand-walked chunk table. TRUE floor division, never GDScript's truncating int/int
## (the M1-T2 trap-2 family, re-pinned in its second file).
func test_chunk_of_uses_true_floor_division_including_negative_coordinates() -> void:
	var layout: HexLayout = _loaded()
	for i: int in range(CHUNK_PROBE_HEXES.size()):
		assert_eq(
			layout.chunk_of(CHUNK_PROBE_HEXES[i]),
			CHUNK_PROBE_EXPECTED[i],
			"(X): chunk_of(%s)" % str(CHUNK_PROBE_HEXES[i])
		)


## (X) — the trap stated as its own failure mode: a truncating implementation maps (-1,-1) to
## (0,0), merging the four chunks around the origin into one 15x15 super-chunk. The four hexes
## just inside each quadrant of the origin must land in four DISTINCT chunks.
func test_chunk_of_never_merges_the_four_chunks_around_the_origin() -> void:
	var layout: HexLayout = _loaded()
	var seen: Dictionary = {}
	for hex: Vector2i in ORIGIN_QUADRANT_HEXES:
		seen[layout.chunk_of(hex)] = true
	assert_eq(
		seen.size(),
		4,
		"(X): truncating division would merge these four hexes into one chunk; got %d chunk(s)" % [
			seen.size()
		]
	)
	assert_eq(layout.chunk_of(Vector2i(-1, -1)), Vector2i(-1, -1), "(X): (-1,-1) floors to (-1,-1)")


## (X) — a chunk really is an axial square of `chunk_hexes` edge: all 64 cells of chunk (0,0) and
## all 64 of chunk (-1,-1) map to their own chunk and to nothing else.
func test_chunk_of_is_constant_across_one_whole_chunk_square() -> void:
	var layout: HexLayout = _loaded()
	var wrong: Array[String] = []
	var counted: int = 0
	for base: Vector2i in CHUNK_SQUARE_BASES:
		var origin_x: int = base.x * CHUNK_HEXES
		var origin_y: int = base.y * CHUNK_HEXES
		for dx: int in range(CHUNK_HEXES):
			for dy: int in range(CHUNK_HEXES):
				var hex: Vector2i = Vector2i(origin_x + dx, origin_y + dy)
				counted += 1
				if layout.chunk_of(hex) != base:
					wrong.append("%s -> %s, expected %s" % [
						str(hex), str(layout.chunk_of(hex)), str(base)
					])
	assert_eq(counted, 2 * CHUNK_HEXES * CHUNK_HEXES, "sanity: both chunk squares were walked")
	assert_eq(wrong.size(), 0, "(X): a chunk is an axial square of %d hexes on a side; %s" % [
		CHUNK_HEXES, str(wrong.slice(0, 5))
	])


# =============================================================================================
# E. THE PARTITION — resolution (X), swept over the real §4.1 Small and Medium maps
# =============================================================================================

## (X)/decisions.md M1-T4 (O) — chunk keys are DISTINCT and sorted ascending by chunk-r (y) then
## chunk-q (x): the same (r, then q) ordering HexMap's canonical order uses, so the renderer and
## the sim walk the world the same way.
func test_chunk_keys_are_distinct_and_sorted_by_chunk_r_then_chunk_q() -> void:
	var layout: HexLayout = _loaded()
	for radius: int in FIXTURE_RADII:
		var keys: Array[Vector2i] = layout.chunk_keys(_map_hexes(radius))
		assert_true(keys.size() > 1, "(X): radius %d must be genuinely chunked, got %d key(s)" % [
			radius, keys.size()
		])
		var out_of_order: Array[String] = []
		for i: int in range(1, keys.size()):
			if not _chunk_less(keys[i - 1], keys[i]):
				out_of_order.append("%s then %s" % [str(keys[i - 1]), str(keys[i])])
		assert_eq(
			out_of_order.size(),
			0,
			"(X): radius %d keys ascend by chunk-r then chunk-q (and are distinct); %s" % [
				radius, str(out_of_order.slice(0, 5))
			]
		)


## (X) — the key COUNT is checked against an INDEPENDENT in-test oracle that walks the hexes and
## collects distinct chunk coordinates itself. Never a hard-coded magic count.
func test_chunk_key_count_matches_an_independent_in_test_oracle() -> void:
	var layout: HexLayout = _loaded()
	for radius: int in FIXTURE_RADII:
		var hexes: Array[Vector2i] = _map_hexes(radius)
		var oracle: Array[Vector2i] = _oracle_chunk_keys(hexes, CHUNK_HEXES)
		assert_eq(
			layout.chunk_keys(hexes),
			oracle,
			"(X): radius %d chunk keys must equal the in-test oracle's %d key(s)" % [
				radius, oracle.size()
			]
		)


## (X) — `partition` is a PERMUTATION of the input indices: every index appears in exactly one
## bucket, exactly once, and the buckets together account for all 1,801 / 3,169 hexes.
func test_partition_is_a_permutation_of_the_input_indices() -> void:
	var layout: HexLayout = _loaded()
	for i: int in range(FIXTURE_RADII.size()):
		var hexes: Array[Vector2i] = _map_hexes(FIXTURE_RADII[i])
		assert_eq(hexes.size(), FIXTURE_HEX_COUNTS[i], "sanity: radius %d is %d hexes" % [
			FIXTURE_RADII[i], FIXTURE_HEX_COUNTS[i]
		])
		var buckets: Array[PackedInt32Array] = layout.partition(hexes)
		var keys: Array[Vector2i] = layout.chunk_keys(hexes)
		assert_eq(buckets.size(), keys.size(), "(X): partition is parallel to chunk_keys")

		var seen: PackedInt32Array = PackedInt32Array()
		seen.resize(hexes.size())
		var total: int = 0
		var out_of_range: int = 0
		for bucket: PackedInt32Array in buckets:
			for index: int in bucket:
				total += 1
				if index < 0 or index >= hexes.size():
					out_of_range += 1
				else:
					seen[index] += 1
		assert_eq(out_of_range, 0, "(X): every bucket entry indexes the input array")
		assert_eq(
			total,
			hexes.size(),
			"(X): radius %d buckets hold every hex exactly once" % FIXTURE_RADII[i]
		)
		var duplicated: int = 0
		var absent: int = 0
		for index: int in range(hexes.size()):
			if seen[index] > 1:
				duplicated += 1
			elif seen[index] == 0:
				absent += 1
		assert_eq(duplicated, 0, "(X): no hex index appears in two buckets")
		assert_eq(absent, 0, "(X): no hex index is dropped")


## (X) — membership is exact: every index in bucket i belongs to chunk key i, and the bucket keeps
## the input order.
func test_every_bucket_holds_exactly_its_own_chunk_in_input_order() -> void:
	var layout: HexLayout = _loaded()
	var hexes: Array[Vector2i] = _map_hexes(SMALL_RADIUS)
	var keys: Array[Vector2i] = layout.chunk_keys(hexes)
	var buckets: Array[PackedInt32Array] = layout.partition(hexes)
	assert_eq(buckets.size(), keys.size(), "(X): partition is parallel to chunk_keys")

	var misplaced: Array[String] = []
	var unordered: Array[String] = []
	for i: int in range(buckets.size()):
		var previous: int = -1
		for index: int in buckets[i]:
			if index < 0 or index >= hexes.size():
				continue
			if layout.chunk_of(hexes[index]) != keys[i]:
				misplaced.append("%s is in bucket %s" % [str(hexes[index]), str(keys[i])])
			if index <= previous:
				unordered.append("bucket %s has %d after %d" % [str(keys[i]), index, previous])
			previous = index
	assert_eq(misplaced.size(), 0, "(X): a bucket holds only its own chunk; %s" % [
		str(misplaced.slice(0, 5))
	])
	assert_eq(unordered.size(), 0, "(X): a bucket keeps the input order; %s" % [
		str(unordered.slice(0, 5))
	])


## (X)/§10 — every bucket is non-empty and no bucket can exceed the chunk square (an 8x8 axial
## square cannot hold more than 64 hexes), which is what makes the dirty-chunk rebuild bounded.
func test_bucket_sizes_are_between_one_and_the_chunk_square() -> void:
	var layout: HexLayout = _loaded()
	var limit: int = CHUNK_HEXES * CHUNK_HEXES
	for radius: int in FIXTURE_RADII:
		var buckets: Array[PackedInt32Array] = layout.partition(_map_hexes(radius))
		var wrong: Array[String] = []
		for i: int in range(buckets.size()):
			if buckets[i].size() < 1 or buckets[i].size() > limit:
				wrong.append("bucket %d holds %d hex(es)" % [i, buckets[i].size()])
		assert_eq(wrong.size(), 0, "(X): radius %d bucket sizes are 1..%d; %s" % [
			radius, limit, str(wrong.slice(0, 5))
		])


## §11.1 — the partition is DETERMINISTIC across calls, and each call returns FRESH containers
## (the M1-T2 trap-1 family: a shared/cached return array lets one caller corrupt every later one).
func test_partition_is_deterministic_and_returns_fresh_containers() -> void:
	var layout: HexLayout = _loaded()
	var hexes: Array[Vector2i] = _map_hexes(SMALL_RADIUS)

	var first_keys: Array[Vector2i] = layout.chunk_keys(hexes)
	var second_keys: Array[Vector2i] = layout.chunk_keys(hexes)
	assert_eq(first_keys, second_keys, "§11.1: chunk_keys is deterministic across calls")

	var first_sizes: Array[int] = _bucket_sizes(layout.partition(hexes))
	var second_sizes: Array[int] = _bucket_sizes(layout.partition(hexes))
	assert_eq(first_sizes, second_sizes, "§11.1: partition is deterministic across calls")

	first_keys.clear()
	assert_eq(
		layout.chunk_keys(hexes).size(),
		second_keys.size(),
		"§11.1: chunk_keys must return a FRESH array, not a shared/cached one"
	)


## §11.1 — the partition is a function of the input SET, not of its order: a deterministically
## shuffled copy yields the IDENTICAL chunk_keys array and the same hexes per key. This is what
## catches a `chunk_keys` that emits Dictionary key order instead of the sorted order (X).
func test_a_shuffled_input_yields_the_identical_chunk_keys_and_hex_sets() -> void:
	var layout: HexLayout = _loaded()
	var hexes: Array[Vector2i] = _map_hexes(SMALL_RADIUS)
	var shuffled: Array[Vector2i] = _deterministic_shuffle(hexes)
	assert_eq(shuffled.size(), hexes.size(), "sanity: the shuffle keeps every hex")
	assert_ne(shuffled, hexes, "sanity: the shuffle really reorders the input")

	var keys: Array[Vector2i] = layout.chunk_keys(hexes)
	var shuffled_keys: Array[Vector2i] = layout.chunk_keys(shuffled)
	assert_eq(shuffled_keys, keys, "(X): chunk_keys is sorted, so input order cannot change it")

	var straight: Array[Array] = _hexes_per_key(hexes, layout.partition(hexes))
	var scrambled: Array[Array] = _hexes_per_key(shuffled, layout.partition(shuffled))
	assert_eq(straight.size(), scrambled.size(), "(X): the same number of buckets either way")
	var different: Array[String] = []
	for i: int in range(mini(straight.size(), scrambled.size())):
		if straight[i] != scrambled[i]:
			var label: String = str(keys[i]) if i < keys.size() else "?"
			different.append("bucket %d (%s)" % [i, label])
	assert_eq(different.size(), 0, "(X): each chunk holds the same hex SET either way; %s" % [
		str(different.slice(0, 5))
	])


## (X) — totality: an empty input is an empty partition, never a phantom chunk.
func test_empty_input_yields_empty_chunk_keys_and_partition() -> void:
	var layout: HexLayout = _loaded()
	var empty: Array[Vector2i] = []
	assert_eq(layout.chunk_keys(empty).size(), 0, "(X): no hexes means no chunk keys")
	assert_eq(layout.partition(empty).size(), 0, "(X): no hexes means no buckets")


# =============================================================================================
# F. THE TUNABLES ARE READ FROM DATA (§13.6) — proven by mutating the params IN TEXT, the
#    M1-T4/M1-T5 precedent: a shadowing code literal is CAUGHT here, not merely forbidden by the
#    source scan.
# =============================================================================================

## §13.6/§10 — `chunk_hexes` genuinely drives the partition: at edge 4 the chunk count strictly
## increases, buckets shrink to at most 16, and (7,7) moves from chunk (0,0) to chunk (1,1).
func test_chunk_size_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var hexes: Array[Vector2i] = _map_hexes(SMALL_RADIUS)

	var coarse: HexLayout = _loaded()
	var coarse_keys: int = coarse.chunk_keys(hexes).size()

	var fine: HexLayout = HexLayout.new()
	var ok: bool = fine.load_params_text(
		_with_value("chunk_hexes", str(FINE_CHUNK_HEXES)), SOURCE
	)
	assert_true(ok, "§13.6: a retuned chunk_hexes must load: %s" % str(_error_lines(fine)))
	assert_eq(fine.chunk_hexes(), FINE_CHUNK_HEXES, "§13.6: chunk_hexes comes from the document")
	assert_eq(fine.chunk_of(Vector2i(7, 7)), Vector2i(1, 1), "(X): at edge 4, (7,7) is chunk (1,1)")

	var fine_keys: int = fine.chunk_keys(hexes).size()
	assert_true(
		fine_keys > coarse_keys,
		"§13.6: a finer chunk edge must yield MORE chunks (%d at edge %d vs %d at edge %d)" % [
			fine_keys, FINE_CHUNK_HEXES, coarse_keys, CHUNK_HEXES
		]
	)
	var limit: int = FINE_CHUNK_HEXES * FINE_CHUNK_HEXES
	var oversized: int = 0
	for bucket: PackedInt32Array in fine.partition(hexes):
		if bucket.size() > limit:
			oversized += 1
	assert_eq(oversized, 0, "§13.6/(X): at edge %d no bucket may exceed %d hexes" % [
		FINE_CHUNK_HEXES, limit
	])


## §13.6/§1.2 — `hex_width_m` genuinely drives the placement. 18.5 is inside §1.2's range and is
## FRACTIONAL, which also pins that the metre tunables are float leaves.
func test_hex_width_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text(_with_value("hex_width_m", "18.5"), SOURCE)
	assert_true(ok, "§13.6: a retuned hex_width_m must load: %s" % str(_error_lines(layout)))
	assert_almost_eq(layout.hex_width_m(), 18.5, TOL, "§13.6: hex_width_m comes from the document")

	var radius: float = 18.5 / 2.0
	var world: Vector3 = layout.hex_to_world(Vector2i(1, 0), MIN_ELEVATION)
	assert_almost_eq(world.x, 1.5 * radius, TOL, "(W): the column pitch follows hex_width_m")
	assert_almost_eq(world.z, SQRT_3 * radius * 0.5, TOL, "(W): the row pitch follows hex_width_m")


## §13.6/§4.1 — `elevation_step_m` genuinely drives the Y axis, and it too is a float leaf.
func test_elevation_step_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text(_with_value("elevation_step_m", "2.5"), SOURCE)
	assert_true(ok, "§13.6: a retuned elevation_step_m must load: %s" % str(_error_lines(layout)))
	assert_almost_eq(
		layout.elevation_step_m(),
		2.5,
		TOL,
		"§13.6: elevation_step_m comes from the document"
	)
	assert_almost_eq(
		layout.hex_to_world(Vector2i.ZERO, 2).y,
		5.0,
		TOL,
		"(W): world.y is elevation * elevation_step_m"
	)


# =============================================================================================
# G. THE LOAD CONTRACT — resolution (Y), mirroring MapGenerator's (P) and reusing RulesError
# =============================================================================================

## M0-T2 item 2 — line 0 is RESERVED for missing/unreadable files, and a missing file is EXACTLY
## one error. (The message says "is MISSING": the harness refuses on other phrasings.)
func test_a_missing_greybox_file_is_one_file_level_error_on_line_zero() -> void:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_file(MISSING_GREYBOX_PATH)
	assert_false(ok, "(Y): a greybox file that is MISSING must not load")
	assert_eq(layout.errors.size(), 1, "(Y): a missing file is exactly one error: %s" % [
		str(_error_lines(layout))
	])
	if layout.errors.size() == 1:
		assert_eq(
			layout.errors[0].line,
			0,
			"M0-T2 item 2: line 0 is reserved for missing/unreadable files"
		)
	_assert_unconfigured(layout, "missing file")


## (Y) — the canonical text is accepted, so every rejection fixture below differs from a VALID
## document by exactly one planted defect.
func test_the_canonical_greybox_text_is_accepted() -> void:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text(_greybox_text(), SOURCE)
	assert_true(ok, "(Y): the canonical text must load: %s" % str(_error_lines(layout)))
	assert_eq(_error_lines(layout), [] as Array[String], "(Y): a valid document yields no errors")
	assert_eq(layout.chunk_hexes(), CHUNK_HEXES, "sanity: the canonical text configures")


## (Y) + M0-T2 item 8 — a JSON syntax error carries a 1-BASED line (Godot's `get_error_line()` is
## 0-based and must be normalized), never the reserved 0. A trailing comma is useless as a fixture
## on this engine, so an unquoted bareword is planted instead — and the trailing-comma fact is
## pinned in the same test so no future author re-derives it wrongly.
func test_reject_malformed_json_with_a_one_based_line() -> void:
	var lines: Array[String] = []
	for line: String in GREYBOX_LINES:
		lines.append(line)
	lines[2] = '  "hex_width_m": eighteen,'

	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text(_joined(lines), SOURCE)
	assert_false(ok, "(Y): malformed JSON must not load")
	assert_true(layout.errors.size() >= 1, "(Y): malformed JSON reports at least one error")
	if layout.errors.size() >= 1:
		assert_true(
			layout.errors[0].line >= 1,
			"M0-T2 item 2/8: a syntax error carries a 1-based line, never the reserved 0 (got %d)" % [
				layout.errors[0].line
			]
		)
		assert_true(
			layout.errors[0].format_for(SOURCE).begins_with("%s:" % SOURCE),
			"M0-T2 item 6: errors render as '<source>:<line>: <message>'"
		)
	_assert_unconfigured(layout, "malformed JSON")

	var trailing: Array[String] = []
	for line: String in GREYBOX_LINES:
		trailing.append(line)
	trailing[4] = '  "chunk_hexes": 8,'
	var tolerant: HexLayout = HexLayout.new()
	assert_true(
		tolerant.load_params_text(_joined(trailing), SOURCE),
		"M0-T2 item 8: Godot 4.7 ACCEPTS trailing commas, so they are useless as a syntax fixture"
	)


## (Y) — the document root must be a JSON object; a top-level array is a whole-document failure at
## line 1 (never the reserved 0).
func test_reject_a_root_that_is_not_a_json_object() -> void:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text('["greybox"]', SOURCE)
	assert_false(ok, "(Y): a non-object root must not load")
	assert_eq(layout.errors.size(), 1, "(Y): a bad root is exactly one error: %s" % [
		str(_error_lines(layout))
	])
	if layout.errors.size() == 1:
		assert_eq(layout.errors[0].line, 1, "(Y): a bad root is attributed to line 1, never 0")
	_assert_unconfigured(layout, "root is not an object")


## (Y) — each of the three tunables is REQUIRED. With the key deleted outright nothing carries its
## token, so the error falls back to line 1 (M0-T2 item 3's fallback, never the reserved 0).
func test_reject_a_document_missing_any_one_of_the_three_tunables() -> void:
	for key: String in TUNABLE_KEYS:
		_assert_rejected(_without_line(key), key, 1, "missing \"%s\"" % key)


## (Y) — a string where a number is required is a type error attributed to that key's own line.
func test_reject_a_string_where_a_number_is_required() -> void:
	for key: String in TUNABLE_KEYS:
		var text: String = _with_value(key, '"eighteen"')
		_assert_rejected(text, key, _line_of(text, key), "\"%s\" is a string" % key)


## (Y) — all three tunables are STRICTLY positive: a zero-width hex, a zero elevation step or a
## zero-edge chunk are not renderable, and a negative one is meaningless.
func test_reject_a_zero_or_negative_value_for_every_tunable() -> void:
	for key: String in TUNABLE_KEYS:
		var zero_text: String = _with_value(key, "0")
		_assert_rejected(zero_text, key, _line_of(zero_text, key), "\"%s\" is zero" % key)
		var negative_text: String = _with_value(key, "-2")
		_assert_rejected(negative_text, key, _line_of(negative_text, key), "\"%s\" is negative" % key)


## (Y) + M0-T2 item 8 — `chunk_hexes` is an INT leaf: every JSON number arrives as TYPE_FLOAT, so
## an integral float is ACCEPTED and a fractional one REJECTED, never truncated to 8.
func test_chunk_hexes_accepts_an_integral_float_and_rejects_a_fractional_one() -> void:
	var integral: HexLayout = HexLayout.new()
	var ok: bool = integral.load_params_text(_with_value("chunk_hexes", "8.0"), SOURCE)
	assert_true(ok, "M0-T2 item 8: an integral float is a valid int leaf: %s" % [
		str(_error_lines(integral))
	])
	assert_eq(integral.chunk_hexes(), CHUNK_HEXES, "M0-T2 item 8: 8.0 reads back as 8")

	var fractional_text: String = _with_value("chunk_hexes", "8.5")
	_assert_rejected(
		fractional_text,
		"chunk_hexes",
		_line_of(fractional_text, "chunk_hexes"),
		"M0-T2 item 8: a fractional chunk_hexes is rejected, never truncated"
	)


## (Y)/M0-T2 item 5 — §12.1's forward-compatibility precedent: an unknown EXTRA key is not an
## error. The shipped `"id"` is exactly such a key.
func test_an_unknown_extra_key_loads_clean() -> void:
	var lines: Array[String] = []
	for line: String in GREYBOX_LINES:
		lines.append(line)
	lines[1] = '  "id": "greybox", "future_tunable": 7,'
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text(_joined(lines), SOURCE)
	assert_true(ok, "M0-T2 item 5: an unknown extra key is not an error: %s" % [
		str(_error_lines(layout))
	])
	assert_eq(layout.chunk_hexes(), CHUNK_HEXES, "M0-T2 item 5: the known keys still configure")


## (Y)/§11.1 — error ORDER is deterministic and follows the loader's OWN declared key-spec order,
## never the parsed Dictionary's key order. The fixture presents the three keys in the opposite
## order and breaks all three, so the reported order can only come from the spec table. The error
## LINES therefore come out descending, which is the visible proof.
func test_error_order_follows_the_loaders_key_spec_order_not_the_documents() -> void:
	var layout: HexLayout = HexLayout.new()
	var text: String = _joined(SCRAMBLED_LINES)
	var ok: bool = layout.load_params_text(text, SOURCE)
	assert_false(ok, "(Y): a document with three broken tunables must not load")
	assert_true(layout.errors.size() >= TUNABLE_KEYS.size(), "(Y): all errors are collected: %s" % [
		str(_error_lines(layout))
	])

	var order: Array[String] = []
	var zero_lines: int = 0
	var off_document: int = 0
	var document_lines: PackedStringArray = text.split("\n")
	for error: RulesError in layout.errors:
		if not order.has(error.path):
			order.append(error.path)
		if error.line == 0:
			zero_lines += 1
		if error.line < 1 or error.line > document_lines.size():
			off_document += 1
	assert_eq(zero_lines, 0, "M0-T2 item 2: a schema error may never carry the reserved line 0")
	assert_eq(off_document, 0, "(Y): every error line lies inside the document")
	assert_eq(
		order,
		TUNABLE_KEYS,
		"(Y)/§11.1: error order is the loader's spec order %s, not the document's" % [
			str(TUNABLE_KEYS)
		]
	)

	var expected_lines: Array[int] = []
	for key: String in TUNABLE_KEYS:
		expected_lines.append(_line_of(text, key))
	var descending: Array[String] = []
	for i: int in range(1, expected_lines.size()):
		if expected_lines[i] >= expected_lines[i - 1]:
			descending.append("%s at line %d" % [TUNABLE_KEYS[i], expected_lines[i]])
	assert_eq(
		descending.size(),
		0,
		"sanity: this fixture really presents the keys in the OPPOSITE order (lines %s)" % [
			str(expected_lines)
		]
	)
	_assert_unconfigured(layout, "three broken tunables")


## (Y) — a failed load AFTER a successful one still leaves the layout UNCONFIGURED: a half-valid
## params set can never be read, and stale params can never survive.
func test_a_failed_load_after_a_successful_one_leaves_the_layout_unconfigured() -> void:
	var layout: HexLayout = HexLayout.new()
	assert_true(layout.load_params_file(GREYBOX_PATH), "sanity: the shipped file loads first")
	assert_eq(layout.chunk_hexes(), CHUNK_HEXES, "sanity: the first load configured the layout")

	var ok: bool = layout.load_params_text(_without_line("chunk_hexes"), SOURCE)
	assert_false(ok, "(Y): the second, defective load must fail")
	_assert_unconfigured(layout, "failed load after a successful one")


# =============================================================================================
# H. MECHANICAL SOURCE SCANS ON scripts/render/hex_layout.gd — the MIRROR IMAGE of the sim scans.
#    Written FRESH for this file; a new file inherits nothing. Comment stripping is LOAD-BEARING:
#    the doc block quotes the very tokens being forbidden.
# =============================================================================================

## S1 §11.1/§11.2 — HexLayout is the pure half of the renderer: no Node, no SceneTree, no engine
## singleton, no wall-clock, no frame-time and no RNG. The Node arrives at M1-T7.
func test_source_is_engine_free_and_holds_no_node() -> void:
	var code: String = _code_text(LAYOUT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LAYOUT_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the pure renderer half holds no engine state — %s contains %s" % [
				LAYOUT_PATH, banned
			]
		)


## S2 §11.1 — THE MIRROR-IMAGE BOUNDARY. `data -> Sim Core -> EventBus -> Renderer/UI`: the
## renderer observes, it never reaches into the sim and never mutates sim state. This file knows
## only Vector2i/Vector3 and the shared `RulesError` value type, which is asserted PRESENT.
func test_source_never_names_a_sim_class_or_mutates_sim_state() -> void:
	var code: String = _code_text(LAYOUT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LAYOUT_PATH)
	for banned: String in SIM_BOUNDARY_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the renderer never names sim internals — %s contains %s" % [LAYOUT_PATH, banned]
		)
	assert_true(
		code.contains("RulesError"),
		"(Y): %s reuses the shared line-numbered RulesError rather than inventing a second one" % [
			LAYOUT_PATH
		]
	)


## S3 §4.1 line 174 / §13.6 — the map radii and hex counts are content, never engine code, in the
## renderer exactly as in the sim.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(LAYOUT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LAYOUT_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"),
		OK,
		"sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(
		hit,
		"§4.1/§13.6: map sizes are content — %s must not hard-code %s" % [
			LAYOUT_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S4 §13.6 "constants read from data, not code" — floats ARE expected in renderer geometry, so the
## sim suites' no-float scan is deliberately NOT copied. What IS asserted: SQRT_3 is a NAMED const
## (a mathematical constant, decisions.md M1-T5 item 7's precedent), and none of the three shipped
## tunables appears as a bare numeric literal.
func test_the_mathematical_constant_is_named_and_the_tunables_are_not_code_literals() -> void:
	var code: String = _code_text(LAYOUT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LAYOUT_PATH)
	assert_true(
		code.contains("const SQRT_3"),
		"§13.6: SQRT_3 is a mathematical constant and belongs in %s as a named const" % LAYOUT_PATH
	)
	assert_true(
		code.contains("1.7320508075688772"),
		"(W): SQRT_3 must carry full double precision in %s" % LAYOUT_PATH
	)
	var literal: RegEx = RegEx.new()
	assert_eq(
		literal.compile("(?<![0-9A-Za-z_.])(18|3|8)(?![0-9A-Za-z_.])"),
		OK,
		"sanity: the tunable-literal pattern compiles"
	)
	var hit: RegExMatch = literal.search(code)
	assert_null(
		hit,
		"§13.6: hex_width_m/elevation_step_m/chunk_hexes live in %s — %s must not hard-code %s" % [
			GREYBOX_PATH, LAYOUT_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(DATA_DRIVEN_TOKENS.size(), 3, "sanity: all three shipped tunables are covered")


## S5 §11.3 "public rule functions documented with the GDD section they implement", tightened the
## M1-T2 item 11 / M1-T3 item 13 way: the expected public surface is listed EXPLICITLY, so a
## MISSING member fails instead of passing vacuously and an EXTRA member (a mesh builder, a
## MultiMesh helper, a camera or picking entry point) fails too.
func test_public_api_is_exactly_the_nine_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(LAYOUT_PATH, public_functions, undocumented)

	var layout: HexLayout = HexLayout.new()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, LAYOUT_PATH]
		)
		assert_true(
			layout.has_method(required),
			"§11.2: %s must be callable on a HexLayout instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			LAYOUT_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); missing on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(LAYOUT_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public field surface of %s is exactly %s" % [
			LAYOUT_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)


## S6 §11.1/§11.2 — HexLayout is a pure [RefCounted] living in `scripts/render/`, §11.2's own
## directory for MapRenderer/UnitView/LightOverlay/CameraRig. Asserted through get_class() —
## `is Node` is a PARSE ERROR here (M0-T2 item 11 / M0-T5 item (a)).
func test_hex_layout_is_a_pure_refcounted_in_scripts_render() -> void:
	assert_true(FileAccess.file_exists(LAYOUT_PATH), "§11.2: HexLayout lives at %s" % LAYOUT_PATH)
	assert_true(
		FileAccess.file_exists(GREYBOX_PATH),
		"§13.6: the greybox tunables live at %s" % GREYBOX_PATH
	)
	var instance: HexLayout = HexLayout.new()
	assert_eq(instance.get_class(), "RefCounted", "§11.1: HexLayout must be a pure RefCounted")


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A layout configured from the SHIPPED content file, so every geometry assertion above is a
## content-drives-code proof rather than a test-fixture proof.
func _loaded() -> HexLayout:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_file(GREYBOX_PATH)
	assert_true(ok, "§13.6: %s must load: %s" % [GREYBOX_PATH, str(_error_lines(layout))])
	return layout


## Runs one rejection fixture end to end: a document differing from a VALID one by exactly one
## planted defect must be rejected with at least one 1-based error carrying the offending key's
## path at `expected_line`, must never emit the reserved line 0, and must leave the layout
## UNCONFIGURED even though it had just loaded successfully.
func _assert_rejected(text: String, key: String, expected_line: int, label: String) -> void:
	var layout: HexLayout = HexLayout.new()
	var configured: bool = layout.load_params_text(_greybox_text(), SOURCE)
	assert_true(configured, "sanity [%s]: the un-mutated document loads first" % label)

	var ok: bool = layout.load_params_text(text, SOURCE)
	assert_false(ok, "(Y) [%s]: the planted defect must be rejected" % label)
	assert_true(layout.errors.size() >= 1, "(Y) [%s]: rejection reports at least one error" % label)

	var document_lines: PackedStringArray = text.split("\n")
	var zero_lines: int = 0
	var off_document: int = 0
	var at_key: int = 0
	for error: RulesError in layout.errors:
		if error.line == 0:
			zero_lines += 1
		if error.line < 0 or error.line > document_lines.size():
			off_document += 1
		if error.path == key and error.line == expected_line:
			at_key += 1
	assert_eq(zero_lines, 0, "M0-T2 item 2 [%s]: line 0 is reserved for missing files" % label)
	assert_eq(off_document, 0, "(Y) [%s]: every error line is inside the document" % label)
	assert_true(
		at_key >= 1,
		"(Y) [%s]: an error must carry path \"%s\" at line %d; got %s" % [
			label, key, expected_line, str(_error_lines(layout))
		]
	)
	_assert_unconfigured(layout, label)


## (Y) — the UNCONFIGURED contract: every accessor reports its zero and every geometry function is
## total, so a rejected document can never produce half-valid placement.
func _assert_unconfigured(layout: HexLayout, label: String) -> void:
	assert_eq(layout.hex_width_m(), 0.0, "(Y) [%s]: an unconfigured layout has no hex width" % label)
	assert_eq(
		layout.elevation_step_m(),
		0.0,
		"(Y) [%s]: an unconfigured layout has no elevation step" % label
	)
	assert_eq(layout.chunk_hexes(), 0, "(Y) [%s]: an unconfigured layout has no chunk size" % label)
	assert_eq(
		layout.hex_to_world(Vector2i(2, 3), 2),
		Vector3.ZERO,
		"(Y) [%s]: an unconfigured layout places every hex at the origin" % label
	)
	assert_eq(
		layout.chunk_of(Vector2i(9, -9)),
		Vector2i.ZERO,
		"(Y) [%s]: an unconfigured layout has no chunk grid" % label
	)
	assert_eq(
		layout.chunk_keys(CHUNK_PROBE_HEXES).size(),
		0,
		"(Y) [%s]: an unconfigured layout yields no chunk keys" % label
	)
	assert_eq(
		layout.partition(CHUNK_PROBE_HEXES).size(),
		0,
		"(Y) [%s]: an unconfigured layout yields no buckets" % label
	)


## Every hex of a map of `radius`, in HexMap's (O) canonical order — the order the renderer will
## actually receive from the sim.
func _map_hexes(radius: int) -> Array[Vector2i]:
	var map: HexMap = HexMap.new(radius)
	return map.hexes()


## The in-test ORACLE for the chunk key set: walks the hexes, collects distinct chunk coordinates
## with this file's own floor division, and sorts them by chunk-r then chunk-q. Independent of
## `hex_layout.gd`, so a count is never a magic number.
func _oracle_chunk_keys(hexes: Array[Vector2i], edge: int) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for hex: Vector2i in hexes:
		var key: Vector2i = Vector2i(_floor_div(hex.x, edge), _floor_div(hex.y, edge))
		if not seen.has(key):
			seen[key] = true
			out.append(key)
	out.sort_custom(_chunk_less)
	return out


## Resolution (X)'s ordering predicate: ascending chunk-r (y), then ascending chunk-q (x). Strict,
## so equal keys are NOT less — which is what makes the sortedness assertion also prove distinctness.
func _chunk_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## TRUE floor division, written fresh here as the test's own oracle. GDScript's `/` truncates
## toward zero, so -1 / 8 is 0 rather than -1 (the M1-T2 trap-2 family).
func _floor_div(n: int, d: int) -> int:
	@warning_ignore("integer_division")
	var quotient: int = n / d
	if n % d != 0 and (n < 0) != (d < 0):
		quotient -= 1
	return quotient


## The hexes held by each bucket, sorted canonically, so two partitions of the same SET can be
## compared regardless of the order their inputs arrived in.
func _hexes_per_key(hexes: Array[Vector2i], buckets: Array[PackedInt32Array]) -> Array[Array]:
	var out: Array[Array] = []
	for bucket: PackedInt32Array in buckets:
		var members: Array[Vector2i] = []
		for index: int in bucket:
			if index >= 0 and index < hexes.size():
				members.append(hexes[index])
		members.sort_custom(_chunk_less)
		out.append(members)
	return out


## Bucket sizes, as a typed array, for cheap whole-partition comparison.
func _bucket_sizes(buckets: Array[PackedInt32Array]) -> Array[int]:
	var out: Array[int] = []
	for bucket: PackedInt32Array in buckets:
		out.append(bucket.size())
	return out


## An RNG-FREE deterministic reordering (§11.1: no `randi()` anywhere in the suite). Walking a
## fixed stride coprime with the input size is a permutation; the assertion below re-checks that
## rather than trusting the arithmetic.
func _deterministic_shuffle(items: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var count: int = items.size()
	if count == 0:
		return out
	var seen: PackedInt32Array = PackedInt32Array()
	seen.resize(count)
	for i: int in range(count):
		var at: int = (i * SHUFFLE_STRIDE) % count
		seen[at] += 1
		out.append(items[at])
	var missed: int = 0
	for i: int in range(count):
		if seen[i] != 1:
			missed += 1
	assert_eq(missed, 0, "sanity: the deterministic shuffle must be a permutation of its input")
	return out


## The canonical greybox document as one string.
func _greybox_text() -> String:
	return _joined(GREYBOX_LINES)


## Joins source lines with newlines through a PackedStringArray, which is what String.join takes.
func _joined(source_lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in source_lines:
		packed.append(line)
	return "\n".join(packed)


## The canonical document with the whole top-level key `key` DELETED, repairing the trailing comma
## so the result is still valid JSON — the defect must be a MISSING KEY, not a syntax error.
func _without_line(key: String) -> String:
	var kept: Array[String] = []
	var dropped: int = 0
	for line: String in GREYBOX_LINES:
		if line.strip_edges().begins_with('"%s":' % key):
			dropped += 1
			continue
		kept.append(line)
	assert_eq(dropped, 1, "sanity: the fixture carries exactly one top-level \"%s\" line" % key)

	var last_value_at: int = -1
	for i: int in range(kept.size()):
		var stripped: String = kept[i].strip_edges()
		if stripped != "{" and stripped != "}":
			last_value_at = i
	if last_value_at != -1 and kept[last_value_at].ends_with(","):
		kept[last_value_at] = kept[last_value_at].substr(0, kept[last_value_at].length() - 1)
	return _joined(kept)


## The canonical document with one top-level key's VALUE replaced verbatim — one planted defect
## per fixture, and the key's own line number preserved.
func _with_value(key: String, value_text: String) -> String:
	var lines: Array[String] = []
	var replaced: int = 0
	for line: String in GREYBOX_LINES:
		if line.strip_edges().begins_with('"%s":' % key):
			var suffix: String = "," if line.strip_edges().ends_with(",") else ""
			lines.append('  "%s": %s%s' % [key, value_text, suffix])
			replaced += 1
		else:
			lines.append(line)
	assert_eq(replaced, 1, "sanity: the fixture carries exactly one top-level \"%s\" line" % key)
	return _joined(lines)


## 1-based line number of the first line carrying the JSON key token `"key"`, or 1 when the key is
## absent entirely — never a magic constant (decisions.md M0-T2 item 7).
func _line_of(text: String, key: String) -> int:
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	for i: int in range(lines.size()):
		if lines[i].contains('"%s"' % key):
			return i + 1
	return 1


## Rendered errors, for readable failure messages.
func _error_lines(layout: HexLayout) -> Array[String]:
	var out: Array[String] = []
	for error: RulesError in layout.errors:
		out.append(error.format_for(SOURCE))
	return out


## The shipped content file, read verbatim.
func _shipped_greybox_text() -> String:
	var file: FileAccess = FileAccess.open(GREYBOX_PATH, FileAccess.READ)
	assert_not_null(file, "§13.6: %s must be readable" % GREYBOX_PATH)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## The shipped content file, parsed — so its values are read from the DOCUMENT, independently of
## the loader under test.
func _parsed_shipped_greybox() -> Dictionary:
	var json: JSON = JSON.new()
	assert_eq(json.parse(_shipped_greybox_text()), OK, "§13.6: %s must be valid JSON" % GREYBOX_PATH)
	var data: Variant = json.data
	if not (data is Dictionary):
		assert_true(false, "§13.6: %s must be a JSON object" % GREYBOX_PATH)
		return {}
	var root: Dictionary = data as Dictionary
	return root


## A JSON number as a float (Godot 4.7 hands every JSON number back as TYPE_FLOAT — M0-T2 item 8).
func _numeric(value: Variant) -> float:
	if value is float:
		var as_float: float = value
		return as_float
	if value is int:
		var as_int: int = value
		return float(as_int)
	assert_true(false, "§13.6: a greybox tunable must be a JSON number")
	return 0.0


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
