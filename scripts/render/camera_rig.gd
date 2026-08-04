## CameraRig — GDD §9.1 ("Orbiting tactical camera (rotate 360°, tilt 15-80°, zoom 8-60 m);
## edge-pan + WASD; tap-select, drag-box multi-select (mobile-friendly hit targets)"), §10
## ("Greybox first ... Rock rendered as chunked MultiMeshInstance3D ... Target: Medium map at
## 60 fps on mid-range hardware; SDFGI off"), §11.1 (data -> Sim Core (engine-free) -> EventBus
## -> Renderer/UI; the sim never calls the renderer), §11.2 (`scripts/render/` — MapRenderer,
## UnitView, LightOverlay, CameraRig), §11.3, §13.2 tier 1, §13.4, §13.6, §14 M1 ("camera rig").
##
## The Node half of §14 M1's camera-rig deliverable: an orbiting/tilting/dollying/panning rig
## that derives a Camera3D transform from four data-loaded limits plus three data-loaded speeds
## and an edge-pan margin. Hex picking (M1-T9), tap-select/drag-box multi-select (§9.1, but
## selection itself is M4/M8), overlays/north-compass/minimap (§9.1, M8) and any EventBus
## subscription are DELIBERATELY ABSENT (§13.4: invent nothing ahead of its milestone).
##
## Resolutions (docs/decisions.md, continuing M1-T7's lettering at (AH)):
##   (AI) CAMERA FRAME AND DERIVED TRANSFORM — world +Y up, ground = XZ (HexLayout's (W)), hex
##        (0,0) at the world origin. `yaw` rotates about +Y; yaw 0 puts the camera on the +Z side
##        of the focus looking toward -Z. With P = pitch, Y = yaw in radians:
##        `origin = focus + zoom * Vector3(cos(P)*sin(Y), sin(P), cos(P)*cos(Y))`, oriented by
##        `looking_at(focus, Vector3.UP)` (Godot puts -Z forward, so `basis.z` is the unit vector
##        from the focus toward the camera; no roll; distance to the focus is exactly the zoom).
##   (AJ) YAW WRAPS into [0, 360) (never clamps — "rotate 360°" is unbounded); PITCH and ZOOM
##        CLAMP inclusively to the data limits. A successful load frames the WIDEST LEGAL VIEW —
##        yaw 0, pitch at its data maximum, zoom at its data maximum, focus at the world origin —
##        the only initial state derivable from data alone (there is deliberately no absolute
##        setter). `DEGREES_PER_TURN` may be a named const (the SQRT_3/RADIAL_SEGMENTS/FNV
##        precedent, decisions.md M1-T5 item 7); the four §9.1 limits and the three speeds may
##        NOT — they are content in `data/render/camera.json`.
##   (AK) PAN is camera-relative and stays on the ground plane: `pan(right_m, forward_m)`
##        translates the FOCUS only, by `right_m * right(yaw) + forward_m * forward(yaw)` where
##        `right(yaw) = (cos yaw, 0, -sin yaw)` and `forward(yaw) = (-sin yaw, 0, -cos yaw)` —
##        both unit, orthogonal, horizontal, and equal to the camera's own `basis.x` and the
##        ground projection of `-basis.z`. `focus_point().y` never changes.
##   (AL) LOAD CONTRACT mirrors MapGenerator's (P), HexLayout's (Y) and MapRenderer's (AF)
##        exactly and REUSES RulesError (§13.4, simplest reading — RulesError is explicitly
##        allowed in renderer files, M1-T6 (Y)). Line 0 is reserved for a missing/unreadable
##        file and is never emitted for a schema error; schema errors carry the offending
##        top-level key's own 1-based line (fallback 1); ALL errors are collected, never
##        stopping at the first; error ORDER comes from the loader's own DECLARED key-spec
##        order, never the parsed Dictionary's; unknown extra top-level keys load clean. SEMANTIC
##        attribution: `min_pitch_deg >= max_pitch_deg` -> `max_pitch_deg`; `min_zoom_m <= 0` ->
##        `min_zoom_m`; `min_zoom_m >= max_zoom_m` -> `max_zoom_m`; a speed `<= 0` -> that speed's
##        own key; `edge_pan_margin_px < 0` -> `edge_pan_margin_px` (0 is legal — it disables
##        edge-pan). A leaf that already failed its own schema check never also raises a
##        cascading band error. ANY error leaves the rig UNCONFIGURED, including a failed load
##        that follows a successful one.
##   (AM) The three speeds and the edge margin are NEW tunable content — §9.1 prints limits,
##        never speeds — so no GDD cell moves. They live in `data/render/camera.json`, a NEW
##        file rather than four more keys in `greybox.json` precisely because
##        `tests/unit/test_hex_layout.gd` asserts `greybox.json` byte-for-byte.
##
## TOTALITY (the M1-T1 (B) spirit, re-measured for a Node): a rig whose load failed — or was
## never attempted — reports the ZERO sentinel from every accessor, `Transform3D.IDENTITY` from
## `camera_transform()`, and treats every mutator as a SILENT no-op. No engine error, no crash.
##
## §9.1's "edge-pan + WASD" (plus Q/E orbit and R/F tilt, and wheel zoom) is UNTESTABLE headless:
## this rig is never added to the SceneTree by the unit suite, so `_process`/`_unhandled_input`
## never run there. Both are kept THIN — every mutation delegates to the tested mutators below.
class_name CameraRig
extends Node3D

