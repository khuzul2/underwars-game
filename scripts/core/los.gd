## Los — GDD §4.1 (Hex Grid Specification, binding), §11.1 (sim core is engine-free and
## deterministic), §11.2 (`scripts/core/` — "HexMath, Los, Pathfinder, ... — pure & unit-tested",
## which names `Los` as its own peer file), §11.3 (coding conventions), §13.2 tier 1 ("every core/
## function"), §13.6, §14 M1 acceptance criterion "LOS property tests".
##
## Pure [RefCounted], all-static: Los is never instantiated in production code. It implements
## exactly one sentence of §4.1, transcribed verbatim from docs/GAME_DESIGN.md line 172:
##   "Line of sight uses standard hex line-drawing (lerp in cube space, round); a line is blocked
##    by any Solid hex, or by any hex whose elevation exceeds **both** endpoints' elevation."
## The line-drawing half is ALREADY BUILT AND PINNED — [method HexMath.line] (resolutions
## (C)/(C2)/(D)). This file CALLS it and must never re-implement, wrap or "optimize" it: the exact
## rational rounding there is what makes the symmetry property below true.
##
## THE RULE:
##   path = HexMath.line(a, b); N = path.size() - 1; cap = maxi(elev(a), elev(b));
##   an INTERIOR hex h == path[i] for i in 1..N-1 blocks iff is_solid(h) OR elev(h) > cap (STRICT);
##   path[0] (== a) and path[N] (== b) are NEVER tested;
##   has_line_of_sight == "no interior hex blocks"; blocking_hexes == every blocker, in line order.
##
## §13.4 ambiguity resolutions (logged in docs/decisions.md; the lettering continues M1-T1's (A)/(B)
## and M1-T2's (C)-(G) and is cross-referenced by tests/unit/test_los.gd — keep it stable). No
## docs/GAME_DESIGN.md edit accompanies them: §4.1 gives an algorithm here, so no numeric table cell
## moved.
##   (H) TERRAIN INJECTION SHAPE. No GameState, no map type and no terrain enum exist yet (§4.4's
##       generator is a later M1 task), so terrain arrives as two injected [Callable]s —
##       `is_solid(Vector2i) -> bool` and `elevation(Vector2i) -> int` — as parameters 3 and 4. A
##       Callable is an integer/Variant built-in, not a Node or singleton, so §11.1 purity holds;
##       inventing a map type here would pre-empt §4.4. When GameState lands, callers bind closures
##       over it and this file never changes.
##   (I) ENDPOINT EXEMPTION. Only INTERIOR hexes (line indices 1..N-1) are tested. A Solid endpoint
##       does not block its own line — you can always see out of, and into, the hex you stand on or
##       look at. (The elevation half is arithmetically vacuous under (J), since an endpoint's own
##       elevation can never exceed maxi of the two endpoints, but it is stated so no later stage
##       "fixes" it.)
##   (J) "EXCEEDS BOTH ENDPOINTS' ELEVATION" IS STRICT ">" AGAINST maxi(elev(a), elev(b)). Equal
##       elevation does NOT block. The cap is computed ONCE before the loop.
##   (K) DEGENERATE LINES ARE ALWAYS OPEN. distance == 0 (line [a]) and distance == 1 (line [a, b])
##       have zero interior hexes, so they are unconditionally open regardless of terrain — a
##       CONSEQUENCE of (I), never a separate early return that could drift from it.
##   (L) AN INVALID CALLABLE MEANS OPEN TERRAIN. If either Callable fails `is_valid()`,
##       [method has_line_of_sight] returns true and [method blocking_hexes] returns [] — a total
##       function: no crash, no engine error, no assert abort headless (same spirit as M1-T1
##       resolution (B)). Off-map / unknown-hex semantics are the CALLER's responsibility: Los knows
##       no map bounds, calls the Callables only for interior hexes, and imposes no elevation range
##       check (§4.1's 0-3 is the generator's contract, not this file's).
##
## §13.6 "constants read from data, not code" is VACUOUS here and deliberately so: the blocking
## predicate is algorithm, not tunable content, so data/ruleset.json carries no LOS key and must not
## gain one. Los mutates no GameState and touches no EventBus, so "events emitted for every state
## change" has no subject matter either.
class_name Los
extends RefCounted

## §4.1 "a line is blocked by any Solid hex, or by any hex whose elevation exceeds **both**
## endpoints' elevation" — true when no INTERIOR hex of HexMath.line(a, b) blocks (resolutions
## (I)/(J)/(K)/(L)). May short-circuit on the first blocker.
static func has_line_of_sight(a: Vector2i, b: Vector2i, is_solid: Callable, elevation: Callable) -> bool:
	if not is_solid.is_valid() or not elevation.is_valid():
		return true
	var path: Array[Vector2i] = HexMath.line(a, b)
	var cap: int = maxi(int(elevation.call(a)), int(elevation.call(b)))
	for i: int in range(1, path.size() - 1):
		if _blocks(path[i], cap, is_solid, elevation):
			return false
	return true


## §4.1 "a line is blocked by any Solid hex, or by any hex whose elevation exceeds **both**
## endpoints' elevation" — every blocking INTERIOR hex of HexMath.line(a, b), in line order,
## nearest to `a` first. Always a fresh [Array] (§11.1).
static func blocking_hexes(a: Vector2i, b: Vector2i, is_solid: Callable, elevation: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_solid.is_valid() or not elevation.is_valid():
		return out
	var path: Array[Vector2i] = HexMath.line(a, b)
	var cap: int = maxi(int(elevation.call(a)), int(elevation.call(b)))
	for i: int in range(1, path.size() - 1):
		if _blocks(path[i], cap, is_solid, elevation):
			out.append(path[i])
	return out


## Private helper — §4.1: a single interior hex blocks iff it is Solid OR its elevation strictly
## exceeds `cap` (resolution (J)). Not part of the public API (§11.2/§13.4: exactly two functions).
static func _blocks(h: Vector2i, cap: int, is_solid: Callable, elevation: Callable) -> bool:
	var solid: bool = bool(is_solid.call(h))
	if solid:
		return true
	var height: int = int(elevation.call(h))
	return height > cap
