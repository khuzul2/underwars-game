## HexPicker — GDD §4.1 ("**Flat-top hexes, axial coordinates (q, r)**; cube coordinates for
## algorithms"; "Elevation: integer 0-3 per hex"), §9.1 ("tap-select, drag-box multi-select
## (mobile-friendly hit targets)" — only the PICKING half; selection state is M4/M8), §10
## ("Greybox first ... Rock rendered as chunked MultiMeshInstance3D"), §11.1 (data -> Sim Core
## (engine-free) -> EventBus -> Renderer/UI; the sim never calls the renderer), §11.2
## (`scripts/render/`), §11.3, §13.2 tier 1, §13.4, §13.6, §14 M1 ("hex picking").
##
## The LAST §14 M1 deliverable: the inverse of HexLayout's (W) `hex_to_world`, a ray/plane
## intersector, the elevation-layered pick, and one thin Camera3D screen-point adapter. A pure
## [RefCounted]: it holds no Node, subscribes to no EventBus and names no sim class — terrain
## arrives ONLY through the injected `elevation_at` [Callable] (the M1-T3 (H) precedent), so
## binding a closure over a real map at M4 needs zero change here.
##
## Resolutions (docs/decisions.md, continuing M1-T8's lettering at (AQ)):
##   (AQ) THE PICK RULE — pick against the FLAT TOP PLANE OF EACH ELEVATION LEVEL, scanned from
##        `top_elevation` DOWN to 0; a level is accepted iff the hex under that plane's
##        intersection actually has that elevation. First acceptance wins; no acceptance is an
##        explicit "no hex" (an empty Array). Exact for the greybox's flat prism tops; it is a
##        top-face test, NOT a full ray/prism intersection.
##   (AR) THE INVERSE FORMULA AND THE ROUNDING — `q_frac = world.x / (1.5 * R)`,
##        `r_frac = world.z / (SQRT_3 * R) - 0.5 * q_frac`, with `world.y` IGNORED. The
##        fractional cube is scaled to integers by PICK_SCALE and handed to
##        `HexMath.cube_round_scaled`, REUSING (C)/(C2)'s round-half-up + largest-diff cascade
##        rather than inventing a second rounding. §4.1's 0-3 elevation range stays a CALLER
##        parameter (`top_elevation`), never a literal here.
##   (AS) TOTALITY — unconfigured (null layout, or one whose load failed) -> `pick` empty and
##        `world_to_hex` Vector2i.ZERO; `ray_plane_point` is pure geometry and stays
##        layout-independent. `direction.y == 0.0`, `t < 0` or a zero-length ray -> no hit;
##        `t == 0.0` IS a hit; the direction need not be normalised; an INVALID `elevation_at`
##        -> a FLAT pick at y = 0 (the M1-T3 (L) spirit: the picker compares, it does not police
##        the map); `top_elevation < 0` clamps to 0. No crash, no engine error, no assert abort.
##   (AT) WHERE PICKING LIVES — a new pure [RefCounted] in `scripts/render/` rather than a method
##        on CameraRig (whose public surface is exactly `errors` + 19 functions), because a method
##        needing a live Camera3D is not sweepable headless and M1-T6 (Z) makes an untestable pick
##        an unpinnable pick. `pick_from_screen` is the ONLY engine-coupled member and is thin and
##        delegating, like CameraRig's input layer.
class_name HexPicker
extends RefCounted

## Ratio of a flat-top hex's centre-to-centre row spacing to its circumradius — the same
## mathematical constant `HexLayout` carries (decisions.md M1-T5 item 7 precedent), needed here to
## invert (W) without re-deriving it from data at call time.
const SQRT_3: float = 1.7320508075688772

## (AR) — algorithmic scale factor the fractional cube coordinate is multiplied by before handing
## it to [method HexMath.cube_round_scaled], the same precedent as SQRT_3/RADIAL_SEGMENTS/
## DEGREES_PER_TURN/FNV (decisions.md M1-T5 item 7): not §13.6 content, just rounding precision.
const PICK_SCALE: int = 1000000

## The layout supplying `hex_width_m()` and `elevation_step_m()`; null until [method set_layout].
var _layout: HexLayout = null


