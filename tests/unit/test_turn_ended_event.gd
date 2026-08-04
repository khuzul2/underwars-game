## TurnEndedEvent — the project's FIRST concrete [Event] subclass. GDD §11.1 (Layered Design,
## **binding**), §3.3 (Turn Model), §11.2, §11.3, §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 706): "**EventBus**: typed events emitted by apply() (hex\_changed, unit\_moved,
##         combat\_resolved, breach\_triggered, noise\_ping, collapse, research\_done,
##         wave\_spawned, victory, ...). Renderer/UI subscribe; **the sim never calls them**."
##   §11.1 (line 707): "**Determinism rules:** iterate collections in stable ID order ...
##         GameState.hash() (FNV over canonical serialization) must be reproducible."
##   §3.3  (line 137): "Sequential player turns (IGOUGO, Civ-style), **fixed order by player
##         index**, then a **World phase**."
##
## `docs/decisions.md` was re-scanned end to end this iteration: the ONLY logged §12.1 override is
## (AU)(i), irrelevant here, and **NO logged override touches §11.1 or §3.3**. The binding prior
## resolution is M0-T3 **(f)**: §11.1's printed event names are ILLUSTRATIVE and open-ended, so
## `scripts/core/event.gd` and `scripts/core/event_bus.gd` declare NO vocabulary — a concrete
## event owns its own name. `turn_ended` is not one of the nine names §11.1 lists (that list ends
## with ", ..."), which is precisely why the vocabulary may not live in the infrastructure.
## The payload shape below is a §13.4 resolution lettered **(AV)** ((AU) must NOT be renumbered):
##   (AV) TurnEndedEvent carries `player_index` (who just ended), `next_player_index` (who is up)
##       and `turn` (the turn number AFTER the advance), and `to_dict()` calls the base FIRST so
##       "type" stays the FIRST key (the `scripts/core/event.gd` line 23 contract).
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY; the base class via the script's `get_base_script`.
##
## The source scans at the bottom are written FRESH for `scripts/sim/events/turn_ended_event.gd`.
extends GutTest

const TURN_ENDED_PATH: String = "res://scripts/sim/events/turn_ended_event.gd"
const EVENT_PATH: String = "res://scripts/core/event.gd"
const EVENT_BUS_PATH: String = "res://scripts/core/event_bus.gd"

## (AV) — the canonical key order of `to_dict()`: "type" FIRST, then the payload in declaration
## order.
const EXPECTED_DICT_KEYS: Array[String] = [
	"type", "player_index", "next_player_index", "turn"
]

## §11.1 — tokens that would make the sim core engine-bound.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"Time.",
	"OS.",
	"queue_free(",
]

## §11.1 "Renderer/UI subscribe; **the sim never calls them**".
const RENDERER_TOKENS: Array[String] = [
	"MapRenderer",
	"CameraRig",
	"HexPicker",
	"HexLayout",
	"MultiMesh",
	"Camera3D",
	"Node3D",
]

## §3.2 line 133 "If turn 200 is reached (configurable)" / §12.1 `victory.turn_limit` — M6.
const VICTORY_TURN_LIMIT_TOKEN: String = "200"

## The COMPLETE public surface of TurnEndedEvent: one const, three payload fields, `to_dict`.
## `_init` is excluded from the collected list by the leading underscore and is pinned by
## construction. `type` is INHERITED from [Event] and is not re-declared here.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["to_dict"]
const REQUIRED_PUBLIC_VARS: Array[String] = ["player_index", "next_player_index", "turn"]
const REQUIRED_PUBLIC_CONSTS: Array[String] = ["TYPE_NAME"]

## Doc-comment sections accepted by the S5 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§3.3"]


# =============================================================================================
# A. IDENTITY AND PAYLOAD (§11.1 line 706, §3.3 line 137)
# =============================================================================================

