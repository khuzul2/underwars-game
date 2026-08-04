## MapRenderer — GDD §10 ("Rock rendered as chunked MultiMeshInstance3D (per-instance custom data
## = type/tint); dirty-chunk rebuilds on dig. Target: Medium map at 60 fps on mid-range hardware;
## SDFGI off"; "Greybox first. All MVP visuals are flat-shaded prisms and capsules"), §4.1
## ("**Flat-top hexes, axial coordinates (q, r)**"; "Elevation: integer 0-3 per hex"), §4.2 (the
## nine Solid type ids, kept OPAQUE here — no whitelist in engine code), §11.1 (the layered
## boundary: data -> Sim Core -> EventBus -> Renderer/UI, and THE SIM NEVER CALLS THE RENDERER),
## §11.2 (`scripts/render/` — MapRenderer, UnitView, LightOverlay, CameraRig), §11.3, §13.2, §13.6.
##
## RENDERER SLICE 2 of §14 M1's "chunked MultiMesh renderer": the NODE half. One
## MultiMeshInstance3D child per HexLayout chunk, per-instance transforms from
## HexLayout.hex_to_world(), per-instance custom data = the hex's terrain tint, one shared prism
## mesh + material, and a dirty-chunk rebuild seam that M2's dig will call.
##
## STRUCTURAL TESTING ONLY (decisions.md M1-T6 (Z), re-measured M1-T7): headless MultiMesh does not
## retain instance data, so per-instance transforms/custom data are written here but never read
## back anywhere in this file or its test suite. `tests/unit/test_map_renderer.gd` pins the write
## the only way headless allows: a source-token scan for `set_instance_transform(` and
## `set_instance_custom_data(`.
##
## Resolutions (docs/decisions.md, continuing HexLayout's lettering at (AA)):
##   (AA) One MultiMeshInstance3D child per chunk, added in HexLayout.chunk_keys() canonical order,
##        named "chunk_%d_%d" % [key.x, key.y].
##   (AB) TOTALITY: build() requires a configured HexLayout AND a loaded palette AND a non-null map
##        with hex_count() > 0; otherwise zero children, empty chunk_keys(), empty flush_dirty().
##        Any palette error leaves the palette UNLOADED, including a failed load after a
##        successful one.
##   (AC) Per-instance transform origin = layout.hex_to_world(hex, map.get_elevation(hex)) with an
##        identity basis, MapRenderer-local (chunk node transforms stay identity); custom data =
##        tint_for(map.get_terrain_type(hex)) with alpha reserved at 1.0 for M3's Lit/Dark shader.
##   (AD) ONE shared CylinderMesh (radial_segments 6; top/bottom radius = hex_width_m/2; height =
##        elevation_step_m) and ONE shared StandardMaterial3D across every chunk.
##   (AE) mark_hex_dirty(hex) marks layout.chunk_of(hex) only if that chunk was built; flush_dirty
##        rebuilds ONLY marked chunks IN PLACE (same nodes, same MultiMesh objects), returns keys
##        in canonical order, and clears the dirty set.
##   (AF) Palette load contract mirrors MapGenerator's (P) / HexLayout's (Y), reusing RulesError.
##   (AG) The nine tints + fallback are NEW tunable content (data/render/terrain_palette.json); no
##        GDD cell moves. §4.2's vocabulary stays un-whitelisted in engine code.
##   (AH) At M1 every in-bounds hex is drawn as solid rock; cave-hex culling arrives with M2's dig.
##
## SCOPE (§13.4: invent nothing ahead of its milestone): the renderer NODE only. No scenes/Main.tscn,
## no Camera3D, no WorldEnvironment, no EventBus subscription, no shader — those belong to
## M1-T8/M1-T9/M3.
class_name MapRenderer
extends Node3D

## A hex prism has one side per axial direction — a mathematical constant (the SQRT_3/FNV
## precedent, decisions.md M1-T5 item 7), not tunable content.
const RADIAL_SEGMENTS: int = 6

## An RGB triple is always three channel values 0-255 — schema shape, not tunable content.
const RGB_TRIPLE_SIZE: int = 3
const RGB_MIN: int = 0
const RGB_MAX: int = 255

## The palette loader's declared key-spec order — error order follows THIS, never the parsed
## Dictionary's key order (§11.1, resolution (AF)).
const SPEC_KEYS: PackedStringArray = ["fallback_rgb", "tints"]

