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
## M1-T2 adds sections H–M and five more §13.4 resolutions. §4.1 gives an **algorithm** here, not a
## table — "Line of sight uses standard hex line-drawing (lerp in cube space, round)" — so there is
## no printed cell to transcribe: every expected value in sections H–M was DERIVED from that
## sentence plus the fixed §4.1 direction order, and re-derived independently by the Tests stage
## against a reference model (radius-4 disc × itself, 3,721 ordered pairs, zero property
## violations) before being pinned. Keep the (C)–(G) lettering stable — `hex_math.gd`'s header and
## docs/decisions.md both reference it.
##   (C) ROUNDING IS ROUND-HALF-UP MEANING TOWARD +INFINITY (§11.1 "integers + fixed percent math,
##       round-half-up at the final step"), computed EXACTLY over rationals with denominator N and
##       never in floats: round_half_up(n, d) == floor_div(2*n + d, 2*d) for d > 0, where floor_div
##       is a TRUE floor. GDScript's int/int truncates toward zero (-1 / 3 == 0, not -1), so the
##       correction is load-bearing: without it every negative-coordinate line rounds the wrong
##       way. Godot's `roundi()` rounds half AWAY FROM ZERO and is therefore the WRONG primitive —
##       it maps -1/2 to -1 and -3/2 to -2 where half-up gives 0 and -1. Two probes in section I
##       are chosen precisely because the two conventions disagree on them.
##   (C2) `cube_round_scaled` repairs x + y + z == 0 with the standard largest-diff cascade on the
##       SCALED integer diffs (`if dx > dy and dx > dz: rx = -ry-rz` / `elif dy > dz: ry = -rx-rz`
##       / `else: rz = -rx-ry`), so a two-way or three-way tie deterministically repairs **z**.
##       `denom <= 0` returns the numerators unchanged (same spirit as (B): total, no abort).
##   (D) `line(a, b)` walks i = 0..N over the EXACT numerators cube(a)*N + (cube(b)-cube(a))*i with
##       denominator N = distance(a, b) (N == 0 => [a]). Because the numerators carry no epsilon
##       nudge, line(a, b) is EXACTLY reverse(line(b, a)); that symmetry is pinned as a property
##       (P4) and is what a float implementation with an epsilon tie-break would fail.
##   (E) `ring(c, r)`: corner i == c + DIRECTIONS[i] * r; traversal starts at corner 0 and leaves
##       corner i in direction DIRECTIONS[(i + 2) % 6], r steps per side, appending BEFORE
##       stepping. Consequence, pinned below: ring(c, 1) == neighbors(c) element-for-element.
##   (F) radius < 0 => EMPTY array (both `ring` and `hexes_in_range`); radius == 0 => [center].
##   (G) hexes_in_range(c, r) == [c] + ring(c,1) + ring(c,2) + … + ring(c,r), in that order.
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

## §14 M1 names the deliverable "HexMath (axial/cube, LOS, lines, rings)", so lines and rings are
## HexMath members (LOS is the one piece §11.2 splits out, into `scripts/core/los.gd` at M1-T3).
## These four must exist as PUBLIC functions and must each carry a `## §4.1` doc comment.
const SLICE_TWO_PUBLIC_FUNCTIONS: Array[String] = [
	"cube_round_scaled",
	"line",
	"ring",
	"hexes_in_range",
]

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
	for required: String in SLICE_TWO_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§14 M1 'HexMath (axial/cube, LOS, lines, rings)': %s must be a public function of %s" % [
				required, HEX_MATH_PATH
			]
		)
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
# H. TRUE FLOOR DIVISION (§13.4 resolution (C)) — the primitive the whole exact-rational
#    formulation stands on. GDScript's `int / int` TRUNCATES TOWARD ZERO, so an uncorrected
#    helper rounds every negative cube coordinate the wrong way and quietly bends hex lines.
# =============================================================================================

