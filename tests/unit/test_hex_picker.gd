## HexPicker — GDD §4.1 ("**Flat-top hexes, axial coordinates (q, r)**; cube coordinates for
## algorithms"; "**Elevation:** integer 0-3 per hex"), §1.2 ("Hex scale ~ 15-20 m (cosmetic
## only)"), §9.1 ("tap-select, drag-box multi-select (mobile-friendly hit targets)"), §10 ("Rock
## rendered as chunked MultiMeshInstance3D ... Target: Medium map at 60 fps ...; SDFGI off"),
## §11.1 (data -> Sim Core (engine-free) -> EventBus -> Renderer/UI; the sim never calls the
## renderer), §11.2 (`scripts/render/`), §11.3, §13.2 tier 1, §13.4, §13.6, §14 M1 ("hex
## picking" — the LAST M1 deliverable).
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §4.1 line 171: "**Flat-top hexes, axial coordinates (q, r)**; cube coordinates for
##                  algorithms. Distance = cube distance. Neighbor order (fixed, index 0-5): E,
##                  NE, NW, W, SW, SE."
##   §4.1 line 173: "**Elevation:** integer 0-3 per hex." — used here as a TEST FIXTURE and as
##                  the caller-supplied `top_elevation`, deliberately NOT as a code literal.
##   §1.2 line 41:  "Hex scale ~ 15-20 m (cosmetic only)."
##   §9.1 line 666: "Orbiting tactical camera (rotate 360 deg, tilt 15-80 deg, zoom 8-60 m);
##                  edge-pan + WASD; tap-select, drag-box multi-select (mobile-friendly hit
##                  targets)." — names tap-select but legislates NO picking geometry.
##   §10 line 680:  "Rock rendered as chunked MultiMeshInstance3D (per-instance custom data =
##                  type/tint); dirty-chunk rebuilds on dig. Target: Medium map at 60 fps on
##                  mid-range hardware; SDFGI off."
##   §14 line 1097: M1's deliverable list, ending in "hex picking".
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §4.1, §9.1, §1.2 or §10**, so the printed text governs unamended. The binding prior
## resolutions are **(V)/(W)/(X)/(Y)** (M1-T6), **(AA)-(AH)** (M1-T7), **(AI)-(AP)** (M1-T8),
## plus **(C)/(C2)** (M1-T2, the rounding) and **(H)/(L)** (M1-T3, injected Callables). Every
## expected value below is DERIVED from those; **no GDD cell moves.**
##
## The §13.4 resolutions this file pins continue M1-T8's lettering at **(AQ)** — keep it stable:
##   (AQ) THE PICK RULE. §9.1 names tap-select but prints no picking geometry, and elevation
##        (§4.1 line 173) makes "project onto y = 0" wrong on a bowl whose hexes sit at four
##        heights. Resolution: pick against the FLAT TOP PLANE OF EACH ELEVATION LEVEL, scanned
##        from `top_elevation` DOWN to 0; a level is accepted iff the hex under that plane's
##        intersection actually HAS that elevation. First acceptance wins; no acceptance is an
##        explicit "no hex" (an empty Array). Honest caveat: this is a TOP-FACE test, not a full
##        ray/prism intersection, so a ray grazing a tall column's SIDE can resolve to the hex
##        behind it — acceptable at greybox fidelity, revisitable when M4 selection needs more.
##   (AR) THE INVERSE FORMULA AND THE ROUNDING. Exact algebraic inverse of (W):
##            q_frac = world.x / (1.5 * R)
##            r_frac = world.z / (SQRT_3 * R) - 0.5 * q_frac
##        with `world.y` IGNORED. The fractional cube `Vector3i(nq, -(nq + nr), nr)` is scaled to
##        integers by the named const `PICK_SCALE` and handed to `HexMath.cube_round_scaled`,
##        REUSING (C)/(C2)'s round-half-up + largest-diff cascade (ties repair z) rather than
##        inventing a second rounding — the "never re-implement the line walk" precedent from
##        M1-T3. §4.1's 0-3 elevation range stays a CALLER parameter and a TEST fixture.
##   (AS) TOTALITY (the (B)/(L)/(AB) spirit — no crash, no engine error, no assert abort
##        headless). Unconfigured -> `pick` empty, `world_to_hex` Vector2i.ZERO;
##        `ray_plane_point` is pure geometry and stays layout-INDEPENDENT. `direction.y == 0.0`,
##        `t < 0`, or a zero-length direction -> no hit; `t == 0.0` IS a hit; the direction need
##        not be normalised; an INVALID `elevation_at` Callable -> a FLAT pick at y = 0 (the (L)
##        spirit: the picker compares, it does not police the map); `top_elevation < 0` clamps
##        to 0.
##   (AT) WHERE PICKING LIVES: a NEW pure `RefCounted` at `scripts/render/hex_picker.gd`, NOT a
##        method on `CameraRig` (whose public surface is exactly `errors` + 19 functions, and
##        whose scan fails on an EXTRA member) — and, more importantly, because a method needing
##        a live `Camera3D` is not sweepable headless, and M1-T6 **(Z)** means an untestable pick
##        is an unpinnable pick. `pick_from_screen` is the ONLY engine-coupled member.
##
## THE OPTIONAL §G BEHAVIOURAL SMOKE TEST WAS **DROPPED**, and this is the record of that call:
## measured this iteration on the pinned repo-local binary, a `Camera3D` added under the headless
## root reports `get_viewport() == null`, so `project_ray_origin`/`project_ray_normal` cannot be
## exercised headless at all (the M1-T6 **(Z)** family). `pick_from_screen` is therefore pinned by
## its null-camera guard (§G below) plus the REQUIRED-token scan (S5), exactly as (AT) allows.
## §13.4: never stall.
##
## §13.6 clauses that are VACUOUS here, stated rather than assumed: `HexPicker` mutates no
## `GameState`, constructs no `Command` and touches no `EventBus`, so "events emitted for every
## state change" has no subject matter. **No golden is re-recorded** —
## `tests/golden/mapgen_concentric_bowl_small_seed1337.json` (`content_hash 0xcad24923`) is
## untouched and nothing here can move it. `data/render/greybox.json` is **byte-untouched**
## (`tests/unit/test_hex_layout.gd` asserts it byte-for-byte); every retuning below happens in
## params TEXT, never in the shipped file.
##
## FLOAT PRECISION, measured this iteration: `Vector3` components are 32-bit floats in Godot 4
## (decisions.md M1-T8 **(AI)**) — a component of magnitude ~62 carries ~6.4e-7 of representation
## error — so every world-space comparison here uses a 1e-4 tolerance. Hex IDENTITY comparisons
## are exact `Vector2i` equality and need no tolerance at all: the nearest rounding boundary sits
## half a hex (~4.5 m) away from any centre.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via `get_class()` ONLY.
##
## HARNESS TRAP (decisions.md M1-T5 item 9, standing rule): `tools/run_tests.sh` greps the WHOLE
## run output for five diagnostic phrases. No failure message in this file may contain any of
## them — this file says "is MISSING".
##
## The source scans in §F are written FRESH for `scripts/render/hex_picker.gd` and inherit
## NOTHING from `test_hex_layout.gd`, `test_map_renderer.gd` or `test_camera_rig.gd`. Comment
## stripping is LOAD-BEARING: the doc block above quotes the very tokens being forbidden. The
## no-float scan is deliberately NOT applied — renderer geometry is not a §11.1 rule surface
## (M1-T6 **(Y)**).
extends GutTest

