## HexMath — GDD §4.1 (Hex Grid Specification, **binding**), §11.1 (sim core is engine-free and
## deterministic), §11.2 (`scripts/core/` — "HexMath, Los, Pathfinder, ... — pure & unit-tested"),
## §11.3 (coding conventions), §13.2 tier 1 ("every core/ function"), §13.6, §14 M1 row.
##
## The §4.1 text these tests pin, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   "Flat-top hexes, axial coordinates (q, r); cube coordinates for algorithms. Distance = cube
##    distance. Neighbor order (fixed, index 0-5): E, NE, NW, W, SW, SE."
##   "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40 (4,921)."
##
## docs/decisions.md was read: **NO logged override touches §4.1**, so the printed values above are
## authoritative for this file.
##
## §13.6 "constants read from data, not code" is VACUOUS here and deliberately so: `data/ruleset.json`
## carries no hex-geometry key and must not gain one. The six deltas and the cube-distance formula
## are geometry/algorithm, not tunable content; the tunable map radii 24/32/40 belong to
## `data/mapgen/*.json` (§4.4, generator task). They therefore appear as literals ONLY in this test
## file — `test_source_carries_no_map_size_constant` pins that they never appear in hex_math.gd.
##
## §13.4 ambiguity resolutions pinned here (the GDD legislates neither; Land logs both in
## docs/decisions.md):
##   (A) FLAT-TOP vs. THE DIRECTION NAMES. §4.1 says "Flat-top hexes" AND names the six indices
##       E, NE, NW, W, SW, SE — which is the pointy-top naming of the six standard axial deltas.
##       Simplest interpretation: the SIM stores the deltas in the GDD's stated index order and
##       uses the GDD's stated names verbatim as index labels; hex-to-screen orientation is a
##       RENDERER concern (later M1 task) and changes no sim value. The index order and the names
##       below are therefore NOT to be "fixed" for orientation.
##   (B) OUT-OF-RANGE DIRECTION INDEX. `neighbor(h, dir)` with `dir` outside 0..5 returns `h`
##       unchanged and `opposite(dir)` returns `dir` unchanged — no crash, no engine error, no
##       assert abort headless (a hex grid has no seventh neighbour; the identity is the simplest
##       total function).
##
## ARITHMETIC CORRECTION recorded by the Tests stage: the M1-T1 task spec listed a hand-computed
## case `distance((1,-3),(4,2)) == 5`. That is a miscalculation — cube a = (1, 2, -3), cube b =
## (4, -6, 2), delta = (-3, 8, -5), so the cube distance is **8** (and (3+8+5)/2 = 8 agrees). §4.1
## states only "Distance = cube distance" (a formula, not a table), so the formula governs and this
## file pins 8. No GDD value moved.
##
## TRAP (hit live in M0-T2, docs/decisions.md item 11): `x is Node` against a RefCounted-typed
## variable is a statically impossible cast that GDScript rejects at PARSE time; GUT then logs
## "Ignoring script ..." and exits 0, silently deleting this whole file from the run. Non-Node-ness
## is therefore asserted via get_class() ONLY, never with `is`.
extends GutTest

const HEX_MATH_PATH: String = "res://scripts/core/hex_math.gd"

## §4.1 "Neighbor order (fixed, index 0-5): E, NE, NW, W, SW, SE" — the six standard axial deltas
## in the GDD's stated order. Transcribed here, in the test, so the implementation is measured
## against the document and never against itself.
const EXPECTED_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # 0  E
	Vector2i(1, -1),  # 1  NE
	Vector2i(0, -1),  # 2  NW
	Vector2i(-1, 0),  # 3  W
	Vector2i(-1, 1),  # 4  SW
	Vector2i(0, 1),   # 5  SE
]

const EXPECTED_DIRECTION_NAMES: Array[String] = ["E", "NE", "NW", "W", "SW", "SE"]

## §11.1 — tokens that would make the sim core engine-bound. Checked against source with comments
## stripped, so a doc comment quoting the rule ("no Node, no Scene Tree") is never a false failure.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"randi(",
	"randf(",
	"Time.",
	"OS.",
]

