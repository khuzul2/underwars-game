## Los — GDD §4.1 (Hex Grid Specification, **binding**), §11.1 (sim core is engine-free and
## deterministic), §11.2 (`scripts/core/` — "HexMath, Los, Pathfinder, ... — pure & unit-tested"),
## §11.3 (coding conventions), §13.2 tier 1 ("every core/ function"), §13.4, §13.6,
## §14 M1 acceptance criterion "LOS property tests".
##
## THE ONE SENTENCE THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md` line 172:
##   "Line of sight uses standard hex line-drawing (lerp in cube space, round); a line is blocked
##    by any Solid hex, or by any hex whose elevation exceeds **both** endpoints' elevation."
## Supporting §4.1 facts, also verbatim:
##   line 173: "**Elevation:** integer 0-3 per hex."
##   §4.2:     "Solid hexes (volumetric rock; block movement, LOS, and light)".
##
## docs/decisions.md was scanned end-to-end this iteration: **NO logged override touches §4.1**, so
## the printed text above governs unamended. §4.1 gives an ALGORITHM here, not a table, so there is
## no printed cell to transcribe: every expected value below is DERIVED, and each was re-derived
## independently by the Tests stage against a reference model built from the GDD text (radius-4 disc
## x itself, 3,721 ordered pairs, zero property violations) before being pinned — per the lesson
## recorded as decisions.md M1-T1 item 3 and M1-T2 item 9.
##
## THE LINE-DRAWING HALF IS ALREADY BUILT AND PINNED (`HexMath.line()`, resolutions (C)/(C2)/(D),
## 106 green tests). `Los` calls it; it must never re-implement, wrap or "optimize" it. This file
## references `HexMath.line()` only to cross-check hand-derived interiors — its job is to pin the
## BLOCKING rule, not to re-pin line drawing.
##
## THE RULE AS PINNED HERE:
##   path = HexMath.line(a, b); N = path.size() - 1; cap = maxi(elev(a), elev(b));
##   an INTERIOR hex h == path[i] for i in 1..N-1 blocks iff is_solid(h) OR elev(h) > cap (STRICT);
##   path[0] (== a) and path[N] (== b) are NEVER tested;
##   has_line_of_sight == "no interior hex blocks"; blocking_hexes == every blocker, in line order.
##
## §13.4 ambiguity resolutions pinned here (the GDD legislates none of them; Land logs all five in
## docs/decisions.md). The lettering CONTINUES M1-T1's (A)/(B) and M1-T2's (C)-(G) — keep it stable,
## `scripts/core/los.gd`'s header and docs/decisions.md both reference it:
##   (H) TERRAIN INJECTION SHAPE. No GameState, no map type and no terrain enum exist yet (§4.4's
##       generator is a later M1 task), so `Los` receives terrain as two injected Callables —
##       `is_solid(Vector2i) -> bool` and `elevation(Vector2i) -> int` — as parameters 3 and 4.
##       A Callable is an integer/Variant built-in, not a Node or singleton, so §11.1 purity holds;
##       inventing a map type here would pre-empt §4.4 and force a rewrite. When GameState lands,
##       callers bind closures over it and `Los` itself never changes.
##   (I) ENDPOINT EXEMPTION. Only INTERIOR hexes (line indices 1..N-1) are tested. A Solid endpoint
##       does not block its own line — you can always see out of, and into, the hex you stand on or
##       look at. (The elevation half of the exemption is arithmetically vacuous under (J), since an
##       endpoint's own elevation can never exceed maxi of the two endpoints, but it is stated
##       explicitly so no later stage "fixes" it.)
##   (J) "EXCEEDS BOTH ENDPOINTS' ELEVATION" IS STRICT ">" AGAINST maxi(elev(a), elev(b)). Equal
##       elevation does NOT block. The cap is computed ONCE before the loop. An implementation
##       using ">=" fails exactly `test_elevation_equal_to_the_higher_endpoint_does_not_block`.
##   (K) DEGENERATE LINES ARE ALWAYS OPEN. distance == 0 (line [a]) and distance == 1 (line [a, b])
##       have zero interior hexes and are therefore unconditionally open regardless of terrain.
##       This is a CONSEQUENCE of (I), not a separate special case — an early return that could
##       drift from it is a defect even while it happens to agree.
##   (L) AN INVALID CALLABLE MEANS OPEN TERRAIN. If either Callable fails `is_valid()`,
##       `has_line_of_sight` returns true and `blocking_hexes` returns [] — a total function: no
##       crash, no engine error, no assert abort headless (the same spirit as M1-T1 resolution (B):
##       a bad argument must never tear down a 60-turn headless run). Off-map / unknown-hex
##       semantics are explicitly the CALLER's responsibility: `Los` knows no map bounds, calls the
##       Callables only for interior hexes, and imposes no elevation range check (§4.1's 0-3 is the
##       generator's contract, not Los's).
##
## §13.6 "constants read from data, not code" is VACUOUS here and deliberately so: the blocking
## predicate is ALGORITHM, not tunable content — the same data-vs-code line decisions.md M1-T1
## item 4 and M1-T2 item 12 drew for hex geometry. `data/ruleset.json` carries no LOS key and must
## not gain one. `Los` mutates no GameState and touches no EventBus, so "events emitted for every
## state change" likewise has no subject matter. Goldens: none re-recorded — none exist yet.
##
## TRAP (hit live in M0-T2, docs/decisions.md item 11 / M0-T5 item (a)): `x is Node` against a
## RefCounted-typed variable is a statically impossible cast that GDScript rejects at PARSE time;
## GUT then logs "Ignoring script ..." and the whole file silently vanishes from the run.
## Non-Node-ness is therefore asserted via get_class() ONLY, never with `is`.
##
## SCAN COVERAGE NOTE: `tests/unit/test_hex_math.gd`'s source scans cover `hex_math.gd` ONLY — a new
## file inherits nothing — so sections C1-C5 below re-run the equivalent five scans against
## `scripts/core/los.gd`.
extends GutTest

