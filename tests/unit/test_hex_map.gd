## HexMap — GDD §4.1 (Hex Grid Specification, **binding**), §11.1 (GameState's map is a "hex
## array: type, elevation, features, light, stress, knowledge per player"; the sim core is
## engine-free, integer-only and deterministic), §11.2 (`scripts/sim/`), §11.3 (coding
## conventions), §13.2 tier 1 (unit tests), §13.6.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   line 173: "**Elevation:** integer 0-3 per hex."
##   line 174: "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40
##             (4,921)."
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §4.1 or §4.4**, so the printed text above governs unamended. The three radii and their three
## hex counts are the ONLY numeric §4.1 table, and they may appear in this test file and in
## `data/mapgen/*.json` — never in engine code (§13.6; scan C3 below enforces it for
## `hex_map.gd`, exactly as `test_hex_math.gd`/`test_los.gd` do for their own files; a new file
## inherits NOTHING from those scans).
##
## §4.1 legislates no container shape at all, so everything about storage, ordering and
## out-of-bounds behaviour is a §13.4 resolution. Its lettering continues M1-T1's (A)/(B),
## M1-T2's (C)-(G) and M1-T3's (H)-(L):
##   (O) HexMap STORAGE, CANONICAL ORDER AND TOTALITY.
##       - `HexMap.new(radius)` holds ELEVATION ONLY in slice 1. Terrain type (§4.2), features,
##         veins, light, stress and per-player knowledge belong to later tasks (§13.4).
##       - Membership is cube distance from the origin: `HexMath.distance(ZERO, hex) <= radius`.
##       - `hex_count()` is `3 * radius * (radius + 1) + 1` for radius >= 0 and 0 for radius < 0.
##       - CANONICAL ITERATION ORDER: `r` ascending from `-radius` to `+radius`, and within each
##         `r`, `q` ascending. **The M1-T5 golden will hash this order, so it is pinned NOW.**
##         `index_of()` is strictly increasing along it, which welds the storage index to the
##         order and catches a q/r-swapped index.
##       - `hexes()` returns a FRESH `Array[Vector2i]` per call (M1-T2 trap 1 / M1-T3 P7 — this
##         is the third file where a cached return array would be a cross-caller corruption
##         hazard, so it is re-pinned rather than assumed).
##       - A fresh map reads elevation 0 (§4.1's floor) on every in-bounds hex.
##       - EVERY accessor is TOTAL, in the spirit of M1-T1 resolution (B) and M1-T3 resolution
##         (L): a bad argument must never tear down a headless run. Off-disc, `get_elevation`
##         returns the sentinel -1, `index_of` returns -1, `set_elevation` is a silent no-op and
##         `is_in_bounds` is false. A negative radius is the empty map.
##
## §13.6 "constants read from data, not code" — `hex_map.gd` carries no radius constant: the
## radius is a constructor argument fed from `data/mapgen/*.json` (§4.4 line 238). §13.6 "events
## emitted for every state change" is vacuous: this class is a plain container, mutates no
## GameState and touches no EventBus. Goldens: none re-recorded — none exist yet (the project's
## first golden lands with M1-T5).
##
## TRAP (hit live in M0-T2, decisions.md item 11 / M0-T5 item (a)): `x is Node` against a
## RefCounted-typed variable is a statically impossible cast that GDScript rejects at PARSE time;
## GUT then logs "Ignoring script ..." and the whole file silently vanishes from the run.
## Non-Node-ness is therefore asserted via get_class() ONLY, never with `is`.
extends GutTest

const HEX_MAP_PATH: String = "res://scripts/sim/hex_map.gd"

## §4.1 line 174, verbatim. Allowed here and in data/mapgen/*.json — nowhere else.
const SMALL_RADIUS: int = 24
const MEDIUM_RADIUS: int = 32
const LARGE_RADIUS: int = 40
const SMALL_HEXES: int = 1801
const MEDIUM_HEXES: int = 3169
const LARGE_HEXES: int = 4921

## Out-of-bounds sentinel shared by get_elevation() and index_of() (resolution (O)).
const OUT_OF_BOUNDS: int = -1

## §11.1 — tokens that would make the sim core engine-bound. Checked against source with comments
## stripped, so a doc comment quoting the rule is never a false failure.
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