## §4.1 map radii and their hex counts, plus the §4.4 hint that generator parameters live in
## data/mapgen/*.json. None of these numbers may appear in hex_math.gd.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## A handful of hexes spread over all six sextants plus the origin — reused by the property tests.
const SAMPLE_HEXES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(3, -2),
	Vector2i(-4, 1),
	Vector2i(2, 5),
	Vector2i(-6, -1),
	Vector2i(7, 0),
	Vector2i(0, -9),
	Vector2i(-3, 8),
]


# =============================================================================================
# A. COORDINATE MAPPING (§4.1 "axial coordinates (q, r); cube coordinates for algorithms")
# =============================================================================================

## §4.1 — axial (q, r) maps to cube (x, y, z) as x = q, z = r, y = -q - r, and every produced cube
## satisfies the defining invariant x + y + z == 0.
func test_axial_to_cube_uses_the_standard_mapping() -> void:
	assert_eq(
		HexMath.axial_to_cube(Vector2i(0, 0)),
		Vector3i(0, 0, 0),
		"§4.1: axial (0,0) is cube (0,0,0)"
	)
	assert_eq(
		HexMath.axial_to_cube(Vector2i(1, 0)),
		Vector3i(1, -1, 0),
		"§4.1: x = q, z = r, y = -q-r"
	)
	assert_eq(
		HexMath.axial_to_cube(Vector2i(0, 1)),
		Vector3i(0, -1, 1),
		"§4.1: x = q, z = r, y = -q-r"
	)
	assert_eq(
		HexMath.axial_to_cube(Vector2i(3, -2)),
		Vector3i(3, -1, -2),
		"§4.1: x = q, z = r, y = -q-r"
	)
	assert_eq(
		HexMath.axial_to_cube(Vector2i(-4, 7)),
		Vector3i(-4, -3, 7),
		"§4.1: x = q, z = r, y = -q-r"
	)


## §4.1 — cube (x, y, z) maps back to axial as q = x, r = z (y is redundant, recoverable from the
## invariant), so axial -> cube -> axial is the identity over the whole grid.
func test_axial_cube_round_trip_is_identity_over_a_swept_grid() -> void:
	var checked: int = 0
	var invariant_breaks: Array[String] = []
	var round_trip_breaks: Array[String] = []
	for q: int in range(-8, 9):
		for r: int in range(-8, 9):
			checked += 1
			var axial: Vector2i = Vector2i(q, r)
			var cube: Vector3i = HexMath.axial_to_cube(axial)
			if cube.x + cube.y + cube.z != 0:
				invariant_breaks.append("%s -> %s" % [axial, cube])
			var back: Vector2i = HexMath.cube_to_axial(cube)
			if back != axial:
				round_trip_breaks.append("%s -> %s -> %s" % [axial, cube, back])

	assert_eq(checked, 289, "sanity: the sweep covered all 17x17 axial coordinates in [-8, 8]")
	assert_eq(
		invariant_breaks.size(),
		0,
		"§4.1: every cube coordinate must satisfy x+y+z == 0; first breaks: %s" % [str(invariant_breaks.slice(0, 5))]
	)
	assert_eq(
		round_trip_breaks.size(),
		0,
		"§4.1: axial -> cube -> axial is the identity; first breaks: %s" % [str(round_trip_breaks.slice(0, 5))]
	)


## §4.1 — a cube coordinate is well-formed iff x + y + z == 0. Anything else is not a hex.
func test_is_valid_cube_enforces_the_zero_sum_invariant() -> void:
	assert_true(HexMath.is_valid_cube(Vector3i(0, 0, 0)), "§4.1: (0,0,0) sums to 0 — valid")
	assert_true(HexMath.is_valid_cube(Vector3i(1, -1, 0)), "§4.1: (1,-1,0) sums to 0 — valid")
	assert_true(HexMath.is_valid_cube(Vector3i(2, -1, -1)), "§4.1: (2,-1,-1) sums to 0 — valid")
	assert_false(HexMath.is_valid_cube(Vector3i(1, 0, 0)), "§4.1: (1,0,0) sums to 1 — NOT a hex")
	assert_false(HexMath.is_valid_cube(Vector3i(1, 1, 1)), "§4.1: (1,1,1) sums to 3 — NOT a hex")


