## HexMath — GDD §4.1 (Hex Grid Specification, binding), §11.1 (sim core is engine-free and
## deterministic), §11.2 (`scripts/core/` — "HexMath, Los, Pathfinder, ... — pure & unit-tested"),
## §11.3 (coding conventions), §13.2 tier 1 ("every core/ function"), §13.6, §14 M1 row.
##
## Pure [RefCounted], all-static: HexMath is never instantiated. Axial coordinates are plain
## [Vector2i] (q, r); cube coordinates are plain [Vector3i] (x, y, z) satisfying x + y + z == 0.
## Slice 1 (M1-T1): coordinate conversion, the fixed 6-direction table, neighbours/opposites, cube
## distance, radius membership, hex-count-for-radius. Slice 2 (M1-T2): the §4.1 hex-line primitive
## ("lerp in cube space, round") in EXACT INTEGER rational arithmetic, plus rings and ranges.
## LOS is deliberately NOT here — §11.2 names `Los` as a separate `scripts/core/` file and it lands
## at M1-T3, once there is terrain to block with.
##
## §13.4 ambiguity resolutions (logged in docs/decisions.md, no docs/GAME_DESIGN.md edit — no
## numeric table value moved):
##   (A) FLAT-TOP vs. THE DIRECTION NAMES. §4.1 says "Flat-top hexes" AND names the six indices
##       E, NE, NW, W, SW, SE — the pointy-top naming of the six standard axial deltas. This file
##       stores the deltas in the GDD's stated index order and uses the GDD's stated names verbatim
##       as index labels; hex-to-screen orientation is a RENDERER concern (later M1 task) and does
##       not change any sim value here.
##   (B) OUT-OF-RANGE DIRECTION INDEX. [method neighbor] and [method opposite] treat an index
##       outside 0..5 as the identity (return the input unchanged) — no crash, no engine error, no
##       assert abort headless. A hex grid has no seventh neighbour; the identity is the simplest
##       total function (§13.4).
##   (C) ROUNDING IS ROUND-HALF-UP MEANING TOWARD +INFINITY (§11.1 "integers + fixed percent math,
##       round-half-up at the final step"), computed exactly over rationals with denominator N and
##       never in floats: round_half_up(n, d) == _floor_div(2 * n + d, 2 * d) for d > 0.
##       [method _floor_div] is TRUE floor: GDScript's int/int truncates toward zero, so -3 / 6
##       yields 0 rather than -1, and without the correction every negative-coordinate line is
##       wrong. Godot's [method @GlobalScope.roundi] rounds half AWAY FROM ZERO and is therefore
##       the WRONG primitive here — it is never used in this file.
##   (C2) CUBE ROUNDING REPAIRS THE INVARIANT WITH THE LARGEST-DIFF CASCADE, ties repairing z.
##       [method cube_round_scaled] rounds each component with (C), then repairs x + y + z == 0 on
##       the SCALED integer diffs dx = |rx*denom - n.x| (etc.):
##       `if dx > dy and dx > dz: rx = -ry - rz` / `elif dy > dz: ry = -rx - rz` / `else:
##       rz = -rx - ry`. A two-way or three-way tie therefore deterministically repairs z. A
##       `denom <= 0` returns `numerators` unchanged — the same spirit as (B): no crash, no assert
##       abort headless.
##   (D) HEX LINES ARE EXACTLY REVERSIBLE. [method line] uses N = distance(a, b) as the denominator
##       and exact integer numerators (no epsilon nudge), so line(a, b) is exactly the reverse of
##       line(b, a). A float implementation with an epsilon tie-break would not have this property.
##   (E) RING TRAVERSAL. Corner i of [method ring] is `center + DIRECTIONS[i] * radius`; traversal
##       starts at corner 0 and leaves corner i in direction `DIRECTIONS[(i + 2) % 6]`, `radius`
##       steps per side, appending BEFORE stepping. Consequence: `ring(c, 1)` equals
##       [method neighbors] element-for-element.
##   (F) A NEGATIVE RADIUS IS THE EMPTY ARRAY for both [method ring] and [method hexes_in_range];
##       radius 0 is `[center]`. Total functions, no crash (same spirit as (B)).
##   (G) [method hexes_in_range] is the spiral composition
##       `[center] + ring(c, 1) + ring(c, 2) + … + ring(c, radius)`, in that order.
##
## §13.6 "constants read from data, not code" is vacuous here and deliberately so: the six
## direction deltas and the cube-distance formula are geometry/algorithm, not tunable content.
## The tunable map radii (Small 24 / Medium 32 / Large 40, §4.1) belong to `data/mapgen/*.json`
## (§4.4, generator task) and are NOT hard-coded in this file.
class_name HexMath
extends RefCounted

## §4.1 "Neighbor order (fixed, index 0-5): E, NE, NW, W, SW, SE" — the six standard axial deltas,
## in the GDD's stated index order. See resolution (A) above: not reordered for screen layout.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # 0  E
	Vector2i(1, -1),  # 1  NE
	Vector2i(0, -1),  # 2  NW
	Vector2i(-1, 0),  # 3  W
	Vector2i(-1, 1),  # 4  SW
	Vector2i(0, 1),   # 5  SE
]