const LOS_PATH: String = "res://scripts/core/los.gd"

## §11.1 — tokens that would make the sim core engine-bound. Checked against source with comments
## stripped, so a doc comment quoting the rule is never a false failure.
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

## §4.1 map radii and their hex counts (§4.4: generator parameters live in data/mapgen/*.json).
## None of these numbers may appear in los.gd — LOS knows no map bounds (resolution (L)).
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public API of `Los` (§11.2 names it a separate core/ peer). Exactly these two, in
## any order, and nothing else — vision range, fog of war and Darkvision (§4.3/§4.7) belong to later
## milestones (§13.4: invent nothing ahead of its milestone).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"has_line_of_sight",
	"blocking_hexes",
]

## The §4.1 direction-0 (E) axis used by every hand-walked case: a straight run of distance 4 whose
## line involves no rounding at all, so the interior is unambiguous by hand. Re-derived below in
## `test_the_hand_walked_axis_has_the_expected_interior` against the already-pinned HexMath.line().
const AXIS_A: Vector2i = Vector2i(0, 0)
const AXIS_B: Vector2i = Vector2i(4, 0)

## Radii for the property sweeps. Terrain is populated out to FIXTURE_RADIUS so that every line
## between two swept hexes lands on populated ground; pairs are swept over SWEEP_RADIUS (61 hexes,
## 3,721 ordered pairs — the same template M1-T2's P4 sweep used).
const SWEEP_RADIUS: int = 4
const FIXTURE_RADIUS: int = 5

## Fixed, hand-chosen probe pairs for the monotonicity sweep (C: three long diagonals that the
## fixture already blocks, plus two genuinely-open runs so the sweep can observe a real true->false
## flip and is therefore not vacuous).
const MONOTONICITY_PAIRS: Array[Vector2i] = [
	Vector2i(-4, 0), Vector2i(4, 0),
	Vector2i(0, -4), Vector2i(0, 4),
	Vector2i(-4, 4), Vector2i(4, -4),
	Vector2i(-4, 0), Vector2i(-3, 3),
	Vector2i(-4, 0), Vector2i(-2, 1),
]

## A handful of hexes spread over all six sextants plus the origin — reused by the repeatability
## test, exactly as `test_hex_math.gd` does.
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

# ---------------------------------------------------------------------------------------------
# Terrain state backing the injected Callables (resolution (H)). Both dictionaries are FULLY
# POPULATED before any Callable is handed to `Los`, and no RNG is involved anywhere (§11.1).
# ---------------------------------------------------------------------------------------------

## Per-case terrain for the hand-walked section A cases.
var _case_solids: Dictionary = {}
var _case_elevations: Dictionary = {}

## The deterministic disc fixture used by the section B property sweeps.
var _fixture_solids: Dictionary = {}
var _fixture_elevations: Dictionary = {}

## The one extra Solid hex added on top of the fixture by the monotonicity sweep.
var _extra_solid: Vector2i = Vector2i(9999, 9999)


# =============================================================================================
# A. HAND-WALKED BLOCKING CASES (§4.1 line 172; resolutions (I)/(J)/(K)/(L))
#    All on the §4.1 direction-0 (E) axis (0,0) -> (4,0): distance 4, interior exactly
#    [(1,0), (2,0), (3,0)], no rounding involved.
# =============================================================================================

## Sanity anchor for the whole section: the axis interior is re-derived from the already-pinned
## `HexMath.line()` (§4.1 "standard hex line-drawing"), so every case below stands on a checked
## interior rather than on an assumption.
func test_the_hand_walked_axis_has_the_expected_interior() -> void:
	var path: Array[Vector2i] = HexMath.line(AXIS_A, AXIS_B)
	assert_eq(
		path,
		_axials([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]),
		"§4.1: the direction-0 axis (0,0)..(4,0) is a straight unrounded run"
	)
	assert_eq(HexMath.distance(AXIS_A, AXIS_B), 4, "§4.1: the axis spans cube distance 4")
	assert_eq(path.slice(1, path.size() - 1), _axials([
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)
	]), "§4.1: the interior of the axis is exactly three hexes")