# =============================================================================================
# B. THE FIXED NEIGHBOUR ORDER (§4.1 "Neighbor order (fixed, index 0-5): E, NE, NW, W, SW, SE")
# =============================================================================================

## §4.1 — the direction table is FIXED: six entries, in the stated index order, with the stated
## names. Every later system (LOS, pathfinding, rings, mapgen) indexes into this table, so a
## re-ordering here would silently change generated maps and recorded goldens. See resolution (A)
## in the header: the names are the GDD's verbatim labels and are not to be re-derived from screen
## orientation.
func test_direction_table_is_the_fixed_gdd_order() -> void:
	assert_eq(HexMath.DIRECTIONS.size(), 6, "§4.1: exactly six neighbour directions, index 0-5")
	assert_eq(
		HexMath.DIRECTION_NAMES.size(),
		6,
		"§4.1: exactly six direction names, index 0-5"
	)
	if HexMath.DIRECTIONS.size() != 6 or HexMath.DIRECTION_NAMES.size() != 6:
		return

	for i: int in range(6):
		var delta: Vector2i = HexMath.DIRECTIONS[i]
		assert_eq(
			delta,
			EXPECTED_DIRECTIONS[i],
			"§4.1: index %d (%s) is axial delta %s" % [i, EXPECTED_DIRECTION_NAMES[i], EXPECTED_DIRECTIONS[i]]
		)
		var name_at_index: String = HexMath.DIRECTION_NAMES[i]
		assert_eq(
			name_at_index,
			EXPECTED_DIRECTION_NAMES[i],
			"§4.1: 'Neighbor order (fixed, index 0-5): E, NE, NW, W, SW, SE' — index %d is %s" % [i, EXPECTED_DIRECTION_NAMES[i]]
		)


## §4.1 — `neighbors(h)` returns the six adjacent hexes in the fixed index order, for the origin
## and for an arbitrary non-origin hex alike (the order must not be an accident of h == (0,0)).
func test_neighbors_returns_the_six_in_fixed_index_order() -> void:
	for origin: Vector2i in [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-5, 4)]:
		var ring: Array[Vector2i] = HexMath.neighbors(origin)
		assert_eq(ring.size(), 6, "§4.1: a hex has exactly six neighbours (h = %s)" % [origin])
		if ring.size() != 6:
			continue
		for i: int in range(6):
			assert_eq(
				ring[i],
				origin + EXPECTED_DIRECTIONS[i],
				"§4.1: neighbours(%s)[%d] is the %s neighbour" % [origin, i, EXPECTED_DIRECTION_NAMES[i]]
			)
			assert_eq(
				HexMath.neighbor(origin, i),
				origin + EXPECTED_DIRECTIONS[i],
				"§4.1: neighbor(%s, %d) agrees with neighbors()[%d]" % [origin, i, i]
			)


## §4.1 — the six neighbours of a hex are six DISTINCT hexes (a degenerate or duplicated delta
## would silently halve a ring and corrupt every BFS built on it).
func test_the_six_neighbours_are_pairwise_distinct() -> void:
	for origin: Vector2i in SAMPLE_HEXES:
		var ring: Array[Vector2i] = HexMath.neighbors(origin)
		var seen: Dictionary = {}
		for h: Vector2i in ring:
			seen[h] = true
		assert_eq(
			seen.size(),
			6,
			"§4.1: the six neighbours of %s must be pairwise distinct, got %s" % [origin, ring]
		)
		assert_false(
			seen.has(origin),
			"§4.1: a hex is never its own neighbour (h = %s)" % [origin]
		)


