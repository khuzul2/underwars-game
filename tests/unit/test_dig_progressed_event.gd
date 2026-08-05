## DigProgressedEvent — the project's FOURTH concrete [Event] subclass. GDD §11.1 (Layered Design,
## **binding**), §3.4 step 4 (the tick it announces), §4.2 (the worker-turns it spends), §11.2,
## §11.3, §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 706): "**EventBus**: typed events emitted by apply() (hex\_changed, unit\_moved,
##         combat\_resolved, breach\_triggered, noise\_ping, collapse, research\_done,
##         wave\_spawned, victory, ...). Renderer/UI subscribe; **the sim never calls them**."
##   §11.1 (line 708): "**Save/load & replay:** save = JSON snapshot of GameState (+ ruleset
##         version + seed + command log)." — the reason `to_dict()` flattens the axial hex into the
##         two JSON SCALARS `hex_q`/`hex_r`: a `Vector2i` is not a JSON scalar.
##   §3.4  (line 148, step 4): "Dig progress ticks; completed digs apply yields, then **Breach
##         checks** (§4.6), then **Noise pings** (§4.8)."
##   §4.2  (line 197): "Dig time is **total worker-turns**; multiple workers on adjacent hexes may
##         work the same target (**max 2 simultaneous diggers per hex**)." — the reason the event
##         carries `digger_count`: the worker-turns SPENT by this tick are the crew size, and the
##         renderer/UI cannot recompute them from the remainder alone.
##
## `docs/decisions.md` was re-scanned this iteration: the only logged §12.1/§4.2 overrides are
## **(AU)(i)** and **(AW)(i)**, neither of which touches §11.1, §3.4 or §4.2 line 197. The binding
## prior resolution is M0-T3 **(f)**: §11.1's printed event names are ILLUSTRATIVE and open-ended,
## so `scripts/core/event.gd` and `scripts/core/event_bus.gd` declare NO vocabulary — a concrete
## event owns its own name, and `dig_progressed` is not one of the nine names §11.1 lists. The
## payload shape is a §13.4 resolution to be lettered **(BA)(v)** by Land ((AU)–(AZ) must NOT be
## renumbered): `player_index` (whose start-of-turn tick spent the worker-turns), `hex`,
## `digger_count` (the worker-turns spent) and `remaining_turns` (the site's remainder AFTER the
## tick), serialized base-FIRST so "type" stays the first key.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY; the base class via the script's `get_base_script`.
##
## The source scans at the bottom are written FRESH for
## `scripts/sim/events/dig_progressed_event.gd`.
extends GutTest

const DIG_PROGRESSED_PATH: String = "res://scripts/sim/events/dig_progressed_event.gd"
const EVENT_PATH: String = "res://scripts/core/event.gd"
const EVENT_BUS_PATH: String = "res://scripts/core/event_bus.gd"

## (BA)(v) — the canonical key order of `to_dict()`: "type" FIRST, then the payload in declaration
## order, with the axial hex flattened into two JSON scalars.
const EXPECTED_DICT_KEYS: Array[String] = [
	"type",
	"player_index",
	"hex_q",
	"hex_r",
	"digger_count",
	"remaining_turns",
]

## §4.1 "axial coordinates (q, r)" — the hexes the fixtures announce.
const SAMPLE_HEX: Vector2i = Vector2i(1, -1)
const OTHER_HEX: Vector2i = Vector2i(-2, 3)

## §4.2 line 197 "max 2 simultaneous diggers per hex" — the crew size the fixture spends.
const FIXTURE_DIGGERS: int = 2

## §4.2 line 186 "Dense Granite | 4" minus the two worker-turns above.
const FIXTURE_REMAINING: int = 2

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
	"Input.",
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