## §13.4 (C) — `_floor_div(n, d)` is TRUE floor division. The negative cases are the whole point:
## GDScript evaluates `-7 / 3` as -2 and `-1 / 3` as 0, but floor gives -3 and -1. (`_floor_div` is
## private by naming convention only; GDScript exposes it, which is what lets this pin exist at all
## — and the §11.3 doc-comment scan deliberately skips `_`-prefixed functions.)
func test_floor_div_is_true_floor_not_truncation_toward_zero() -> void:
	assert_eq(HexMath._floor_div(7, 3), 2, "§13.4 (C): floor(7/3) == 2")
	assert_eq(
		HexMath._floor_div(-7, 3),
		-3,
		"§13.4 (C): floor(-7/3) == -3 — GDScript's `/` truncates to -2, which is the trap"
	)
	assert_eq(HexMath._floor_div(-6, 3), -2, "§13.4 (C): floor(-6/3) == -2 (exact, nothing to correct)")
	assert_eq(HexMath._floor_div(6, 3), 2, "§13.4 (C): floor(6/3) == 2")
	assert_eq(
		HexMath._floor_div(-1, 3),
		-1,
		"§13.4 (C): floor(-1/3) == -1 — GDScript's `/` truncates to 0, which is the trap"
	)
	assert_eq(HexMath._floor_div(0, 3), 0, "§13.4 (C): floor(0/3) == 0")


## §13.4 (C) — the defining inequality of floor division, swept rather than sampled:
## q * d <= n < (q + 1) * d for every n and every positive d. Stated with multiplication only, so
## the property is checked against the definition and never against another division.
func test_floor_div_satisfies_the_defining_floor_inequality() -> void:
	var checked: int = 0
	var breaks: Array[String] = []
	for d: int in range(1, 7):
		for n: int in range(-20, 21):
			checked += 1
			var q: int = HexMath._floor_div(n, d)
			if q * d > n or (q + 1) * d <= n:
				breaks.append("floor_div(%d, %d) = %d" % [n, d, q])

	assert_eq(checked, 246, "sanity: 41 numerators x 6 denominators were checked")
	assert_eq(
		breaks.size(),
		0,
		"§13.4 (C): q*d <= n < (q+1)*d must hold for every n, d; first breaks: %s" % [str(breaks.slice(0, 5))]
	)


# =============================================================================================
# I. EXACT CUBE ROUNDING (§4.1 "lerp in cube space, round" + §11.1 "round-half-up at the final
#    step"; §13.4 resolutions (C)/(C2)). Rationals are carried as (numerators, denom) integers —
#    a float would put every later golden at the mercy of platform rounding.
# =============================================================================================

## §13.4 (C) — half-up means toward +INFINITY, not away from zero. Both probes below are chosen
## because the two conventions DISAGREE on them, so `roundi()`/`round()` cannot pass this test:
##   (-1,-1,2)/2 = (-0.5,-0.5,1). Half-up rounds the halves to 0,0 giving (0,0,1); the sum is 1 and
##   the scaled diffs are (1,1,0), so `dy > dz` repairs y => (0,-1,1). roundi would round the
##   halves to -1,-1 giving (-1,-1,1); sum -1, diffs (1,1,0), repair y => (-1,0,1).
##   (-3,1,2)/2 = (-1.5,0.5,1). Half-up gives (-1,1,1); sum 1, diffs (1,1,0), repair y => (-1,0,1).
##   roundi gives (-2,1,1), which already sums to 0 and is returned untouched.
func test_cube_round_scaled_rounds_half_toward_positive_infinity() -> void:
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(-1, -1, 2), 2),
		Vector3i(0, -1, 1),
		"§13.4 (C): -1/2 rounds UP to 0, not away from zero to -1 — roundi() would give (-1,0,1)"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(-3, 1, 2), 2),
		Vector3i(-1, 0, 1),
		"§13.4 (C): -3/2 rounds UP to -1, not away from zero to -2 — roundi() would give (-2,1,1)"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(0, 0, 0), 3),
		Vector3i(0, 0, 0),
		"§13.4 (C): the origin rounds to itself at any denominator"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(4, -2, -2), 2),
		Vector3i(2, -1, -1),
		"§13.4 (C): an exactly-representable rational rounds to itself"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(10, -4, -6), 2),
		Vector3i(5, -2, -3),
		"§13.4 (C): an exactly-representable rational rounds to itself"
	)


## §13.4 (C2) — the invariant-repair cascade breaks ties by repairing **z**. A cascade whose final
## `else` repaired y instead would return (1,-1,0) and (1,-2,1) here, so this test is the direct
## pin on the tie-break direction (the two hex lines through a half-step in section J are its
## end-to-end consequence).
func test_cube_round_scaled_breaks_ties_by_repairing_z() -> void:
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(2, -1, -1), 2),
		Vector3i(1, 0, -1),
		"§13.4 (C2): dx=0, dy=dz=1 — a two-way tie falls through to the final else, repairing z"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(1, -2, 1), 2),
		Vector3i(1, -1, 0),
		"§13.4 (C2): dx=dz=1, dy=0 — neither guard fires, so the final else repairs z"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(0, 0, 0), 5),
		Vector3i(0, 0, 0),
		"§13.4 (C2): a three-way tie of zero diffs repairs z, which is already correct"
	)