## §11.1 determinism — `neighbors()` must hand back a FRESH array each call. A GDScript `const
## Array[Vector2i]` is not deeply immutable and a cached/shared result would let one caller's
## mutation corrupt the §4.1 table for every later caller (and for every recorded golden).
func test_neighbors_returns_a_fresh_array_each_call() -> void:
	var h: Vector2i = Vector2i(3, -2)
	var first: Array[Vector2i] = HexMath.neighbors(h)
	var second: Array[Vector2i] = HexMath.neighbors(h)
	assert_false(
		is_same(first, second),
		"§11.1: neighbors() must return a fresh array, not a shared/cached one"
	)

	if first.size() == 6:
		first[0] = Vector2i(999, 999)

	var third: Array[Vector2i] = HexMath.neighbors(h)
	assert_eq(second.size(), 6, "sanity: the second call returned six neighbours")
	if second.size() == 6:
		assert_eq(
			second[0],
			h + EXPECTED_DIRECTIONS[0],
			"§4.1: mutating one result must not corrupt another live result"
		)
	assert_eq(third.size(), 6, "sanity: the third call returned six neighbours")
	if third.size() == 6:
		assert_eq(
			third[0],
			h + EXPECTED_DIRECTIONS[0],
			"§4.1: mutating a result must not corrupt later calls"
		)
	if HexMath.DIRECTIONS.size() == 6:
		assert_eq(
			HexMath.DIRECTIONS[0],
			EXPECTED_DIRECTIONS[0],
			"§4.1: the shared direction table survives a caller mutating a neighbours() result"
		)


# =============================================================================================
# C. OPPOSITES (§4.1 — a consequence of the fixed order: E<->W, NE<->SW, NW<->SE)
# =============================================================================================

## §4.1 — the fixed order pairs each direction with the one three steps around the ring:
## 0 E <-> 3 W, 1 NE <-> 4 SW, 2 NW <-> 5 SE, i.e. opposite(i) == (i + 3) % 6.
func test_opposite_is_index_plus_three_modulo_six() -> void:
	assert_eq(HexMath.opposite(0), 3, "§4.1: E (0) is opposite W (3)")
	assert_eq(HexMath.opposite(1), 4, "§4.1: NE (1) is opposite SW (4)")
	assert_eq(HexMath.opposite(2), 5, "§4.1: NW (2) is opposite SE (5)")
	assert_eq(HexMath.opposite(3), 0, "§4.1: W (3) is opposite E (0)")
	assert_eq(HexMath.opposite(4), 1, "§4.1: SW (4) is opposite NE (1)")
	assert_eq(HexMath.opposite(5), 2, "§4.1: SE (5) is opposite NW (2)")
	for i: int in range(6):
		assert_eq(
			HexMath.opposite(i),
			(i + 3) % 6,
			"§4.1: opposite(%d) == (%d + 3) %% 6" % [i, i]
		)


## §4.1 — the geometric meaning of "opposite": a direction delta and its opposite delta cancel,
## so the table and the opposite() accessor describe the same ring.
func test_opposite_directions_are_additive_inverses() -> void:
	if HexMath.DIRECTIONS.size() != 6:
		assert_eq(HexMath.DIRECTIONS.size(), 6, "§4.1: exactly six neighbour directions, index 0-5")
		return
	for i: int in range(6):
		var back: int = HexMath.opposite(i)
		assert_between(back, 0, 5, "§4.1: opposite(%d) must itself be a valid index" % [i])
		if back < 0 or back > 5:
			continue
		assert_eq(
			HexMath.DIRECTIONS[i] + HexMath.DIRECTIONS[back],
			Vector2i.ZERO,
			"§4.1: %s and its opposite are additive inverses" % [EXPECTED_DIRECTION_NAMES[i]]
		)