## A1 — §4.2 "Solid hexes ... block movement, LOS, and light" + §4.1 "a line is blocked by any Solid
## hex". One Solid interior hex blocks, and it is the only reported blocker.
func test_a_solid_interior_hex_blocks_the_line() -> void:
	_assert_case(
		"A1",
		AXIS_A,
		AXIS_B,
		[Vector2i(2, 0)],
		{},
		false,
		_axials([Vector2i(2, 0)])
	)


## A2 — resolution (I), ENDPOINT EXEMPTION. Both endpoints Solid and nothing else: the line is OPEN.
## An implementation that scans indices 0..N instead of 1..N-1 fails exactly here.
func test_solid_endpoints_do_not_block_their_own_line() -> void:
	_assert_case(
		"A2",
		AXIS_A,
		AXIS_B,
		[Vector2i(0, 0), Vector2i(4, 0)],
		{},
		true,
		_axials([])
	)


## A3 — §4.1 "any hex whose elevation exceeds **both** endpoints' elevation". Both endpoints at
## elevation 1 and an interior hex at 2: 2 > maxi(1, 1) == 1, so it blocks.
func test_elevation_above_both_endpoints_blocks() -> void:
	_assert_case(
		"A3",
		AXIS_A,
		AXIS_B,
		[],
		{Vector2i(0, 0): 1, Vector2i(4, 0): 1, Vector2i(2, 0): 2},
		false,
		_axials([Vector2i(2, 0)])
	)


## A4 + A6 — resolution (J), the STRICT ">" reading of "exceeds", pinned twice.
## A4: raising ONE endpoint to 2 makes cap == maxi(2, 1) == 2, and 2 > 2 is false, so the same
## terrain that blocked in A3 is now open — the hex no longer exceeds **both** endpoints.
## A6: an all-elevation-3 line is open for the same reason (§4.1's legal range is 0-3; `Los`
## performs no range validation — it compares, it does not police).
## An implementation using ">=" fails exactly here.
func test_elevation_equal_to_the_higher_endpoint_does_not_block() -> void:
	_assert_case(
		"A4",
		AXIS_A,
		AXIS_B,
		[],
		{Vector2i(0, 0): 2, Vector2i(4, 0): 1, Vector2i(2, 0): 2},
		true,
		_axials([])
	)
	_assert_case(
		"A6",
		AXIS_A,
		AXIS_B,
		[],
		{Vector2i(0, 0): 3, Vector2i(4, 0): 3, Vector2i(2, 0): 3},
		true,
		_axials([])
	)


## A5 — multi-blocker ORDERING. Two interior hexes exceed the cap; `blocking_hexes` reports both in
## LINE ORDER, nearest to `a` first.
func test_multiple_blockers_are_reported_in_line_order() -> void:
	_assert_case(
		"A5",
		AXIS_A,
		AXIS_B,
		[],
		{Vector2i(2, 0): 1, Vector2i(3, 0): 3},
		false,
		_axials([Vector2i(2, 0), Vector2i(3, 0)])
	)


## A7 — §4.1 joins the two clauses with "or", never "and": a Solid hex blocks even when its own
## elevation is at or below the cap. Here (2,0) is Solid at elevation 0 while the cap is 3.
func test_the_solid_clause_is_independent_of_the_elevation_clause() -> void:
	_assert_case(
		"A7",
		AXIS_A,
		AXIS_B,
		[Vector2i(2, 0)],
		{Vector2i(0, 0): 3, Vector2i(4, 0): 3, Vector2i(2, 0): 0},
		false,
		_axials([Vector2i(2, 0)])
	)


## A8 + A9 — resolution (K), DEGENERATE LINES ARE ALWAYS OPEN. distance 0 (line == [a]) and
## distance 1 (line == [a, b]) have zero interior hexes, so the worst possible terrain — the far
## hex Solid AND at elevation 3 — cannot block.
func test_degenerate_and_adjacent_lines_are_always_open() -> void:
	_assert_case(
		"A8 (a == b)",
		AXIS_A,
		AXIS_A,
		[Vector2i(0, 0)],
		{Vector2i(0, 0): 3},
		true,
		_axials([])
	)
	assert_eq(
		HexMath.line(AXIS_A, AXIS_A).size(),
		1,
		"§4.1 (K): a degenerate line holds one hex, hence zero interior hexes"
	)
	_assert_case(
		"A9 (adjacent)",
		AXIS_A,
		Vector2i(1, 0),
		[Vector2i(1, 0)],
		{Vector2i(1, 0): 3},
		true,
		_axials([])
	)
	assert_eq(
		HexMath.line(AXIS_A, Vector2i(1, 0)).size(),
		2,
		"§4.1 (K): an adjacent line holds two hexes, hence zero interior hexes"
	)