const PICKER_PATH: String = "res://scripts/render/hex_picker.gd"
const GREYBOX_PATH: String = "res://data/render/greybox.json"
const SOURCE: String = "greybox.json"

# ---------------------------------------------------------------------------------------------
# The shipped tunables and the geometry derived from them. Every derived decimal is re-checked
# in `test_the_pinned_geometry_is_re_derived_from_the_printed_gdd_text` (the M1-T1 item 3 /
# M1-T6 standing rule made executable): a typo below fails THERE, before any implementation is
# blamed for it.
# ---------------------------------------------------------------------------------------------

## Mathematical constant, transcribed independently of `hex_layout.gd` / `hex_picker.gd`.
const SQRT_3: float = 1.7320508075688772

const HEX_WIDTH_M: float = 18.0
const ELEVATION_STEP_M: float = 3.0

## (W) — circumradius, column pitch, row pitch and the half-row offset for the shipped width.
const CIRCUMRADIUS_M: float = 9.0
const COLUMN_STEP: float = 13.5
const ROW_STEP: float = 15.588457268119896
const HALF_ROW_STEP: float = 7.794228634059948

## (AI) — Vector3 components are 32-bit floats in Godot 4; ~6.4e-7 of error at magnitude 62.
const TOL_WORLD: float = 0.0001

## §4.1 line 173 — "Elevation: integer 0-3 per hex", a FIXTURE range and the caller's
## `top_elevation`, never a literal inside `hex_picker.gd`.
const MIN_ELEVATION: int = 0
const MAX_ELEVATION: int = 3

## decisions.md M1-T4 (O) — `HexMap.get_elevation`'s off-disc sentinel, reused as this suite's
## "there is no hex here" fixture value.
const OFF_MAP_ELEVATION: int = -1

## §A3 — the round-trip sweep: the radius-8 disc is 3*8*9 + 1 == 217 hexes, times four
## elevations == 868 cases.
const ROUND_TRIP_RADIUS: int = 8
const ROUND_TRIP_HEXES: int = 217

## §A4/§C — the smaller disc used for the nearest-centre sweep and the pick fixtures.
const FIXTURE_RADIUS: int = 4

## §A4 — fractions along a centre-to-centre segment. 0.50 is deliberately NOT pinned: an exact
## midpoint is a knife-edge tie whose answer is (C2)'s repair rule, not a picking property.
const NEAR_FRACTION: float = 0.45
const FAR_FRACTION: float = 0.55

## §C6 — repeat count for the determinism sweep.
const REPEAT_CALLS: int = 100

## §E1 — a retuned hex width (double the shipped one) and the geometry it implies.
const WIDE_HEX_WIDTH_M: float = 36.0
const WIDE_COLUMN_STEP: float = 27.0
const WIDE_HALF_ROW_STEP: float = 15.588457268119896

## §E2 — a retuned elevation step, and the slanted ray that separates the y = 6 and y = 10
## planes into two DIFFERENT hexes.
const TALL_ELEVATION_STEP_M: float = 5.0
const SLANT_ORIGIN: Vector3 = Vector3(0.0, 20.0, 0.0)
const SLANT_DIRECTION: Vector3 = Vector3(0.0, -1.0, 2.0)
const SLANT_AT_TEN: Vector3 = Vector3(0.0, 10.0, 20.0)
const SLANT_AT_SIX: Vector3 = Vector3(0.0, 6.0, 28.0)
const SLANT_HEX_AT_TEN: Vector2i = Vector2i(0, 1)

# ---------------------------------------------------------------------------------------------
# §C1 — THE SCAN-ORDER DISCRIMINATOR, hand-computed. Ray origin (0, 9, 0), direction (0, -1, 1),
# top_elevation 3, shipped tunables (elevation planes y = 0, 3, 6, 9):
#   level 3 -> (0, 9, 0) -> hex (0, 0)   level 2 -> (0, 6, 3) -> hex (0, 0)
#   level 1 -> (0, 3, 6) -> hex (0, 0)   level 0 -> (0, 0, 9) -> hex (0, 1)
# Cross-check of the level-0 arithmetic, independent of the implementation:
#   r_frac = 9 / 15.588457268119896 = 0.5773502691896257
#   cube numerators (0, -577350, 577350) at PICK_SCALE 1000000 -> cube_round_scaled -> (0, -1, 1)
#   -> axial (0, 1); hex (0,1)'s centre is (0, 0, 15.588457268119896), 6.588 m from the point,
#   against 9.0 m to hex (0,0)'s centre. Nearest-centre confirmed.
# ---------------------------------------------------------------------------------------------
const SCAN_ORIGIN: Vector3 = Vector3(0.0, 9.0, 0.0)
const SCAN_DIRECTION: Vector3 = Vector3(0.0, -1.0, 1.0)
const SCAN_GROUND_HEX: Vector2i = Vector2i(0, 1)
const SCAN_TOP_HEX: Vector2i = Vector2i(0, 0)

# ---------------------------------------------------------------------------------------------
# The canonical greybox params document, byte-for-byte the shipped one (asserted below). Every
# retuning in §E mutates THIS TEXT; `data/render/greybox.json` itself is never written.
# ---------------------------------------------------------------------------------------------
const GREYBOX_LINES: Array[String] = [
	'{',
	'  "id": "greybox",',
	'  "hex_width_m": 18,',
	'  "elevation_step_m": 3,',
	'  "chunk_hexes": 8',
	'}',
]

# ---------------------------------------------------------------------------------------------
# §F — source-scan vocabularies (§11.1, §11.2, §11.3, §13.6). Written FRESH for this file.
# ---------------------------------------------------------------------------------------------

## §11.1 — HexPicker is a pure [RefCounted]. `Camera3D` is the ONE engine type it may name
## (resolution (AT)); everything below stays forbidden. `queue_free(` is forbidden project-wide
## (the M1-T7 standing rule).
const ENGINE_BOUND_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"queue_free(",
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"Time.",
	"OS.",
]

## §11.1 — the MIRROR-IMAGE boundary: terrain reaches the picker ONLY through the injected
## `elevation_at` Callable (the M1-T3 (H) precedent), so no sim class may be named here and no
## sim state may be mutated. §13.4 additionally keeps selection/GameState/Command out of M1.
const SIM_BOUNDARY_TOKENS: Array[String] = [
	"HexMap",
	"MapGenerator",
	"Rng",
	"set_elevation(",
	"set_terrain_type(",
	"EventBus",
	"GameState",
	"Command",
]

## §4.1 line 174 — the radii and hex counts are content in `data/`, never engine code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## §13.6 — the layout tunables and the geometry derived from them arrive through HexLayout's
## accessors, so none of them may appear as a literal in the picker.
const LAYOUT_LITERAL_TOKENS: Array[String] = ["18", "13.5", "15.588"]

## §13.6/(AR)/(AT) — what the picker MUST contain: the shared rounding (never re-implemented,
## the M1-T3 "never re-implement the line walk" precedent), the two data accessors, the Los
## Callable idiom, the named algorithmic scale const, and the thin camera adapter's two calls.
const REQUIRED_TOKENS: Array[String] = [
	"HexMath.cube_round_scaled(",
	"HexMath.cube_to_axial(",
	"SQRT_3",
	"PICK_SCALE",
	"hex_width_m(",
	"elevation_step_m(",
	"elevation_at.call(",
	"is_valid()",
	"project_ray_origin(",
	"project_ray_normal(",
]