## §4.1 — stepping to a neighbour and back along the opposite direction returns home, for every
## index and from anywhere on the grid.
func test_neighbor_then_opposite_returns_home() -> void:
	for origin: Vector2i in SAMPLE_HEXES:
		for i: int in range(6):
			var stepped: Vector2i = HexMath.neighbor(origin, i)
			var returned: Vector2i = HexMath.neighbor(stepped, HexMath.opposite(i))
			assert_eq(
				returned,
				origin,
				"§4.1: neighbor(neighbor(%s, %d), opposite(%d)) == %s" % [origin, i, i, origin]
			)


# =============================================================================================
# D. DISTANCE (§4.1 "Distance = cube distance")
# =============================================================================================

## §4.1 "Distance = cube distance" — hand-computed cases. See the header note: the task spec's
## `distance((1,-3),(4,2)) == 5` was a miscalculation; the cube distance is 8.
func test_distance_hand_computed_cases() -> void:
	assert_eq(HexMath.distance(Vector2i(0, 0), Vector2i(0, 0)), 0, "§4.1: distance to self is 0")
	assert_eq(HexMath.distance(Vector2i(0, 0), Vector2i(3, 0)), 3, "§4.1: cube (3,-3,0) — distance 3")
	assert_eq(HexMath.distance(Vector2i(0, 0), Vector2i(0, 3)), 3, "§4.1: cube (0,-3,3) — distance 3")
	assert_eq(HexMath.distance(Vector2i(0, 0), Vector2i(3, -3)), 3, "§4.1: cube (3,0,-3) — distance 3")
	assert_eq(HexMath.distance(Vector2i(0, 0), Vector2i(-2, -2)), 4, "§4.1: cube (-2,4,-2) — distance 4")
	assert_eq(HexMath.distance(Vector2i(0, 0), Vector2i(2, -1)), 2, "§4.1: cube (2,-1,-1) — distance 2")
	assert_eq(
		HexMath.distance(Vector2i(1, -3), Vector2i(4, 2)),
		8,
		"§4.1: cube (1,2,-3) to (4,-6,2), delta (-3,8,-5) — distance 8"
	)
	assert_eq(
		HexMath.distance(Vector2i(-4, 5), Vector2i(3, -2)),
		7,
		"§4.1: cube (-4,-1,5) to (3,-1,-2), delta (-7,0,7) — distance 7"
	)
	assert_eq(
		HexMath.distance(Vector2i(2, 2), Vector2i(-1, -1)),
		6,
		"§4.1: cube (2,-4,2) to (-1,2,-1), delta (3,-6,3) — distance 6"
	)


## §4.1 — each of the six neighbours of a hex is at distance exactly 1 (this is what makes the
## direction table and the distance function the same geometry).
func test_every_neighbour_is_at_distance_one() -> void:
	for origin: Vector2i in SAMPLE_HEXES:
		for i: int in range(6):
			assert_eq(
				HexMath.distance(origin, HexMath.neighbor(origin, i)),
				1,
				"§4.1: the %s neighbour of %s is at distance 1" % [EXPECTED_DIRECTION_NAMES[i], origin]
			)


## §4.1 "Distance = cube distance" — the two standard closed forms of cube distance must agree:
## max(|dx|,|dy|,|dz|) and (|dx|+|dy|+|dz|)/2. Both are computed HERE from the §4.1 axial->cube
## mapping, so this pins the implementation against the definition rather than against itself.
func test_distance_equals_both_standard_cube_forms() -> void:
	var checked: int = 0
	var max_form_breaks: Array[String] = []
	var half_sum_form_breaks: Array[String] = []
	for a: Vector2i in SAMPLE_HEXES:
		for b: Vector2i in SAMPLE_HEXES:
			checked += 1
			var ax: int = a.x
			var az: int = a.y
			var ay: int = -a.x - a.y
			var bx: int = b.x
			var bz: int = b.y
			var by: int = -b.x - b.y
			var dx: int = absi(ax - bx)
			var dy: int = absi(ay - by)
			var dz: int = absi(az - bz)
			var by_max: int = maxi(dx, maxi(dy, dz))
			@warning_ignore("integer_division")
			var by_half_sum: int = (dx + dy + dz) / 2
			var actual: int = HexMath.distance(a, b)
			if actual != by_max:
				max_form_breaks.append("%s..%s expected %d got %d" % [a, b, by_max, actual])
			if actual != by_half_sum:
				half_sum_form_breaks.append("%s..%s expected %d got %d" % [a, b, by_half_sum, actual])

	assert_eq(checked, 64, "sanity: every ordered pair of the 8 sample hexes was checked")
	assert_eq(
		max_form_breaks.size(),
		0,
		"§4.1: distance == max(|dx|,|dy|,|dz|) on cube coords; first breaks: %s" % [str(max_form_breaks.slice(0, 5))]
	)
	assert_eq(
		half_sum_form_breaks.size(),
		0,
		"§4.1: distance == (|dx|+|dy|+|dz|)/2 on cube coords; first breaks: %s" % [str(half_sum_form_breaks.slice(0, 5))]
	)


