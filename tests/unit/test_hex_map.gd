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
##   (U) M1-T5 — THE TERRAIN-TYPE FIELD AND `content_hash()`.
##       - §4.2's terrain-type id is stored in ONE PackedStringArray over the SAME (O) index
##         scheme; no Dictionary, and still no band array (band stays derivable from distance and
##         is therefore not state). The default AND the out-of-bounds value is the EMPTY id "";
##         `set_terrain_type` off-disc is a silent no-op, exactly like `set_elevation`.
##       - `content_hash() -> int` is a reproducible FNV hash (§11.1: "GameState.hash() (FNV over
##         canonical serialization) must be reproducible") folded over `hexes()` in the (O)
##         canonical order, covering the radius, every hex coordinate, every elevation and every
##         terrain-type id. It is deliberately NOT named `hash` — overriding `Object.hash()`
##         trips `native_method_override`, which is level 2 (an error) under the M0-T4 gate.
##       - **THIS IS THE VALUE THE PROJECT'S FIRST GOLDEN RECORDS** (§14 M1 acceptance criterion
##         (a), "Golden mapgen test (seed => terrain hash)"), so from M1-T5 onward any change to
##         the fold order, the canonical order or the stored fields is a §13.6 golden re-record
##         needing a dated docs/decisions.md reason in the SAME commit.
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

## (U) — the empty terrain-type id: both the default of a fresh map and the out-of-bounds answer.
const NO_TERRAIN: String = ""

## §4.2 terrain-type ids used by the storage round-trip below. They are §4.2's own Solid row ids;
## which of them the GENERATOR may emit is `tests/unit/test_map_generator.gd`'s business — HexMap
## is a container and holds opaque strings.
const SAMPLE_TERRAIN_IDS: Array[String] = [
	"soft_dirt",
	"hard_rock",
	"dense_granite",
	"gold_vein",
]

## §11.1 — tokens that would make the sim core engine-bound. Checked against source with comments
## stripped, so a doc comment quoting the rule is never a false failure.
##
## M1-T5 AMENDMENT (a STRENGTHENING, logged — decisions.md M1-T4 resolution (Q) deliberately
## carved no RNG exception): `RandomNumberGenerator` joins the list. `scripts/core/rng.gd` is the
## project's SINGLE home of the engine RNG (resolution (R)); a container must never touch it.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"RandomNumberGenerator",
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

## The COMPLETE public function surface of HexMap after M1-T5. Exactly these nine, in any order,
## and nothing else — a features array, a light/stress accessor or a vein-node entry point would
## pre-empt M2/M3 (§13.4: invent nothing ahead of its milestone).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"hex_count",
	"is_in_bounds",
	"index_of",
	"hexes",
	"get_elevation",
	"set_elevation",
	"get_terrain_type",
	"set_terrain_type",
	"content_hash",
]

## The COMPLETE public FIELD surface of HexMap. M1-T5 adds terrain TYPE storage but no new public
## field: band stays derivable from distance rather than state (§11.1's field list does not
## include it), and the type array is private behind the two accessors.
const REQUIRED_PUBLIC_VARS: Array[String] = ["radius"]

## Doc-comment sections accepted by scan S4 (§11.3). §4.2 joins the list with M1-T5's terrain-type
## field; §11.1 covers `content_hash` (the FNV reproducibility clause).
const DOC_SECTIONS: Array[String] = ["§4.1", "§4.2", "§4.4", "§11.1"]

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
# E2. TERRAIN-TYPE STORAGE (§4.2 hex types; resolution (U)) — M1-T5
# =============================================================================================

## (U)/§4.2 — a fresh map reads the EMPTY id everywhere in bounds (a map has no terrain until the
## generator writes one), and a written id reads back exactly, independently, on every hex.
func test_terrain_type_defaults_to_empty_and_round_trips_per_hex() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	assert_eq(
		map.hexes().size(),
		HexMath.hex_count_for_radius(SWEEP_RADIUS),
		"sanity: this sweep must actually visit the whole disc, never pass vacuously"
	)
	var non_empty: Array[String] = []
	for hex: Vector2i in map.hexes():
		if map.get_terrain_type(hex) != NO_TERRAIN:
			non_empty.append("%s -> %s" % [hex, map.get_terrain_type(hex)])
	assert_eq(non_empty.size(), 0, "(U): a fresh map carries no terrain type; %s" % [
		str(non_empty.slice(0, 5))
	])

	for hex: Vector2i in map.hexes():
		map.set_terrain_type(hex, _sample_terrain_for(hex))
	var mismatches: Array[String] = []
	for hex: Vector2i in map.hexes():
		var expected: String = _sample_terrain_for(hex)
		if map.get_terrain_type(hex) != expected:
			mismatches.append("%s -> %s, expected %s" % [hex, map.get_terrain_type(hex), expected])
	assert_eq(mismatches.size(), 0, "(U): every hex stores its own terrain type; %s" % [
		str(mismatches.slice(0, 5))
	])


