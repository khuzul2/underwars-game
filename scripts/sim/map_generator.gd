## MapGenerator — GDD §4.4 (Map Generation — the Concentric Bowl, binding table), §4.1 (map
## radii and "Elevation: integer 0-3 per hex"), §11.1 (sim core is engine-free, integer-only and
## deterministic), §11.2 (`scripts/sim/` — GameState + systems), §11.3, §12.6 (a map/scenario
## references `"generator": "mapgen/concentric_bowl.json"`, so the bowl is a DATA FILE and this
## class is the one data-driven generator), §13.6.
##
## SLICE 1 (M1-T4) BUILDS THE BAND + ELEVATION SKELETON ONLY: the §4.4 concentric bands and the
## descending terraced bowl. Terrain-type composition (§4.2's 70% Soft Dirt / 20% Hard Rock,
## 55% Hard Rock / 15% Granite, granite-dominant Core), veins, Fungal Groves, chasms, rivers,
## Ruins, lairs, the Ancient Throne and player spawns are M1-T5 — and so is the project's first
## GOLDEN. §13.4: invent nothing ahead of its milestone. THIS SLICE USES NO RNG AT ALL.
##
## §13.4 resolutions (logged in docs/decisions.md; the lettering continues M1-T3's (H)-(L) —
## keep it stable, `tests/unit/test_map_generator.gd` cross-references it):
##   (M) BAND RULE. With bands listed OUTER TO INNER exactly as §4.4 prints them, let
##       `outer_pct[k]` be the cumulative share at band k's OUTER edge, summed from the
##       innermost band (safe_rim 100, mid_mantle 70, deep_core 30). For `d = HexMath.distance`
##       and map radius `R`, `band_index_at(d, R)` is the LAST (innermost) index k with
##       `d * 100 <= outer_pct[k] * R`, else 0. Pure integer CROSS-MULTIPLICATION: no division,
##       no rounding primitive, no float, hence no `@warning_ignore("integer_division")`.
##   (N) TERRACE RULE. The terrace table is `{from_share_pct, elevation}` rows listed outer to
##       inner in strictly decreasing `from_share_pct`; `elevation_at(d, R)` is the elevation of
##       the FIRST row satisfying `d * 100 > from_share_pct * R`, else the innermost row's
##       elevation. The comparison is STRICT ">" while (M)'s is "<=": that complementarity is
##       what makes terrace boundaries coincide exactly with band boundaries at a shared
##       percentage (30 and 70 appear in both tables). `>=` misaligns them at every
##       exact-multiple radius — e.g. R=40, d=28, where 70*40 == 2800 == 28*100.
##   (P) LOAD CONTRACT. Params are validated like the ruleset (§12.1 discipline): all errors
##       collected as [RulesError] with 1-based lines, and on ANY error the generator is left
##       UNCONFIGURED — a half-valid params set can never be read. Line 0 stays RESERVED for
##       missing/unreadable files (M0-T2 item 2). Schema errors are attributed to the first line
##       whose text carries the JSON key token of the offending TOP-LEVEL key, falling back to 1.
##
## §13.6 "events emitted for every state change" is VACUOUS here: this slice mutates no
## GameState and touches no EventBus, so there is no state change to emit an event for.
class_name MapGenerator
extends RefCounted

## Every failure of the last params load, earliest-first. Empty on success (§12.1 discipline).
var errors: Array[RulesError] = []

## True only after a successful [method load_params_text]/[method load_params_file]; cleared by
## any failed load, even one that follows a successful one (resolution (P)).
var _configured: bool = false

## Parallel arrays (never a Dictionary — §11.1 stable-order discipline): map size ids and radii.
var _size_ids: PackedStringArray = PackedStringArray()
var _size_radii: PackedInt32Array = PackedInt32Array()

## Parallel arrays: band ids and their §4.4 share of radius, listed outer to inner.
var _band_ids: PackedStringArray = PackedStringArray()
var _band_share_pct: PackedInt32Array = PackedInt32Array()

## Parallel arrays: resolution (N)'s terrace thresholds, listed outer to inner in strictly
## decreasing `from_share_pct`.
var _terrace_from_pct: PackedInt32Array = PackedInt32Array()
var _terrace_elevation: PackedInt32Array = PackedInt32Array()


## §4.4 — validates a whole mapgen params document and, on success, configures this generator.
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
		syntax_error.message = syntax_message if not syntax_message.is_empty() else "JSON syntax error"
		errors.append(syntax_error)
		return false

	var data: Variant = json.data
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")

	if not (data is Dictionary):
		var root_error: RulesError = RulesError.new()
		root_error.line = 1
		root_error.path = ""
		root_error.message = "mapgen params root must be a JSON object"
		errors.append(root_error)
		return false

	var root: Dictionary = data as Dictionary

	var new_size_ids: PackedStringArray = PackedStringArray()
	var new_size_radii: PackedInt32Array = PackedInt32Array()
	var new_band_ids: PackedStringArray = PackedStringArray()
	var new_band_share_pct: PackedInt32Array = PackedInt32Array()
	var new_terrace_from_pct: PackedInt32Array = PackedInt32Array()
	var new_terrace_elevation: PackedInt32Array = PackedInt32Array()

	_validate_map_sizes(root, lines, new_size_ids, new_size_radii)
	_validate_bands(root, lines, new_band_ids, new_band_share_pct)
	_validate_terraces(root, lines, new_terrace_from_pct, new_terrace_elevation)

	if not errors.is_empty():
		return false

	_size_ids = new_size_ids
	_size_radii = new_size_radii
	_band_ids = new_band_ids
	_band_share_pct = new_band_share_pct
	_terrace_from_pct = new_terrace_from_pct
	_terrace_elevation = new_terrace_elevation
	_configured = true
	return true