## §4.1 — metric properties of cube distance: identity (d(a,a) == 0), symmetry and non-negativity,
## swept over a grid so the properties are pinned as properties, not as a handful of samples.
func test_distance_is_a_non_negative_symmetric_metric() -> void:
	var checked: int = 0
	var identity_breaks: Array[String] = []
	var symmetry_breaks: Array[String] = []
	var negative_breaks: Array[String] = []
	for aq: int in range(-4, 5):
		for ar: int in range(-4, 5):
			var a: Vector2i = Vector2i(aq, ar)
			if HexMath.distance(a, a) != 0:
				identity_breaks.append("%s" % [a])
			for bq: int in range(-4, 5):
				for br: int in range(-4, 5):
					checked += 1
					var b: Vector2i = Vector2i(bq, br)
					var forward: int = HexMath.distance(a, b)
					if forward != HexMath.distance(b, a):
						symmetry_breaks.append("%s..%s" % [a, b])
					if forward < 0:
						negative_breaks.append("%s..%s = %d" % [a, b, forward])

	assert_eq(checked, 6561, "sanity: all 81x81 ordered pairs in [-4,4]^2 were checked")
	assert_eq(
		identity_breaks.size(),
		0,
		"§4.1: distance(a, a) == 0; first breaks: %s" % [str(identity_breaks.slice(0, 5))]
	)
	assert_eq(
		symmetry_breaks.size(),
		0,
		"§4.1: distance(a, b) == distance(b, a); first breaks: %s" % [str(symmetry_breaks.slice(0, 5))]
	)
	assert_eq(
		negative_breaks.size(),
		0,
		"§4.1: distance is never negative; first breaks: %s" % [str(negative_breaks.slice(0, 5))]
	)


## §4.1 — the triangle inequality, the property every later pathfinding/LOS heuristic (§4.3, M4)
## will assume: distance(a, c) <= distance(a, b) + distance(b, c).
func test_distance_satisfies_the_triangle_inequality() -> void:
	var checked: int = 0
	var breaks: Array[String] = []
	for a: Vector2i in SAMPLE_HEXES:
		for b: Vector2i in SAMPLE_HEXES:
			for c: Vector2i in SAMPLE_HEXES:
				checked += 1
				var direct: int = HexMath.distance(a, c)
				var via: int = HexMath.distance(a, b) + HexMath.distance(b, c)
				if direct > via:
					breaks.append("%s..%s..%s: %d > %d" % [a, b, c, direct, via])

	assert_eq(checked, 512, "sanity: all 8^3 triples of the sample hexes were checked")
	assert_eq(
		breaks.size(),
		0,
		"§4.1: distance(a,c) <= distance(a,b) + distance(b,c); first breaks: %s" % [str(breaks.slice(0, 5))]
	)


# =============================================================================================
# E. RADIUS MEMBERSHIP AND MAP SIZES (§4.1 "Map sizes (hex radius): Small 24 (1,801 hexes),
#    Medium 32 (3,169), Large 40 (4,921)")
# =============================================================================================