## The COMPLETE public function surface (§13.4: invent nothing ahead of its milestone — no
## selection state, no tap-select semantics, no drag-box, no overlay/compass/minimap).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"set_layout",
	"world_to_hex",
	"ray_plane_point",
	"pick",
	"pick_from_screen",
]

## Doc-comment sections accepted by the §11.3 scan for this file.
const DOC_SECTIONS: Array[String] = ["§4.1", "§9.1", "§10", "§11.2"]


# =============================================================================================
# A. THE INVERSE PLACEMENT — resolution (AR), the exact algebraic inverse of (W)
# =============================================================================================

## The mechanical re-derivation demanded by the M1-T1 item 3 / M1-T6 standing rule: every derived
## decimal pinned above is recomputed here from SQRT_3 and the shipped width alone, using nothing
## from `hex_picker.gd`.
func test_the_pinned_geometry_is_re_derived_from_the_printed_gdd_text() -> void:
	assert_almost_eq(SQRT_3 * SQRT_3, 3.0, TOL_WORLD, "sanity: SQRT_3 squared is 3")
	# (AR) says "exact algebraic inverse of (W)", which is only true while the picker inverts the
	# SAME geometry HexLayout places with. Both carry their own copy of the mathematical constant
	# (decisions.md M1-T5 item 7), so the copies must agree EXACTLY — measured live at Verify
	# (M1-T9 probes P13/P14), a 1% drift in the picker's copy moves no hex inside the radius-8
	# sweep and would otherwise land silently.
	assert_eq(
		HexPicker.SQRT_3,
		HexLayout.SQRT_3,
		"(AR): the picker must invert (W) with HexLayout's own SQRT_3, never a drifted copy"
	)
	assert_eq(
		HexPicker.SQRT_3,
		SQRT_3,
		"(AR): and both must equal the value transcribed independently in this suite"
	)
	assert_almost_eq(
		CIRCUMRADIUS_M, HEX_WIDTH_M / 2.0, TOL_WORLD, "(W): the circumradius is half the hex width"
	)
	assert_almost_eq(COLUMN_STEP, 1.5 * CIRCUMRADIUS_M, TOL_WORLD, "(W): column pitch is 1.5 * R")
	assert_almost_eq(ROW_STEP, SQRT_3 * CIRCUMRADIUS_M, TOL_WORLD, "(W): row pitch is SQRT_3 * R")
	assert_almost_eq(HALF_ROW_STEP, ROW_STEP / 2.0, TOL_WORLD, "(W): half-row offset is ROW_STEP/2")
	assert_almost_eq(
		WIDE_COLUMN_STEP,
		1.5 * (WIDE_HEX_WIDTH_M / 2.0),
		TOL_WORLD,
		"§E1: the retuned column pitch is 1.5 * (36/2)"
	)
	assert_almost_eq(
		WIDE_HALF_ROW_STEP,
		SQRT_3 * (WIDE_HEX_WIDTH_M / 2.0) * 0.5,
		TOL_WORLD,
		"§E1: the retuned half-row offset is SQRT_3 * 18 * 0.5"
	)
	assert_eq(
		HexMath.hexes_in_range(Vector2i.ZERO, ROUND_TRIP_RADIUS).size(),
		ROUND_TRIP_HEXES,
		"§A3: the radius-8 disc is 3*8*9 + 1 hexes"
	)
	assert_eq(
		HexMath.hex_count_for_radius(ROUND_TRIP_RADIUS),
		ROUND_TRIP_HEXES,
		"§4.1: HexMath's own count agrees with the sweep size"
	)
	assert_eq(
		MAX_ELEVATION - MIN_ELEVATION + 1, 4, "§4.1 line 173: elevation 0-3 is four levels"
	)

	# §C1's hand-computed level intersections, re-derived from the ray alone.
	var expected_z: Array[float] = [9.0, 6.0, 3.0, 0.0]
	var slips: Array[String] = []
	for elevation: int in range(MIN_ELEVATION, MAX_ELEVATION + 1):
		var plane_y: float = float(elevation) * ELEVATION_STEP_M
		var t: float = (plane_y - SCAN_ORIGIN.y) / SCAN_DIRECTION.y
		var point: Vector3 = SCAN_ORIGIN + SCAN_DIRECTION * t
		if absf(point.z - expected_z[elevation]) > TOL_WORLD:
			slips.append("level %d meets z=%f, expected %f" % [
				elevation, point.z, expected_z[elevation]
			])
	assert_eq(slips.size(), 0, "§C1: the hand-computed scan intersections; %s" % [str(slips)])
	assert_almost_eq(
		9.0 / ROW_STEP,
		0.5773502691896257,
		TOL_WORLD,
		"§C1: the level-0 r_frac quoted in this file's header"
	)


## (AR)/§4.1 — the world origin is hex (0, 0): the inverse's fixed point.
func test_world_to_hex_maps_the_world_origin_to_hex_zero() -> void:
	var picker: HexPicker = _picker()
	assert_eq(
		picker.world_to_hex(Vector3.ZERO),
		Vector2i.ZERO,
		"(AR): the world origin is hex (0, 0) — the inverse of (W)'s fixed point"
	)


## (AR)/(W) — the exact value M1-T6 (V) quotes verbatim for §4.1's index 0: hex (1, 0) sits at
## world (13.5, 0, 7.794228634059948). The inverse must return it.
func test_world_to_hex_recovers_the_resolution_w_neighbour_placement() -> void:
	var picker: HexPicker = _picker()
	assert_eq(
		picker.world_to_hex(Vector3(COLUMN_STEP, 0.0, HALF_ROW_STEP)),
		Vector2i(1, 0),
		"(V)/(W)/(AR): (13.5, 0, 7.794228634059948) is hex (1, 0)"
	)


## (AR) — THE CENTRAL PIN: `world_to_hex(hex_to_world(h, e)) == h` for all 217 hexes of the
## radius-8 disc at all four §4.1 elevations, 868 cases. That the sweep runs over EVERY elevation
## is what proves `world.y` is ignored by the inverse.
func test_world_to_hex_round_trips_every_hex_of_the_radius_eight_disc() -> void:
	var layout: HexLayout = _shipped_layout()
	var picker: HexPicker = HexPicker.new()
	picker.set_layout(layout)

	var hexes: Array[Vector2i] = HexMath.hexes_in_range(Vector2i.ZERO, ROUND_TRIP_RADIUS)
	assert_eq(hexes.size(), ROUND_TRIP_HEXES, "sanity: the sweep really covers the radius-8 disc")
	var broken: Array[String] = []
	var cases: int = 0
	for hex: Vector2i in hexes:
		for elevation: int in range(MIN_ELEVATION, MAX_ELEVATION + 1):
			cases += 1
			var world: Vector3 = layout.hex_to_world(hex, elevation)
			var recovered: Vector2i = picker.world_to_hex(world)
			if recovered != hex:
				broken.append("%s at elevation %d came back as %s" % [
					str(hex), elevation, str(recovered)
				])
	assert_eq(
		cases,
		ROUND_TRIP_HEXES * (MAX_ELEVATION - MIN_ELEVATION + 1),
		"sanity: all 868 round-trip cases were walked"
	)
	assert_eq(broken.size(), 0, "(AR): world_to_hex inverts (W) exactly, and IGNORES world.y; %s" % [
		str(broken.slice(0, 5))
	])