## §11.1 — TurnEndedEvent IS an [Event]: the bus dispatches by `type`, so the subclass must carry
## the base's write-once type field. Asserted through the script's base script, never `is Node`.
func test_turn_ended_event_is_an_event() -> void:
	var event: TurnEndedEvent = TurnEndedEvent.new(0, 1, 1)
	var own_script: Script = event.get_script()
	assert_not_null(own_script, "sanity: the instance carries its script")
	if own_script == null:
		return
	var base_script: Script = own_script.get_base_script()
	assert_not_null(base_script, "§11.1: TurnEndedEvent extends the Event base")
	if base_script == null:
		return
	assert_eq(
		base_script.resource_path,
		EVENT_PATH,
		"§11.1: TurnEndedEvent must extend %s so the EventBus can dispatch it" % EVENT_PATH
	)


## §11.1 — the type name is exactly `turn_ended`, declared once as the event's OWN constant, and
## the instance's inherited `type` field carries it.
func test_the_type_name_is_turn_ended() -> void:
	assert_eq(
		TurnEndedEvent.TYPE_NAME, &"turn_ended", "§11.1: the event's type is exactly \"turn_ended\""
	)
	assert_eq(
		typeof(TurnEndedEvent.TYPE_NAME),
		TYPE_STRING_NAME,
		"§11.1: an event type is a StringName, as EventBus.subscribe expects"
	)
	var event: TurnEndedEvent = TurnEndedEvent.new(2, 0, 2)
	assert_eq(
		event.type, TurnEndedEvent.TYPE_NAME, "§11.1: the constructor sets the inherited type field"
	)


## (AV)/§3.3 — the three payload fields are carried verbatim from the constructor, in the
## documented meaning: who just ended, who is up next, and the turn number AFTER the advance.
func test_the_payload_is_carried_verbatim() -> void:
	var event: TurnEndedEvent = TurnEndedEvent.new(2, 0, 2)
	assert_eq(event.player_index, 2, "§3.3: player_index is the player whose turn just ended")
	assert_eq(event.next_player_index, 0, "§3.3: next_player_index is the player who is up")
	assert_eq(event.turn, 2, "§3.3: turn is the turn number AFTER the advance")

	var later: TurnEndedEvent = TurnEndedEvent.new(1, 2, 7)
	assert_eq(later.player_index, 1, "§3.3: a second event carries its own payload")
	assert_eq(later.next_player_index, 2, "§3.3: a second event carries its own payload")
	assert_eq(later.turn, 7, "§3.3: a second event carries its own payload")


# =============================================================================================
# B. to_dict() (§11.1 line 707 canonical serialization; scripts/core/event.gd line 23)
# =============================================================================================

## §11.1 — "type" is the FIRST key and the payload follows in DECLARATION order. The base inserts
## "type" first precisely so a subclass's keys land after it; a subclass that builds its own
## Dictionary from scratch breaks the canonical order for every logged replay.
func test_to_dict_puts_type_first_then_the_payload_in_declaration_order() -> void:
	var event: TurnEndedEvent = TurnEndedEvent.new(2, 0, 2)
	var serialized: Dictionary = event.to_dict()
	assert_eq(
		serialized.keys(),
		["type", "player_index", "next_player_index", "turn"] as Array,
		"§11.1: to_dict() is {\"type\" FIRST, player_index, next_player_index, turn}"
	)
	assert_eq(
		EXPECTED_DICT_KEYS.size(), 4, "sanity: the documented key order has four entries"
	)
	assert_eq(serialized.get("type"), "turn_ended", "§11.1: the base renders type as a String")
	assert_eq(serialized.get("player_index"), 2, "§3.3: the acting player is serialized")
	assert_eq(serialized.get("next_player_index"), 0, "§3.3: the next player is serialized")
	assert_eq(serialized.get("turn"), 2, "§3.3: the turn AFTER the advance is serialized")


## §11.1 — a FRESH Dictionary every call, so a logger can never alias (and then mutate) the
## event's internals (the M1-T9 item 6 freshness lesson, pinned with `is_same` IDENTITY).
func test_to_dict_returns_a_fresh_dictionary_every_call() -> void:
	var event: TurnEndedEvent = TurnEndedEvent.new(1, 2, 3)
	var first: Dictionary = event.to_dict()
	var second: Dictionary = event.to_dict()
	assert_eq(first.keys(), second.keys(), "§11.1: the serialization is reproducible")
	assert_false(is_same(first, second), "§11.1: to_dict() hands back a fresh Dictionary")
	first["turn"] = 999
	assert_eq(
		event.to_dict().get("turn"), 3, "§11.1: mutating a returned Dictionary cannot reach the event"
	)
	assert_eq(event.turn, 3, "§11.1: mutating a returned Dictionary cannot reach the payload")


