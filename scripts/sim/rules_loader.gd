## Loads and validates `data/ruleset.json` — the §12.1 constant set that every rule reads from
## (§11.1: "no magic numbers — everything reads from the loaded ruleset", §11.3).
##
## Pure [RefCounted]: no Node, no SceneTree, no engine singletons beyond [JSON] (and
## [FileAccess], confined to [method load_file]) — §11.1.
##
## Contract:
##   - [member rules] stays EMPTY whenever validation fails: a half-valid ruleset is never readable.
##   - [member errors] is deterministic (§11.1): same text ⇒ same list, same order; the loader
##     iterates its own declared §12.1 spec order (see [method _spec]), never the parse result's
##     key order.
##   - Error lines are 1-based (first line of the document == line 1). Godot's
##     `JSON.get_error_line()` is 0-based — probed on the pinned 4.7 build — so it is
##     normalized here, not in callers. Line 0 means "no line" (file-level errors only).
##   - Every JSON number parses as a float on this engine, even literals like `1` or `250`, so
##     "int" leaves accept an integral float and reject one with a fractional part — never
##     silently truncated (decisions.md M0-T2).
class_name RulesLoader
extends RefCounted

## The validated ruleset. Empty until a load succeeds; emptied again by any failed load.
var rules: Dictionary = {}

## Every failure of the last load, earliest-in-spec-order first. Empty on success.
var errors: Array[RulesError] = []


## §12.1/§14 — validates `text` (a whole ruleset document) and, on success, publishes it to
## [member rules]. `source` names the document for callers that render errors via
## [method RulesError.format_for]. Returns true on success.
func load_text(text: String, _source: String) -> bool:
	rules = {}
	errors = []

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
		root_error.message = "ruleset root must be a JSON object"
		errors.append(root_error)
		return false

	var root: Dictionary = data as Dictionary
	for node: Dictionary in _spec():
		_validate_node(root, node, "", lines)

	if not errors.is_empty():
		rules = {}
		return false

	rules = root
	return true


## §14 — reads `path` and delegates to [method load_text] (the only filesystem touch in this
## class). A missing or unreadable file yields exactly one error with line 0.
func load_file(path: String) -> bool:
	rules = {}
	errors = []

	if not FileAccess.file_exists(path):
		var missing_error: RulesError = RulesError.new()
		missing_error.line = 0
		missing_error.path = ""
		missing_error.message = "ruleset file not found: %s" % path
		errors.append(missing_error)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: RulesError = RulesError.new()
		open_error.line = 0
		open_error.path = ""
		open_error.message = "failed to open ruleset file: %s" % path
		errors.append(open_error)
		return false

	var text: String = file.get_as_text()
	return load_text(text, path)


## §12.1 — true when `dotted_path` (e.g. "vein_nodes.gold.rate") resolves in the loaded ruleset.
func has(dotted_path: String) -> bool:
	return _resolve(dotted_path) != null


## §12.1 — integer constant at `dotted_path`.
func get_int(dotted_path: String) -> int:
	var value: Variant = _resolve(dotted_path)
	if value is int:
		return value
	if value is float:
		return int(value)
	return 0


## §12.1 — fractional constant at `dotted_path`.
func get_float(dotted_path: String) -> float:
	var value: Variant = _resolve(dotted_path)
	if value is float:
		return value
	if value is int:
		return float(value)
	return 0.0


## §12.1 — string constant at `dotted_path` (e.g. "version").
func get_string(dotted_path: String) -> String:
	var value: Variant = _resolve(dotted_path)
	if value is String:
		return value
	return ""


## §12.1 — fixed-length integer array at `dotted_path` (effective_armor_clamp,
## train_turns_by_tier, tech_cost_by_tier, wrath.thresholds).
func get_int_array(dotted_path: String) -> Array[int]:
	var out: Array[int] = []
	var value: Variant = _resolve(dotted_path)
	if value is Array:
		for entry: Variant in (value as Array):
			if entry is int:
				out.append(entry)
			elif entry is float:
				out.append(int(entry))
	return out


## §12.1 — the keys of the object at `dotted_path`, ASCENDING, a FRESH [Array] every call. Empty
## for a missing path or a non-object leaf. This is the accessor the author-chosen "map" spec
## kind exists to make readable (e.g. `dig.profiles`).
func get_keys(dotted_path: String) -> Array[String]:
	var out: Array[String] = []
	var value: Variant = _resolve(dotted_path)
	if not (value is Dictionary):
		return out
	for key: Variant in (value as Dictionary).keys():
		if key is String:
			out.append(key)
	out.sort()
	return out


# -------------------------------------------------------------------------------------------
# Internal: dotted-path resolution.
# -------------------------------------------------------------------------------------------

## Walks [member rules] by dotted path, returning null when any segment is absent or the
## container along the way is not a Dictionary. null is never a legitimate leaf value in this
## schema, so it doubles as the "not found" sentinel for [method has].
func _resolve(dotted_path: String) -> Variant:
	var current: Variant = rules
	for segment: String in dotted_path.split("."):
		if not (current is Dictionary):
			return null
		var dict: Dictionary = current as Dictionary
		if not dict.has(segment):
			return null
		current = dict[segment]
	return current