## (AR)/(C2) — NEAREST CENTRE: a point 45% of the way toward a neighbour still belongs to the
## hex it started in, and one 55% of the way belongs to the neighbour. The exact 0.50 midpoint is
## deliberately NOT pinned — that is a knife-edge tie answered by (C2)'s repair rule, not a
## picking property.
func test_a_point_nearer_one_centre_resolves_to_that_centre() -> void:
	var layout: HexLayout = _shipped_layout()
	var picker: HexPicker = HexPicker.new()
	picker.set_layout(layout)

	var near_slips: Array[String] = []
	var far_slips: Array[String] = []
	var cases: int = 0
	for hex: Vector2i in HexMath.hexes_in_range(Vector2i.ZERO, FIXTURE_RADIUS):
		var centre: Vector3 = layout.hex_to_world(hex, MIN_ELEVATION)
		for dir: int in range(HexMath.DIRECTIONS.size()):
			var other: Vector2i = HexMath.neighbor(hex, dir)
			var other_centre: Vector3 = layout.hex_to_world(other, MIN_ELEVATION)
			var span: Vector3 = other_centre - centre
			cases += 1
			if picker.world_to_hex(centre + span * NEAR_FRACTION) != hex:
				near_slips.append("%s -> dir %d at 0.45" % [str(hex), dir])
			if picker.world_to_hex(centre + span * FAR_FRACTION) != other:
				far_slips.append("%s -> dir %d at 0.55" % [str(hex), dir])
	assert_true(cases > 0, "sanity: the nearest-centre sweep really ran")
	assert_eq(near_slips.size(), 0, "(AR): 45%% of the way across still belongs to the source; %s" % [
		str(near_slips.slice(0, 5))
	])
	assert_eq(far_slips.size(), 0, "(AR): 55%% of the way across belongs to the neighbour; %s" % [
		str(far_slips.slice(0, 5))
	])


## (W) re-pinned from the picker's side: all six §4.1 neighbours sit at exactly one row pitch, so
## the geometry the inverse is inverting is the geometry M1-T6 shipped.
func test_all_six_neighbour_centres_sit_at_one_row_pitch() -> void:
	var layout: HexLayout = _shipped_layout()
	var centre: Vector3 = layout.hex_to_world(Vector2i.ZERO, MIN_ELEVATION)
	var wrong: Array[String] = []
	for dir: int in range(HexMath.DIRECTIONS.size()):
		var offset: Vector3 = layout.hex_to_world(
			HexMath.neighbor(Vector2i.ZERO, dir), MIN_ELEVATION
		) - centre
		if absf(offset.length() - ROW_STEP) > TOL_WORLD:
			wrong.append("dir %d is %f from the centre" % [dir, offset.length()])
	assert_eq(HexMath.DIRECTIONS.size(), 6, "sanity: §4.1 fixes six directions")
	assert_eq(wrong.size(), 0, "(W): every neighbour centre is one row pitch (%f) away; %s" % [
		ROW_STEP, str(wrong)
	])


# =============================================================================================
# B. THE RAY/PLANE INTERSECTOR — resolution (AS)
#    t = (plane_y - origin.y) / direction.y; a hit iff direction.y != 0.0 AND t >= 0.0.
# =============================================================================================

## (AS) — a straight-down ray over hex (1, 0) meets the ground plane exactly at that hex's centre.
func test_a_downward_ray_meets_the_ground_plane_at_the_hex_centre() -> void:
	var picker: HexPicker = _picker()
	var hits: Array[Vector3] = picker.ray_plane_point(
		Vector3(COLUMN_STEP, 100.0, HALF_ROW_STEP), Vector3.DOWN, 0.0
	)
	assert_eq(hits.size(), 1, "(AS): a forward ray meets the plane exactly once")
	if hits.size() == 1:
		assert_almost_eq(hits[0].x, COLUMN_STEP, TOL_WORLD, "(AS): the intersection keeps world.x")
		assert_almost_eq(hits[0].y, 0.0, TOL_WORLD, "(AS): the intersection lies ON the plane")
		assert_almost_eq(hits[0].z, HALF_ROW_STEP, TOL_WORLD, "(AS): the intersection keeps world.z")
		assert_eq(
			picker.world_to_hex(hits[0]),
			Vector2i(1, 0),
			"(AR)/(AS): the ground intersection resolves to hex (1, 0)"
		)


## (AS) — a ray PARALLEL to the plane never hits, for any plane, including one at its own height.
func test_a_ray_parallel_to_the_plane_never_hits() -> void:
	var picker: HexPicker = _picker()
	var planes: Array[float] = [0.0, 3.0, 9.0, -4.0]
	var wrong: Array[String] = []
	for plane_y: float in planes:
		if picker.ray_plane_point(Vector3(0.0, 9.0, 0.0), Vector3(1.0, 0.0, 0.0), plane_y).size() != 0:
			wrong.append("plane y=%f" % plane_y)
	assert_eq(wrong.size(), 0, "(AS): direction.y == 0 is never a hit, not even coplanar; %s" % [
		str(wrong)
	])


## (AS) — a ray pointing AWAY from the plane never hits: t < 0 is behind the eye.
func test_a_ray_pointing_away_from_the_plane_never_hits() -> void:
	var picker: HexPicker = _picker()
	assert_eq(
		picker.ray_plane_point(Vector3(0.0, 100.0, 0.0), Vector3.UP, 0.0).size(),
		0,
		"(AS): t < 0 is a backward hit and must be discarded"
	)


## (AS) — t == 0.0 IS a hit: an origin already on the plane picks the hex beneath itself.
func test_an_origin_already_on_the_plane_is_a_hit_at_t_zero() -> void:
	var picker: HexPicker = _picker()
	var origin: Vector3 = Vector3(0.0, 9.0, 0.0)
	var hits: Array[Vector3] = picker.ray_plane_point(origin, Vector3.DOWN, 9.0)
	assert_eq(hits.size(), 1, "(AS): t == 0 is a HIT, never discarded with the backward rays")
	if hits.size() == 1:
		assert_almost_eq(hits[0].distance_to(origin), 0.0, TOL_WORLD, "(AS): t == 0 is the origin")


## (AS) — the direction need NOT be normalised: scaling it cannot move the intersection.
func test_the_ray_direction_need_not_be_normalised() -> void:
	var picker: HexPicker = _picker()
	var origin: Vector3 = Vector3(COLUMN_STEP, 40.0, HALF_ROW_STEP)
	var unit: Array[Vector3] = picker.ray_plane_point(origin, Vector3(0.0, -1.0, 0.5), 0.0)
	var scaled: Array[Vector3] = picker.ray_plane_point(origin, Vector3(0.0, -7.0, 3.5), 0.0)
	assert_eq(unit.size(), 1, "sanity: the unscaled ray hits")
	assert_eq(scaled.size(), 1, "(AS): a scaled direction still hits")
	if unit.size() == 1 and scaled.size() == 1:
		assert_almost_eq(
			unit[0].distance_to(scaled[0]),
			0.0,
			TOL_WORLD,
			"(AS): scaling the direction by 7 cannot move the intersection"
		)


## (AS) — a zero-length direction is degenerate and never hits.
func test_a_zero_length_ray_never_hits() -> void:
	var picker: HexPicker = _picker()
	assert_eq(
		picker.ray_plane_point(Vector3(0.0, 9.0, 0.0), Vector3.ZERO, 0.0).size(),
		0,
		"(AS): a zero-length direction is not a ray"
	)