## §4.1 — a rounded cube is still a cube: the result of `cube_round_scaled` always satisfies
## x + y + z == 0, and no component may drift a whole hex away from the exact rational it rounds
## (|r_c * denom - n_c| <= denom). Swept over every zero-sum numerator triple in a window and every
## denominator 1..7, so this pins the repair cascade as a property (P8) rather than by sample.
func test_cube_round_scaled_always_returns_a_valid_nearby_cube() -> void:
	var checked: int = 0
	var invalid: Array[String] = []
	var far: Array[String] = []
	for denom: int in range(1, 8):
		for nx: int in range(-9, 10):
			for ny: int in range(-9, 10):
				checked += 1
				var numerators: Vector3i = Vector3i(nx, ny, -nx - ny)
				var rounded: Vector3i = HexMath.cube_round_scaled(numerators, denom)
				if not HexMath.is_valid_cube(rounded):
					invalid.append("%s/%d -> %s" % [numerators, denom, rounded])
				if (
					absi(rounded.x * denom - numerators.x) > denom
					or absi(rounded.y * denom - numerators.y) > denom
					or absi(rounded.z * denom - numerators.z) > denom
				):
					far.append("%s/%d -> %s" % [numerators, denom, rounded])

	assert_eq(checked, 2527, "sanity: 19x19 zero-sum numerators x 7 denominators were checked")
	assert_eq(
		invalid.size(),
		0,
		"§4.1/§13.4 (C2): every rounded cube must satisfy x+y+z == 0; first breaks: %s" % [str(invalid.slice(0, 5))]
	)
	assert_eq(
		far.size(),
		0,
		"§13.4 (C2): rounding must not move a component a whole hex; first breaks: %s" % [str(far.slice(0, 5))]
	)


## §13.4 (C2) — a non-positive denominator is the identity, in the same spirit as resolution (B):
## no crash, no engine error, no assert abort headless. A degenerate denominator must never tear
## down a 60-turn headless run (§11.1).
func test_cube_round_scaled_is_the_identity_for_a_non_positive_denominator() -> void:
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(5, -3, 1), 0),
		Vector3i(5, -3, 1),
		"§13.4 (C2): denom == 0 returns the numerators unchanged (no division by zero)"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(5, -3, 1), -2),
		Vector3i(5, -3, 1),
		"§13.4 (C2): a negative denom returns the numerators unchanged"
	)
	assert_eq(
		HexMath.cube_round_scaled(Vector3i(1, -1, 0), 0),
		Vector3i(1, -1, 0),
		"§13.4 (C2): denom == 0 is the identity even for an already-valid cube"
	)


# =============================================================================================
# J. HEX LINES (§4.1 "Line of sight uses standard hex line-drawing (lerp in cube space, round)";
#    §13.4 resolution (D)). Every expected list below was re-derived by the Tests stage from the
#    §4.1 algorithm plus (C)/(C2), independently of the implementation.
# =============================================================================================

## §4.1 + §13.4 (D) — the degenerate line and the three straight runs along direction deltas. A
## straight run must land on exactly the hexes you would reach by stepping the direction, with no
## rounding wobble at all.
func test_line_degenerate_and_straight_runs() -> void:
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(0, 0)),
		_axials([Vector2i(0, 0)]),
		"§13.4 (D): N == 0 yields the single hex [a], never [a, a]"
	)
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(3, 0)),
		_axials([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]),
		"§4.1: a straight run E (direction 0) steps one hex at a time"
	)
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(0, 3)),
		_axials([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]),
		"§4.1: a straight run SE (direction 5) steps one hex at a time"
	)
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(3, -3)),
		_axials([Vector2i(0, 0), Vector2i(1, -1), Vector2i(2, -2), Vector2i(3, -3)]),
		"§4.1: a straight run NE (direction 1) steps one hex at a time"
	)