## §11.1 determinism — the serialization is a pure function of the payload: equal payloads
## serialize equally, different payloads do not collide. Compared field by field, because
## Dictionary equality in GDScript is not a content comparison we want to rely on here.
func test_to_dict_is_a_pure_function_of_the_payload() -> void:
	assert_eq(
		_serialized_values(TurnEndedEvent.new(1, 2, 3)),
		_serialized_values(TurnEndedEvent.new(1, 2, 3)),
		"§11.1: equal payloads serialize identically"
	)
	assert_ne(
		_serialized_values(TurnEndedEvent.new(1, 2, 3)),
		_serialized_values(TurnEndedEvent.new(2, 1, 3)),
		"§11.1: swapping actor and next player is a different event"
	)
	assert_ne(
		_serialized_values(TurnEndedEvent.new(1, 2, 3)),
		_serialized_values(TurnEndedEvent.new(1, 2, 4)),
		"§11.1: a different turn number is a different event"
	)


# =============================================================================================
# C. THE BUS CARRIES IT (§11.1 line 706 "Renderer/UI subscribe; the sim never calls them")
# =============================================================================================

## §11.1 — the existing [EventBus] dispatches the new subclass by its type with no change to the
## infrastructure: a subscriber on `turn_ended` receives the typed instance itself, not a copy.
func test_the_event_bus_dispatches_the_new_subclass_unchanged() -> void:
	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(TurnEndedEvent.TYPE_NAME, handler.on_event)
	var event: TurnEndedEvent = TurnEndedEvent.new(2, 0, 2)
	bus.emit(event)
	assert_eq(handler.calls, 1, "§11.1: a subscriber on turn_ended is delivered the event")
	assert_true(
		is_same(handler.last_event, event), "§11.1: the bus delivers the very instance emitted"
	)
	assert_eq(handler.payloads, [Vector3i(2, 0, 2)] as Array[Vector3i], "§11.1: payload intact")


## M0-T3 (f) — a subscriber on a DIFFERENT type is not disturbed: the new vocabulary entry does
## not leak into the infrastructure's dispatch.
func test_a_subscriber_on_another_type_is_not_disturbed() -> void:
	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(&"some_other_event", handler.on_event)
	bus.emit(TurnEndedEvent.new(0, 1, 1))
	assert_eq(handler.calls, 0, "M0-T3 (f): dispatch is by type — nothing else is delivered")


# =============================================================================================
# D. MECHANICAL SOURCE SCANS ON scripts/sim/events/turn_ended_event.gd
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(TURN_ENDED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % TURN_ENDED_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			TURN_ENDED_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % TURN_ENDED_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % TURN_ENDED_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R); an event is a payload, so
## it names no renderer either.
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(TURN_ENDED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % TURN_ENDED_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				TURN_ENDED_PATH, banned
			]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [
				TURN_ENDED_PATH, banned
			]
		)


## S3 §13.4/M1-T9 — an event carries a payload, nothing else: no loader (`RulesError` ABSENT so a
## second loader cannot grow here), no `Object.hash()` override, no §3.2/§12.1 turn limit, and no
## knowledge of the Command that emitted it (the arrow runs sim -> bus -> renderer, one way).
func test_source_is_payload_only() -> void:
	var code: String = _code_text(TURN_ENDED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % TURN_ENDED_PATH)
	assert_false(
		code.contains("RulesError"),
		"M1-T9: %s loads no document and must not carry a loader" % TURN_ENDED_PATH
	)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			TURN_ENDED_PATH
		]
	)
	assert_false(
		code.contains(VICTORY_TURN_LIMIT_TOKEN),
		"§3.2/§12.1: the turn limit is M6 — %s must not contain %s" % [
			TURN_ENDED_PATH, VICTORY_TURN_LIMIT_TOKEN
		]
	)
	assert_false(
		code.contains("Command"),
		"§11.1: an event is a payload — %s must not know which Command emitted it" % TURN_ENDED_PATH
	)