## §11.1 / M1-T2 trap 1, re-pinned in its fifth file — every returned Array is FRESH, so one
## caller's mutation can never corrupt the next call. The `is_same` IDENTITY check is the
## load-bearing half and matches `test_hex_math.gd`'s `_assert_fresh_pair` / `test_los.gd`'s P7
## precedent: a cache that CLEARS itself on entry survives the pollution check alone (measured live
## at Verify, M1-T9 probe P11) while still handing every caller the same aliased Array.
func test_ray_plane_point_returns_a_fresh_array_per_call() -> void:
	var picker: HexPicker = _picker()
	var origin: Vector3 = Vector3(0.0, 20.0, 0.0)
	var first: Array[Vector3] = picker.ray_plane_point(origin, Vector3.DOWN, 0.0)
	var twin: Array[Vector3] = picker.ray_plane_point(origin, Vector3.DOWN, 0.0)
	assert_false(
		is_same(first, twin),
		"§11.1: ray_plane_point must return a fresh array, not a shared/cached one"
	)
	assert_eq(first.size(), 1, "sanity: the control ray hits")
	first.clear()
	first.append(Vector3(999.0, 999.0, 999.0))
	var second: Array[Vector3] = picker.ray_plane_point(origin, Vector3.DOWN, 0.0)
	assert_eq(second.size(), 1, "M1-T2 trap 1: ray_plane_point returns a FRESH array per call")
	if second.size() == 1:
		assert_almost_eq(second[0].y, 0.0, TOL_WORLD, "M1-T2 trap 1: the fresh hit is unpolluted")
	assert_eq(twin.size(), 1, "M1-T2 trap 1: the earlier result survived both later calls intact")


# =============================================================================================
# C. THE LAYERED PICK — resolution (AQ)
#    Scan e from min(top_elevation, ...) DOWN to 0; accept iff int(elevation_at.call(hex)) == e.
# =============================================================================================

## (AQ) — THE SCAN-ORDER DISCRIMINATOR, and the pin that makes top-first load-bearing. ONE ray,
## TWO maps, TWO different answers. An ascending (bottom-first) scan returns (0, 1) in BOTH cases
## and therefore fails the second half of this test. See the hand-computed table in this file's
## constants block.
func test_the_pick_scans_elevation_levels_from_the_top_down() -> void:
	var picker: HexPicker = _picker()

	var flat: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	var on_the_floor: Array[Vector2i] = picker.pick(
		SCAN_ORIGIN,
		SCAN_DIRECTION,
		_table_elevation.bind(flat, OFF_MAP_ELEVATION),
		MAX_ELEVATION
	)
	assert_eq(
		on_the_floor,
		[SCAN_GROUND_HEX] as Array[Vector2i],
		"(AQ): with every hex at elevation 0 the ray falls through to the GROUND plane"
	)

	var terraced: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	terraced[SCAN_TOP_HEX] = MAX_ELEVATION
	var on_the_column: Array[Vector2i] = picker.pick(
		SCAN_ORIGIN,
		SCAN_DIRECTION,
		_table_elevation.bind(terraced, OFF_MAP_ELEVATION),
		MAX_ELEVATION
	)
	assert_eq(
		on_the_column,
		[SCAN_TOP_HEX] as Array[Vector2i],
		"(AQ): raising hex (0,0) to elevation 3 makes the TOP plane win — the scan is top-down"
	)

	assert_ne(
		on_the_floor,
		on_the_column,
		"(AQ): the same ray must answer differently on the two maps, or the scan order is unpinned"
	)


## (AQ) — a straight-down ray resolves the hex under it at whatever elevation that hex has: level
## 3 misses (nothing is that tall), level 2 matches.
func test_a_straight_down_ray_resolves_the_hex_at_its_own_elevation() -> void:
	var picker: HexPicker = _picker()
	var table: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	table[Vector2i(1, 0)] = 2
	assert_eq(
		picker.pick(
			Vector3(COLUMN_STEP, 50.0, HALF_ROW_STEP),
			Vector3.DOWN,
			_table_elevation.bind(table, OFF_MAP_ELEVATION),
			MAX_ELEVATION
		),
		[Vector2i(1, 0)] as Array[Vector2i],
		"(AQ): a hex at elevation 2 is accepted on the y = 6 plane, not on y = 9"
	)


## (AQ) — OFF MAP is an explicit "no hex": when the injected terrain reports HexMap's (O) off-disc
## sentinel everywhere, no level can ever match.
func test_an_off_map_ray_is_an_explicit_no_hex() -> void:
	var picker: HexPicker = _picker()
	var nowhere: Callable = _table_elevation.bind({}, OFF_MAP_ELEVATION)
	var rays: Array[Vector3] = [Vector3.DOWN, SCAN_DIRECTION, Vector3(0.3, -1.0, -0.7)]
	var wrong: Array[String] = []
	for direction: Vector3 in rays:
		if picker.pick(Vector3(0.0, 80.0, 0.0), direction, nowhere, MAX_ELEVATION).size() != 0:
			wrong.append(str(direction))
	assert_eq(wrong.size(), 0, "(AQ): an off-map hex is never picked; %s" % [str(wrong)])

	# A disc-bounded fixture plus a ray aimed far outside it is the same statement from the
	# other side: the terrain exists, the ray simply lands nowhere on it.
	var disc: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	assert_eq(
		picker.pick(
			Vector3(4000.0, 60.0, -4000.0),
			Vector3.DOWN,
			_table_elevation.bind(disc, OFF_MAP_ELEVATION),
			MAX_ELEVATION
		).size(),
		0,
		"(AQ): a ray landing outside the terrain the caller knows about picks nothing"
	)


## (AQ)/(AS) — the pick inherits every degenerate-ray rule from the intersector: parallel,
## backward and zero-length rays all pick nothing, even over perfectly good terrain.
func test_degenerate_rays_never_pick() -> void:
	var picker: HexPicker = _picker()
	var flat: Callable = _table_elevation.bind(
		_flat_table(FIXTURE_RADIUS, MIN_ELEVATION), OFF_MAP_ELEVATION
	)
	var probes: Array[Array] = [
		["parallel", Vector3(0.0, 40.0, 0.0), Vector3(1.0, 0.0, 0.0)],
		["backward", Vector3(0.0, 40.0, 0.0), Vector3.UP],
		["zero-length", Vector3(0.0, 40.0, 0.0), Vector3.ZERO],
	]
	for probe: Array in probes:
		var label: String = probe[0]
		var probe_origin: Vector3 = probe[1]
		var probe_direction: Vector3 = probe[2]
		assert_eq(
			picker.pick(probe_origin, probe_direction, flat, MAX_ELEVATION).size(),
			0,
			"(AS): a %s ray picks nothing" % label
		)


