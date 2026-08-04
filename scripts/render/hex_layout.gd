## HexLayout — GDD §4.1 ("**Flat-top hexes, axial coordinates (q, r)**"; "Elevation: integer 0-3
## per hex"), §1.2 ("Hex scale ~ 15-20 m (cosmetic only)"), §10 ("Rock rendered as chunked
## MultiMeshInstance3D (per-instance custom data = type/tint); dirty-chunk rebuilds on dig"),
## §11.1 (the layered boundary: data -> Sim Core -> EventBus -> Renderer/UI, and THE SIM NEVER
## CALLS THE RENDERER), §11.2 (`scripts/render/` — MapRenderer, UnitView, LightOverlay,
## CameraRig), §11.3, §13.2, §13.6.
##
## RENDERER SLICE 1 of §14 M1's "chunked MultiMesh renderer": the pure, headless-testable half —
## WHAT to draw and WHERE. This class is a plain [RefCounted] that knows only [Vector2i] and
## [Vector3]; it holds no Node, builds no mesh and creates no MultiMesh. The Node half
## (MapRenderer: one MultiMeshInstance3D per chunk, per-instance transforms and custom data,
## dirty-chunk rebuilds, `scenes/Main.tscn`) is M1-T7, the camera rig M1-T8 and hex picking
## M1-T9 (§13.4: invent nothing ahead of its milestone).
##
## WHY THE PURE HALF EXISTS AT ALL: measured on the pinned repo-local Godot 4.7 console binary,
## the headless dummy renderer DOES NOT STORE MultiMesh instance data — `set_instance_transform`
## followed by `get_instance_transform` returns the identity, `set_instance_custom_data` reads
## back as (0,0,0,1) and `MultiMesh.buffer` is empty even with a non-zero `instance_count`. No
## headless test can therefore ever verify per-instance placement by reading a MultiMesh back, so
## the placement math must live here, returning plain values.
##
## BOUNDARY (§11.1, binding): this file names NO sim class — not HexMap, not MapGenerator, not
## Rng — and mutates no sim state (no set_elevation, no set_terrain_type). It operates on an
## `Array[Vector2i]` handed to it by its caller, which is what keeps it decoupled and fully
## unit-testable; M1-T7's MapRenderer is the one that will read the map. `RulesError` is the
## project's shared line-numbered error value type (used by RulesLoader and MapGenerator) and is
## reused here rather than inventing a second one (§13.4, simplest interpretation).
##
## The three tunables — `hex_width_m`, `elevation_step_m`, `chunk_hexes` — are CONTENT and live in
## `data/render/greybox.json` (§13.6 "constants read from data, not code"). SQRT_3 is a
## MATHEMATICAL constant and correctly lives here as a `const`, the same precedent as HexMap's FNV
## constants (decisions.md M1-T5 item 7) — do not "fix" that as a §13.6 violation.
##
## Resolutions (logged in docs/decisions.md, continuing M1-T5's lettering at (V)):
##   (V) FLAT-TOP is the renderer's screen orientation — §4.1's bolded "Flat-top hexes" is the
##       only orientation the GDD states. Direction NAMES stay pure index labels (M1-T1 (A));
##       no sim value moves.
##   (W) LAYOUT FORMULA/UNITS/ORIGIN — XZ ground plane, +Y up, hex (0,0) at the world origin.
##       With circumradius R = hex_width_m / 2: world.x = 1.5*R*q, world.z = SQRT_3*R*(r+0.5*q),
##       world.y = elevation * elevation_step_m.
##   (X) CHUNK PARTITION — axial squares of `chunk_hexes` edge, TRUE floor division, keys sorted
##       ascending chunk-r then chunk-q (HexMap's (O) canonical order); partition returns index
##       buckets parallel to chunk_keys, each in input order.
##   (Y) LOAD CONTRACT — mirrors MapGenerator's resolution (P) exactly, reusing RulesError.
class_name HexLayout
extends RefCounted

## Ratio of a flat-top hex's centre-to-centre row spacing to its circumradius. A mathematical
## constant (decisions.md M1-T5 item 7 precedent), not tunable content, so it lives here rather
## than in data/render/greybox.json.
const SQRT_3: float = 1.7320508075688772