## §4.1 — the direction names, in the same fixed index order as [constant DIRECTIONS].
const DIRECTION_NAMES: PackedStringArray = ["E", "NE", "NW", "W", "SW", "SE"]


## §4.1 — axial (q, r) to cube (x, y, z): x = q, z = r, y = -q - r. The result always satisfies
## the defining cube invariant x + y + z == 0.
static func axial_to_cube(a: Vector2i) -> Vector3i:
	return Vector3i(a.x, -a.x - a.y, a.y)


## §4.1 — cube (x, y, z) to axial (q, r): q = x, r = z. y is redundant, recoverable from the
## invariant x + y + z == 0, so it is dropped here.
static func cube_to_axial(c: Vector3i) -> Vector2i:
	return Vector2i(c.x, c.z)


## §4.1 — a cube coordinate is well-formed iff x + y + z == 0.
static func is_valid_cube(c: Vector3i) -> bool:
	return c.x + c.y + c.z == 0


## §4.1 — the hex adjacent to `a` in fixed direction `dir` (0-5, see [constant DIRECTIONS]). See
## resolution (B) above: an out-of-range `dir` returns `a` unchanged.
static func neighbor(a: Vector2i, dir: int) -> Vector2i:
	if dir < 0 or dir > 5:
		return a
	return a + DIRECTIONS[dir]


## §4.1 — the six hexes adjacent to `a`, in the fixed index order of [constant DIRECTIONS]. Always
## returns a fresh [Array] (never a shared/cached one, per §11.1 determinism): a `const
## Array[Vector2i]` is not deeply immutable in GDScript, so a shared return value would let one
## caller's mutation corrupt every later caller.
static func neighbors(a: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: int in range(6):
		out.append(a + DIRECTIONS[dir])
	return out


## §4.1 — the direction three steps around the fixed ring from `dir`: opposite(i) == (i + 3) % 6
## (E<->W, NE<->SW, NW<->SE). See resolution (B) above: an out-of-range `dir` returns `dir`
## unchanged.
static func opposite(dir: int) -> int:
	if dir < 0 or dir > 5:
		return dir
	return (dir + 3) % 6


## §4.1 "Distance = cube distance" — max(|dx|, |dy|, |dz|) between `a` and `b`'s cube coordinates.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var cube_a: Vector3i = axial_to_cube(a)
	var cube_b: Vector3i = axial_to_cube(b)
	var dx: int = absi(cube_a.x - cube_b.x)
	var dy: int = absi(cube_a.y - cube_b.y)
	var dz: int = absi(cube_a.z - cube_b.z)
	return maxi(dx, maxi(dy, dz))


## §4.1 "Map sizes (hex radius)" — true when `a` is within `radius` hexes of the origin (0,0),
## i.e. distance(origin, a) <= radius. The tunable radii themselves (Small 24, Medium 32,
## Large 40) live in data/mapgen/*.json (§4.4), not in this file.
static func is_within_radius(a: Vector2i, radius: int) -> bool:
	return distance(Vector2i.ZERO, a) <= radius


## §4.1 "Map sizes (hex radius)" — the number of hexes within `radius` of the origin:
## 3 * radius * (radius + 1) + 1. The GDD table values (Small 1,801 / Medium 3,169 / Large 4,921)
## are this formula evaluated at radius 24/32/40 and are pinned by the formula, not hard-coded.
static func hex_count_for_radius(radius: int) -> int:
	return 3 * radius * (radius + 1) + 1


# =================================================================================================
# SLICE 2 (M1-T2) — DELIBERATELY-WRONG TESTS-STAGE STUBS.
#
# These five members exist ONLY so that `tests/unit/test_hex_math.gd` PARSES: a call to a missing
# method is a GDScript parse error, which silently un-collects the whole test file (the M0-T5
# false green, docs/decisions.md M0-T5 item (a)). Every body below returns a wrong value on
# purpose, so the new tests fail on VALUES rather than on loading. The Implement stage replaces
# this whole block with resolutions (C)–(G) above.
# =================================================================================================


## §4.1 "lerp in cube space, round" — STUB (M1-T2 Tests stage, deliberately wrong). Rounds the
## exact rational `numerators / denom` to the nearest cube coordinate per resolutions (C)/(C2).
static func cube_round_scaled(numerators: Vector3i, denom: int) -> Vector3i:
	return numerators * denom


## §4.1 "Line of sight uses standard hex line-drawing (lerp in cube space, round)" — STUB (M1-T2
## Tests stage, deliberately wrong). The hexes from `a` to `b` inclusive, per resolution (D).
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.append(a)
	out.append(b)
	return out


## §4.1 — STUB (M1-T2 Tests stage, deliberately wrong). The hexes at exactly `radius` from
## `center`, in the fixed traversal order of resolution (E).
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.append(center + Vector2i(radius, 0))
	return out


## §4.1 — STUB (M1-T2 Tests stage, deliberately wrong). The hexes within `radius` of `center` in
## spiral order, per resolution (G).
static func hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.append(center + Vector2i(0, radius))
	return out


# STUB (M1-T2 Tests stage, deliberately wrong): this truncates toward zero instead of flooring,
# which is exactly the trap resolution (C) exists to close.
static func _floor_div(n: int, d: int) -> int:
	@warning_ignore("integer_division")
	var q: int = n / d
	return q