## S4 M0-T3 (f) — THE INFRASTRUCTURE STAYS FREE OF THE VOCABULARY, and this task edits neither
## `scripts/core/event.gd` nor `scripts/core/event_bus.gd`. The event owns its own name; the base
## owns the "type first" contract.
func test_the_event_infrastructure_declares_no_vocabulary() -> void:
	var event_code: String = _code_text(EVENT_PATH)
	var bus_code: String = _code_text(EVENT_BUS_PATH)
	assert_false(event_code.is_empty(), "sanity: %s must be readable" % EVENT_PATH)
	assert_false(bus_code.is_empty(), "sanity: %s must be readable" % EVENT_BUS_PATH)
	assert_false(
		event_code.contains("turn_ended"),
		"M0-T3 (f): the Event base declares no vocabulary — the name lives on the subclass"
	)
	assert_false(
		bus_code.contains("turn_ended"), "M0-T3 (f): the EventBus declares no vocabulary"
	)
	assert_false(
		event_code.contains("TurnEnded"), "M0-T3 (f): the Event base names no concrete subclass"
	)


## S5 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: one const, three payload
## fields and `to_dict`. A MISSING member fails, and an EXTRA one (a second const, a phase enum, a
## timestamp) fails too.
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(TURN_ENDED_PATH, public_functions, undocumented)

	var event: TurnEndedEvent = TurnEndedEvent.new(0, 1, 1)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, TURN_ENDED_PATH]
		)
		assert_true(
			event.has_method(required),
			"§11.2: %s must be callable on a TurnEndedEvent instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			TURN_ENDED_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(TURN_ENDED_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public FIELD surface of %s is exactly %s" % [
			TURN_ENDED_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)
	assert_eq(
		_collect_public_consts(TURN_ENDED_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.4: %s declares exactly one public const (its OWN type name)" % TURN_ENDED_PATH
	)


## S6 §11.1/§11.2 — TurnEndedEvent is a pure [RefCounted] in `scripts/sim/events/`: concrete
## events carry SIM payloads, so they live under `sim/`, while `scripts/core/event.gd` stays pure
## infrastructure (§11.2's printed file list is illustrative — the M0-T3 (f) / M1-T9 (AT)
## precedent). Asserted through get_class() — `is Node` would be a PARSE ERROR here.
func test_turn_ended_event_is_a_pure_refcounted_in_scripts_sim_events() -> void:
	assert_true(
		FileAccess.file_exists(TURN_ENDED_PATH),
		"§11.2: TurnEndedEvent belongs at %s" % TURN_ENDED_PATH
	)
	assert_eq(
		TurnEndedEvent.new(0, 1, 1).get_class(),
		"RefCounted",
		"§11.1: TurnEndedEvent must be a pure RefCounted"
	)


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Counts deliveries and records the payload of every TurnEndedEvent it receives.
class CountingHandler extends RefCounted:
	var calls: int = 0
	var last_event: Event = null
	var payloads: Array[Vector3i] = []

	func on_event(event: Event) -> void:
		calls += 1
		last_event = event
		var ended: TurnEndedEvent = event as TurnEndedEvent
		if ended != null:
			payloads.append(Vector3i(ended.player_index, ended.next_player_index, ended.turn))


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## An event's canonical serialization flattened to a comparable String array: the key order plus
## each value, so two events can be compared without relying on Dictionary equality semantics.
func _serialized_values(event: TurnEndedEvent) -> Array[String]:
	var out: Array[String] = []
	var serialized: Dictionary = event.to_dict()
	for key: Variant in serialized.keys():
		out.append("%s=%s" % [str(key), str(serialized[key])])
	return out


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


## Every top-level public `var` declared by a source file, in source order.
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


## Every top-level public `const` declared by a source file, in source order.
func _collect_public_consts(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with("const "):
			continue
		var rest: String = raw_line.substr(6)
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