## (U) — terrain type and elevation are INDEPENDENT fields over the same index: writing one must
## never disturb the other. A single shared array (or a swapped index) fails here.
func test_terrain_type_and_elevation_do_not_alias_each_other() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	for hex: Vector2i in map.hexes():
		map.set_elevation(hex, posmod(hex.x * 2 + hex.y * 7, 4))
		map.set_terrain_type(hex, _sample_terrain_for(hex))
	var breaks: Array[String] = []
	for hex: Vector2i in map.hexes():
		if map.get_elevation(hex) != posmod(hex.x * 2 + hex.y * 7, 4):
			breaks.append("elevation clobbered at %s" % [hex])
		if map.get_terrain_type(hex) != _sample_terrain_for(hex):
			breaks.append("terrain clobbered at %s" % [hex])
	assert_eq(breaks.size(), 0, "(U): the two per-hex fields are independent; %s" % [
		str(breaks.slice(0, 5))
	])


## (U) — out-of-bounds terrain reads are the EMPTY id and out-of-bounds writes are SILENT NO-OPS,
## exactly like elevation (M1-T1 (B) / M1-T3 (L)): a bad argument must never tear down a headless
## run, and must never corrupt an in-bounds hex either.
func test_out_of_bounds_terrain_access_is_total_and_never_corrupts_the_map() -> void:
	var map: HexMap = HexMap.new(SWEEP_RADIUS)
	map.set_terrain_type(Vector2i.ZERO, SAMPLE_TERRAIN_IDS[0])
	for hex: Vector2i in _off_disc_probes(SWEEP_RADIUS):
		assert_eq(
			map.get_terrain_type(hex),
			NO_TERRAIN,
			"(U): get_terrain_type(%s) off the disc is the empty id" % [hex]
		)
		map.set_terrain_type(hex, SAMPLE_TERRAIN_IDS[1])
		assert_eq(
			map.get_terrain_type(hex),
			NO_TERRAIN,
			"(U): set_terrain_type(%s) off the disc is a silent no-op" % [hex]
		)
	assert_eq(
		map.get_terrain_type(Vector2i.ZERO),
		SAMPLE_TERRAIN_IDS[0],
		"(U): an off-disc write must not alias an in-bounds hex"
	)
	var empty: HexMap = HexMap.new(-1)
	assert_eq(
		empty.get_terrain_type(Vector2i.ZERO),
		NO_TERRAIN,
		"(U): nothing is readable on a negative-radius map"
	)


## §11.1 — two HexMap instances share no terrain storage either (the M1-T2 trap-1 family).
func test_two_maps_do_not_share_terrain_storage() -> void:
	var first: HexMap = HexMap.new(SWEEP_RADIUS)
	var second: HexMap = HexMap.new(SWEEP_RADIUS)
	first.set_terrain_type(Vector2i.ZERO, SAMPLE_TERRAIN_IDS[2])
	assert_eq(
		first.get_terrain_type(Vector2i.ZERO),
		SAMPLE_TERRAIN_IDS[2],
		"sanity: the write landed on the first map"
	)
	assert_eq(
		second.get_terrain_type(Vector2i.ZERO),
		NO_TERRAIN,
		"§11.1: two HexMap instances must not share terrain storage"
	)


# =============================================================================================
# E3. content_hash() — §11.1 "GameState.hash() (FNV over canonical serialization) must be
#     reproducible"; resolution (U). THIS IS WHAT THE PROJECT'S FIRST GOLDEN RECORDS (§14 M1).
# =============================================================================================

## §11.1 — the hash is a pure function of CONTENT: two independently built maps carrying the same
## radius, elevations and terrain types hash identically, and the value is stable across repeated
## calls on the same instance (no counter, no clock, no allocation address in the fold).
func test_content_hash_is_stable_and_content_addressed() -> void:
	var first: HexMap = _populated(SWEEP_RADIUS)
	var second: HexMap = _populated(SWEEP_RADIUS)
	var value: int = first.content_hash()
	assert_eq(typeof(value), TYPE_INT, "§11.1: content_hash() is a plain int, never a float")
	assert_eq(first.content_hash(), value, "§11.1: content_hash() is stable across calls")
	assert_eq(
		second.content_hash(),
		value,
		"§11.1: two independently built identical maps must hash identically"
	)