## §4.1 + §13.4 (C2) — the two tie cases, where the exact cube midpoint sits on a half-step and the
## repair cascade decides the answer. These are the end-to-end consequence of the tie-break pinned
## in section I:
##   line((0,0),(2,-1)) i=1: exact cube (1, -1/2, -1/2); scaled diffs dx=0, dy=dz=1 => else repairs
##   z => cube (1,0,-1) => axial (1,-1). An implementation with the tie-break backwards yields (1,0).
##   line((0,0),(1,1))  i=1: exact cube (1/2, -1, 1/2); dx=dz=1, dy=0, so `dx > dz` is FALSE and
##   `dy > dz` is FALSE => else repairs z => cube (1,-1,0) => axial (1,0).
func test_line_tie_cases_resolve_through_the_z_repair() -> void:
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(2, -1)),
		_axials([Vector2i(0, 0), Vector2i(1, -1), Vector2i(2, -1)]),
		"§13.4 (C2): the dy==dz tie repairs z, so the midpoint is (1,-1) and not (1,0)"
	)
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(1, 1)),
		_axials([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]),
		"§13.4 (C2): the dx==dz tie also falls to the else branch, so the midpoint is (1,0)"
	)
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(4, -2)),
		_axials([Vector2i(0, 0), Vector2i(1, -1), Vector2i(2, -1), Vector2i(3, -2), Vector2i(4, -2)]),
		"§4.1: a half-slope line alternates its two component steps deterministically"
	)


## §13.4 (D) — exact-rational numerators make the line EXACTLY reversible, as concrete values.
## The property form is swept in section L (P4); these two are the hand-checked witnesses.
func test_line_reversed_endpoints_give_the_reversed_line() -> void:
	assert_eq(
		HexMath.line(Vector2i(2, -1), Vector2i(0, 0)),
		_axials([Vector2i(2, -1), Vector2i(1, -1), Vector2i(0, 0)]),
		"§13.4 (D): line((2,-1),(0,0)) is exactly the reverse of line((0,0),(2,-1))"
	)
	assert_eq(
		HexMath.line(Vector2i(1, 1), Vector2i(0, 0)),
		_axials([Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0)]),
		"§13.4 (D): line((1,1),(0,0)) is exactly the reverse of line((0,0),(1,1))"
	)


## §4.1 — a long off-origin line, which independently re-confirms the arithmetic correction in
## docs/decisions.md M1-T1 item 3: cube a = (1,2,-3), cube b = (4,-6,2), delta (-3,8,-5), so
## distance((1,-3),(4,2)) is **8** (not the 5 a task spec once claimed) and the line therefore has
## 9 hexes.
func test_line_long_off_origin_case() -> void:
	var walked: Array[Vector2i] = HexMath.line(Vector2i(1, -3), Vector2i(4, 2))
	assert_eq(walked.size(), 9, "§4.1: distance((1,-3),(4,2)) == 8, so the line has 9 hexes")
	assert_eq(
		walked,
		_axials([
			Vector2i(1, -3),
			Vector2i(1, -2),
			Vector2i(2, -2),
			Vector2i(2, -1),
			Vector2i(3, -1),
			Vector2i(3, 0),
			Vector2i(3, 1),
			Vector2i(4, 1),
			Vector2i(4, 2),
		]),
		"§4.1: the exact-rational hex line from (1,-3) to (4,2)"
	)


# =============================================================================================
# K. RINGS AND RANGES (§14 M1 "HexMath (axial/cube, LOS, lines, rings)"; §13.4 (E)/(F)/(G))
# =============================================================================================

## §13.4 (E) — `ring(c, r)` starts at corner 0 (`c + DIRECTIONS[0] * r`) and leaves corner i in
## direction `DIRECTIONS[(i + 2) % 6]`, appending before each step. The radius-1 consequence is the
## sharpest pin available: it must equal `neighbors(c)` element-for-element, which welds the ring
## traversal to the §4.1 fixed direction order rather than to a private convention.
func test_ring_radius_one_is_exactly_neighbors() -> void:
	assert_eq(
		HexMath.ring(Vector2i(0, 0), 1),
		_axials([
			Vector2i(1, 0),
			Vector2i(1, -1),
			Vector2i(0, -1),
			Vector2i(-1, 0),
			Vector2i(-1, 1),
			Vector2i(0, 1),
		]),
		"§13.4 (E): ring((0,0),1) is the six §4.1 deltas in index order E, NE, NW, W, SW, SE"
	)
	for centre: Vector2i in SAMPLE_HEXES:
		assert_eq(
			HexMath.ring(centre, 1),
			HexMath.neighbors(centre),
			"§13.4 (E): ring(%s, 1) must equal neighbors(%s) element-for-element" % [centre, centre]
		)