## §4.1 map-size table, verbatim: radius 24 => 1,801 hexes; 32 => 3,169; 40 => 4,921. Those three
## counts are exactly 3*r*(r+1)+1, so the table pins the formula; the degenerate radii 0 and 1 pin
## its ends. NOTE: these radii live here in the TEST only — §4.4 puts generator parameters in
## data/mapgen/*.json, so hex_math.gd must contain no map-size constant (pinned separately below).
func test_hex_count_for_radius_matches_the_gdd_map_size_table() -> void:
	assert_eq(HexMath.hex_count_for_radius(0), 1, "§4.1: a radius-0 map is the single centre hex")
	assert_eq(HexMath.hex_count_for_radius(1), 7, "§4.1: radius 1 is the centre plus one ring of 6")
	assert_eq(HexMath.hex_count_for_radius(24), 1801, "§4.1 map sizes: Small 24 => 1,801 hexes")
	assert_eq(HexMath.hex_count_for_radius(32), 3169, "§4.1 map sizes: Medium 32 => 3,169 hexes")
	assert_eq(HexMath.hex_count_for_radius(40), 4921, "§4.1 map sizes: Large 40 => 4,921 hexes")


## §4.1 — "Map sizes (hex radius)": membership of a radius-r map is distance-from-origin <= r.
## The Small-map radius 24 is used as the worked example; 25 and (13,13) (cube distance 26) sit
## outside it.
func test_is_within_radius_is_distance_from_origin() -> void:
	assert_true(HexMath.is_within_radius(Vector2i(0, 0), 0), "§4.1: the centre is within radius 0")
	for i: int in range(6):
		var n: Vector2i = HexMath.neighbor(Vector2i(0, 0), i)
		assert_true(
			HexMath.is_within_radius(n, 1),
			"§4.1: the %s neighbour is within radius 1" % [EXPECTED_DIRECTION_NAMES[i]]
		)
		assert_false(
			HexMath.is_within_radius(n, 0),
			"§4.1: the %s neighbour is NOT within radius 0" % [EXPECTED_DIRECTION_NAMES[i]]
		)
	assert_true(HexMath.is_within_radius(Vector2i(24, 0), 24), "§4.1: (24,0) is on the Small-map rim")
	assert_true(HexMath.is_within_radius(Vector2i(0, 24), 24), "§4.1: (0,24) is on the Small-map rim")
	assert_true(HexMath.is_within_radius(Vector2i(24, -24), 24), "§4.1: (24,-24) is on the Small-map rim")
	assert_false(HexMath.is_within_radius(Vector2i(25, 0), 24), "§4.1: (25,0) is outside radius 24")
	assert_false(
		HexMath.is_within_radius(Vector2i(13, 13), 24),
		"§4.1: (13,13) is at cube distance 26 — outside radius 24"
	)


# =============================================================================================
# F. OUT-OF-RANGE DIRECTION INDEX (§13.4 resolution (B) — see header)
# =============================================================================================

## §13.4 resolution (B): a hex has no seventh neighbour, so an out-of-range direction index is the
## identity — `neighbor()` returns the hex unchanged, `opposite()` returns the index unchanged.
## No crash, no engine error, no assert abort headless: the sim must stay deterministic under a
## bad index rather than tearing down a 60-turn headless run (§11.1).
func test_out_of_range_direction_index_is_the_identity() -> void:
	var h: Vector2i = Vector2i(3, -2)
	assert_eq(HexMath.neighbor(h, -1), h, "§13.4 (B): neighbor(h, -1) returns h unchanged")
	assert_eq(HexMath.neighbor(h, 6), h, "§13.4 (B): neighbor(h, 6) returns h unchanged")
	assert_eq(HexMath.neighbor(h, 99), h, "§13.4 (B): neighbor(h, 99) returns h unchanged")
	assert_eq(HexMath.opposite(-1), -1, "§13.4 (B): opposite(-1) returns the index unchanged")
	assert_eq(HexMath.opposite(6), 6, "§13.4 (B): opposite(6) returns the index unchanged")
	assert_eq(HexMath.opposite(99), 99, "§13.4 (B): opposite(99) returns the index unchanged")