## §11.1 — the hash covers TERRAIN TYPE: changing exactly one hex's type must change it. Without
## this the M1 golden would be blind to the very field the acceptance criterion names
## ("seed => TERRAIN hash").
func test_content_hash_changes_when_a_single_terrain_type_changes() -> void:
	var map: HexMap = _populated(SWEEP_RADIUS)
	var before: int = map.content_hash()
	map.set_terrain_type(Vector2i(1, -1), "mithril_seam")
	assert_ne(
		map.content_hash(),
		before,
		"§11.1/(U): the hash must cover every hex's terrain type"
	)


## §11.1 — the hash also covers ELEVATION, so the M1-T4 bowl cannot drift underneath the golden.
func test_content_hash_changes_when_a_single_elevation_changes() -> void:
	var map: HexMap = _populated(SWEEP_RADIUS)
	var before: int = map.content_hash()
	var hex: Vector2i = Vector2i(-2, 1)
	map.set_elevation(hex, map.get_elevation(hex) + 1)
	assert_ne(map.content_hash(), before, "§11.1/(U): the hash must cover every hex's elevation")


## §11.1 — the hash covers the map's SHAPE: two empty maps of different radii must not collide,
## even though every stored value in both is the default.
func test_content_hash_distinguishes_map_radii() -> void:
	var values: Dictionary = {}
	for radius: int in [0, 1, 2, 3]:
		var map: HexMap = HexMap.new(radius)
		var value: int = map.content_hash()
		assert_false(
			values.has(value),
			"§11.1: radius %d collides with radius %s" % [radius, str(values.get(value, -1))]
		)
		values[value] = radius
	assert_eq(values.size(), 4, "§11.1: four distinct radii give four distinct hashes")


## §11.1 "canonical serialization" — the hash depends on the map's CONTENT and on HexMap's own
## canonical order, never on the order in which a caller happened to write the cells. The
## generator writes in canonical order; a later system (or a test) will not.
func test_content_hash_is_independent_of_write_order() -> void:
	var forward: HexMap = HexMap.new(SWEEP_RADIUS)
	for hex: Vector2i in forward.hexes():
		forward.set_elevation(hex, posmod(hex.x * 2 + hex.y * 7, 4))
		forward.set_terrain_type(hex, _sample_terrain_for(hex))
	var backward: HexMap = HexMap.new(SWEEP_RADIUS)
	var reversed_hexes: Array[Vector2i] = backward.hexes()
	reversed_hexes.reverse()
	for hex: Vector2i in reversed_hexes:
		backward.set_terrain_type(hex, _sample_terrain_for(hex))
		backward.set_elevation(hex, posmod(hex.x * 2 + hex.y * 7, 4))
	assert_eq(
		backward.content_hash(),
		forward.content_hash(),
		"§11.1: the hash is over canonical content, not over write order"
	)


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
## singletons, no randi()/randf(), no wall-clock input — and, from M1-T5, no
## `RandomNumberGenerator` either. That token was ADDED (never a token removed) because
## `scripts/core/rng.gd` is now the project's single sanctioned home for the seeded engine RNG
## (resolution (R)); a per-hex container has no business owning randomness at all.
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
## function of hex_map.gd carries a DOC_SECTIONS doc-comment block. The scan is also TIGHTENED the
## way M1-T2 item 11 / M1-T3 item 13 tightened theirs: the expected public surface is listed
## explicitly, so a MISSING member fails the scan instead of passing vacuously and an EXTRA member
## (a features/light/stress accessor pre-empting M2 or M3) fails it too.
func test_public_api_is_exactly_the_nine_documented_functions() -> void:
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
		"§11.3: every public rule function needs a %s doc comment; missing on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(HEX_MAP_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: band is derivable, not state — the public field surface of %s is exactly %s" % [
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


## A deterministic §4.2 terrain-type id per hex, so the storage round-trip cannot pass by writing
## one id everywhere. No RNG here — the fixture must be reproducible (§11.1).
func _sample_terrain_for(hex: Vector2i) -> String:
	return SAMPLE_TERRAIN_IDS[posmod(hex.x * 3 + hex.y * 5, SAMPLE_TERRAIN_IDS.size())]


## A map with BOTH per-hex fields populated deterministically, for the content_hash properties.
func _populated(radius: int) -> HexMap:
	var map: HexMap = HexMap.new(radius)
	for hex: Vector2i in map.hexes():
		map.set_elevation(hex, posmod(hex.x * 2 + hex.y * 7, 4))
		map.set_terrain_type(hex, _sample_terrain_for(hex))
	return map


## Builds a typed `Array[Vector2i]` from an inline literal, so an expected value can be written
## at the assertion site while still comparing typed array against typed array.
func _axials(items: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Vector2i in items:
		out.append(item)
	return out


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