## A10 — resolution (L), AN INVALID CALLABLE MEANS OPEN TERRAIN. The control case is genuinely
## blocked with both Callables valid; replacing either (or both) with an empty `Callable()` must
## yield an open line and an empty blocker list, with no crash and no assert abort headless.
func test_invalid_callables_mean_open_terrain() -> void:
	_load_case([Vector2i(2, 0)], {Vector2i(3, 0): 3})
	var solid: Callable = _case_is_solid
	var elevation: Callable = _case_elevation

	assert_false(
		Los.has_line_of_sight(AXIS_A, AXIS_B, solid, elevation),
		"control: with both Callables valid this terrain genuinely blocks"
	)

	var probes: Array[Array] = [
		["both invalid", Callable(), Callable()],
		["is_solid invalid", Callable(), elevation],
		["elevation invalid", solid, Callable()],
	]
	for probe: Array in probes:
		var label: String = str(probe[0])
		var probe_solid: Callable = probe[1]
		var probe_elevation: Callable = probe[2]
		assert_true(
			Los.has_line_of_sight(AXIS_A, AXIS_B, probe_solid, probe_elevation),
			"§13.4 (L): %s — an invalid Callable means open terrain" % [label]
		)
		assert_eq(
			Los.blocking_hexes(AXIS_A, AXIS_B, probe_solid, probe_elevation),
			_axials([]),
			"§13.4 (L): %s — blocking_hexes must be empty, not a crash" % [label]
		)


# =============================================================================================
# B. LOS PROPERTY TESTS (§14 M1 acceptance criterion "LOS property tests"; §13.2 tier 1)
#    Sweep template: the radius-4 disc (61 hexes, 3,721 ordered pairs), the same shape M1-T2's P4
#    sweep used. ONE fixed, deterministic, hand-built terrain fixture; no RNG anywhere (§11.1).
#    Violations are collected and asserted once, so a break reports its own coordinates instead of
#    drowning the run in thousands of assertions.
# =============================================================================================

## Sanity anchor for every sweep below: the fixture must actually contain Solid hexes, hexes at the
## §4.1 maximum elevation 3, and at least one hex that is BOTH — otherwise P2's "including Solid and
## elevation-3 hexes" would pass vacuously. Reference model (re-derived independently by the Tests
## stage): 61 hexes in the sweep disc, 5 Solid, 14 at elevation 3, (4,-3) both.
func test_the_terrain_fixture_is_not_degenerate() -> void:
	_build_fixture()
	var disc: Array[Vector2i] = _disc(SWEEP_RADIUS)
	assert_eq(disc.size(), 61, "sanity: the radius-4 disc holds 3*4*5+1 == 61 hexes")

	var solid_count: int = 0
	var peak_count: int = 0
	var both_count: int = 0
	for h: Vector2i in disc:
		var is_solid: bool = _fixture_is_solid(h)
		var e: int = _fixture_elevation(h)
		assert_between(e, 0, 3, "§4.1: fixture elevations are integer 0-3 (%s)" % [h])
		if is_solid:
			solid_count += 1
		if e == 3:
			peak_count += 1
		if is_solid and e == 3:
			both_count += 1

	assert_eq(solid_count, 5, "fixture: the sweep disc holds 5 Solid hexes")
	assert_eq(peak_count, 14, "fixture: the sweep disc holds 14 hexes at elevation 3")
	assert_eq(both_count, 1, "fixture: exactly one hex is both Solid and at elevation 3")
	assert_true(_fixture_is_solid(Vector2i(4, -3)), "fixture: (4,-3) is the Solid elevation-3 hex")
	assert_eq(_fixture_elevation(Vector2i(4, -3)), 3, "fixture: (4,-3) sits at elevation 3")
	assert_true(_fixture_is_solid(Vector2i(0, 0)), "fixture: the origin is Solid (P2 must survive it)")


## P1 SYMMETRY — §4.1 read together with resolutions (D) and (J): `line(a,b)` is exactly
## `reverse(line(b,a))` and the cap `maxi(elev(a), elev(b))` is symmetric, so line of sight is a
## SYMMETRIC relation. `blocking_hexes` is correspondingly the exact reverse. A float/epsilon line
## implementation, or an asymmetric cap (e.g. one that used only the viewer's elevation), breaks
## this immediately — which is precisely why it is pinned over all 3,721 ordered pairs.
func test_los_is_symmetric_over_the_radius_four_disc() -> void:
	_build_fixture()
	var is_solid: Callable = _fixture_is_solid
	var elevation: Callable = _fixture_elevation
	var disc: Array[Vector2i] = _disc(SWEEP_RADIUS)

	var pairs: int = 0
	var blocked: int = 0
	var predicate_breaks: Array[String] = []
	var reverse_breaks: Array[String] = []
	for a: Vector2i in disc:
		for b: Vector2i in disc:
			pairs += 1
			var forward: bool = Los.has_line_of_sight(a, b, is_solid, elevation)
			if not forward:
				blocked += 1
			if forward != Los.has_line_of_sight(b, a, is_solid, elevation):
				predicate_breaks.append("%s..%s" % [a, b])
			var back_blockers: Array[Vector2i] = Los.blocking_hexes(b, a, is_solid, elevation)
			back_blockers.reverse()
			if Los.blocking_hexes(a, b, is_solid, elevation) != back_blockers:
				reverse_breaks.append("%s..%s" % [a, b])

	assert_eq(pairs, 3721, "sanity: all 61x61 ordered pairs of the radius-4 disc were swept")
	assert_gt(blocked, 0, "sanity: the fixture blocks SOME pairs, so symmetry is not vacuous")
	assert_lt(blocked, pairs, "sanity: the fixture leaves SOME pairs open, so symmetry is not vacuous")
	assert_eq(
		predicate_breaks.size(),
		0,
		"P1 §4.1: has_line_of_sight(a,b) == has_line_of_sight(b,a); first breaks: %s" % [
			str(predicate_breaks.slice(0, 3))
		]
	)
	assert_eq(
		reverse_breaks.size(),
		0,
		"P1 §4.1 + (D): blocking_hexes(b,a) is the exact reverse of blocking_hexes(a,b); first breaks: %s" % [
			str(reverse_breaks.slice(0, 3))
		]
	)