## §4.4 — reads `path` and delegates to [method load_params_text]. A missing or unreadable file
## yields exactly one error with line 0.
func load_params_file(path: String) -> bool:
	errors = []
	_clear_configuration()

	if not FileAccess.file_exists(path):
		var missing_error: RulesError = RulesError.new()
		missing_error.line = 0
		missing_error.path = ""
		missing_error.message = "mapgen params file not found: %s" % path
		errors.append(missing_error)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: RulesError = RulesError.new()
		open_error.line = 0
		open_error.path = ""
		open_error.message = "failed to open mapgen params file: %s" % path
		errors.append(open_error)
		return false

	var text: String = file.get_as_text()
	file.close()
	return load_params_text(text, path)


## §4.1 — hex radius configured for `size_id` ("small"/"medium"/"large"), or 0 when unknown.
func radius_for_size(size_id: String) -> int:
	for i: int in range(_size_ids.size()):
		if _size_ids[i] == size_id:
			return _size_radii[i]
	return 0


## §4.4 — number of concentric bands.
func band_count() -> int:
	return _band_ids.size()


## §4.4 — band id at `band_index`, listed outer to inner; "" when out of range.
func band_id(band_index: int) -> String:
	if band_index < 0 or band_index >= _band_ids.size():
		return ""
	return _band_ids[band_index]


## §4.4 — resolution (M): band index for a hex at cube distance `distance` on a map of radius
## `map_radius`.
func band_index_at(distance: int, map_radius: int) -> int:
	if map_radius <= 0:
		return 0
	var outer_pct: Array[int] = _cumulative_outer_pct()
	for k: int in range(outer_pct.size() - 1, -1, -1):
		if distance * 100 <= outer_pct[k] * map_radius:
			return k
	return 0


## §4.4/§4.1 — resolution (N): terraced-bowl elevation (0-3) for a hex at cube distance
## `distance` on a map of radius `map_radius`.
func elevation_at(distance: int, map_radius: int) -> int:
	if map_radius <= 0:
		return 0
	for i: int in range(_terrace_from_pct.size()):
		if distance * 100 > _terrace_from_pct[i] * map_radius:
			return _terrace_elevation[i]
	# Resolution (N)'s terminal case — reached only by the centre hex under a table whose
	# innermost row is `from_share_pct` 0. The answer is the INNERMOST ROW'S elevation, READ FROM
	# DATA (§13.6 "constants read from data, not code"): with the shipped table that is 0, §4.4's
	# "Core 0", but hard-coding the 0 would silently shadow a retuned innermost terrace. The
	# literal 0 survives only as the UNCONFIGURED sentinel, where there is no row to read.
	if _terrace_elevation.is_empty():
		return 0
	return _terrace_elevation[_terrace_elevation.size() - 1]


## §4.4 — builds the descending terraced bowl of radius `map_radius`. Returns an empty map when
## this generator is UNCONFIGURED (resolution (P)), regardless of `map_radius`.
func generate(map_radius: int) -> HexMap:
	if not _configured:
		return HexMap.new(-1)
	var map: HexMap = HexMap.new(map_radius)
	for hex: Vector2i in map.hexes():
		var d: int = HexMath.distance(Vector2i.ZERO, hex)
		map.set_elevation(hex, elevation_at(d, map_radius))
	return map


# -------------------------------------------------------------------------------------------
# Internal: load contract (resolution (P)).
# -------------------------------------------------------------------------------------------

## Resets this generator to UNCONFIGURED. Called at the start of every load attempt so a failed
## load never leaves stale params behind (mirrors RulesLoader's `rules = {}`).
func _clear_configuration() -> void:
	_configured = false
	_size_ids = PackedStringArray()
	_size_radii = PackedInt32Array()
	_band_ids = PackedStringArray()
	_band_share_pct = PackedInt32Array()
	_terrace_from_pct = PackedInt32Array()
	_terrace_elevation = PackedInt32Array()