## §4.2's nine Solid terrain ids, the Cave id and §5.1's seven resources. FORBIDDEN: an event is a
## PAYLOAD, and adding content must stay a DATA edit ((T)/(AH)/(AU)(iv), §13.5's M6 canary).
const FORBIDDEN_VOCABULARY: Array[String] = [
	"soft_dirt",
	"hard_rock",
	"dense_granite",
	"artificial_granite",
	"rubble",
	"gold_vein",
	"iron_vein",
	"magestone_crust",
	"mithril_seam",
	"plain_floor",
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §13.6 — §4.2's dig/vein numbers must never appear in an event payload class. Only 0 and 1 are
## permitted standalone (field initialisers).
const FORBIDDEN_NUMERALS: Array[String] = [
	"2", "3", "4", "10", "15", "25", "60", "120", "150", "200", "250",
]
const PERMITTED_NUMERALS: Array[String] = ["0", "1"]

## The COMPLETE public surface: ONE const, FOUR payload fields, `to_dict`. `_init` is excluded by
## the leading underscore and is pinned by construction. `type` is INHERITED from [Event].
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["to_dict"]
const REQUIRED_PUBLIC_VARS: Array[String] = [
	"player_index", "hex", "digger_count", "remaining_turns"
]
const REQUIRED_PUBLIC_CONSTS: Array[String] = ["TYPE_NAME"]

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§4.2", "§3.4"]


# =============================================================================================
# A. IDENTITY AND PAYLOAD (§11.1 line 706, §3.4 step 4, §4.2 line 197)
# =============================================================================================

## §11.1 — DigProgressedEvent IS an [Event]: the bus dispatches by `type`, so the subclass must
## carry the base's write-once type field. Asserted through the script's base script, never
## `is Node`.
func test_dig_progressed_event_is_an_event() -> void:
	var own_script: Script = _event().get_script()
	assert_not_null(own_script, "sanity: the instance carries its script")
	if own_script == null:
		return
	var base_script: Script = own_script.get_base_script()
	assert_not_null(base_script, "§11.1: DigProgressedEvent extends the Event base")
	if base_script == null:
		return
	assert_eq(
		base_script.resource_path,
		EVENT_PATH,
		"§11.1: DigProgressedEvent must extend %s so the EventBus can dispatch it" % EVENT_PATH
	)


## §11.1 / M0-T3 (f) — the type name is exactly `dig_progressed`, declared once as the event's OWN
## constant, and the instance's INHERITED `type` field carries it (the constructor must call
## `super(TYPE_NAME)`).
func test_the_type_name_is_dig_progressed() -> void:
	assert_eq(
		DigProgressedEvent.TYPE_NAME,
		&"dig_progressed",
		"§11.1: the event's type is exactly \"dig_progressed\""
	)
	assert_eq(
		typeof(DigProgressedEvent.TYPE_NAME),
		TYPE_STRING_NAME,
		"§11.1: an event type is a StringName, as EventBus.subscribe expects"
	)
	assert_eq(_event().type, DigProgressedEvent.TYPE_NAME, "§11.1: the constructor sets `type`")
	for other: StringName in [
		DigStartedEvent.TYPE_NAME, DigCancelledEvent.TYPE_NAME, TurnEndedEvent.TYPE_NAME
	]:
		assert_ne(
			DigProgressedEvent.TYPE_NAME, other, "M0-T3 (f): each concrete event owns a DISTINCT name"
		)


## (BA)(v)/§4.2 — the four payload fields are carried verbatim from the constructor: whose tick
## spent the worker-turns, which hex progressed, how many worker-turns were spent (the crew size)
## and what remains AFTER the tick.
func test_the_payload_is_carried_verbatim() -> void:
	var progressed: DigProgressedEvent = DigProgressedEvent.new(
		1, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_REMAINING
	)
	assert_eq(progressed.player_index, 1, "(BA)(v): the player whose turn ticked the site")
	assert_eq(progressed.hex, SAMPLE_HEX, "§4.1: the hex that progressed")
	assert_eq(progressed.digger_count, FIXTURE_DIGGERS, "§4.2 line 197: the worker-turns SPENT")
	assert_eq(progressed.remaining_turns, FIXTURE_REMAINING, "§4.2: the remainder AFTER the tick")

	var other: DigProgressedEvent = DigProgressedEvent.new(0, OTHER_HEX, 1, 0)
	assert_eq(other.player_index, 0, "(BA)(v): a second event carries its own payload")
	assert_eq(other.hex, OTHER_HEX, "(BA)(v): a second event carries its own payload")
	assert_eq(other.digger_count, 1, "(BA)(v): a second event carries its own payload")
	assert_eq(other.remaining_turns, 0, "§4.2: a completing tick reports a remainder of ZERO")


# =============================================================================================
# B. to_dict() (§11.1 line 707 canonical serialization / line 708 "save = JSON snapshot")
# =============================================================================================

## §11.1 — "type" is the FIRST key and the payload follows in DECLARATION order, with the axial hex
## flattened into `hex_q`/`hex_r`. A subclass that builds its own Dictionary from scratch breaks
## the canonical order for every logged replay.
func test_to_dict_puts_type_first_then_the_payload_in_declaration_order() -> void:
	var serialized: Dictionary = _event().to_dict()
	assert_eq(
		serialized.keys(),
		["type", "player_index", "hex_q", "hex_r", "digger_count", "remaining_turns"] as Array,
		"§11.1: to_dict() is {\"type\" FIRST, player_index, hex_q, hex_r, digger_count, "
			+ "remaining_turns}"
	)
	assert_eq(EXPECTED_DICT_KEYS.size(), 6, "sanity: the documented key order has six entries")
	assert_eq(serialized.get("type"), "dig_progressed", "§11.1: the base renders type as a String")
	assert_eq(serialized.get("player_index"), 1, "(BA)(v): the ticking player is serialized")
	assert_eq(serialized.get("hex_q"), SAMPLE_HEX.x, "§11.1 line 708: q is a JSON scalar")
	assert_eq(serialized.get("hex_r"), SAMPLE_HEX.y, "§11.1 line 708: r is a JSON scalar")
	assert_eq(serialized.get("digger_count"), FIXTURE_DIGGERS, "§4.2: the crew size is serialized")
	assert_eq(
		serialized.get("remaining_turns"), FIXTURE_REMAINING, "§4.2: the remainder is serialized"
	)


## §11.1 line 708 — EVERY serialized value is a JSON SCALAR, and the whole Dictionary survives a
## real `JSON.stringify` -> `JSON.parse_string` round trip WITH ITS KEY ORDER INTACT. `sort_keys`
## defaults to `true` on the pinned 4.7 build ((AW)(vii)(a)), so the third argument is `false`.
func test_every_serialized_value_is_a_json_scalar_and_survives_a_round_trip() -> void:
	var serialized: Dictionary = _event().to_dict()
	for key: Variant in serialized.keys():
		var kind: int = typeof(serialized[key])
		assert_true(
			kind == TYPE_STRING or kind == TYPE_INT or kind == TYPE_BOOL,
			"§11.1 line 708: \"%s\" must serialize to a JSON scalar, not %d" % [str(key), kind]
		)
	assert_false(
		serialized.has("hex"),
		"§11.1 line 708: the raw Vector2i must NOT be serialized — it is not a JSON scalar"
	)

	var parsed: Variant = JSON.parse_string(JSON.stringify(serialized, "", false))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "§11.1 line 708: the payload IS valid JSON")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var round_tripped: Dictionary = parsed
	var keys_as_strings: Array[String] = []
	for key: Variant in round_tripped.keys():
		keys_as_strings.append(str(key))
	assert_eq(
		keys_as_strings,
		EXPECTED_DICT_KEYS,
		"§11.1 line 708: the JSON round trip must preserve the canonical key ORDER"
	)