## P2 REFLEXIVITY — resolution (K): a hex always sees itself, because `line(h, h)` is `[h]` and has
## zero interior hexes. This must hold for EVERY hex in the fixture, including the ones the fixture
## marks Solid and the ones at elevation 3 (pinned non-vacuous by
## `test_the_terrain_fixture_is_not_degenerate`).
func test_los_is_reflexive_even_on_solid_and_peak_hexes() -> void:
	_build_fixture()
	var is_solid: Callable = _fixture_is_solid
	var elevation: Callable = _fixture_elevation

	var breaks: Array[String] = []
	var checked: int = 0
	for h: Vector2i in _disc(SWEEP_RADIUS):
		checked += 1
		if not Los.has_line_of_sight(h, h, is_solid, elevation):
			breaks.append("%s (solid=%s, elev=%d)" % [h, _fixture_is_solid(h), _fixture_elevation(h)])
		if not Los.blocking_hexes(h, h, is_solid, elevation).is_empty():
			breaks.append("%s reported blockers on its own hex" % [h])

	assert_eq(checked, 61, "sanity: every hex of the radius-4 disc was checked")
	assert_eq(
		breaks.size(),
		0,
		"P2 §13.4 (K): every hex sees itself, Solid or not; first breaks: %s" % [str(breaks.slice(0, 3))]
	)


## P3 AN ALL-OPEN BOARD NEVER BLOCKS — §4.1: with no Solid hex anywhere and every elevation equal
## (0), neither clause of the rule can ever fire, so every one of the 3,721 ordered pairs has line
## of sight and an empty blocker list.
func test_an_all_open_board_never_blocks() -> void:
	var is_solid: Callable = _never_solid
	var elevation: Callable = _flat_ground
	var disc: Array[Vector2i] = _disc(SWEEP_RADIUS)

	var pairs: int = 0
	var breaks: Array[String] = []
	for a: Vector2i in disc:
		for b: Vector2i in disc:
			pairs += 1
			if not Los.has_line_of_sight(a, b, is_solid, elevation):
				breaks.append("%s..%s reported blocked" % [a, b])
			var blockers: Array[Vector2i] = Los.blocking_hexes(a, b, is_solid, elevation)
			if not blockers.is_empty():
				breaks.append("%s..%s reported blockers %s" % [a, b, blockers])

	assert_eq(pairs, 3721, "sanity: all 61x61 ordered pairs of the radius-4 disc were swept")
	assert_eq(
		breaks.size(),
		0,
		"P3 §4.1: an all-open board blocks nothing; first breaks: %s" % [str(breaks.slice(0, 3))]
	)


## P4 ADJACENCY IS ALWAYS OPEN — resolutions (I)/(K): `line(h, neighbour)` is `[h, neighbour]`, so
## there is no interior hex to block. Swept under the WORST-CASE fixture (every hex Solid, every
## hex at elevation 3) and over all six §4.1 directions, so it pins the endpoint exemption rather
## than the terrain.
func test_adjacent_hexes_always_see_each_other_even_on_worst_case_terrain() -> void:
	var is_solid: Callable = _always_solid
	var elevation: Callable = _peak_everywhere

	var checked: int = 0
	var breaks: Array[String] = []
	for h: Vector2i in _disc(SWEEP_RADIUS):
		for dir: int in range(6):
			checked += 1
			var n: Vector2i = HexMath.neighbor(h, dir)
			if not Los.has_line_of_sight(h, n, is_solid, elevation):
				breaks.append("%s -> %s (dir %d)" % [h, n, dir])
			if not Los.blocking_hexes(h, n, is_solid, elevation).is_empty():
				breaks.append("%s -> %s (dir %d) reported blockers" % [h, n, dir])

	assert_eq(checked, 366, "sanity: 61 hexes x 6 §4.1 directions were checked")
	assert_eq(
		breaks.size(),
		0,
		"P4 §13.4 (I)/(K): adjacent hexes always see each other; first breaks: %s" % [str(breaks.slice(0, 3))]
	)