## §4.1's radii and their hex counts are TUNABLE CONTENT (§4.4 line 238: generator parameters
## live in data/mapgen/*.json). None of these may appear in hex_map.gd.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface of HexMap. Exactly these six, in any order, and nothing
## else — a terrain-type array, a band array or a features array would pre-empt M1-T5 (§13.4).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"hex_count",
	"is_in_bounds",
	"index_of",
	"hexes",
	"get_elevation",
	"set_elevation",
]

## The COMPLETE public FIELD surface of HexMap. Slice 1 stores elevation only, and band is
## derivable from distance rather than state (§11.1's field list does not include it), so a
## second public array here would pre-empt M1-T5 (§13.4).
const REQUIRED_PUBLIC_VARS: Array[String] = ["radius"]

## Small radii used by the exhaustive sweeps, so every ordered pair stays cheap.
const SWEEP_RADIUS: int = 6


# =============================================================================================
# A. THE §4.1 MAP-SIZE TABLE (line 174) AND THE DEGENERATE RADII (resolution (O))
# =============================================================================================

## §4.1 line 174 — "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40
## (4,921)". Each parenthesised count is cross-checked against the already-pinned closed form
## `hex_count_for_radius(r) == 3r(r+1)+1`, so the table and the formula must agree three ways.
func test_hex_count_matches_the_section_4_1_map_size_table() -> void:
	var radii: Array[int] = [SMALL_RADIUS, MEDIUM_RADIUS, LARGE_RADIUS]
	var counts: Array[int] = [SMALL_HEXES, MEDIUM_HEXES, LARGE_HEXES]
	for i: int in range(radii.size()):
		var r: int = radii[i]
		var expected: int = counts[i]
		assert_eq(
			3 * r * (r + 1) + 1,
			expected,
			"sanity: §4.1's parenthesised count for radius %d is 3r(r+1)+1" % r
		)
		assert_eq(
			HexMath.hex_count_for_radius(r),
			expected,
			"§4.1: HexMath.hex_count_for_radius(%d) == %d" % [r, expected]
		)
		var map: HexMap = HexMap.new(r)
		assert_eq(map.radius, r, "§4.1: HexMap.new(%d) stores its radius" % r)
		assert_eq(map.hex_count(), expected, "§4.1: HexMap.new(%d).hex_count() == %d" % [r, expected])


## Resolution (O) — radius 0 is the single origin hex (3*0*1+1 == 1); a negative radius is the
## EMPTY map, never a crash (the spirit of M1-T1 resolution (B)).
func test_degenerate_radii_are_total() -> void:
	var single: HexMap = HexMap.new(0)
	assert_eq(single.hex_count(), 1, "§4.1: radius 0 is the single origin hex")
	assert_eq(single.hexes(), _axials([Vector2i.ZERO]), "§4.1: radius 0 contains only (0,0)")
	assert_true(single.is_in_bounds(Vector2i.ZERO), "§4.1: the origin is in bounds at radius 0")
	assert_false(single.is_in_bounds(Vector2i(1, 0)), "§4.1: (1,0) is out of bounds at radius 0")

	for negative: int in [-1, -5]:
		var empty: HexMap = HexMap.new(negative)
		assert_eq(empty.hex_count(), 0, "(O): radius %d gives an empty map" % negative)
		assert_true(empty.hexes().is_empty(), "(O): radius %d gives an empty hexes()" % negative)
		assert_false(
			empty.is_in_bounds(Vector2i.ZERO),
			"(O): nothing is in bounds on a radius-%d map" % negative
		)
		assert_eq(
			empty.get_elevation(Vector2i.ZERO),
			OUT_OF_BOUNDS,
			"(O): get_elevation on a radius-%d map is the sentinel" % negative
		)


# =============================================================================================
# B. MEMBERSHIP IS CUBE DISTANCE (§4.1 "Distance = cube distance"; resolution (O))
# =============================================================================================