## §11.1 — a FRESH Dictionary every call, so a logger can never alias (and then mutate) the event's
## internals (the M1-T9 item 6 freshness lesson, pinned with `is_same` IDENTITY).
func test_to_dict_returns_a_fresh_dictionary_every_call() -> void:
	var event: DigProgressedEvent = _event()
	var first: Dictionary = event.to_dict()
	var second: Dictionary = event.to_dict()
	assert_eq(first.keys(), second.keys(), "§11.1: the serialization is reproducible")
	assert_false(is_same(first, second), "§11.1: to_dict() hands back a fresh Dictionary")
	first["remaining_turns"] = 999
	assert_eq(
		event.to_dict().get("remaining_turns"),
		FIXTURE_REMAINING,
		"§11.1: mutating a returned Dictionary cannot reach the event"
	)


## §11.1 determinism — the serialization is a pure function of the payload: equal payloads
## serialize equally, and EVERY field distinguishes (including the two hex components separately,
## which a fold that dropped one would hide).
func test_to_dict_is_a_pure_function_of_every_payload_field() -> void:
	var base: Array[String] = _serialized_values(_event())
	assert_eq(base, _serialized_values(_event()), "§11.1: equal payloads serialize identically")
	var mutants: Array[DigProgressedEvent] = [
		DigProgressedEvent.new(0, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_REMAINING),
		DigProgressedEvent.new(
			1, Vector2i(SAMPLE_HEX.x + 1, SAMPLE_HEX.y), FIXTURE_DIGGERS, FIXTURE_REMAINING
		),
		DigProgressedEvent.new(
			1, Vector2i(SAMPLE_HEX.x, SAMPLE_HEX.y + 1), FIXTURE_DIGGERS, FIXTURE_REMAINING
		),
		DigProgressedEvent.new(1, SAMPLE_HEX, 1, FIXTURE_REMAINING),
		DigProgressedEvent.new(1, SAMPLE_HEX, FIXTURE_DIGGERS, 0),
	]
	for mutant: DigProgressedEvent in mutants:
		assert_ne(
			base,
			_serialized_values(mutant),
			"§11.1: every payload field must distinguish two events (%s)" % str(mutant.to_dict())
		)