## P5 PREDICATE / BLOCKERS AGREEMENT — the two public functions are two views of one rule:
## `has_line_of_sight(a,b) == blocking_hexes(a,b).is_empty()`, and every reported blocker is a
## member of `HexMath.line(a,b)` at an index strictly between 0 and N (never `a`, never `b`), in
## strictly increasing line-index order. Swept over all 3,721 ordered pairs of the fixture.
func test_predicate_and_blocker_list_agree_over_the_radius_four_disc() -> void:
	_build_fixture()
	var is_solid: Callable = _fixture_is_solid
	var elevation: Callable = _fixture_elevation
	var disc: Array[Vector2i] = _disc(SWEEP_RADIUS)

	var pairs: int = 0
	var solid_blocked: int = 0
	var elevation_only_blocked: int = 0
	var agreement_breaks: Array[String] = []
	var membership_breaks: Array[String] = []
	var order_breaks: Array[String] = []
	for a: Vector2i in disc:
		for b: Vector2i in disc:
			pairs += 1
			var blockers: Array[Vector2i] = Los.blocking_hexes(a, b, is_solid, elevation)
			if Los.has_line_of_sight(a, b, is_solid, elevation) != blockers.is_empty():
				agreement_breaks.append("%s..%s: predicate disagrees with %s" % [a, b, blockers])
			var path: Array[Vector2i] = HexMath.line(a, b)
			var last_index: int = 0
			var any_solid: bool = false
			for h: Vector2i in blockers:
				var index: int = path.find(h)
				if index <= 0 or index >= path.size() - 1:
					membership_breaks.append("%s..%s: %s sits at line index %d of %d" % [
						a, b, h, index, path.size() - 1
					])
				if index <= last_index:
					order_breaks.append("%s..%s: %s at index %d follows index %d" % [
						a, b, h, index, last_index
					])
				last_index = index
				if _fixture_is_solid(h):
					any_solid = true
			if not blockers.is_empty():
				if any_solid:
					solid_blocked += 1
				else:
					elevation_only_blocked += 1

	assert_eq(pairs, 3721, "sanity: all 61x61 ordered pairs of the radius-4 disc were swept")
	assert_gt(solid_blocked, 0, "sanity: the Solid clause fires somewhere in the sweep")
	assert_gt(elevation_only_blocked, 0, "sanity: the elevation clause fires ALONE somewhere in the sweep")
	assert_eq(
		agreement_breaks.size(),
		0,
		"P5 §4.1: has_line_of_sight == blocking_hexes().is_empty(); first breaks: %s" % [
			str(agreement_breaks.slice(0, 3))
		]
	)
	assert_eq(
		membership_breaks.size(),
		0,
		"P5 §13.4 (I): every blocker is an INTERIOR hex of HexMath.line(a,b); first breaks: %s" % [
			str(membership_breaks.slice(0, 3))
		]
	)
	assert_eq(
		order_breaks.size(),
		0,
		"P5 §4.1: blockers are reported in strictly increasing line order; first breaks: %s" % [
			str(order_breaks.slice(0, 3))
		]
	)


## P6 SOLIDITY MONOTONICITY — §4.2 "Solid hexes ... block ... LOS": marking ONE additional hex Solid
## can only REMOVE line of sight, never create it. Formally, `los(fixture + extra) implies
## los(fixture)`. Swept as five fixed pairs x each of the 61 disc hexes as the extra Solid. The
## sweep also counts genuine true->false flips (5 in the reference model) and asserts at least one,
## so a `Los` that ignored the Solid clause entirely could not pass it vacuously.
func test_adding_one_solid_hex_never_creates_line_of_sight() -> void:
	_build_fixture()
	var base_solid: Callable = _fixture_is_solid
	var boosted_solid: Callable = _fixture_is_solid_plus_extra
	var elevation: Callable = _fixture_elevation
	var disc: Array[Vector2i] = _disc(SWEEP_RADIUS)

	var checked: int = 0
	var flips: int = 0
	var breaks: Array[String] = []
	for i: int in range(0, MONOTONICITY_PAIRS.size(), 2):
		var a: Vector2i = MONOTONICITY_PAIRS[i]
		var b: Vector2i = MONOTONICITY_PAIRS[i + 1]
		var base: bool = Los.has_line_of_sight(a, b, base_solid, elevation)
		for extra: Vector2i in disc:
			checked += 1
			_extra_solid = extra
			var boosted: bool = Los.has_line_of_sight(a, b, boosted_solid, elevation)
			if boosted and not base:
				breaks.append("%s..%s: marking %s Solid CREATED line of sight" % [a, b, extra])
			if base and not boosted:
				flips += 1
	_extra_solid = Vector2i(9999, 9999)

	assert_eq(checked, 305, "sanity: 5 fixed pairs x 61 candidate Solid hexes were checked")
	assert_gt(flips, 0, "sanity: at least one extra Solid genuinely REMOVES line of sight")
	assert_eq(
		breaks.size(),
		0,
		"P6 §4.2: an extra Solid hex can only remove line of sight; first breaks: %s" % [
			str(breaks.slice(0, 3))
		]
	)