## §4.1 — `is_in_bounds` must agree with `HexMath.distance(ZERO, hex) <= radius` on EVERY cell of
## the axial bounding square, not merely on hand-picked hexes. Swept exhaustively at
## SWEEP_RADIUS; a q/r-asymmetric bounds formula (e.g. a rectangle test) fails immediately.
func test_is_in_bounds_agrees_with_cube_distance_over_the_bounding_square() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	var violations: Array[String] = []
	var inside: int = 0
	for r: int in range(-SWEEP_RADIUS - 2, SWEEP_RADIUS + 3):
		for q: int in range(-SWEEP_RADIUS - 2, SWEEP_RADIUS + 3):
			var hex: Vector2i = Vector2i(q, r)
			var expected: bool = HexMath.distance(Vector2i.ZERO, hex) <= SWEEP_RADIUS
			if expected:
				inside += 1
			if map.is_in_bounds(hex) != expected:
				violations.append("%s expected %s" % [hex, expected])
	assert_eq(
		inside,
		HexMath.hex_count_for_radius(SWEEP_RADIUS),
		"sanity: the swept square contains exactly the radius-%d disc" % SWEEP_RADIUS
	)
	assert_eq(
		violations.size(),
		0,
		"§4.1: is_in_bounds must be cube distance <= radius; first breaks: %s" % [
			str(violations.slice(0, 5))
		]
	)


## §4.1 — on a full-size Medium map, the six §4.1 direction axes are in bounds at exactly the
## radius and out of bounds one step further. This is the cheap full-scale probe that a sweep at
## SWEEP_RADIUS cannot give.
func test_direction_axes_are_in_bounds_exactly_out_to_the_radius() -> void:
	var map: HexMap = HexMap.new(MEDIUM_RADIUS)
	for dir: int in range(6):
		var step: Vector2i = HexMath.DIRECTIONS[dir]
		var edge: Vector2i = step * MEDIUM_RADIUS
		var beyond: Vector2i = step * (MEDIUM_RADIUS + 1)
		assert_true(
			map.is_in_bounds(edge),
			"§4.1: %s at exactly the radius is in bounds" % [edge]
		)
		assert_false(
			map.is_in_bounds(beyond),
			"§4.1: %s one step beyond the radius is out of bounds" % [beyond]
		)


# =============================================================================================
# C. CANONICAL ITERATION ORDER (resolution (O)) — the M1-T5 golden will hash it
# =============================================================================================

## (O) — `hexes()` is `r` ascending, then `q` ascending, contains every in-bounds hex exactly
## once and nothing else. The expected sequence is built here INDEPENDENTLY (a plain double loop
## over the bounding square filtered by the already-pinned `HexMath.distance`), never via
## `HexMath.hexes_in_range`, whose spiral order is a different contract (resolution (G)).
func test_hexes_is_the_canonical_r_then_q_ascending_order() -> void:
	for radius: int in [0, 1, SWEEP_RADIUS, SMALL_RADIUS]:
		var map: HexMap = HexMap.new(radius)
		var expected: Array[Vector2i] = _canonical_hexes(radius)
		assert_eq(
			expected.size(),
			HexMath.hex_count_for_radius(radius),
			"sanity: the independently built radius-%d disc has 3r(r+1)+1 hexes" % radius
		)
		assert_eq(
			map.hexes(),
			expected,
			"(O): hexes() at radius %d must be r ascending, then q ascending" % radius
		)
		assert_eq(
			map.hexes().size(),
			map.hex_count(),
			"(O): hexes().size() == hex_count() at radius %d" % radius
		)


## (O) — the spiral order of `HexMath.hexes_in_range` and the canonical order of `hexes()` are
## DIFFERENT sequences over the SAME set. Pinning both directions stops a later "simplification"
## that delegates to the spiral and silently changes what the M1-T5 golden hashes.
func test_hexes_holds_the_same_set_as_hexes_in_range_but_not_the_same_order() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	var canonical: Array[Vector2i] = map.hexes()
	var spiral: Array[Vector2i] = HexMath.hexes_in_range(Vector2i.ZERO, SWEEP_RADIUS)
	assert_eq(canonical.size(), spiral.size(), "(O): both orders cover the same disc")
	var missing: Array[String] = []
	for hex: Vector2i in spiral:
		if not canonical.has(hex):
			missing.append(str(hex))
	assert_eq(missing.size(), 0, "(O): hexes() omits no in-bounds hex; missing %s" % [str(missing)])
	assert_ne(
		canonical,
		spiral,
		"(O): hexes() is the r/q canonical order, NOT HexMath's spiral (resolution (G))"
	)