## (AQ) — "maybe" is an Array of 0 or 1 elements (the `Los.blocking_hexes` precedent), never a
## magic Vector2i sentinel, and every returned Array is FRESH (M1-T2 trap 1).
func test_pick_returns_a_fresh_array_of_at_most_one_hex() -> void:
	var picker: HexPicker = _picker()
	var flat: Callable = _table_elevation.bind(
		_flat_table(FIXTURE_RADIUS, MIN_ELEVATION), OFF_MAP_ELEVATION
	)
	var first: Array[Vector2i] = picker.pick(
		Vector3(0.0, 40.0, 0.0), Vector3.DOWN, flat, MAX_ELEVATION
	)
	var twin: Array[Vector2i] = picker.pick(
		Vector3(0.0, 40.0, 0.0), Vector3.DOWN, flat, MAX_ELEVATION
	)
	assert_false(
		is_same(first, twin),
		"§11.1: pick must return a fresh array, not a shared/cached one (the _assert_fresh_pair rule)"
	)
	assert_eq(first.size(), 1, "(AQ): a hit is exactly one hex, never more")
	first.append(Vector2i(77, 77))
	var second: Array[Vector2i] = picker.pick(
		Vector3(0.0, 40.0, 0.0), Vector3.DOWN, flat, MAX_ELEVATION
	)
	assert_eq(second.size(), 1, "M1-T2 trap 1: pick returns a FRESH array per call")
	if second.size() == 1:
		assert_eq(second[0], Vector2i.ZERO, "M1-T2 trap 1: the fresh answer is unpolluted")


## §11.1 — determinism: 100 identical calls agree, and two independently constructed but
## identical fixtures agree with each other. No RNG, no wall clock, no Dictionary order reaches
## an output.
func test_the_pick_is_deterministic_across_calls_and_across_identical_fixtures() -> void:
	var picker: HexPicker = _picker()
	var table: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	table[SCAN_TOP_HEX] = MAX_ELEVATION
	var elevation_at: Callable = _table_elevation.bind(table, OFF_MAP_ELEVATION)

	var reference: Array[Vector2i] = picker.pick(
		SCAN_ORIGIN, SCAN_DIRECTION, elevation_at, MAX_ELEVATION
	)
	var drifted: int = 0
	for _i: int in range(REPEAT_CALLS):
		if picker.pick(SCAN_ORIGIN, SCAN_DIRECTION, elevation_at, MAX_ELEVATION) != reference:
			drifted += 1
	assert_eq(drifted, 0, "§11.1: %d repeated picks must all agree" % REPEAT_CALLS)

	var twin_picker: HexPicker = _picker()
	var twin_table: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	twin_table[SCAN_TOP_HEX] = MAX_ELEVATION
	assert_eq(
		twin_picker.pick(
			SCAN_ORIGIN,
			SCAN_DIRECTION,
			_table_elevation.bind(twin_table, OFF_MAP_ELEVATION),
			MAX_ELEVATION
		),
		reference,
		"§11.1: an independently built but identical fixture gives the identical answer"
	)


# =============================================================================================
# D. TOTALITY — resolution (AS), the (B)/(L)/(AB) spirit: no crash, no engine error, no assert
#    abort headless.
# =============================================================================================

## (AS) — a picker that was never given a layout picks nothing and places every point at hex
## (0, 0); `ray_plane_point` is PURE GEOMETRY and stays layout-independent (the formula needs no
## layout at all).
func test_a_never_configured_picker_picks_nothing_but_still_intersects_planes() -> void:
	var picker: HexPicker = HexPicker.new()
	_assert_unconfigured(picker, "never set")
	var hits: Array[Vector3] = picker.ray_plane_point(Vector3(0.0, 10.0, 0.0), Vector3.DOWN, 0.0)
	assert_eq(hits.size(), 1, "(AS): ray_plane_point is pure geometry and needs no layout")
	if hits.size() == 1:
		assert_almost_eq(hits[0].y, 0.0, TOL_WORLD, "(AS): the layout-free intersection is on y = 0")


## (AS)/(Y) — a layout whose LOAD FAILED reports `hex_width_m() == 0.0` and must be treated
## exactly like a layout that was never set. A half-valid layout can never produce half-valid
## picking.
func test_a_layout_whose_load_failed_is_treated_as_unconfigured() -> void:
	var broken: HexLayout = HexLayout.new()
	assert_false(
		broken.load_params_text('{"id": "greybox"}', SOURCE),
		"sanity: a params document with no tunables must be rejected"
	)
	assert_eq(broken.hex_width_m(), 0.0, "(Y): a failed load leaves the layout UNCONFIGURED")
	var picker: HexPicker = HexPicker.new()
	picker.set_layout(broken)
	_assert_unconfigured(picker, "layout whose load failed")


## (AS) — `set_layout(null)` after a good layout returns the picker to unconfigured; stale
## geometry can never survive.
func test_set_layout_null_returns_the_picker_to_unconfigured() -> void:
	var picker: HexPicker = _picker()
	assert_eq(
		picker.world_to_hex(Vector3(COLUMN_STEP, 0.0, HALF_ROW_STEP)),
		Vector2i(1, 0),
		"sanity: the picker is configured first"
	)
	picker.set_layout(null)
	_assert_unconfigured(picker, "set_layout(null)")


## (AS)/(L) — an INVALID `elevation_at` Callable means a FLAT pick at y = 0. The picker compares;
## it does not police the map (the M1-T3 (L) spirit).
func test_an_invalid_elevation_callable_falls_back_to_a_flat_ground_pick() -> void:
	var picker: HexPicker = _picker()
	assert_eq(
		picker.pick(
			Vector3(COLUMN_STEP, 50.0, HALF_ROW_STEP), Vector3.DOWN, Callable(), MAX_ELEVATION
		),
		[Vector2i(1, 0)] as Array[Vector2i],
		"(L)/(AS): an invalid Callable picks flat at y = 0 rather than refusing outright"
	)
	assert_eq(
		picker.pick(Vector3(0.0, 50.0, 0.0), Vector3.UP, Callable(), MAX_ELEVATION).size(),
		0,
		"(L)/(AS): the flat fallback still obeys the ray rules — a backward ray hits nothing"
	)


## (AS) — `top_elevation < 0` clamps to 0, so ONLY the ground plane is scanned, and that scan is
## still gated by `elevation_at == 0`. Both halves are asserted: clamping to 0 is not the same as
## scanning nothing.
func test_a_negative_top_elevation_scans_only_the_ground_plane() -> void:
	var picker: HexPicker = _picker()
	var origin: Vector3 = Vector3(COLUMN_STEP, 50.0, HALF_ROW_STEP)

	var raised: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	raised[Vector2i(1, 0)] = 2
	assert_eq(
		picker.pick(
			origin, Vector3.DOWN, _table_elevation.bind(raised, OFF_MAP_ELEVATION), -1
		).size(),
		0,
		"(AS): clamped to level 0, a hex standing at elevation 2 is not accepted"
	)

	var flat: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	assert_eq(
		picker.pick(origin, Vector3.DOWN, _table_elevation.bind(flat, OFF_MAP_ELEVATION), -1),
		[Vector2i(1, 0)] as Array[Vector2i],
		"(AS): the ground plane IS still scanned after the clamp"
	)


## (AS) — a `top_elevation` far above any real elevation is harmless: the extra planes simply
## never match, and the answer is unchanged.
func test_a_top_elevation_above_every_real_elevation_is_harmless() -> void:
	var picker: HexPicker = _picker()
	var table: Dictionary = _flat_table(FIXTURE_RADIUS, MIN_ELEVATION)
	table[Vector2i(1, 0)] = 1
	var elevation_at: Callable = _table_elevation.bind(table, OFF_MAP_ELEVATION)
	var origin: Vector3 = Vector3(COLUMN_STEP, 100.0, HALF_ROW_STEP)
	var tall: Array[Vector2i] = picker.pick(origin, Vector3.DOWN, elevation_at, 9)
	assert_eq(
		tall,
		[Vector2i(1, 0)] as Array[Vector2i],
		"(AS): planes above every real elevation never match, so the answer is unchanged"
	)
	assert_eq(
		tall,
		picker.pick(origin, Vector3.DOWN, elevation_at, MAX_ELEVATION),
		"(AS): top_elevation 9 and top_elevation 3 agree on a map whose tallest hex is 1"
	)