## §9.1 "rotate 360°" — one full turn, a MATHEMATICAL constant (the SQRT_3/RADIAL_SEGMENTS/FNV
## precedent, decisions.md M1-T5 item 7), not tunable content.
const DEGREES_PER_TURN: float = 360.0

## The loader's DECLARED key-spec order — error order follows THIS, never the parsed
## Dictionary's (§11.1, resolution (AL)).
const SPEC_KEYS: PackedStringArray = [
	"min_pitch_deg",
	"max_pitch_deg",
	"min_zoom_m",
	"max_zoom_m",
	"pan_speed_mps",
	"orbit_speed_dps",
	"zoom_speed_mps",
	"edge_pan_margin_px",
]

## Index into [constant SPEC_KEYS] of the one INT leaf (a pixel margin is a whole number).
const EDGE_MARGIN_INDEX: int = 7

## Every failure of the last params load, earliest-first. Empty on success.
var errors: Array[RulesError] = []

var _configured: bool = false
var _min_pitch_deg: float = 0.0
var _max_pitch_deg: float = 0.0
var _min_zoom_m: float = 0.0
var _max_zoom_m: float = 0.0
var _pan_speed_mps: float = 0.0
var _orbit_speed_dps: float = 0.0
var _zoom_speed_mps: float = 0.0
var _edge_pan_margin_px: int = 0

var _yaw_deg: float = 0.0
var _pitch_deg: float = 0.0
var _zoom_m: float = 0.0
var _focus: Vector3 = Vector3.ZERO

## The rig's own driven camera when this node lives in a built scene (scenes/Main.tscn). Null
## outside a tree, which every headless unit test relies on — `_process` never runs there.
@onready var _camera: Camera3D = $Camera3D


## §9.1/(AL) — validates a camera params document and, on success, configures this rig at the
## widest legal view (resolution (AJ)). ANY error leaves the rig UNCONFIGURED.
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
			syntax_message if not syntax_message.is_empty() else "camera params JSON syntax error"
		)
		errors.append(syntax_error)
		return false

	var data: Variant = json.data
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	if not (data is Dictionary):
		var root_error: RulesError = RulesError.new()
		root_error.line = 1
		root_error.path = ""
		root_error.message = "camera params root must be a JSON object"
		errors.append(root_error)
		return false

	var root: Dictionary = data as Dictionary
	var values: Array[float] = []
	var valid: Array[bool] = []
	for i: int in range(SPEC_KEYS.size()):
		var key: String = SPEC_KEYS[i]
		values.append(0.0)
		valid.append(false)
		if not root.has(key):
			_add_error(key, lines, "camera params is MISSING required key \"%s\"" % key)
			continue
		var raw: Variant = root[key]
		if not (raw is float or raw is int):
			_add_error(key, lines, "\"%s\" must be a number" % key)
			continue
		if i == EDGE_MARGIN_INDEX and not _is_integral(raw):
			_add_error(key, lines, "\"%s\" must be a whole number" % key)
			continue
		values[i] = _as_float(raw)
		valid[i] = true

	_validate_semantics(values, valid, lines)

	if not errors.is_empty():
		return false

	_min_pitch_deg = values[0]
	_max_pitch_deg = values[1]
	_min_zoom_m = values[2]
	_max_zoom_m = values[3]
	_pan_speed_mps = values[4]
	_orbit_speed_dps = values[5]
	_zoom_speed_mps = values[6]
	_edge_pan_margin_px = int(values[EDGE_MARGIN_INDEX])

	_yaw_deg = 0.0
	_pitch_deg = _max_pitch_deg
	_zoom_m = _max_zoom_m
	_focus = Vector3.ZERO
	_configured = true
	return true