## (O) — no duplicates and no out-of-bounds members, checked independently of the ordering
## assertion above so a defect cannot hide behind a matching count.
func test_hexes_contains_every_in_bounds_hex_exactly_once() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	var seen: Dictionary = {}
	var duplicates: Array[String] = []
	var out_of_bounds: Array[String] = []
	for hex: Vector2i in map.hexes():
		if seen.has(hex):
			duplicates.append(str(hex))
		seen[hex] = true
		if HexMath.distance(Vector2i.ZERO, hex) > SWEEP_RADIUS:
			out_of_bounds.append(str(hex))
	assert_eq(duplicates.size(), 0, "(O): hexes() has no duplicates; saw %s" % [str(duplicates)])
	assert_eq(
		out_of_bounds.size(),
		0,
		"(O): hexes() contains no off-disc hex; saw %s" % [str(out_of_bounds)]
	)
	assert_eq(
		seen.size(),
		HexMath.hex_count_for_radius(SWEEP_RADIUS),
		"(O): hexes() covers the whole radius-%d disc" % SWEEP_RADIUS
	)


## §11.1 freshness contract (M1-T2 trap 1, M1-T3 P7) — `hexes()` must build a NEW array per call.
## A cached/shared array is a cross-caller corruption hazard AND would let one consumer's
## `sort()` silently re-order what the M1-T5 golden hashes.
func test_hexes_returns_a_fresh_array_every_call() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	var first: Array[Vector2i] = map.hexes()
	var second: Array[Vector2i] = map.hexes()
	var expected: Array[Vector2i] = _canonical_hexes(SWEEP_RADIUS)
	assert_false(is_same(first, second), "§11.1: hexes() must return a fresh array, not a cached one")
	assert_eq(first, second, "§11.1: repeated hexes() calls yield the identical sequence")
	if not first.is_empty():
		first[0] = Vector2i(999, 999)
	first.append(Vector2i(999, 999))
	first.clear()
	assert_eq(second, expected, "§11.1: mutating one hexes() result must not corrupt another")
	assert_eq(map.hexes(), expected, "§11.1: mutating a result must not corrupt the map itself")


# =============================================================================================
# D. STABLE DENSE INDEXING (resolution (O))
# =============================================================================================

## (O) — `index_of` is injective over the disc, non-negative and bounded by the axial bounding
## square, and STRICTLY INCREASING along the canonical order. The monotonicity clause is what
## welds the index to the order: a q/r-swapped index still yields distinct values, but it walks
## the canonical sequence out of order and fails here.
func test_index_of_is_injective_and_increases_along_the_canonical_order() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	var square: int = (2 * SWEEP_RADIUS + 1) * (2 * SWEEP_RADIUS + 1)
	var seen: Dictionary = {}
	var collisions: Array[String] = []
	var out_of_range: Array[String] = []
	var regressions: Array[String] = []
	var previous: int = -1
	for hex: Vector2i in map.hexes():
		var index: int = map.index_of(hex)
		if index < 0 or index >= square:
			out_of_range.append("%s -> %d" % [hex, index])
		if seen.has(index):
			collisions.append("%s collides with %s at %d" % [hex, seen[index], index])
		seen[index] = hex
		if index <= previous:
			regressions.append("%s -> %d after %d" % [hex, index, previous])
		previous = index
	assert_eq(out_of_range.size(), 0, "(O): every index is within the bounding square; %s" % [
		str(out_of_range.slice(0, 5))
	])
	assert_eq(collisions.size(), 0, "(O): index_of is injective; %s" % [str(collisions.slice(0, 5))])
	assert_eq(regressions.size(), 0, "(O): index_of increases along the canonical order; %s" % [
		str(regressions.slice(0, 5))
	])
	assert_eq(seen.size(), map.hex_count(), "(O): every in-bounds hex has its own index")


## (O) — `index_of` is a TOTAL function: off-disc it is the -1 sentinel, never a crash and never
## an in-range index that would alias a real hex.
func test_index_of_is_minus_one_off_the_disc() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	for hex: Vector2i in _off_disc_probes(SWEEP_RADIUS):
		assert_eq(
			map.index_of(hex),
			OUT_OF_BOUNDS,
			"(O): index_of(%s) off the radius-%d disc is -1" % [hex, SWEEP_RADIUS]
		)


# =============================================================================================
# E. ELEVATION STORAGE (§4.1 line 173 "Elevation: integer 0-3 per hex")
# =============================================================================================