# =============================================================================================
# G. PURITY, DETERMINISM AND CONVENTIONS (§11.1, §11.2, §11.3, §13.6)
# =============================================================================================

## §11.1 "pure GDScript RefCounted classes ... No Node, no Scene Tree" + §11.2 (core lives in
## scripts/core/). Non-Node-ness is asserted through get_class() — see the TRAP note in the header.
func test_hex_math_is_a_pure_refcounted_in_scripts_core() -> void:
	assert_true(FileAccess.file_exists(HEX_MATH_PATH), "§11.2: HexMath lives at %s" % HEX_MATH_PATH)
	var instance: HexMath = HexMath.new()
	assert_eq(instance.get_class(), "RefCounted", "§11.1: HexMath must be a pure RefCounted")


## §11.1 "the core must run headless byte-identically": no Node, no Scene Tree, no engine
## singletons, no randi()/randf(), and no wall-clock input. Scans the shipped source with comments
## stripped, so quoting the rule in a doc comment is never a false failure.
func test_source_is_engine_free() -> void:
	var code: String = _code_text(HEX_MATH_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % HEX_MATH_PATH)
	for token: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(token),
			"§11.1: the sim core must be engine-free — %s contains %s" % [HEX_MATH_PATH, token]
		)


## §11.1 "Determinism rules: ... no float accumulation in rules (integers + fixed percent math)".
## Hex geometry is entirely integer arithmetic, so the file must contain NO float literal and no
## `float` type at all — a single float in the coordinate layer would put every later golden at the
## mercy of platform rounding.
func test_source_contains_no_float_math() -> void:
	var code: String = _code_text(HEX_MATH_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % HEX_MATH_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(
		float_literal.compile("\\.[0-9]"),
		OK,
		"sanity: the float-literal pattern compiles"
	)
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			HEX_MATH_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % HEX_MATH_PATH
	)


## §13.6 "constants read from data, not code" + §4.4 ("Generator parameters (ring shares, vein
## densities, lair counts, seed) live in data/mapgen/*.json"). The §4.1 map radii 24/32/40 and their
## hex counts are TUNABLE CONTENT and belong to data, not to the geometry module: `hex_math.gd`
## exposes the formula (`hex_count_for_radius`) and must hard-code no map size.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(HEX_MATH_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % HEX_MATH_PATH)
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
			HEX_MATH_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## §11.3 "public rule functions documented with the GDD section they implement (e.g., ## §6.1)".
## Every public function in hex_math.gd implements §4.1, so each must carry a doc-comment block
## naming it.
func test_public_rule_functions_cite_their_gdd_section() -> void:
	var lines: PackedStringArray = _raw_text(HEX_MATH_PATH).split("\n")
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
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
		if not doc_block.contains("§4.1"):
			undocumented.append(function_name)

	assert_gt(public_functions.size(), 0, "sanity: the scan found public functions to check")
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public rule function needs a '## §4.1' doc comment; missing on: %s" % [str(undocumented)]
	)


## §11.1 "the core must run headless byte-identically" — repeating the same calls on the same
## inputs yields identical results. Compared run-against-run, so this pins the rule (no hidden RNG,
## no iteration-order or wall-clock dependency) rather than any particular value.
func test_repeated_calls_are_identical() -> void:
	for a: Vector2i in SAMPLE_HEXES:
		assert_eq(
			HexMath.axial_to_cube(a),
			HexMath.axial_to_cube(a),
			"§11.1: axial_to_cube(%s) is repeatable" % [a]
		)
		assert_eq(
			HexMath.neighbors(a),
			HexMath.neighbors(a),
			"§11.1: neighbors(%s) is repeatable" % [a]
		)
		for b: Vector2i in SAMPLE_HEXES:
			assert_eq(
				HexMath.distance(a, b),
				HexMath.distance(a, b),
				"§11.1: distance(%s, %s) is repeatable" % [a, b]
			)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

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