## §13.4 (E) — radius 2 walked out by hand from corner 0, two hexes per side, and a radius-1 ring
## off the origin to prove the traversal is translation-invariant (not an accident of c == (0,0)).
func test_ring_hand_walked_cases() -> void:
	assert_eq(
		HexMath.ring(Vector2i(0, 0), 2),
		_axials([
			Vector2i(2, 0),
			Vector2i(2, -1),
			Vector2i(2, -2),
			Vector2i(1, -2),
			Vector2i(0, -2),
			Vector2i(-1, -1),
			Vector2i(-2, 0),
			Vector2i(-2, 1),
			Vector2i(-2, 2),
			Vector2i(-1, 2),
			Vector2i(0, 2),
			Vector2i(1, 1),
		]),
		"§13.4 (E): ring((0,0),2) — corner i is DIRECTIONS[i]*2, each side stepped in DIRECTIONS[(i+2)%6]"
	)
	assert_eq(
		HexMath.ring(Vector2i(3, -2), 1),
		_axials([
			Vector2i(4, -2),
			Vector2i(4, -3),
			Vector2i(3, -3),
			Vector2i(2, -2),
			Vector2i(2, -1),
			Vector2i(3, -1),
		]),
		"§13.4 (E): the ring traversal is translation-invariant"
	)


## §13.4 (F) — radius 0 is the centre alone and a NEGATIVE radius is the EMPTY array, for both
## functions. Total functions (same spirit as (B)): a bad radius must never abort a headless run.
func test_ring_and_range_degenerate_radii_are_total() -> void:
	assert_eq(HexMath.ring(Vector2i(0, 0), 0), _axials([Vector2i(0, 0)]), "§13.4 (F): ring(c,0) == [c]")
	assert_eq(HexMath.ring(Vector2i(3, -2), 0), _axials([Vector2i(3, -2)]), "§13.4 (F): ring(c,0) == [c]")
	assert_eq(HexMath.ring(Vector2i(0, 0), -1), _axials([]), "§13.4 (F): a negative radius is the empty ring")
	assert_eq(HexMath.ring(Vector2i(0, 0), -7), _axials([]), "§13.4 (F): a negative radius is the empty ring")
	assert_eq(
		HexMath.hexes_in_range(Vector2i(0, 0), 0),
		_axials([Vector2i(0, 0)]),
		"§13.4 (F): hexes_in_range(c,0) == [c]"
	)
	assert_eq(
		HexMath.hexes_in_range(Vector2i(0, 0), -1),
		_axials([]),
		"§13.4 (F): a negative radius is the empty range"
	)


## §13.4 (G) — `hexes_in_range` is the spiral composition `[c] + ring(c,1) + … + ring(c,r)`, in
## that order: the centre first, then whole rings outward. Pinned literally at radius 1 and then
## against the composition itself out to radius 5, so the ordering contract cannot drift.
func test_hexes_in_range_is_the_spiral_composition_of_rings() -> void:
	assert_eq(
		HexMath.hexes_in_range(Vector2i(0, 0), 1),
		_axials([
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, -1),
			Vector2i(0, -1),
			Vector2i(-1, 0),
			Vector2i(-1, 1),
			Vector2i(0, 1),
		]),
		"§13.4 (G): centre first, then ring 1 in fixed §4.1 direction order"
	)
	for centre: Vector2i in [Vector2i(0, 0), Vector2i(-5, 3)]:
		for radius: int in range(0, 6):
			var expected: Array[Vector2i] = _axials([centre])
			for r: int in range(1, radius + 1):
				expected.append_array(HexMath.ring(centre, r))
			assert_eq(
				HexMath.hexes_in_range(centre, radius),
				expected,
				"§13.4 (G): hexes_in_range(%s, %d) == [c] + ring(1) + … + ring(%d)" % [centre, radius, radius]
			)


## §4.1 map-size formula — the range size must equal `hex_count_for_radius(r) == 3*r*(r+1)+1` for
## every radius. Asserted against the FUNCTION, so the two independent formulations (enumerate the
## spiral vs. evaluate the closed form) cross-check each other; the three literals are the
## hand-computed anchors 19 / 37 / 217 for radii 2 / 3 / 8.
func test_hexes_in_range_size_matches_the_hex_count_formula() -> void:
	assert_eq(HexMath.hexes_in_range(Vector2i(0, 0), 2).size(), 19, "§4.1: 3*2*3+1 == 19 hexes")
	assert_eq(HexMath.hexes_in_range(Vector2i(0, 0), 3).size(), 37, "§4.1: 3*3*4+1 == 37 hexes")
	assert_eq(HexMath.hexes_in_range(Vector2i(0, 0), 8).size(), 217, "§4.1: 3*8*9+1 == 217 hexes")
	for radius: int in range(0, 9):
		assert_eq(
			HexMath.hexes_in_range(Vector2i(0, 0), radius).size(),
			HexMath.hex_count_for_radius(radius),
			"§4.1: |hexes_in_range(c, %d)| == hex_count_for_radius(%d)" % [radius, radius]
		)