## §9.1 — binds the [HexLayout] whose (W) placement this picker inverts. Passing `null` (or a
## layout whose load failed) returns the picker to its unconfigured state (resolution (AS)).
func set_layout(layout: HexLayout) -> void:
	_layout = layout


## §4.1 — the axial hex whose centre is nearest `world`, ignoring `world.y` (resolution (AR)), the
## exact algebraic inverse of `HexLayout.hex_to_world`'s (W) placement. Vector2i.ZERO when
## unconfigured.
func world_to_hex(world: Vector3) -> Vector2i:
	if not _is_configured():
		return Vector2i.ZERO
	var circumradius: float = _layout.hex_width_m() / 2.0
	var q_frac: float = world.x / (1.5 * circumradius)
	var r_frac: float = world.z / (SQRT_3 * circumradius) - 0.5 * q_frac
	var nq: int = roundi(q_frac * float(PICK_SCALE))
	var nr: int = roundi(r_frac * float(PICK_SCALE))
	var numerators: Vector3i = Vector3i(nq, -(nq + nr), nr)
	return HexMath.cube_to_axial(HexMath.cube_round_scaled(numerators, PICK_SCALE))


## §10 — the single intersection of the ray with the horizontal plane `y = plane_y`, as an Array
## of 0 or 1 points; empty means "no forward hit" (resolution (AS)). Pure geometry — needs no
## [HexLayout] and works even on an unconfigured picker.
func ray_plane_point(ray_origin: Vector3, ray_direction: Vector3, plane_y: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if ray_direction.y == 0.0:
		return out
	var t: float = (plane_y - ray_origin.y) / ray_direction.y
	if t < 0.0:
		return out
	out.append(ray_origin + ray_direction * t)
	return out


## §9.1 — the elevation-layered pick (resolution (AQ)): scans elevation levels from
## `top_elevation` (clamped to >= 0) down to 0 and returns the first hex whose own elevation
## (via `elevation_at`) matches the level its plane was hit on, as an Array of 0 or 1 hexes. Empty
## is an explicit "no hex". An unconfigured picker always picks nothing (resolution (AS)); an
## INVALID `elevation_at` falls back to a single flat pick at y = 0 (the M1-T3 (L) spirit — the
## picker compares, it does not police the map).
func pick(
	ray_origin: Vector3,
	ray_direction: Vector3,
	elevation_at: Callable,
	top_elevation: int
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _is_configured():
		return out

	if not elevation_at.is_valid():
		var flat_hit: Array[Vector3] = ray_plane_point(ray_origin, ray_direction, 0.0)
		if flat_hit.is_empty():
			return out
		out.append(world_to_hex(flat_hit[0]))
		return out

	var step: float = _layout.elevation_step_m()
	var top: int = maxi(top_elevation, 0)
	for level: int in range(top, -1, -1):
		var plane_y: float = float(level) * step
		var level_hit: Array[Vector3] = ray_plane_point(ray_origin, ray_direction, plane_y)
		if level_hit.is_empty():
			continue
		var hex: Vector2i = world_to_hex(level_hit[0])
		if int(elevation_at.call(hex)) == level:
			out.append(hex)
			return out
	return out


## §9.1 — the thin Camera3D adapter (resolution (AT)): projects `screen_point` into a world ray
## via `project_ray_origin`/`project_ray_normal` and delegates to [method pick]. A null camera is
## an explicit "no hex", never a crash.
func pick_from_screen(
	camera: Camera3D,
	screen_point: Vector2,
	elevation_at: Callable,
	top_elevation: int
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if camera == null:
		return out
	return pick(
		camera.project_ray_origin(screen_point),
		camera.project_ray_normal(screen_point),
		elevation_at,
		top_elevation
	)


# -------------------------------------------------------------------------------------------
# Internal
# -------------------------------------------------------------------------------------------

## Resolution (AS) — a picker is usable only with a layout that actually loaded; an unconfigured
## HexLayout reports a zero hex width.
func _is_configured() -> bool:
	return _layout != null and _layout.hex_width_m() > 0.0
