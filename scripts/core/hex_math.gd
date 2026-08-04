## HexMath — GDD §4.1 (Hex Grid Specification, binding), §11.1 (sim core is engine-free and
## deterministic), §11.2 (`scripts/core/` — "HexMath, Los, Pathfinder, ... — pure & unit-tested"),
## §11.3 (coding conventions), §13.2 tier 1 ("every core/ function"), §13.6, §14 M1 row.
##
## Pure [RefCounted], all-static: HexMath is never instantiated. Axial coordinates are plain
## [Vector2i] (q, r); cube coordinates are plain [Vector3i] (x, y, z) satisfying x + y + z == 0.
## Slice 1 only (M1-T1): coordinate conversion, the fixed 6-direction table, neighbours/opposites,
## cube distance, radius membership, hex-count-for-radius. LOS, hex lines, rings and ranges are a
## later M1 task (PROGRESS explicitly splits the slice this way) — not written here.
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