# =============================================================================================
# L. LINE AND RING PROPERTIES (§14 M1 asks for property tests; this is the line/ring half — the
#    LOS half arrives with `scripts/core/los.gd` at M1-T3)
# =============================================================================================

## §4.1 + §13.4 (D) — the five line properties, swept over EVERY ordered pair drawn from the
## radius-4 disc around the origin (61 hexes, 3,721 pairs):
##   P1 |line(a,b)| == distance(a,b) + 1        P2 the line starts at a and ends at b
##   P3 consecutive hexes are at distance exactly 1 (the line is a walk of unit steps)
##   P4 line(a,b) == reverse(line(b,a))         P5 distance(a,h) + distance(h,b) == distance(a,b)
## P4 is the one an epsilon-nudge float implementation fails, which is precisely why it is here.
## Violations are collected and asserted once, so a break reports its own coordinates instead of
## drowning the run in 3,721 assertions.
func test_line_properties_over_the_radius_four_disc() -> void:
	var disc: Array[Vector2i] = _disc(4)
	assert_eq(disc.size(), 61, "sanity: the radius-4 disc holds 3*4*5+1 == 61 hexes")

	var pairs: int = 0
	var p1: Array[String] = []
	var p2: Array[String] = []
	var p3: Array[String] = []
	var p4: Array[String] = []
	var p5: Array[String] = []
	for a: Vector2i in disc:
		for b: Vector2i in disc:
			pairs += 1
			var forward: Array[Vector2i] = HexMath.line(a, b)
			var span: int = HexMath.distance(a, b)
			if forward.size() != span + 1:
				p1.append("%s..%s: %d hexes for distance %d" % [a, b, forward.size(), span])
				continue
			if forward[0] != a or forward[forward.size() - 1] != b:
				p2.append("%s..%s: endpoints %s..%s" % [a, b, forward[0], forward[forward.size() - 1]])
			for i: int in range(forward.size() - 1):
				if HexMath.distance(forward[i], forward[i + 1]) != 1:
					p3.append("%s..%s: step %d is %s -> %s" % [a, b, i, forward[i], forward[i + 1]])
			var backward: Array[Vector2i] = HexMath.line(b, a)
			backward.reverse()
			if forward != backward:
				p4.append("%s..%s: %s vs %s" % [a, b, forward, backward])
			for h: Vector2i in forward:
				if HexMath.distance(a, h) + HexMath.distance(h, b) != span:
					p5.append("%s..%s: %s is off the geodesic" % [a, b, h])

	assert_eq(pairs, 3721, "sanity: all 61x61 ordered pairs of the radius-4 disc were swept")
	assert_eq(
		p1.size(),
		0,
		"P1 §4.1: |line(a,b)| == distance(a,b) + 1; first breaks: %s" % [str(p1.slice(0, 3))]
	)
	assert_eq(
		p2.size(),
		0,
		"P2 §4.1: a line starts at a and ends at b; first breaks: %s" % [str(p2.slice(0, 3))]
	)
	assert_eq(
		p3.size(),
		0,
		"P3 §4.1: a line is a walk of unit steps; first breaks: %s" % [str(p3.slice(0, 3))]
	)
	assert_eq(
		p4.size(),
		0,
		"P4 §13.4 (D): exact rationals make line(a,b) == reverse(line(b,a)); first breaks: %s" % [str(p4.slice(0, 3))]
	)
	assert_eq(
		p5.size(),
		0,
		"P5 §4.1: every hex on a line is between its endpoints; first breaks: %s" % [str(p5.slice(0, 3))]
	)