# -------------------------------------------------------------------------------------------
# Internal: schema validation (§12.1).
# -------------------------------------------------------------------------------------------

## The declared §12.1 constant schema, in table order — this order is what makes
## [member errors] deterministic (§11.1): the first error is always the earliest offending
## leaf in this list, never whatever order the JSON parser's Dictionary happens to iterate.
## Each node is {"path": <key>, "kind": <string|int|float|object|int_array>, ...}:
##   - "object" nodes carry "children": Array[Dictionary] of nested nodes.
##   - "int_array" nodes carry "size": int, the required exact length.
func _spec() -> Array[Dictionary]:
	return [
		{"path": "version", "kind": "string"},
		{
			"path": "dig_turns",
			"kind": "object",
			"children": [
				{"path": "soft", "kind": "int"},
				{"path": "hard", "kind": "int"},
				{"path": "granite", "kind": "int"},
				{"path": "artificial_granite", "kind": "int"},
				{"path": "artificial_granite_owner", "kind": "int"},
				{"path": "rubble", "kind": "int"},
				{"path": "vein", "kind": "int"},
				{"path": "mithril", "kind": "int"},
			],
		},
		{
			"path": "dig_yields",
			"kind": "object",
			"children": [
				{"path": "soft", "kind": "object", "children": [{"path": "food", "kind": "int"}]},
				{"path": "hard", "kind": "object", "children": [{"path": "stone", "kind": "int"}]},
				{"path": "granite", "kind": "object", "children": [{"path": "stone", "kind": "int"}]},
				{
					"path": "artificial_granite",
					"kind": "object",
					"children": [{"path": "stone", "kind": "int"}],
				},
				{"path": "rubble", "kind": "object", "children": [{"path": "stone", "kind": "int"}]},
			],
		},
		{
			"path": "dig",
			"kind": "object",
			"children": [
				{"path": "max_diggers_per_hex", "kind": "int"},
				{
					"path": "profiles",
					"kind": "map",
					"entry": [
						{"path": "turns_key", "kind": "string"},
						{"path": "owner_turns_key", "kind": "string"},
						{"path": "yield_key", "kind": "string"},
						{"path": "vein_key", "kind": "string"},
					],
				},
			],
		},
		{
			"path": "vein_nodes",
			"kind": "object",
			"children": [
				{"path": "gold", "kind": "object", "children": _vein_node_children()},
				{"path": "iron", "kind": "object", "children": _vein_node_children()},
				{"path": "magestone", "kind": "object", "children": _vein_node_children()},
				{"path": "mithril", "kind": "object", "children": _vein_node_children()},
			],
		},
		{
			"path": "combat",
			"kind": "object",
			"children": [
				{"path": "armor_factor", "kind": "int"},
				{"path": "effective_armor_clamp", "kind": "int_array", "size": 2},
				{"path": "counter_ratio", "kind": "float"},
				{"path": "min_damage", "kind": "int"},
			],
		},
		{
			"path": "modifiers",
			"kind": "object",
			"children": [
				{"path": "elevation_per_level", "kind": "float"},
				{"path": "elevation_max", "kind": "float"},
				{"path": "dark_penalty", "kind": "float"},
				{"path": "cover_arm", "kind": "int"},
				{"path": "trench_arm", "kind": "int"},
			],
		},
		{
			"path": "light",
			"kind": "object",
			"children": [
				{"path": "brazier_radius", "kind": "int"},
				{"path": "hq_radius", "kind": "int"},
				{"path": "torch_radius", "kind": "int"},
			],
		},
		{
			"path": "structure",
			"kind": "object",
			"children": [
				{"path": "support_radius", "kind": "int"},
				{"path": "stress_collapse_threshold", "kind": "int"},
				{"path": "collapse_chance", "kind": "float"},
				{"path": "collapse_damage", "kind": "int"},
			],
		},
		{
			"path": "noise",
			"kind": "object",
			"children": [
				{"path": "dig", "kind": "int"},
				{"path": "blast", "kind": "int"},
				{"path": "cave_cost", "kind": "int"},
				{"path": "solid_cost", "kind": "int"},
			],
		},
		{
			"path": "wrath",
			"kind": "object",
			"children": [
				{"path": "mithril_per_turn", "kind": "int"},
				{"path": "blast", "kind": "int"},
				{"path": "wonder_start", "kind": "int"},
				{"path": "wonder_done", "kind": "int"},
				{"path": "throne_per_turn", "kind": "int"},
				{"path": "decay", "kind": "int"},
				{"path": "thresholds", "kind": "int_array", "size": 3},
				{"path": "reset", "kind": "int"},
			],
		},
		{"path": "upkeep_deficit_hp_pct", "kind": "float"},
		{"path": "housing", "kind": "object", "children": [{"path": "hq", "kind": "int"}]},
		{"path": "train_turns_by_tier", "kind": "int_array", "size": 4},
		{"path": "tech_cost_by_tier", "kind": "int_array", "size": 4},
		{
			"path": "victory",
			"kind": "object",
			"children": [
				{"path": "throne_hold_turns", "kind": "int"},
				{"path": "wonder_survive_turns", "kind": "int"},
				{"path": "turn_limit", "kind": "int"},
			],
		},
	]