## Validates the top-level "map_sizes" array: every entry needs a string id and a positive
## integral radius. Errors are attributed to the "map_sizes" line (resolution (P)).
func _validate_map_sizes(
	root: Dictionary,
	lines: PackedStringArray,
	out_ids: PackedStringArray,
	out_radii: PackedInt32Array
) -> void:
	if not root.has("map_sizes"):
		_add_error("map_sizes", lines, "missing required key \"map_sizes\"")
		return
	var raw: Variant = root["map_sizes"]
	if not (raw is Array):
		_add_error("map_sizes", lines, "\"map_sizes\" must be an array")
		return
	var entries: Array = raw
	for entry: Variant in entries:
		if not (entry is Dictionary):
			_add_error("map_sizes", lines, "each map size entry must be an object")
			continue
		var dict: Dictionary = entry
		var id_value: Variant = dict.get("id", null)
		if not (id_value is String):
			_add_error("map_sizes", lines, "every map size needs a string id")
		else:
			var id_text: String = id_value
			out_ids.append(id_text)
		var radius_value: Variant = dict.get("radius", null)
		if not _is_integral(radius_value):
			_add_error("map_sizes", lines, "map size radius must be an integer")
			continue
		var radius: int = _as_int(radius_value)
		if radius <= 0:
			_add_error("map_sizes", lines, "map size radius must be positive")
		out_radii.append(radius)


## Validates the top-level "bands" array: every entry needs a string id and an integral
## `share_pct`, and the shares must sum to 100 (§4.4). Errors are attributed to the "bands"
## line (resolution (P)).
func _validate_bands(
	root: Dictionary,
	lines: PackedStringArray,
	out_ids: PackedStringArray,
	out_shares: PackedInt32Array
) -> void:
	if not root.has("bands"):
		_add_error("bands", lines, "missing required key \"bands\"")
		return
	var raw: Variant = root["bands"]
	if not (raw is Array):
		_add_error("bands", lines, "\"bands\" must be an array")
		return
	var entries: Array = raw
	var total: int = 0
	for entry: Variant in entries:
		if not (entry is Dictionary):
			_add_error("bands", lines, "each band entry must be an object")
			continue
		var dict: Dictionary = entry
		var id_value: Variant = dict.get("id", null)
		if not (id_value is String):
			_add_error("bands", lines, "every ring must carry an id")
		else:
			var id_text: String = id_value
			out_ids.append(id_text)
		var share_value: Variant = dict.get("share_pct", null)
		if not _is_integral(share_value):
			_add_error("bands", lines, "band share_pct must be an integer")
			continue
		var share: int = _as_int(share_value)
		out_shares.append(share)
		total += share
	if total != 100:
		_add_error("bands", lines, "ring shares must sum to 100 (got %d)" % total)


## Validates the top-level "terraces" array: every entry needs an integral `from_share_pct` and
## `elevation` (0-3), strictly decreasing outer to inner (resolution (N)). Errors are attributed
## to the "terraces" line (resolution (P)).
func _validate_terraces(
	root: Dictionary,
	lines: PackedStringArray,
	out_from: PackedInt32Array,
	out_elevation: PackedInt32Array
) -> void:
	if not root.has("terraces"):
		_add_error("terraces", lines, "missing required key \"terraces\"")
		return
	var raw: Variant = root["terraces"]
	if not (raw is Array):
		_add_error("terraces", lines, "\"terraces\" must be an array")
		return
	var entries: Array = raw
	var previous_from: int = 101
	for entry: Variant in entries:
		if not (entry is Dictionary):
			_add_error("terraces", lines, "each terrace entry must be an object")
			continue
		var dict: Dictionary = entry
		var from_value: Variant = dict.get("from_share_pct", null)
		var elevation_value: Variant = dict.get("elevation", null)
		if not _is_integral(from_value) or not _is_integral(elevation_value):
			_add_error("terraces", lines, "terrace entries need integer from_share_pct/elevation")
			continue
		var from_pct: int = _as_int(from_value)
		var elevation: int = _as_int(elevation_value)
		if elevation < 0 or elevation > 3:
			_add_error("terraces", lines, "terrace elevation must be an integer 0-3")
		if from_pct >= previous_from:
			_add_error("terraces", lines, "terraces must strictly decrease outer to inner")
		previous_from = from_pct
		out_from.append(from_pct)
		out_elevation.append(elevation)


## §4.4 — cumulative share at each band's OUTER edge, summed from the innermost band, with
## bands kept in their stored outer-to-inner order (resolution (M)).
func _cumulative_outer_pct() -> Array[int]:
	var out: Array[int] = []
	for k: int in range(_band_share_pct.size()):
		var total: int = 0
		for j: int in range(k, _band_share_pct.size()):
			total += _band_share_pct[j]
		out.append(total)
	return out


## Appends one [RulesError] attributed to the first line carrying the top-level key's own JSON
## token, falling back to line 1 (resolution (P) — deliberately simpler than
## `RulesLoader._attribute_line`, because this schema has no nested paths to walk).
func _add_error(top_level_key: String, lines: PackedStringArray, message: String) -> void:
	var err: RulesError = RulesError.new()
	err.path = top_level_key
	err.message = message
	err.line = _line_for_key(lines, top_level_key)
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


## Converts a value already known to satisfy [method _is_integral] into an [int].
func _as_int(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var as_float: float = value
		return int(as_float)
	return 0