## Every failure of the last palette load, earliest-first. Empty on success.
var errors: Array[RulesError] = []

var _layout: HexLayout = null

var _palette_loaded: bool = false
var _fallback_color: Color = Color(0.0, 0.0, 0.0, 1.0)
var _tints: Dictionary = {}

var _shared_mesh: CylinderMesh = null
var _shared_material: StandardMaterial3D = null

## Cached from the last successful build(): the chunk keys in canonical order, the hex-index
## bucket parallel to each key, the flat hex list they index into, and a lookup of which chunks
## exist (so mark_hex_dirty can no-op on an unbuilt chunk without scanning an array).
var _chunk_keys_cache: Array[Vector2i] = []
var _chunk_buckets_cache: Array[PackedInt32Array] = []
var _built_hexes: Array[Vector2i] = []
var _chunk_index: Dictionary = {}

## Chunk keys marked for the next flush_dirty(); a lookup/dedup set only, never iterated into
## output directly (§11.1) — flush_dirty walks the ordered [member _chunk_keys_cache] instead.
var _dirty: Dictionary = {}


## §10 — validates a terrain-palette document and, on success, loads it. ANY error leaves the
## palette UNLOADED, including a failed load that follows a successful one.
func load_palette_text(text: String, _source: String) -> bool:
	errors = []
	_clear_palette()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(text)
	if parse_result != OK:
		var syntax_error: RulesError = RulesError.new()
		syntax_error.line = json.get_error_line() + 1
		syntax_error.path = ""
		var syntax_message: String = json.get_error_message()
		syntax_error.message = (
			syntax_message if not syntax_message.is_empty() else "terrain palette JSON syntax error"
		)
		errors.append(syntax_error)
		return false

	var data: Variant = json.data
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	if not (data is Dictionary):
		var root_error: RulesError = RulesError.new()
		root_error.line = 1
		root_error.path = ""
		root_error.message = "terrain palette root must be a JSON object"
		errors.append(root_error)
		return false

	var root: Dictionary = data as Dictionary

	var fallback_rgb: Vector3i = _validate_fallback(root, lines)
	var tint_ids: Array[String] = []
	var tint_colors: Array[Color] = []
	_validate_tints(root, lines, tint_ids, tint_colors)

	if not errors.is_empty():
		return false

	_fallback_color = Color8(fallback_rgb.x, fallback_rgb.y, fallback_rgb.z)
	_tints = {}
	for i: int in range(tint_ids.size()):
		_tints[tint_ids[i]] = tint_colors[i]
	_palette_loaded = true
	return true


## §10 — reads `path` and delegates to [method load_palette_text]. A missing or unreadable file is
## exactly one error attributed to the reserved line 0.
func load_palette_file(path: String) -> bool:
	errors = []
	_clear_palette()

	if not FileAccess.file_exists(path):
		var missing_error: RulesError = RulesError.new()
		missing_error.line = 0
		missing_error.path = ""
		missing_error.message = "terrain palette file is MISSING: %s" % path
		errors.append(missing_error)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: RulesError = RulesError.new()
		open_error.line = 0
		open_error.path = ""
		open_error.message = "failed to open terrain palette file: %s" % path
		errors.append(open_error)
		return false

	var text: String = file.get_as_text()
	file.close()
	return load_palette_text(text, path)


## §4.2 — the greybox tint a terrain-type id maps to; the palette fallback for an unknown id.
## When no palette has ever loaded successfully, returns the black sentinel (resolution (AB)).
func tint_for(type_id: String) -> Color:
	if not _palette_loaded:
		return Color(0.0, 0.0, 0.0, 1.0)
	if _tints.has(type_id):
		return _tints[type_id]
	return _fallback_color


## §10 — injects the [HexLayout] that supplies placement and the chunk partition.
func set_layout(layout: HexLayout) -> void:
	_layout = layout