## §9.1/(AL) — reads `path` and delegates to [method load_params_text]. A missing or unreadable
## file is exactly one error attributed to the reserved line 0 (M0-T2 item 2).
func load_params_file(path: String) -> bool:
	errors = []
	_clear_configuration()

	if not FileAccess.file_exists(path):
		var missing_error: RulesError = RulesError.new()
		missing_error.line = 0
		missing_error.path = ""
		missing_error.message = "camera params file is MISSING: %s" % path
		errors.append(missing_error)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: RulesError = RulesError.new()
		open_error.line = 0
		open_error.path = ""
		open_error.message = "failed to open camera params file: %s" % path
		errors.append(open_error)
		return false

	var text: String = file.get_as_text()
	file.close()
	return load_params_text(text, path)


## §9.1 — the printed tilt band (min, max) in degrees; Vector2.ZERO when unconfigured.
func pitch_limits_deg() -> Vector2:
	if not _configured:
		return Vector2.ZERO
	return Vector2(_min_pitch_deg, _max_pitch_deg)


## §9.1 — the printed zoom band (min, max) in metres; Vector2.ZERO when unconfigured.
func zoom_limits_m() -> Vector2:
	if not _configured:
		return Vector2.ZERO
	return Vector2(_min_zoom_m, _max_zoom_m)


## §9.1/(AM) — the configured camera-relative ground pan speed, metres/second; 0.0 unconfigured.
func pan_speed_mps() -> float:
	return _pan_speed_mps


## §9.1/(AM) — the configured yaw orbit speed, degrees/second; 0.0 unconfigured.
func orbit_speed_dps() -> float:
	return _orbit_speed_dps


## §9.1/(AM) — the configured dolly (zoom) speed, metres/second; 0.0 unconfigured.
func zoom_speed_mps() -> float:
	return _zoom_speed_mps


## §9.1/(AM) — the configured edge-pan trigger margin, in pixels; 0 unconfigured (also the value
## that disables edge-pan when explicitly configured to zero).
func edge_pan_margin_px() -> int:
	return _edge_pan_margin_px


## §9.1 — current yaw, canonicalised into [0, 360) (resolution (AJ)); 0.0 unconfigured.
func yaw_deg() -> float:
	return _yaw_deg


## §9.1 — current pitch/tilt, clamped to the data band (resolution (AJ)); 0.0 unconfigured.
func pitch_deg() -> float:
	return _pitch_deg


## §9.1 — current zoom/dolly distance, clamped to the data band (resolution (AJ)); 0.0
## unconfigured.
func zoom_m() -> float:
	return _zoom_m


## §9.1/(AI) — the point the camera orbits and looks at; Vector3.ZERO unconfigured.
func focus_point() -> Vector3:
	return _focus


## §9.1/(AI) — moves the focus point verbatim; a silent no-op while unconfigured.
func set_focus(point: Vector3) -> void:
	if not _configured:
		return
	_focus = point


## §9.1 — orbits yaw by `delta_deg`, wrapping into [0, 360) (resolution (AJ)); a silent no-op
## while unconfigured.
func orbit(delta_deg: float) -> void:
	if not _configured:
		return
	_yaw_deg = _wrapped_yaw(_yaw_deg + delta_deg)