## §4.1 — a fresh map reads elevation 0 (the §4.1 floor) everywhere in bounds, and a written
## value reads back exactly, independently, on every hex of the disc.
func test_elevation_defaults_to_zero_and_round_trips_per_hex() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	assert_eq(
		map.hexes().size(),
		HexMath.hex_count_for_radius(SWEEP_RADIUS),
		"sanity: this sweep must actually visit the whole disc, never pass vacuously on an empty one"
	)
	var non_zero: Array[String] = []
	for hex: Vector2i in map.hexes():
		if map.get_elevation(hex) != 0:
			non_zero.append("%s -> %d" % [hex, map.get_elevation(hex)])
	assert_eq(non_zero.size(), 0, "§4.1: a fresh map is at elevation 0 everywhere; %s" % [
		str(non_zero.slice(0, 5))
	])

	var mismatches: Array[String] = []
	for hex: Vector2i in map.hexes():
		var value: int = posmod(hex.x * 2 + hex.y * 7, 4)
		map.set_elevation(hex, value)
	for hex: Vector2i in map.hexes():
		var expected: int = posmod(hex.x * 2 + hex.y * 7, 4)
		if map.get_elevation(hex) != expected:
			mismatches.append("%s -> %d, expected %d" % [hex, map.get_elevation(hex), expected])
	assert_eq(mismatches.size(), 0, "§4.1: every hex stores its own elevation; %s" % [
		str(mismatches.slice(0, 5))
	])


## §11.1 — two HexMap instances share no storage. A `static`/`const` backing array would make the
## whole sim non-deterministic the moment two maps exist (the M1-T2 trap-1 family).
func test_two_maps_do_not_share_storage() -> void:
	var first: HexMap = HexMap.new(SWEEP_RADIUS)
	var second: HexMap = HexMap.new(SWEEP_RADIUS)
	first.set_elevation(Vector2i.ZERO, 3)
	assert_eq(first.get_elevation(Vector2i.ZERO), 3, "sanity: the write landed on the first map")
	assert_eq(
		second.get_elevation(Vector2i.ZERO),
		0,
		"§11.1: two HexMap instances must not share elevation storage"
	)


## (O) — out-of-bounds reads are the -1 sentinel and out-of-bounds writes are SILENT NO-OPS: a
## bad argument must never tear down a headless run (M1-T1 (B) / M1-T3 (L)), and it must never
## corrupt an in-bounds hex either.
func test_out_of_bounds_access_is_total_and_never_corrupts_the_map() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	map.set_elevation(Vector2i.ZERO, 2)
	for hex: Vector2i in _off_disc_probes(SWEEP_RADIUS):
		assert_eq(
			map.get_elevation(hex),
			OUT_OF_BOUNDS,
			"(O): get_elevation(%s) off the disc is the -1 sentinel" % [hex]
		)
		map.set_elevation(hex, 3)
		assert_eq(
			map.get_elevation(hex),
			OUT_OF_BOUNDS,
			"(O): set_elevation(%s) off the disc is a silent no-op" % [hex]
		)
	assert_eq(
		map.get_elevation(Vector2i.ZERO),
		2,
		"(O): an off-disc write must not alias an in-bounds hex"
	)
	assert_eq(map.hex_count(), HexMath.hex_count_for_radius(SWEEP_RADIUS), "(O): the disc is intact")


# =============================================================================================
# F. MECHANICAL SOURCE SCANS ON scripts/sim/hex_map.gd (§11.1, §11.2, §11.3, §13.6)
#    `test_hex_math.gd` and `test_los.gd` scan their own files ONLY — a new file inherits
#    NOTHING — so all five scans are re-written here against hex_map.gd.
# =============================================================================================

## S1 §11.1 "Determinism rules: ... no float accumulation in rules (integers + fixed percent
## math)". The container is Vector2i / PackedInt32Array / integer arithmetic throughout, so the
## file must contain NO float literal and no `float` type at all, and no `integer_division`
## warning suppression either — the index formula is multiplication, never division. Comment
## stripping is load-bearing: the doc comments contain "§4.1", which `\.[0-9]` would otherwise
## hit.
func test_source_contains_no_float_math_and_no_division() -> void:
	var code: String = _code_text(HEX_MAP_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % HEX_MAP_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			HEX_MAP_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % HEX_MAP_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"(O): the storage index is cross-multiplication — %s needs no integer division" % HEX_MAP_PATH
	)