## P7 FRESH ARRAY PER CALL (§11.1) — the same contract `HexMath.neighbors/line/ring/hexes_in_range`
## already carry, and proven load-bearing there by a live mutation probe (decisions.md M1-T2 item 5).
## A `const`/`static` cached array is not deeply immutable in GDScript, so a shared return value
## lets one caller's mutation corrupt every later caller and every golden. Checked for a non-empty
## result AND for the empty result, since a cached "no blockers" array is the easy mistake.
func test_blocking_hexes_returns_a_fresh_array_each_call() -> void:
	_load_case([], {Vector2i(2, 0): 1, Vector2i(3, 0): 3})
	var solid: Callable = _case_is_solid
	var elevation: Callable = _case_elevation
	var expected: Array[Vector2i] = _axials([Vector2i(2, 0), Vector2i(3, 0)])
	_assert_fresh_pair(
		Los.blocking_hexes(AXIS_A, AXIS_B, solid, elevation),
		Los.blocking_hexes(AXIS_A, AXIS_B, solid, elevation),
		expected,
		"blocking_hexes((0,0),(4,0)) with two blockers"
	)
	assert_eq(
		Los.blocking_hexes(AXIS_A, AXIS_B, solid, elevation),
		expected,
		"§11.1: mutating a blocking_hexes() result must not corrupt later calls"
	)

	_load_case([], {})
	var open_solid: Callable = _case_is_solid
	var open_elevation: Callable = _case_elevation
	_assert_fresh_pair(
		Los.blocking_hexes(AXIS_A, AXIS_B, open_solid, open_elevation),
		Los.blocking_hexes(AXIS_A, AXIS_B, open_solid, open_elevation),
		_axials([]),
		"blocking_hexes((0,0),(4,0)) with no blockers"
	)
	assert_eq(
		Los.blocking_hexes(AXIS_A, AXIS_B, open_solid, open_elevation),
		_axials([]),
		"§11.1: mutating an EMPTY blocking_hexes() result must not corrupt later calls"
	)


## P8 REPEATABILITY (§11.1 "the core must run headless byte-identically") — calling each public
## function twice on identical inputs yields identical results. Compared run-against-run, so it pins
## the rule (no hidden state, no RNG, no wall clock, no Dictionary iteration order) rather than any
## particular value.
func test_los_calls_are_repeatable() -> void:
	_build_fixture()
	var is_solid: Callable = _fixture_is_solid
	var elevation: Callable = _fixture_elevation
	for a: Vector2i in SAMPLE_HEXES:
		for b: Vector2i in SAMPLE_HEXES:
			assert_eq(
				Los.has_line_of_sight(a, b, is_solid, elevation),
				Los.has_line_of_sight(a, b, is_solid, elevation),
				"§11.1: has_line_of_sight(%s, %s) is repeatable" % [a, b]
			)
			assert_eq(
				Los.blocking_hexes(a, b, is_solid, elevation),
				Los.blocking_hexes(a, b, is_solid, elevation),
				"§11.1: blocking_hexes(%s, %s) is repeatable" % [a, b]
			)


# =============================================================================================
# C. MECHANICAL SOURCE SCANS ON scripts/core/los.gd (§11.1, §11.2, §11.3, §13.6)
#    `test_hex_math.gd`'s scans cover hex_math.gd ONLY — a new file inherits nothing, so the five
#    scans are re-run here against los.gd.
# =============================================================================================

## C1 (S1) §11.1 "Determinism rules: ... no float accumulation in rules (integers + fixed percent
## math)". The whole predicate is Vector2i/Vector3i, maxi/absi and integer comparison, so the file
## must contain NO float literal and no `float` type at all. Comment stripping is load-bearing here:
## the doc comments contain "§4.1", which the `\.[0-9]` pattern would otherwise hit.
func test_source_contains_no_float_math() -> void:
	var code: String = _code_text(LOS_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LOS_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			LOS_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % LOS_PATH
	)


## C2 (S2) §11.1 "the core must run headless byte-identically": no Node, no Scene Tree, no engine
## singletons, no randi()/randf(), no wall-clock input. Scans the shipped source with comments
## stripped, so quoting the rule in a doc comment is never a false failure.
func test_source_is_engine_free() -> void:
	var code: String = _code_text(LOS_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LOS_PATH)
	for token: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(token),
			"§11.1: the sim core must be engine-free — %s contains %s" % [LOS_PATH, token]
		)


## C3 (S3) §4.4/§13.6 — the §4.1 map radii 24/32/40 and their hex counts are TUNABLE CONTENT and
## belong to data/mapgen/*.json. `Los` knows no map bounds at all (resolution (L): off-map semantics
## are the caller's responsibility), so none of those numbers may appear in it.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(LOS_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % LOS_PATH)
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
			LOS_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## C4 (S4) §11.3 "public rule functions documented with the GDD section they implement" — every
## public function in los.gd implements §4.1, so each must carry a doc-comment block naming it. The
## scan is also TIGHTENED the way M1-T2 item 11 tightened hex_math's: `has_line_of_sight` and
## `blocking_hexes` must EXIST as public functions (so a missing member fails the scan instead of
## passing vacuously) and the public surface must be EXACTLY those two — vision range, fog of war
## and Darkvision (§4.3/§4.7) belong to later milestones (§13.4).
func test_public_api_is_exactly_two_functions_citing_section_4_1() -> void:
	var lines: PackedStringArray = _raw_text(LOS_PATH).split("\n")
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

	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2/§4.1: %s must be a public function of %s" % [required, LOS_PATH]
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			LOS_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public rule function needs a '## §4.1' doc comment; missing on: %s" % [
			str(undocumented)
		]
	)
	assert_true(
		_code_text(LOS_PATH).contains("HexMath.line("),
		"§4.1: Los must DELEGATE line drawing to the already-pinned HexMath.line(), never re-implement it"
	)