## §13.4 (E)/(F) — P6: for r >= 1 a ring holds exactly 6*r DISTINCT hexes, every one at distance
## exactly r from the centre (r == 0 holds the centre alone). Checked at the origin and off it, so
## the property is the geometry and not an artefact of c == (0,0).
func test_ring_properties_out_to_radius_eight() -> void:
	var checked: int = 0
	var size_breaks: Array[String] = []
	var duplicate_breaks: Array[String] = []
	var distance_breaks: Array[String] = []
	for centre: Vector2i in [Vector2i(0, 0), Vector2i(-5, 3)]:
		for radius: int in range(0, 9):
			checked += 1
			var walked: Array[Vector2i] = HexMath.ring(centre, radius)
			var expected_size: int = 6 * radius if radius >= 1 else 1
			if walked.size() != expected_size:
				size_breaks.append("ring(%s, %d): %d entries, expected %d" % [centre, radius, walked.size(), expected_size])
			var seen: Dictionary = {}
			for h: Vector2i in walked:
				seen[h] = true
				if HexMath.distance(centre, h) != radius:
					distance_breaks.append("ring(%s, %d): %s is at distance %d" % [centre, radius, h, HexMath.distance(centre, h)])
			if seen.size() != walked.size():
				duplicate_breaks.append("ring(%s, %d): %d distinct of %d" % [centre, radius, seen.size(), walked.size()])

	assert_eq(checked, 18, "sanity: radii 0..8 were checked at two centres")
	assert_eq(
		size_breaks.size(),
		0,
		"P6 §13.4 (E): |ring(c,r)| == 6*r for r >= 1, 1 for r == 0; first breaks: %s" % [str(size_breaks.slice(0, 3))]
	)
	assert_eq(
		duplicate_breaks.size(),
		0,
		"P6 §13.4 (E): a ring never repeats a hex; first breaks: %s" % [str(duplicate_breaks.slice(0, 3))]
	)
	assert_eq(
		distance_breaks.size(),
		0,
		"P6 §4.1: every hex of ring(c,r) is at cube distance exactly r; first breaks: %s" % [str(distance_breaks.slice(0, 3))]
	)


## §13.4 (F)/(G) — P7: `hexes_in_range(c, r)` holds exactly `hex_count_for_radius(r)` DISTINCT
## hexes, all within distance r, and its first element is the centre.
func test_hexes_in_range_properties_out_to_radius_eight() -> void:
	var checked: int = 0
	var size_breaks: Array[String] = []
	var duplicate_breaks: Array[String] = []
	var distance_breaks: Array[String] = []
	var centre_breaks: Array[String] = []
	for centre: Vector2i in [Vector2i(0, 0), Vector2i(-5, 3)]:
		for radius: int in range(0, 9):
			checked += 1
			var covered: Array[Vector2i] = HexMath.hexes_in_range(centre, radius)
			if covered.size() != HexMath.hex_count_for_radius(radius):
				size_breaks.append("range(%s, %d): %d entries, expected %d" % [
					centre, radius, covered.size(), HexMath.hex_count_for_radius(radius)
				])
			if covered.is_empty() or covered[0] != centre:
				centre_breaks.append("range(%s, %d) does not start at the centre" % [centre, radius])
			var seen: Dictionary = {}
			for h: Vector2i in covered:
				seen[h] = true
				if HexMath.distance(centre, h) > radius:
					distance_breaks.append("range(%s, %d): %s is at distance %d" % [centre, radius, h, HexMath.distance(centre, h)])
			if seen.size() != covered.size():
				duplicate_breaks.append("range(%s, %d): %d distinct of %d" % [centre, radius, seen.size(), covered.size()])

	assert_eq(checked, 18, "sanity: radii 0..8 were checked at two centres")
	assert_eq(
		size_breaks.size(),
		0,
		"P7 §4.1: |hexes_in_range(c,r)| == hex_count_for_radius(r); first breaks: %s" % [str(size_breaks.slice(0, 3))]
	)
	assert_eq(
		centre_breaks.size(),
		0,
		"P7 §13.4 (G): the spiral starts at the centre; first breaks: %s" % [str(centre_breaks.slice(0, 3))]
	)
	assert_eq(
		duplicate_breaks.size(),
		0,
		"P7 §13.4 (G): the spiral never repeats a hex; first breaks: %s" % [str(duplicate_breaks.slice(0, 3))]
	)
	assert_eq(
		distance_breaks.size(),
		0,
		"P7 §4.1: every hex of hexes_in_range(c,r) is within distance r; first breaks: %s" % [str(distance_breaks.slice(0, 3))]
	)


# =============================================================================================
# M. FRESHNESS AND DETERMINISM FOR THE SLICE-2 ARRAYS (§11.1) — the same contract `neighbors()`
#    already carries. A `const`/`static` cached array is not deeply immutable in GDScript, so a
#    shared return value lets one caller's mutation corrupt every later caller and every golden.
# =============================================================================================