## S2 §11.1 "the core must run headless byte-identically": no Node, no Scene Tree, no engine
## singletons, no randi()/randf(), no wall-clock input. NOTE FOR M1-T5: the composition slice
## will need seeded rolls through `state.rng`; it must AMEND this scan with a logged reason,
## never delete it. Slice 1 uses no RNG at all, so no exception is carved today.
func test_source_is_engine_free() -> void:
	var code: String = _code_text(HEX_MAP_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % HEX_MAP_PATH)
	for token: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(token),
			"§11.1: the sim core must be engine-free — %s contains %s" % [HEX_MAP_PATH, token]
		)


## S3 §4.4 line 238 / §13.6 — the §4.1 map radii and their hex counts are TUNABLE CONTENT living
## in data/mapgen/*.json. HexMap takes its radius as a constructor argument and must hard-code
## none of them.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(HEX_MAP_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % HEX_MAP_PATH)
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
			HEX_MAP_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S4 §11.3 "public rule functions documented with the GDD section they implement" — every public
## function of hex_map.gd carries a `## §4.1` (or `## §4.4`) doc-comment block. The scan is also
## TIGHTENED the way M1-T2 item 11 / M1-T3 item 13 tightened theirs: the expected public surface
## is listed explicitly, so a MISSING member fails the scan instead of passing vacuously and an
## EXTRA member (a terrain-type array accessor pre-empting M1-T5) fails it too.
func test_public_api_is_exactly_the_six_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(HEX_MAP_PATH, public_functions, undocumented)

	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2/§4.1: %s must be a public function of %s" % [required, HEX_MAP_PATH]
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			HEX_MAP_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(HEX_MAP_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: slice 1 stores ELEVATION ONLY — the public field surface of %s is exactly %s" % [
			HEX_MAP_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)
	assert_true(
		_code_text(HEX_MAP_PATH).contains("HexMath.distance("),
		"§4.1: membership is cube distance — HexMap must call HexMath.distance(), never re-derive it"
	)


## S5 §11.1 "pure GDScript RefCounted classes ... No Node, no Scene Tree" + §11.2 (the map is
## GameState's, so it lives in scripts/sim/). Non-Node-ness is asserted through get_class() — see
## the TRAP note in the header; `is Node` is a PARSE ERROR here, not a failure.
func test_hex_map_is_a_pure_refcounted_in_scripts_sim() -> void:
	assert_true(FileAccess.file_exists(HEX_MAP_PATH), "§11.2: HexMap lives at %s" % HEX_MAP_PATH)
	var instance: HexMap = HexMap.new(0)
	assert_eq(instance.get_class(), "RefCounted", "§11.1: HexMap must be a pure RefCounted")


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## The canonical order, built INDEPENDENTLY of HexMap: `r` ascending, then `q` ascending, over
## the axial bounding square, filtered by the already-pinned §4.1 cube distance.
func _canonical_hexes(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius < 0:
		return out
	for r: int in range(-radius, radius + 1):
		for q: int in range(-radius, radius + 1):
			var hex: Vector2i = Vector2i(q, r)
			if HexMath.distance(Vector2i.ZERO, hex) <= radius:
				out.append(hex)
	return out


## A spread of hexes just outside the disc, including the six axis overshoots and two far-away
## probes, for the totality assertions.
func _off_disc_probes(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: int in range(6):
		out.append(HexMath.DIRECTIONS[dir] * (radius + 1))
		out.append(HexMath.DIRECTIONS[dir] * (radius + 3))
	out.append(Vector2i(radius + 1, -1))
	out.append(Vector2i(-1, radius + 1))
	out.append(Vector2i(1000, -1000))
	return out


## Builds a typed `Array[Vector2i]` from an inline literal, so an expected value can be written
## at the assertion site while still comparing typed array against typed array.
func _axials(items: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Vector2i in items:
		out.append(item)
	return out


## Walks a source file and fills `public_functions` with every public function name (in source
## order) and `undocumented` with those whose preceding comment block cites neither §4.1 nor
## §4.4. Shared by the S4 scans of both M1-T4 files.
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


## Every top-level public `var` declared by a source file, in source order. Shared by the S4
## scans of both M1-T4 files so that an EXTRA public field fails the scan.
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