# =============================================================================================
# C. THE BUS CARRIES IT (§11.1 line 706 "Renderer/UI subscribe; the sim never calls them")
# =============================================================================================

## §11.1 / M0-T3 (f) — the existing [EventBus] dispatches the new subclass by its type with NO
## change to the infrastructure, and FIVE concrete events now share the bus without crossing.
func test_dispatch_is_by_type_and_the_five_concrete_events_do_not_cross() -> void:
	var bus: EventBus = EventBus.new()
	var mine: CountingHandler = CountingHandler.new()
	var others: CountingHandler = CountingHandler.new()
	bus.subscribe(DigProgressedEvent.TYPE_NAME, mine.on_event)
	for other: StringName in [
		DigStartedEvent.TYPE_NAME,
		DigCancelledEvent.TYPE_NAME,
		DigCompletedEvent.TYPE_NAME,
		TurnEndedEvent.TYPE_NAME,
	]:
		bus.subscribe(other, others.on_event)

	var event: DigProgressedEvent = _event()
	bus.emit(event)
	assert_eq(mine.calls, 1, "§11.1: a subscriber on dig_progressed is delivered the event")
	assert_true(
		is_same(mine.last_event, event), "§11.1: the bus delivers the very instance emitted"
	)
	assert_eq(others.calls, 0, "M0-T3 (f): no other subscription hears it")

	bus.emit(TurnEndedEvent.new(0, 1, 1))
	assert_eq(mine.calls, 1, "M0-T3 (f): the dig_progressed subscriber is not disturbed")
	assert_eq(others.calls, 1, "M0-T3 (f): each subscriber hears exactly its own type")


# =============================================================================================
# D. MECHANICAL SOURCE SCANS on scripts/sim/events/dig_progressed_event.gd
#    Written FRESH for this file — it inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(DIG_PROGRESSED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_PROGRESSED_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	assert_null(
		float_literal.search(code),
		"§11.1: integer math only — %s must contain no float literal" % DIG_PROGRESSED_PATH
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % DIG_PROGRESSED_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R); an event is a payload, so it
## names no renderer either.
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(DIG_PROGRESSED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_PROGRESSED_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				DIG_PROGRESSED_PATH, banned
			]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [
				DIG_PROGRESSED_PATH, banned
			]
		)


## S3 §13.4/M1-T9 — an event carries a payload, nothing else: no loader (`RulesError`/`DigRules`
## ABSENT so a second source of dig numbers cannot grow here), no `Object.hash()` override, no
## `GameState`/`DigSite`/`DigTick` reach-back, and no knowledge of the Command that emitted it.
func test_source_is_payload_only() -> void:
	var code: String = _code_text(DIG_PROGRESSED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_PROGRESSED_PATH)
	for banned: String in [
		"RulesError", "RulesLoader", "DigRules", "DigSite", "DigTick", "GameState", "Command"
	]:
		assert_false(
			code.contains(banned),
			"M1-T9/(BA)(v): an event is a payload — %s must not name %s" % [
				DIG_PROGRESSED_PATH, banned
			]
		)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			DIG_PROGRESSED_PATH
		]
	)


## S4 M0-T3 (f) — THE INFRASTRUCTURE STAYS FREE OF THE VOCABULARY, and this task edits neither
## `scripts/core/event.gd` nor `scripts/core/event_bus.gd`.
func test_the_event_infrastructure_declares_no_vocabulary() -> void:
	var event_code: String = _code_text(EVENT_PATH)
	var bus_code: String = _code_text(EVENT_BUS_PATH)
	assert_false(event_code.is_empty(), "sanity: %s must be readable" % EVENT_PATH)
	assert_false(bus_code.is_empty(), "sanity: %s must be readable" % EVENT_BUS_PATH)
	for banned: String in [
		"dig_progressed", "DigProgressed", "dig_completed", "DigCompleted", "dig_started",
		"dig_cancelled", "turn_ended"
	]:
		assert_false(
			event_code.contains(banned),
			"M0-T3 (f): the Event base declares no vocabulary — it must not name %s" % banned
		)
		assert_false(
			bus_code.contains(banned),
			"M0-T3 (f): the EventBus declares no vocabulary — it must not name %s" % banned
		)