# =============================================================================================
# E. THE TUNABLES ARE READ FROM DATA (§13.6) — proven BY MUTATION, the (AM)/(Y) precedent, never
#    by a token scan alone. `data/render/greybox.json` stays BYTE-UNTOUCHED: every retuning below
#    happens in params TEXT.
# =============================================================================================

## §13.6/§1.2 — the canonical in-file fixture really is the shipped document, so every mutation
## below is "the shipped file plus exactly one retuned value".
func test_the_canonical_fixture_matches_the_shipped_greybox_file() -> void:
	assert_eq(
		_shipped_greybox_text().replace("\r\n", "\n").strip_edges(),
		_greybox_text(HEX_WIDTH_M, ELEVATION_STEP_M).strip_edges(),
		"the in-file fixture must equal the shipped %s byte for byte" % GREYBOX_PATH
	)


## §13.6/§1.2 — `hex_width_m` genuinely drives the INVERSE. At width 36 (R = 18) the point
## (27, 0, 15.588457268119896) is hex (1, 0)'s own centre; under the shipped width 18 the very
## same point is NOT hex (1, 0). No 18 / 9.0 / 13.5 / 15.588... literal can shadow the data.
func test_hex_width_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var wide_layout: HexLayout = _layout_from(WIDE_HEX_WIDTH_M, ELEVATION_STEP_M)
	var probe: Vector3 = Vector3(WIDE_COLUMN_STEP, 0.0, WIDE_HALF_ROW_STEP)
	var centre: Vector3 = wide_layout.hex_to_world(Vector2i(1, 0), MIN_ELEVATION)
	assert_almost_eq(
		centre.distance_to(probe),
		0.0,
		TOL_WORLD,
		"sanity: at width 36 the probe point IS hex (1,0)'s centre"
	)

	var wide_picker: HexPicker = HexPicker.new()
	wide_picker.set_layout(wide_layout)
	assert_eq(
		wide_picker.world_to_hex(probe),
		Vector2i(1, 0),
		"§13.6: the inverse follows hex_width_m from the document"
	)
	assert_ne(
		_picker().world_to_hex(probe),
		Vector2i(1, 0),
		"§13.6: under the shipped width 18 the same point is a DIFFERENT hex"
	)


## §13.6/§4.1 — `elevation_step_m` genuinely drives which PLANE the pick matches on. The slanted
## ray's y = 10 and y = 6 intersections land on two different hexes, so retuning the step from 3
## to 5 moves the accepted level from y = 6 to y = 10 and the answer changes.
func test_elevation_step_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var shipped_picker: HexPicker = _picker()
	assert_eq(
		shipped_picker.world_to_hex(SLANT_AT_TEN),
		SLANT_HEX_AT_TEN,
		"§E2: the y = 10 intersection of the slanted ray is hex (0, 1)"
	)
	assert_ne(
		shipped_picker.world_to_hex(SLANT_AT_SIX),
		SLANT_HEX_AT_TEN,
		"§E2: the y = 6 intersection is a DIFFERENT hex — that is what makes this a discriminator"
	)

	var table: Dictionary = {}
	table[SLANT_HEX_AT_TEN] = 2
	var elevation_at: Callable = _table_elevation.bind(table, MIN_ELEVATION)

	var tall_picker: HexPicker = HexPicker.new()
	tall_picker.set_layout(_layout_from(HEX_WIDTH_M, TALL_ELEVATION_STEP_M))
	assert_eq(
		tall_picker.pick(SLANT_ORIGIN, SLANT_DIRECTION, elevation_at, MAX_ELEVATION),
		[SLANT_HEX_AT_TEN] as Array[Vector2i],
		"§13.6: at step 5 the elevation-2 plane is y = 10 and the raised hex is accepted"
	)
	assert_ne(
		shipped_picker.pick(SLANT_ORIGIN, SLANT_DIRECTION, elevation_at, MAX_ELEVATION),
		[SLANT_HEX_AT_TEN] as Array[Vector2i],
		"§13.6: at the shipped step 3 the elevation-2 plane is y = 6 and the answer differs"
	)


# =============================================================================================
# F. MECHANICAL SOURCE SCANS ON scripts/render/hex_picker.gd — written FRESH for this file; a new
#    file inherits nothing. Comment stripping is LOAD-BEARING: the doc block quotes the very
#    tokens being forbidden.
# =============================================================================================

## S1 §11.1/(AT) — the picker holds no engine state. `Camera3D` is the ONE engine type it may
## name; no Node, no SceneTree, no singleton, no wall clock, no frame time, no RNG.
func test_source_is_engine_free_apart_from_the_camera_adapter() -> void:
	var code: String = _code_text(PICKER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PICKER_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the picker holds no engine state — %s contains %s" % [PICKER_PATH, banned]
		)
	assert_true(
		code.contains("Camera3D"),
		"(AT): pick_from_screen is the ONE engine-coupled member and must name Camera3D"
	)


## S2 §11.1/(H) — the MIRROR-IMAGE boundary: terrain reaches the picker ONLY through the injected
## `elevation_at` Callable, so binding a closure over a real map at M4 needs zero change here.
## §13.4 keeps GameState/Command/EventBus out of M1 entirely.
func test_source_never_names_a_sim_class_or_a_later_milestones_system() -> void:
	var code: String = _code_text(PICKER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PICKER_PATH)
	for banned: String in SIM_BOUNDARY_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/§13.4: the picker names no sim class — %s contains %s" % [PICKER_PATH, banned]
		)


## S3 §4.1 line 174 / §13.6 — map sizes are content in `data/`, never engine code.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(PICKER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PICKER_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"),
		OK,
		"sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(hit, "§4.1/§13.6: map sizes are content — %s must not hard-code %s" % [
		PICKER_PATH, "" if hit == null else hit.get_string()
	])
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S4 §13.6 — the layout tunables and everything derived from them arrive through HexLayout's
## accessors. `18`, `13.5` and `15.588…` may not appear as literals; floats in general are fine
## here (renderer geometry is not a §11.1 rule surface, M1-T6 (Y)), so the sim suites' no-float
## scan is deliberately NOT copied.
func test_source_carries_no_layout_content_literal() -> void:
	var code: String = _code_text(PICKER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PICKER_PATH)
	var literal: RegEx = RegEx.new()
	assert_eq(
		literal.compile("(?<![0-9A-Za-z_.])(18(?![0-9A-Za-z_.])|13\\.5|15\\.588)"),
		OK,
		"sanity: the layout-literal pattern compiles"
	)
	var hit: RegExMatch = literal.search(code)
	assert_null(
		hit,
		"§13.6: hex geometry comes from %s via HexLayout — %s must not hard-code %s" % [
			GREYBOX_PATH, PICKER_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(LAYOUT_LITERAL_TOKENS.size(), 3, "sanity: all three shadowing literals are covered")


## S5 (AR)/(AT) — what the picker MUST contain. The rounding is NEVER re-implemented (the M1-T3
## "never re-implement the line walk" precedent): `HexMath.cube_round_scaled` is required present
## by name, as are the two HexLayout accessors, the Los Callable idiom, the named PICK_SCALE
## const and the camera adapter's two projection calls.
func test_source_reuses_the_shared_rounding_and_the_layout_accessors() -> void:
	var code: String = _code_text(PICKER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PICKER_PATH)
	for required: String in REQUIRED_TOKENS:
		assert_true(
			code.contains(required),
			"(AR)/(AT): %s is MISSING the required token %s" % [PICKER_PATH, required]
		)


## S6 §13.4/§11.3 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (selection state, a drag-box helper, a second
## loader, an overlay hook) fails too. The picker loads no data, so it has NO public vars — it
## must not grow an `errors` field or a second RulesError-shaped loader.
func test_public_api_is_exactly_the_five_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(PICKER_PATH, public_functions, undocumented)

	var picker: HexPicker = HexPicker.new()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, PICKER_PATH]
		)
		assert_true(
			picker.has_method(required),
			"§11.2: %s must be callable on a HexPicker instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			PICKER_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); absent on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(PICKER_PATH),
		[] as Array[String],
		"§13.4: the picker loads no data, so its public FIELD surface is empty"
	)