## §10 — (re)builds one MultiMeshInstance3D child per chunk of `map`, replacing any previous
## build synchronously (resolution (AA)). Draws nothing unless a layout AND a loaded palette AND
## a non-null, non-empty map are all present (resolution (AB)).
func build(map: HexMap) -> void:
	_clear_chunks()
	if _layout == null or not _palette_loaded or map == null:
		return
	if map.hex_count() <= 0:
		return

	_ensure_resources()
	var hexes: Array[Vector2i] = map.hexes()
	var keys: Array[Vector2i] = _layout.chunk_keys(hexes)
	var buckets: Array[PackedInt32Array] = _layout.partition(hexes)
	_built_hexes = hexes
	_chunk_keys_cache = keys
	_chunk_buckets_cache = buckets

	for i: int in range(keys.size()):
		var key: Vector2i = keys[i]
		_chunk_index[key] = i
		var chunk_node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		chunk_node.name = "chunk_%d_%d" % [key.x, key.y]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _shared_mesh
		mm.instance_count = buckets[i].size()
		chunk_node.multimesh = mm
		add_child(chunk_node)
		_fill_chunk(mm, buckets[i], hexes, map)


## §10 — the chunk keys currently built, in HexLayout's canonical order.
func chunk_keys() -> Array[Vector2i]:
	return _chunk_keys_cache.duplicate()


## §10 — marks the chunk owning `hex` for the next [method flush_dirty]; the seam M2's dig calls.
## A silent no-op when unconfigured or when that chunk was never built (resolution (AE)).
func mark_hex_dirty(hex: Vector2i) -> void:
	if _layout == null:
		return
	var key: Vector2i = _layout.chunk_of(hex)
	if not _chunk_index.has(key):
		return
	_dirty[key] = true


## §10 — refills every marked chunk in place (same node, same MultiMesh object) and returns their
## keys in canonical order, clearing the dirty set (resolution (AE)).
func flush_dirty(map: HexMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map == null or _chunk_keys_cache.is_empty():
		return out

	for i: int in range(_chunk_keys_cache.size()):
		var key: Vector2i = _chunk_keys_cache[i]
		if not _dirty.has(key):
			continue
		var chunk_node: MultiMeshInstance3D = get_child(i) as MultiMeshInstance3D
		if chunk_node == null:
			continue
		var mm: MultiMesh = chunk_node.multimesh
		if mm == null:
			continue
		_fill_chunk(mm, _chunk_buckets_cache[i], _built_hexes, map)
		out.append(key)
		_dirty.erase(key)
	return out


# -------------------------------------------------------------------------------------------
# Internal
# -------------------------------------------------------------------------------------------

## Resets the palette to UNLOADED, so a failed load never leaves stale tints behind (mirrors
## HexLayout's `_clear_configuration` / MapGenerator's `_clear_configuration`).
func _clear_palette() -> void:
	_palette_loaded = false
	_fallback_color = Color(0.0, 0.0, 0.0, 1.0)
	_tints = {}


## Removes every chunk node with `remove_child` + `free` — NEVER `queue_free`, which defers to the
## next frame and would double a same-frame rebuild's children — and resets every build-time cache.
func _clear_chunks() -> void:
	while get_child_count() > 0:
		var child: Node = get_child(0)
		remove_child(child)
		child.free()
	_chunk_keys_cache = []
	_chunk_buckets_cache = []
	_built_hexes = []
	_chunk_index = {}
	_dirty = {}


## Lazily allocates the ONE shared prism mesh and the ONE shared material for this renderer
## instance (resolution (AD)); a no-op once already allocated, so every chunk shares the same
## objects however many times build() runs.
func _ensure_resources() -> void:
	if _shared_mesh != null:
		return
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.radial_segments = RADIAL_SEGMENTS
	mesh.top_radius = _layout.hex_width_m() / 2.0
	mesh.bottom_radius = _layout.hex_width_m() / 2.0
	mesh.height = _layout.elevation_step_m()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material = material
	_shared_mesh = mesh
	_shared_material = material


## Writes every instance in `bucket` (indices into `hexes`) into `mm`: transform from
## HexLayout.hex_to_world() with an identity basis, custom data from [method tint_for] with alpha
## reserved at 1.0 (resolution (AC)). Written, never read back (M1-T6 (Z)).
func _fill_chunk(mm: MultiMesh, bucket: PackedInt32Array, hexes: Array[Vector2i], map: HexMap) -> void:
	for j: int in range(bucket.size()):
		var hex: Vector2i = hexes[bucket[j]]
		var elevation: int = map.get_elevation(hex)
		var origin: Vector3 = _layout.hex_to_world(hex, elevation)
		mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, origin))
		mm.set_instance_custom_data(j, tint_for(map.get_terrain_type(hex)))