## The three required greybox keys, walked in THIS declared order — error order therefore follows
## the loader's own spec table, never the parsed Dictionary's key order (§11.1).
const SPEC_KEYS: PackedStringArray = ["hex_width_m", "elevation_step_m", "chunk_hexes"]

## Parallel to [constant SPEC_KEYS]: true where the leaf must be an integral value (chunk_hexes);
## false for the two float-metre leaves.
const SPEC_IS_INT: Array[bool] = [false, false, true]

## Every failure of the last params load, earliest-first. Empty on success.
var errors: Array[RulesError] = []

var _configured: bool = false
var _hex_width_m: float = 0.0
var _elevation_step_m: float = 0.0
var _chunk_hexes: int = 0


## §10 — validates a greybox params document (hex_width_m / elevation_step_m / chunk_hexes) and,
## on success, configures this layout. ANY error (resolution (Y)) leaves the layout UNCONFIGURED,
## including a failed load that follows a successful one.
func load_params_text(text: String, _source: String) -> bool:
	errors = []
	_clear_configuration()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(text)
	if parse_result != OK:
		var syntax_error: RulesError = RulesError.new()
		syntax_error.line = json.get_error_line() + 1
		syntax_error.path = ""
		var syntax_message: String = json.get_error_message()
		syntax_error.message = (
			syntax_message if not syntax_message.is_empty() else "greybox params JSON syntax error"
		)
		errors.append(syntax_error)
		return false

	var data: Variant = json.data
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	if not (data is Dictionary):
		var root_error: RulesError = RulesError.new()
		root_error.line = 1
		root_error.path = ""
		root_error.message = "greybox params root must be a JSON object"
		errors.append(root_error)
		return false

	var root: Dictionary = data as Dictionary
	var values: Array[float] = []
	for i: int in range(SPEC_KEYS.size()):
		var key: String = SPEC_KEYS[i]
		values.append(0.0)
		if not root.has(key):
			_add_error(key, lines, "greybox params is MISSING required key \"%s\"" % key)
			continue
		var raw: Variant = root[key]
		if not (raw is float or raw is int):
			_add_error(key, lines, "\"%s\" must be a number" % key)
			continue
		if SPEC_IS_INT[i] and not _is_integral(raw):
			_add_error(key, lines, "\"%s\" must be a whole number" % key)
			continue
		var value: float = _as_float(raw)
		if value <= 0.0:
			_add_error(key, lines, "\"%s\" must be strictly positive" % key)
			continue
		values[i] = value

	if not errors.is_empty():
		return false

	_hex_width_m = values[0]
	_elevation_step_m = values[1]
	_chunk_hexes = int(values[2])
	_configured = true
	return true


## §10 — reads `path` and delegates to [method load_params_text]. A missing or unreadable file is
## exactly one error attributed to the reserved line 0 (M0-T2 item 2).
func load_params_file(path: String) -> bool:
	errors = []
	_clear_configuration()

	if not FileAccess.file_exists(path):
		var missing_error: RulesError = RulesError.new()
		missing_error.line = 0
		missing_error.path = ""
		missing_error.message = "greybox params file is MISSING: %s" % path
		errors.append(missing_error)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: RulesError = RulesError.new()
		open_error.line = 0
		open_error.path = ""
		open_error.message = "failed to open greybox params file: %s" % path
		errors.append(open_error)
		return false

	var text: String = file.get_as_text()
	file.close()
	return load_params_text(text, path)


## §1.2 — corner-to-corner width of one flat-top hex, in metres; 0.0 when unconfigured.
func hex_width_m() -> float:
	return _hex_width_m


## §4.1 — world-space height of one elevation step, in metres; 0.0 when unconfigured.
func elevation_step_m() -> float:
	return _elevation_step_m


## §10 — edge length, in hexes, of one square MultiMesh chunk; 0 when unconfigured.
func chunk_hexes() -> int:
	return _chunk_hexes


## §4.1 — world position of axial hex `hex` at `elevation`, flat-top oriented (resolution (V)) on
## the XZ ground plane with +Y up; hex (0, 0) at elevation 0 sits at the world origin. Returns
## Vector3.ZERO when unconfigured.
func hex_to_world(hex: Vector2i, elevation: int) -> Vector3:
	if not _configured:
		return Vector3.ZERO
	var circumradius: float = _hex_width_m / 2.0
	var world_x: float = 1.5 * circumradius * float(hex.x)
	var world_z: float = SQRT_3 * circumradius * (float(hex.y) + 0.5 * float(hex.x))
	var world_y: float = float(elevation) * _elevation_step_m
	return Vector3(world_x, world_y, world_z)