## S7 §11.1/§11.2 — HexPicker is a pure [RefCounted] living in `scripts/render/`, §11.2's own
## directory for the renderer classes. Asserted through get_class() — `is Node` is a PARSE ERROR
## here (M0-T2 item 11 / M0-T5 item (a)).
func test_hex_picker_is_a_pure_refcounted_in_scripts_render() -> void:
	assert_true(FileAccess.file_exists(PICKER_PATH), "§11.2: HexPicker lives at %s" % PICKER_PATH)
	var instance: HexPicker = HexPicker.new()
	assert_eq(instance.get_class(), "RefCounted", "§11.1: HexPicker must be a pure RefCounted")


## S8 §13.4 — no second loader and no second rounding helper. The picker reads no document, so
## `RulesError` has no business here (it is allowed in renderer files, M1-T6 (Y), but only for
## files that actually load one); and every occurrence of `cube_round` must be the shared
## `HexMath.cube_round_scaled`.
func test_source_declares_no_second_loader_or_rounding_helper() -> void:
	var code: String = _code_text(PICKER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PICKER_PATH)
	assert_false(
		code.contains("RulesError"),
		"§13.4: %s loads no document and must not carry a second loader" % PICKER_PATH
	)
	assert_eq(
		code.count("cube_round"),
		code.count("HexMath.cube_round_scaled"),
		"(AR): every `cube_round` in %s must be the shared HexMath.cube_round_scaled" % PICKER_PATH
	)


# =============================================================================================
# G. pick_from_screen — the thin delegating adapter (resolution (AT)).
#    The behavioural smoke test was DROPPED: measured this iteration, a Camera3D under the
#    headless root reports `get_viewport() == null`, so project_ray_origin/project_ray_normal
#    cannot be exercised headless at all (the M1-T6 (Z) family). What remains is the null-camera
#    guard below plus S5's REQUIRED-token scan. §13.4: never stall.
# =============================================================================================

## (AT)/(AS) — no camera is an explicit "no hex", never a crash and never a phantom pick.
func test_pick_from_screen_with_no_camera_is_an_explicit_no_hex() -> void:
	var picker: HexPicker = _picker()
	var flat: Callable = _table_elevation.bind(
		_flat_table(FIXTURE_RADIUS, MIN_ELEVATION), OFF_MAP_ELEVATION
	)
	assert_eq(
		picker.pick_from_screen(null, Vector2(320.0, 240.0), flat, MAX_ELEVATION).size(),
		0,
		"(AT): a null camera picks nothing"
	)
	var bare: HexPicker = HexPicker.new()
	assert_eq(
		bare.pick_from_screen(null, Vector2.ZERO, Callable(), MAX_ELEVATION).size(),
		0,
		"(AT)/(AS): an unconfigured picker with a null camera is still total"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A picker configured from the SHIPPED content file, so every geometry assertion above is a
## content-drives-code proof rather than a test-fixture proof.
func _picker() -> HexPicker:
	var picker: HexPicker = HexPicker.new()
	picker.set_layout(_shipped_layout())
	return picker


## The shipped greybox params, loaded through HexLayout.
func _shipped_layout() -> HexLayout:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_file(GREYBOX_PATH)
	assert_true(ok, "§13.6: %s must load" % GREYBOX_PATH)
	return layout


## A layout configured from RETUNED params TEXT — `data/render/greybox.json` is never written.
func _layout_from(hex_width: float, elevation_step: float) -> HexLayout:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_text(_greybox_text(hex_width, elevation_step), SOURCE)
	assert_true(ok, "§13.6: the retuned params must load")
	return layout


## The canonical greybox document with the two metre tunables substituted. `chunk_hexes` never
## moves: the picker does not chunk.
func _greybox_text(hex_width: float, elevation_step: float) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in GREYBOX_LINES:
		if line.strip_edges().begins_with('"hex_width_m":'):
			lines.append('  "hex_width_m": %s,' % _number_text(hex_width))
		elif line.strip_edges().begins_with('"elevation_step_m":'):
			lines.append('  "elevation_step_m": %s,' % _number_text(elevation_step))
		else:
			lines.append(line)
	return "\n".join(lines)


## Renders a tunable the way `data/render/greybox.json` writes it: an integral value with no
## decimal point, so the canonical fixture is byte-identical to the shipped file.
func _number_text(value: float) -> String:
	if absf(value - floorf(value)) < TOL_WORLD:
		return str(int(value))
	return str(value)


## The shipped content file, read verbatim.
func _shipped_greybox_text() -> String:
	var file: FileAccess = FileAccess.open(GREYBOX_PATH, FileAccess.READ)
	assert_not_null(file, "§13.6: %s must be readable" % GREYBOX_PATH)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## A terrain fixture: every hex of the disc at one elevation. Off-disc hexes fall through to the
## bound fallback (decisions.md M1-T4 (O)'s `-1` sentinel, or 0 where an open plain is wanted).
func _flat_table(radius: int, elevation: int) -> Dictionary:
	var table: Dictionary = {}
	for hex: Vector2i in HexMath.hexes_in_range(Vector2i.ZERO, radius):
		table[hex] = elevation
	return table


## The injected terrain [Callable] (the M1-T3 (H) shape): bound with a table and a fallback, it
## is called by the picker as `elevation_at.call(hex)`.
func _table_elevation(hex: Vector2i, table: Dictionary, fallback: int) -> int:
	return int(table.get(hex, fallback))


## (AS) — the UNCONFIGURED contract: no pick, and every point resolves to hex (0, 0), so a
## rejected or absent layout can never produce half-valid picking.
func _assert_unconfigured(picker: HexPicker, label: String) -> void:
	var flat: Callable = _table_elevation.bind(
		_flat_table(FIXTURE_RADIUS, MIN_ELEVATION), OFF_MAP_ELEVATION
	)
	assert_eq(
		picker.pick(Vector3(0.0, 40.0, 0.0), Vector3.DOWN, flat, MAX_ELEVATION).size(),
		0,
		"(AS) [%s]: an unconfigured picker picks nothing" % label
	)
	assert_eq(
		picker.pick(SCAN_ORIGIN, SCAN_DIRECTION, Callable(), MAX_ELEVATION).size(),
		0,
		"(AS) [%s]: not even the flat fallback fires without a layout" % label
	)
	assert_eq(
		picker.world_to_hex(Vector3(COLUMN_STEP, 0.0, HALF_ROW_STEP)),
		Vector2i.ZERO,
		"(AS) [%s]: an unconfigured picker resolves every point to hex (0, 0)" % label
	)


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