## Validates the top-level `fallback_rgb` key, appending to [member errors] on failure. Returns
## `(-1, -1, -1)` on any failure — never a usable colour — so a caller can never mistake a
## rejected document for a loaded one.
func _validate_fallback(root: Dictionary, lines: PackedStringArray) -> Vector3i:
	if not root.has("fallback_rgb"):
		_add_error("fallback_rgb", lines, "terrain palette is MISSING required key \"fallback_rgb\"")
		return Vector3i(-1, -1, -1)
	var parsed: Vector3i = _rgb_row(root["fallback_rgb"])
	if parsed.x < RGB_MIN:
		_add_error("fallback_rgb", lines, "\"fallback_rgb\" must be an RGB triple of bytes 0-255")
		return Vector3i(-1, -1, -1)
	return parsed


## Validates the top-level `tints` key, appending to [member errors] on failure and filling
## `out_ids`/`out_colors` (parallel arrays) with every VALID row. Errors are collected — never
## stop at the first — but a document carrying any error is discarded wholesale by the caller.
func _validate_tints(
	root: Dictionary, lines: PackedStringArray, out_ids: Array[String], out_colors: Array[Color]
) -> void:
	if not root.has("tints"):
		_add_error("tints", lines, "terrain palette is MISSING required key \"tints\"")
		return
	var raw_tints: Variant = root["tints"]
	if not (raw_tints is Array):
		_add_error("tints", lines, "\"tints\" must be an array")
		return
	var rows: Array = raw_tints
	if rows.is_empty():
		_add_error("tints", lines, "\"tints\" must not be empty")
		return

	var seen_types: Dictionary = {}
	for row: Variant in rows:
		if not (row is Dictionary):
			_add_error("tints", lines, "each tint row must be an object")
			continue
		var entry: Dictionary = row
		if not entry.has("type"):
			_add_error("tints", lines, "each tint row needs a \"type\"")
			continue
		var raw_type: Variant = entry["type"]
		if not (raw_type is String):
			_add_error("tints", lines, "\"type\" must be a string")
			continue
		var type_id: String = raw_type
		if type_id.is_empty():
			_add_error("tints", lines, "\"type\" must not be empty")
			continue
		if seen_types.has(type_id):
			_add_error("tints", lines, "duplicate \"type\" \"%s\"" % type_id)
			continue
		var rgb: Vector3i = _rgb_row(entry.get("rgb", null))
		if rgb.x < RGB_MIN:
			_add_error("tints", lines, "\"%s\" needs an RGB triple of bytes 0-255" % type_id)
			continue
		seen_types[type_id] = true
		out_ids.append(type_id)
		out_colors.append(Color8(rgb.x, rgb.y, rgb.z))


## Parses `value` as an RGB triple of whole bytes 0-255. Every Godot 4.7 JSON number arrives as
## TYPE_FLOAT, so an integral float is ACCEPTED and a fractional one REJECTED, never truncated.
## Returns `(-1, -1, -1)` — outside the valid byte range — on any failure.
func _rgb_row(value: Variant) -> Vector3i:
	if not (value is Array):
		return Vector3i(-1, -1, -1)
	var arr: Array = value
	if arr.size() != RGB_TRIPLE_SIZE:
		return Vector3i(-1, -1, -1)
	var components: Array[int] = []
	for component: Variant in arr:
		if not _is_integral(component):
			return Vector3i(-1, -1, -1)
		var as_int: int = _int_of(component)
		if as_int < RGB_MIN or as_int > RGB_MAX:
			return Vector3i(-1, -1, -1)
		components.append(as_int)
	return Vector3i(components[0], components[1], components[2])


## True for an [int] or a fractionless [float] — Godot's JSON parser hands every number back as
## TYPE_FLOAT (decisions.md M0-T2 item 8).
func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var as_float: float = value
		return as_float == floor(as_float)
	return false


## Converts a value already known to be an integral [int] or [float] into an [int].
func _int_of(value: Variant) -> int:
	if value is int:
		var as_int: int = value
		return as_int
	if value is float:
		var as_float: float = value
		return int(as_float)
	return 0


## Appends one [RulesError] attributed to the first line carrying the top-level key's own JSON
## token, falling back to line 1 (resolution (AF); line 0 stays reserved for missing files).
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