## §11.1 — F1: `line`, `ring` and `hexes_in_range` each hand back a FRESH `Array[Vector2i]` per
## call. Two calls must not be the same object, and element-assigning, appending to and finally
## clearing the first result must leave a concurrently-held second result — and every later call —
## untouched.
func test_line_ring_and_range_return_fresh_arrays_each_call() -> void:
	var line_expected: Array[Vector2i] = _axials([Vector2i(0, 0), Vector2i(1, -1), Vector2i(2, -1)])
	_assert_fresh_pair(
		HexMath.line(Vector2i(0, 0), Vector2i(2, -1)),
		HexMath.line(Vector2i(0, 0), Vector2i(2, -1)),
		line_expected,
		"line((0,0),(2,-1))"
	)
	assert_eq(
		HexMath.line(Vector2i(0, 0), Vector2i(2, -1)),
		line_expected,
		"§11.1: mutating a line() result must not corrupt later calls"
	)

	var ring_expected: Array[Vector2i] = _axials([
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
	])
	_assert_fresh_pair(
		HexMath.ring(Vector2i(0, 0), 1),
		HexMath.ring(Vector2i(0, 0), 1),
		ring_expected,
		"ring((0,0),1)"
	)
	assert_eq(
		HexMath.ring(Vector2i(0, 0), 1),
		ring_expected,
		"§11.1: mutating a ring() result must not corrupt later calls"
	)
	if HexMath.DIRECTIONS.size() == 6:
		assert_eq(
			HexMath.DIRECTIONS[0],
			EXPECTED_DIRECTIONS[0],
			"§4.1: the shared direction table survives a caller mutating a ring() result"
		)

	var range_expected: Array[Vector2i] = _axials([Vector2i(0, 0)])
	range_expected.append_array(ring_expected)
	_assert_fresh_pair(
		HexMath.hexes_in_range(Vector2i(0, 0), 1),
		HexMath.hexes_in_range(Vector2i(0, 0), 1),
		range_expected,
		"hexes_in_range((0,0),1)"
	)
	assert_eq(
		HexMath.hexes_in_range(Vector2i(0, 0), 1),
		range_expected,
		"§11.1: mutating a hexes_in_range() result must not corrupt later calls"
	)


## §11.1 "the core must run headless byte-identically" — F2: repeating the same slice-2 calls on
## the same inputs yields equal arrays. Compared run-against-run, so it pins the rule (no hidden
## state, no RNG, no wall clock, no Dictionary iteration order) rather than any particular value.
func test_slice_two_calls_are_repeatable() -> void:
	for a: Vector2i in SAMPLE_HEXES:
		assert_eq(
			HexMath.ring(a, 3),
			HexMath.ring(a, 3),
			"§11.1: ring(%s, 3) is repeatable" % [a]
		)
		assert_eq(
			HexMath.hexes_in_range(a, 2),
			HexMath.hexes_in_range(a, 2),
			"§11.1: hexes_in_range(%s, 2) is repeatable" % [a]
		)
		for b: Vector2i in SAMPLE_HEXES:
			assert_eq(
				HexMath.line(a, b),
				HexMath.line(a, b),
				"§11.1: line(%s, %s) is repeatable" % [a, b]
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


## Builds a typed `Array[Vector2i]` from an inline literal, so an expected value can be written at
## the assertion site while still comparing typed array against typed array.
func _axials(items: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Vector2i in items:
		out.append(item)
	return out


## Every hex within `radius` of the origin, built from the already-pinned §4.1 cube distance (not
## from `hexes_in_range`, which is one of the things under test here).
func _disc(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q: int in range(-radius, radius + 1):
		for r: int in range(-radius, radius + 1):
			var h: Vector2i = Vector2i(q, r)
			if HexMath.distance(Vector2i.ZERO, h) <= radius:
				out.append(h)
	return out


## §11.1 freshness contract, shared by `line` / `ring` / `hexes_in_range`: two calls with identical
## arguments must be two DISTINCT arrays, and element-assigning, appending to and finally clearing
## the first must leave the second completely untouched.
func _assert_fresh_pair(
	first: Array[Vector2i],
	second: Array[Vector2i],
	expected: Array[Vector2i],
	label: String
) -> void:
	assert_false(
		is_same(first, second),
		"§11.1: %s must return a fresh array, not a shared/cached one" % [label]
	)
	assert_eq(first, expected, "sanity: %s returned the expected hexes" % [label])
	if not first.is_empty():
		first[0] = Vector2i(999, 999)
	first.append(Vector2i(999, 999))
	first.clear()
	assert_eq(
		second,
		expected,
		"§11.1: mutating one %s result must not corrupt another live result" % [label]
	)