## §9.1 — tilts pitch by `delta_deg`, clamped inclusively to the data band; a silent no-op while
## unconfigured.
func tilt(delta_deg: float) -> void:
	if not _configured:
		return
	_pitch_deg = clampf(_pitch_deg + delta_deg, _min_pitch_deg, _max_pitch_deg)


## §9.1 — dollies zoom by `delta_m`, clamped inclusively to the data band; a silent no-op while
## unconfigured.
func dolly(delta_m: float) -> void:
	if not _configured:
		return
	_zoom_m = clampf(_zoom_m + delta_m, _min_zoom_m, _max_zoom_m)


## §9.1/(AK) — pans the focus along the camera-relative ground axes; a silent no-op while
## unconfigured.
func pan(right_m: float, forward_m: float) -> void:
	if not _configured:
		return
	var yaw_rad: float = deg_to_rad(_yaw_deg)
	var right_axis: Vector3 = Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
	var forward_axis: Vector3 = Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
	_focus += right_m * right_axis + forward_m * forward_axis


## §9.1/(AI) — the derived camera transform; Transform3D.IDENTITY while unconfigured.
func camera_transform() -> Transform3D:
	if not _configured:
		return Transform3D.IDENTITY
	var yaw_rad: float = deg_to_rad(_yaw_deg)
	var pitch_rad: float = deg_to_rad(_pitch_deg)
	var offset: Vector3 = _zoom_m * Vector3(
		cos(pitch_rad) * sin(yaw_rad), sin(pitch_rad), cos(pitch_rad) * cos(yaw_rad)
	)
	var origin: Vector3 = _focus + offset
	return Transform3D(Basis.IDENTITY, origin).looking_at(_focus, Vector3.UP)