## C5 (S5) §11.1 "pure GDScript RefCounted classes ... No Node, no Scene Tree" + §11.2 (core lives
## in scripts/core/, which lists `Los` as its own peer file). Non-Node-ness is asserted through
## get_class() — see the TRAP note in the header; `is Node` is a PARSE ERROR here, not a failure.
func test_los_is_a_pure_refcounted_in_scripts_core() -> void:
	assert_true(FileAccess.file_exists(LOS_PATH), "§11.2: Los lives at %s" % LOS_PATH)
	var instance: Los = Los.new()
	assert_eq(instance.get_class(), "RefCounted", "§11.1: Los must be a pure RefCounted")


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## Replaces the per-case terrain used by the section A hand-walked cases. Both dictionaries are
## fully populated BEFORE any Callable built on them is handed to `Los` (resolution (H)).
func _load_case(solids: Array, elevations: Dictionary) -> void:
	_case_solids.clear()
	_case_elevations.clear()
	for h: Vector2i in solids:
		_case_solids[h] = true
	for key: Vector2i in elevations:
		_case_elevations[key] = int(elevations[key])


## Runs one hand-walked case end to end: both public functions against the same injected terrain.
func _assert_case(
	label: String,
	a: Vector2i,
	b: Vector2i,
	solids: Array,
	elevations: Dictionary,
	expected_los: bool,
	expected_blockers: Array[Vector2i]
) -> void:
	_load_case(solids, elevations)
	var is_solid: Callable = _case_is_solid
	var elevation: Callable = _case_elevation
	assert_eq(
		Los.has_line_of_sight(a, b, is_solid, elevation),
		expected_los,
		"%s §4.1: has_line_of_sight(%s, %s) must be %s" % [label, a, b, expected_los]
	)
	assert_eq(
		Los.blocking_hexes(a, b, is_solid, elevation),
		expected_blockers,
		"%s §4.1: blocking_hexes(%s, %s) must be %s" % [label, a, b, expected_blockers]
	)


## Section A terrain query — Solid iff the case loaded it (resolution (H)).
func _case_is_solid(h: Vector2i) -> bool:
	return bool(_case_solids.get(h, false))


## Section A terrain query — elevation, defaulting to §4.1's floor of 0 (resolution (H)).
func _case_elevation(h: Vector2i) -> int:
	return int(_case_elevations.get(h, 0))


## Builds the section B disc fixture: one fixed, hand-chosen, RNG-free terrain, fully populated out
## to FIXTURE_RADIUS (so every line between two swept hexes lands on populated ground) BEFORE any
## Callable is created. Solidity and elevation are pure integer functions of (q, r); the elevation
## rule yields exactly §4.1's legal range 0-3.
func _build_fixture() -> void:
	_fixture_solids.clear()
	_fixture_elevations.clear()
	for h: Vector2i in _disc(FIXTURE_RADIUS):
		_fixture_solids[h] = posmod(h.x * 5 + h.y * 3, 11) == 0
		_fixture_elevations[h] = posmod(h.x * 2 + h.y * 7, 4)


## Fixture terrain query — anything outside the populated disc reads as open ground, which is a
## property of the FIXTURE, not of `Los` (resolution (L): off-map semantics are the caller's).
func _fixture_is_solid(h: Vector2i) -> bool:
	return bool(_fixture_solids.get(h, false))


## Fixture terrain query — elevation, defaulting to §4.1's floor of 0 outside the populated disc.
func _fixture_elevation(h: Vector2i) -> int:
	return int(_fixture_elevations.get(h, 0))


## The fixture plus exactly one extra Solid hex, for the P6 monotonicity sweep.
func _fixture_is_solid_plus_extra(h: Vector2i) -> bool:
	return h == _extra_solid or _fixture_is_solid(h)


## An entirely open board (P3): no Solid hex anywhere.
func _never_solid(_h: Vector2i) -> bool:
	return false


## An entirely flat board (P3): every hex at §4.1's minimum elevation 0.
func _flat_ground(_h: Vector2i) -> int:
	return 0


## The worst-case board (P4): every hex Solid.
func _always_solid(_h: Vector2i) -> bool:
	return true


## The worst-case board (P4): every hex at §4.1's maximum elevation 3.
func _peak_everywhere(_h: Vector2i) -> int:
	return 3


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


## Every hex within `radius` of the origin, built from the already-pinned §4.1 cube distance.
func _disc(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q: int in range(-radius, radius + 1):
		for r: int in range(-radius, radius + 1):
			var h: Vector2i = Vector2i(q, r)
			if HexMath.distance(Vector2i.ZERO, h) <= radius:
				out.append(h)
	return out


## §11.1 freshness contract: two calls with identical arguments must be two DISTINCT arrays, and
## element-assigning, appending to and finally clearing the first must leave the second untouched.
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