## S5 (T)/(AH)/(AU)(iv)/§13.6 — NO TERRAIN OR RESOURCE WHITELIST, and NOT ONE printed §4.2 number.
## The event reports what happened; every number in it is supplied by the rule that read §12.1 data.
func test_source_carries_no_vocabulary_and_hard_codes_no_gdd_number() -> void:
	var lowered: String = _code_text(DIG_PROGRESSED_PATH).to_lower()
	assert_false(lowered.is_empty(), "sanity: %s must be readable" % DIG_PROGRESSED_PATH)
	for banned: String in FORBIDDEN_VOCABULARY:
		assert_false(
			lowered.contains(banned),
			"(T)/(AH)/(AU)(iv): terrain and resource ids are DATA — %s must not name \"%s\"" % [
				DIG_PROGRESSED_PATH, banned
			]
		)
	assert_false(lowered.contains("enum "), "(AU)(iv): the vocabulary is never an enum")

	var code: String = _code_text(DIG_PROGRESSED_PATH)
	var numeral: RegEx = RegEx.new()
	assert_eq(
		numeral.compile("(?<![0-9A-Za-z._])([0-9]+)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the standalone-numeral pattern compiles"
	)
	for found: RegExMatch in numeral.search_all(code):
		assert_true(
			PERMITTED_NUMERALS.has(found.get_string()),
			"§13.6: only %s are permitted in %s — found \"%s\"" % [
				str(PERMITTED_NUMERALS), DIG_PROGRESSED_PATH, found.get_string()
			]
		)
	assert_eq(FORBIDDEN_NUMERALS.size(), 11, "sanity: every §4.2/§3.2 numeral is covered")


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: one const, four payload
## fields and `to_dict`. A MISSING member fails, and an EXTRA one (a `total_turns` the renderer does
## not need, a timestamp) fails too. Every declaration is statically typed.
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_PROGRESSED_PATH, public_functions, undocumented)

	var event: DigProgressedEvent = _event()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, DIG_PROGRESSED_PATH]
		)
		assert_true(
			event.has_method(required),
			"§11.2: %s must be callable on a DigProgressedEvent instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			DIG_PROGRESSED_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(DIG_PROGRESSED_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public FIELD surface of %s is exactly %s" % [
			DIG_PROGRESSED_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)
	assert_eq(
		_collect_public_consts(DIG_PROGRESSED_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.4: %s declares exactly one public const (its OWN type name)" % DIG_PROGRESSED_PATH
	)
	assert_eq(
		_untyped_declarations(DIG_PROGRESSED_PATH),
		[] as Array[String],
		"§11.3: static typing everywhere — every `var` in %s must be `var x: T = ...`" % [
			DIG_PROGRESSED_PATH
		]
	)


## S7 §11.1/§11.2 — DigProgressedEvent is a pure [RefCounted] in `scripts/sim/events/`: concrete
## events carry SIM payloads, so they live under `sim/` while `scripts/core/event.gd` stays pure
## infrastructure. Asserted through get_class() — `is Node` would be a PARSE ERROR here.
func test_dig_progressed_event_is_a_pure_refcounted_in_scripts_sim_events() -> void:
	assert_true(
		FileAccess.file_exists(DIG_PROGRESSED_PATH),
		"§11.2: DigProgressedEvent belongs at %s" % DIG_PROGRESSED_PATH
	)
	assert_eq(
		_event().get_class(), "RefCounted", "§11.1: DigProgressedEvent must be a pure RefCounted"
	)


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Counts deliveries and remembers the last event, for any Event type.
class CountingHandler extends RefCounted:
	var calls: int = 0
	var last_event: Event = null

	func on_event(event: Event) -> void:
		calls += 1
		last_event = event


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A fixture event: player 1's tick spent two worker-turns on SAMPLE_HEX, leaving two.
func _event() -> DigProgressedEvent:
	return DigProgressedEvent.new(1, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_REMAINING)


## An event's canonical serialization flattened to a comparable String array.
func _serialized_values(event: DigProgressedEvent) -> Array[String]:
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


## Every `var` declaration in a source file that is NOT of the form `var name: Type = ...`.
func _untyped_declarations(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _code_text(path).split("\n"):
		var stripped: String = raw_line.strip_edges()
		if not stripped.begins_with("var "):
			continue
		var colon_at: int = stripped.find(":")
		var equals_at: int = stripped.find("=")
		if colon_at == -1 or equals_at == -1 or colon_at > equals_at or equals_at == colon_at + 1:
			out.append(stripped)
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