## §9.1/(AI) — writes [method camera_transform] onto `camera`; a silent no-op when `camera` is
## null (the (B) totality spirit).
func apply_to_camera(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.transform = camera_transform()


# -------------------------------------------------------------------------------------------
# Input — §9.1 "edge-pan + WASD" (plus Q/E orbit, R/F tilt, wheel zoom). Thin: every mutation
# delegates to the tested mutators above. UNTESTABLE headless — this rig is never added to the
# SceneTree by the unit suite, so none of this runs there.
# -------------------------------------------------------------------------------------------

## §9.1 — per-frame WASD pan, Q/E orbit, R/F tilt and edge-pan, all driven by data-loaded speeds.
func _process(delta: float) -> void:
	if not _configured:
		return

	var right_input: float = 0.0
	var forward_input: float = 0.0
	if Input.is_physical_key_pressed(KEY_D):
		right_input += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		right_input -= 1.0
	if Input.is_physical_key_pressed(KEY_W):
		forward_input += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		forward_input -= 1.0

	var edge_input: Vector2 = _edge_pan_input()
	right_input += edge_input.x
	forward_input += edge_input.y

	if right_input != 0.0 or forward_input != 0.0:
		pan(right_input * _pan_speed_mps * delta, forward_input * _pan_speed_mps * delta)

	var orbit_input: float = 0.0
	if Input.is_key_pressed(KEY_E):
		orbit_input += 1.0
	if Input.is_key_pressed(KEY_Q):
		orbit_input -= 1.0
	if orbit_input != 0.0:
		orbit(orbit_input * _orbit_speed_dps * delta)

	var tilt_input: float = 0.0
	if Input.is_key_pressed(KEY_R):
		tilt_input += 1.0
	if Input.is_key_pressed(KEY_F):
		tilt_input -= 1.0
	if tilt_input != 0.0:
		tilt(tilt_input * _orbit_speed_dps * delta)

	apply_to_camera(_camera)


## §9.1 — mouse-wheel zoom, stepping by the data-loaded zoom speed.
func _unhandled_input(event: InputEvent) -> void:
	if not _configured:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		dolly(-_zoom_speed_mps)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		dolly(_zoom_speed_mps)


## §9.1 — camera-relative pan input (x = right, y = forward) contributed by the cursor sitting
## within [method edge_pan_margin_px] of a viewport edge; (0, 0) when edge-pan is disabled (a
## zero margin) or the viewport is unavailable.
func _edge_pan_input() -> Vector2:
	if _edge_pan_margin_px <= 0:
		return Vector2.ZERO
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var mouse: Vector2 = viewport.get_mouse_position()
	var size: Vector2 = viewport.get_visible_rect().size
	var margin: float = float(_edge_pan_margin_px)
	var right_input: float = 0.0
	var forward_input: float = 0.0
	if mouse.x <= margin:
		right_input -= 1.0
	elif mouse.x >= size.x - margin:
		right_input += 1.0
	if mouse.y <= margin:
		forward_input += 1.0
	elif mouse.y >= size.y - margin:
		forward_input -= 1.0
	return Vector2(right_input, forward_input)


# -------------------------------------------------------------------------------------------
# Internal
# -------------------------------------------------------------------------------------------

## Resets this rig to UNCONFIGURED, so a failed load never leaves stale limits/state behind
## (mirrors HexLayout's/MapGenerator's/MapRenderer's `_clear_configuration`/`_clear_palette`).
func _clear_configuration() -> void:
	_configured = false
	_min_pitch_deg = 0.0
	_max_pitch_deg = 0.0
	_min_zoom_m = 0.0
	_max_zoom_m = 0.0
	_pan_speed_mps = 0.0
	_orbit_speed_dps = 0.0
	_zoom_speed_mps = 0.0
	_edge_pan_margin_px = 0
	_yaw_deg = 0.0
	_pitch_deg = 0.0
	_zoom_m = 0.0
	_focus = Vector3.ZERO


## (AL) — the semantic band/positivity checks, run only over leaves that passed their own schema
## check: a leaf that already failed never also raises a cascading band error.
func _validate_semantics(values: Array[float], valid: Array[bool], lines: PackedStringArray) -> void:
	if valid[0] and valid[1] and values[0] >= values[1]:
		_add_error("max_pitch_deg", lines, "max_pitch_deg must be strictly greater than min_pitch_deg")

	var min_zoom_ok: bool = true
	if valid[2] and values[2] <= 0.0:
		_add_error("min_zoom_m", lines, "min_zoom_m must be strictly positive")
		min_zoom_ok = false
	if valid[2] and valid[3] and min_zoom_ok and values[2] >= values[3]:
		_add_error("max_zoom_m", lines, "max_zoom_m must be strictly greater than min_zoom_m")

	for i: int in range(3):
		var index: int = 4 + i
		var key: String = SPEC_KEYS[index]
		if valid[index] and values[index] <= 0.0:
			_add_error(key, lines, "%s must be strictly positive" % key)

	if valid[EDGE_MARGIN_INDEX] and values[EDGE_MARGIN_INDEX] < 0.0:
		_add_error("edge_pan_margin_px", lines, "edge_pan_margin_px must not be negative")


## Appends one [RulesError] attributed to the first line carrying the top-level key's own JSON
## token, falling back to line 1 (resolution (AL); line 0 stays reserved for missing files).
func _add_error(key: String, lines: PackedStringArray, message: String) -> void:
	var err: RulesError = RulesError.new()
	err.path = key
	err.message = message
	err.line = _line_for_key(lines, key)
	errors.append(err)


## 1-based line of the first line containing `"<key>"`, or 1 if no line carries it.
func _line_for_key(lines: PackedStringArray, key: String) -> int:
	var token: String = "\"%s\"" % key
	for i: int in range(lines.size()):
		if lines[i].contains(token):
			return i + 1
	return 1


## True for an [int] or a fractionless [float] — Godot's JSON parser hands every number back as
## TYPE_FLOAT (decisions.md M0-T2 item 8).
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


## §9.1/(AJ) — canonicalises `yaw` into the half-open turn [0, 360).
func _wrapped_yaw(yaw: float) -> float:
	var wrapped: float = fmod(yaw, DEGREES_PER_TURN)
	if wrapped < 0.0:
		wrapped += DEGREES_PER_TURN
	return wrapped