## §10 — the axial-square chunk coordinate that owns `hex`, by TRUE floor division of the
## configured chunk edge (resolution (X)). Returns Vector2i.ZERO when unconfigured.
func chunk_of(hex: Vector2i) -> Vector2i:
	if not _configured:
		return Vector2i.ZERO
	return Vector2i(_floor_div(hex.x, _chunk_hexes), _floor_div(hex.y, _chunk_hexes))


## §10 — the distinct chunk coordinates covering `hexes`, sorted ascending by chunk-r then
## chunk-q (decisions.md M1-T4 (O)'s ordering). Empty when unconfigured or `hexes` is empty.
func chunk_keys(hexes: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _configured:
		return out
	var seen: Dictionary = {}
	for hex: Vector2i in hexes:
		var key: Vector2i = chunk_of(hex)
		if not seen.has(key):
			seen[key] = true
			out.append(key)
	out.sort_custom(_chunk_less)
	return out


## §10 — index buckets into `hexes`, parallel to [method chunk_keys], each bucket in input order.
## Empty when unconfigured or `hexes` is empty.
func partition(hexes: Array[Vector2i]) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if not _configured:
		return out
	var keys: Array[Vector2i] = chunk_keys(hexes)
	var slot: Dictionary = {}
	for i: int in range(keys.size()):
		slot[keys[i]] = i
		out.append(PackedInt32Array())
	for i: int in range(hexes.size()):
		var key: Vector2i = chunk_of(hexes[i])
		if not slot.has(key):
			continue
		var at: int = slot[key]
		var bucket: PackedInt32Array = out[at]
		bucket.append(i)
		out[at] = bucket
	return out


# -------------------------------------------------------------------------------------------
# Internal
# -------------------------------------------------------------------------------------------

## Resets this layout to UNCONFIGURED, so a failed load never leaves stale params behind (mirrors
## MapGenerator's `_clear_configuration`).
func _clear_configuration() -> void:
	_configured = false
	_hex_width_m = 0.0
	_elevation_step_m = 0.0
	_chunk_hexes = 0


## Resolution (X)'s ordering predicate: ascending chunk-r (y), then ascending chunk-q (x).
func _chunk_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## TRUE floor division. GDScript's `/` truncates toward zero, so a naive `n / d` would merge the
## four chunks around the origin (the M1-T2 trap-2 family) — guarded here explicitly.
func _floor_div(n: int, d: int) -> int:
	if d == 0:
		return 0
	@warning_ignore("integer_division")
	var quotient: int = n / d
	if n % d != 0 and (n < 0) != (d < 0):
		quotient -= 1
	return quotient


## Appends one [RulesError] attributed to the first line carrying the top-level key's own JSON
## token, falling back to line 1 (resolution (Y)).
func _add_error(key: String, lines: PackedStringArray, message: String) -> void:
	var err: RulesError = RulesError.new()
	err.path = key
	err.message = message
	err.line = _line_for_key(lines, key)
	errors.append(err)


## 1-based line of the first line containing `"<key>"`, or 1 if no line carries it. Line 0 stays
## reserved exclusively for missing/unreadable files (M0-T2 item 2).
func _line_for_key(lines: PackedStringArray, key: String) -> int:
	var token: String = "\"%s\"" % key
	for i: int in range(lines.size()):
		if lines[i].contains(token):
			return i + 1
	return 1


## True for an [int] or a fractionless [float] — Godot's JSON parser hands every number back as
## TYPE_FLOAT, so "is this an int" must mean "is this integral", never "is this literally typed
## int" (decisions.md M0-T2 item 8).
func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var as_float: float = value
		return as_float == floor(as_float)
	return false


## Converts a value already known to be a number ([int] or [float]) into a [float].
func _as_float(value: Variant) -> float:
	if value is int:
		var as_int: int = value
		return float(as_int)
	if value is float:
		var as_float: float = value
		return as_float
	return 0.0