## Shared leaf trio for every §12.1 vein_nodes.* entry (lump / stock / rate, all ints).
func _vein_node_children() -> Array[Dictionary]:
	return [
		{"path": "lump", "kind": "int"},
		{"path": "stock", "kind": "int"},
		{"path": "rate", "kind": "int"},
	]


## Validates one spec `node` inside `container` (a parsed Dictionary or, on a type mismatch,
## some other Variant). `dotted_prefix` is the already-validated ancestor path ("" at the
## root). Recurses into "object" children; appends to [member errors] on any mismatch. Never
## stops at the first error — every leaf in the spec is checked — but because [method _spec]
## is visited in a fixed order and each node is validated before its later siblings, the
## resulting [member errors] list is itself in deterministic, reproducible order (§11.1).
func _validate_node(
	container: Variant, node: Dictionary, dotted_prefix: String, lines: PackedStringArray
) -> void:
	var key: String = node["path"]
	var dotted: String = key if dotted_prefix.is_empty() else "%s.%s" % [dotted_prefix, key]

	if not (container is Dictionary) or not (container as Dictionary).has(key):
		_add_error(dotted, "missing required key \"%s\"" % dotted, lines)
		return

	var value: Variant = (container as Dictionary)[key]
	var kind: String = node["kind"]

	match kind:
		"string":
			if not (value is String):
				_add_error(dotted, "\"%s\" must be a string" % dotted, lines)
		"int":
			if not _is_integral(value):
				_add_error(dotted, "\"%s\" must be an integer" % dotted, lines)
		"float":
			if not (value is float or value is int):
				_add_error(dotted, "\"%s\" must be a number" % dotted, lines)
		"object":
			if not (value is Dictionary):
				_add_error(dotted, "\"%s\" must be an object" % dotted, lines)
			else:
				var children: Array = node["children"]
				for child: Dictionary in children:
					_validate_node(value, child, dotted, lines)
		"int_array":
			var expected_size: int = node["size"]
			if not (value is Array):
				_add_error(dotted, "\"%s\" must be an array" % dotted, lines)
			else:
				var arr: Array = value as Array
				if arr.size() != expected_size:
					_add_error(
						dotted,
						"\"%s\" must have exactly %d entries" % [dotted, expected_size],
						lines
					)
				else:
					for entry: Variant in arr:
						if not _is_integral(entry):
							_add_error(dotted, "\"%s\" entries must be integers" % dotted, lines)
							break
		"map":
			if not (value is Dictionary):
				_add_error(dotted, "\"%s\" must be an object" % dotted, lines)
			else:
				var entries: Dictionary = value as Dictionary
				if entries.is_empty():
					_add_error(dotted, "\"%s\" must not be empty" % dotted, lines)
				else:
					var entry_spec: Array = node["entry"]
					var observed: Array = entries.keys()
					observed.sort()
					for observed_key: Variant in observed:
						var entry_dotted: String = "%s.%s" % [dotted, observed_key]
						for child: Dictionary in entry_spec:
							_validate_node(entries[observed_key], child, entry_dotted, lines)


## True for an [int] or a fractionless [float] — Godot's JSON parser hands every number back
## as TYPE_FLOAT (probed on the pinned 4.7 build), so "is this an int" must mean "is this
## integral", never "is this literally typed int".
func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var as_float: float = value
		return as_float == floor(as_float)
	return false


func _add_error(dotted_path: String, message: String, lines: PackedStringArray) -> void:
	var err: RulesError = RulesError.new()
	err.path = dotted_path
	err.message = message
	err.line = _attribute_line(lines, dotted_path)
	errors.append(err)


## Attributes a 1-based document line to `dotted_path` by scanning the raw text (the parsed
## Variant carries no line info). Walks the path segment by segment: find the parent key's
## token, then search forward from there for the next segment's token. Falls back to the
## last segment that WAS found (§13.4 ambiguity resolution, decisions.md M0-T2), and finally
## to line 1 if no segment is found at all — 0 is reserved exclusively for file-level errors.
func _attribute_line(lines: PackedStringArray, dotted_path: String) -> int:
	var current_line: int = -1
	var search_from: int = 0
	for segment: String in dotted_path.split("."):
		var token: String = "\"%s\"" % segment
		var found: int = _find_token_line(lines, token, search_from)
		if found == -1:
			break
		current_line = found
		search_from = found
	if current_line == -1:
		return 1
	return current_line + 1


## First line index at or after `from_index` containing `token`, or -1.
func _find_token_line(lines: PackedStringArray, token: String, from_index: int) -> int:
	for i: int in range(from_index, lines.size()):
		if lines[i].contains(token):
			return i
	return -1
