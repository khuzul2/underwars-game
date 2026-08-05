## DigCompletedEvent — the project's FIFTH concrete [Event] subclass. GDD §11.1 (Layered Design,
## **binding**), §3.4 step 4 ("completed digs apply yields"), §4.2 (the "Yield on dig" column and
## the Cave hex a Solid hex becomes), §5.1 (per-player integer stockpiles), §11.2, §11.3, §13.2
## tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 706): "**EventBus**: typed events emitted by apply() (hex\_changed, unit\_moved,
##         combat\_resolved, breach\_triggered, noise\_ping, collapse, research\_done,
##         wave\_spawned, victory, ...). Renderer/UI subscribe; **the sim never calls them**."
##   §11.1 (line 708): "**Save/load & replay:** save = JSON snapshot of GameState (+ ruleset
##         version + seed + command log)." — the reason the axial hex is flattened into the two
##         JSON SCALARS `hex_q`/`hex_r` and every other value is a scalar or an array of scalars.
##   §3.4  (line 148, step 4): "Dig progress ticks; **completed digs apply yields**, then **Breach
##         checks** (§4.6), then **Noise pings** (§4.8)."
##   §4.2  (Cave hexes table, first row): "Plain floor | —" — the Cave feature a completed dig
##         leaves behind, carried as `terrain_id` so the terrain FLIP is observable in the stream.
##   §5.1  (line 288): "No storage caps. Stockpiles are **per-player integers**."
##
## §13.6 wants "events emitted for every state change", and ONE completion changes FOUR things:
## worker-turns spent, a stockpile credited, a hex flipped and a site removed (freeing its
## diggers). (BA)(v) resolves that with TWO events rather than four — `dig_progressed` then
## `dig_completed` — the completion carrying a payload rich enough that each sub-change is
## observable: `player_index` (the SITE'S OWNER, credited), `hex`, `digger_ids` (freed, ASCENDING),
## `resource_ids` + `amounts` (the §4.2 yield, ids ASCENDING and index-aligned) and `terrain_id`
## (the Cave id the hex became). A generic `TerrainChangedEvent` is a candidate at M3, when §4.5's
## collapse gives it a second producer.
##
## `docs/decisions.md` was re-scanned this iteration: the only logged §12.1/§4.2 overrides are
## **(AU)(i)** and **(AW)(i)**, neither of which touches §11.1, §3.4, §5.1 or §4.2's Cave table.
## M0-T3 **(f)** stays binding: §11.1's printed event names are ILLUSTRATIVE, so the base and the
## bus declare NO vocabulary and `dig_completed` is the event's OWN name.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY; the base class via the script's `get_base_script`.
##
## The source scans at the bottom are written FRESH for
## `scripts/sim/events/dig_completed_event.gd`.
extends GutTest

const DIG_COMPLETED_PATH: String = "res://scripts/sim/events/dig_completed_event.gd"
const EVENT_PATH: String = "res://scripts/core/event.gd"
const EVENT_BUS_PATH: String = "res://scripts/core/event_bus.gd"

## (BA)(v) — the canonical key order of `to_dict()`: "type" FIRST, then the payload in declaration
## order, with the axial hex flattened into two JSON scalars.
const EXPECTED_DICT_KEYS: Array[String] = [
	"type",
	"player_index",
	"hex_q",
	"hex_r",
	"digger_ids",
	"resource_ids",
	"amounts",
	"terrain_id",
]

## §4.1 "axial coordinates (q, r)" — the hexes the fixtures announce.
const SAMPLE_HEX: Vector2i = Vector2i(1, -1)
const OTHER_HEX: Vector2i = Vector2i(-2, 3)

## (AX) — roster ids are minted from 1 upward; §4.2 line 197 caps a site at two simultaneous
## diggers, so a freed crew is at most two ids.
const FIXTURE_DIGGERS: Array[int] = [1, 2]

## §4.2 line 190 "Gold Vein | 2 | \+25 Gold lump + node" — the yield the fixture announces. The
## node's printed stock 250 and rate 10 are NOT part of it ((AW) item 4 / (BA)(vii)).
const FIXTURE_RESOURCES: Array[String] = ["gold"]
const FIXTURE_AMOUNTS: Array[int] = [25]

## §4.2's Cave-hex table row "Plain floor" — the terrain a completed dig leaves.
const CAVE_TERRAIN_ID: String = "plain_floor"

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

## §4.2's nine Solid terrain ids, the Cave id and §5.1's resources. FORBIDDEN in the payload class:
## adding content must stay a DATA edit ((T)/(AH)/(AU)(iv), §13.5's M6 canary). The event carries
## these as VALUES supplied by the rule; it must never SPELL one.
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

## The COMPLETE public surface: ONE const, SIX payload fields, `to_dict`.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["to_dict"]
const REQUIRED_PUBLIC_VARS: Array[String] = [
	"player_index", "hex", "digger_ids", "resource_ids", "amounts", "terrain_id"
]
const REQUIRED_PUBLIC_CONSTS: Array[String] = ["TYPE_NAME"]

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§4.2", "§3.4", "§5.1"]


# =============================================================================================
# A. IDENTITY AND PAYLOAD (§11.1 line 706, §3.4 step 4, §4.2, §5.1)
# =============================================================================================

## §11.1 — DigCompletedEvent IS an [Event]: the bus dispatches by `type`, so the subclass must
## carry the base's write-once type field. Asserted through the script's base script.
func test_dig_completed_event_is_an_event() -> void:
	var own_script: Script = _event().get_script()
	assert_not_null(own_script, "sanity: the instance carries its script")
	if own_script == null:
		return
	var base_script: Script = own_script.get_base_script()
	assert_not_null(base_script, "§11.1: DigCompletedEvent extends the Event base")
	if base_script == null:
		return
	assert_eq(
		base_script.resource_path,
		EVENT_PATH,
		"§11.1: DigCompletedEvent must extend %s so the EventBus can dispatch it" % EVENT_PATH
	)


## §11.1 / M0-T3 (f) — the type name is exactly `dig_completed`, declared once as the event's OWN
## constant, and the instance's INHERITED `type` field carries it.
func test_the_type_name_is_dig_completed() -> void:
	assert_eq(
		DigCompletedEvent.TYPE_NAME,
		&"dig_completed",
		"§11.1: the event's type is exactly \"dig_completed\""
	)
	assert_eq(
		typeof(DigCompletedEvent.TYPE_NAME),
		TYPE_STRING_NAME,
		"§11.1: an event type is a StringName, as EventBus.subscribe expects"
	)
	assert_eq(_event().type, DigCompletedEvent.TYPE_NAME, "§11.1: the constructor sets `type`")
	for other: StringName in [
		DigStartedEvent.TYPE_NAME,
		DigCancelledEvent.TYPE_NAME,
		DigProgressedEvent.TYPE_NAME,
		TurnEndedEvent.TYPE_NAME,
	]:
		assert_ne(
			DigCompletedEvent.TYPE_NAME, other, "M0-T3 (f): each concrete event owns a DISTINCT name"
		)


## (BA)(iv)(v)/§4.2/§5.1 — the six payload fields are carried verbatim: the SITE'S OWNER (the
## player credited, not necessarily whoever's turn it is), the hex, the freed diggers, the §4.2
## yield as index-aligned ids+amounts, and the Cave terrain the hex became.
func test_the_payload_is_carried_verbatim() -> void:
	var completed: DigCompletedEvent = _event()
	assert_eq(completed.player_index, 1, "(BA)(iv): the SITE'S OWNER is the credited player")
	assert_eq(completed.hex, SAMPLE_HEX, "§4.1: the hex that finished")
	assert_eq(completed.digger_ids, FIXTURE_DIGGERS, "(BA)(iv): the freed diggers, ASCENDING")
	assert_eq(completed.resource_ids, FIXTURE_RESOURCES, "§4.2: the yielded resource ids")
	assert_eq(completed.amounts, FIXTURE_AMOUNTS, "§4.2: \"\\+25 Gold lump\"")
	assert_eq(completed.terrain_id, CAVE_TERRAIN_ID, "§4.2: the Cave terrain the hex became")
	assert_eq(
		completed.resource_ids.size(),
		completed.amounts.size(),
		"§4.2: the ids and the amounts are INDEX-ALIGNED, so both arrays are the same length"
	)


## §11.1 — the payload is a COPY, not an alias: mutating the arrays the caller passed in must not
## reach the event afterwards. The tick hands it `DigSite.digger_ids()` (already fresh) and its own
## working arrays, and a logged replay must not be rewritable through them (the M1-T9 item 6
## freshness lesson).
func test_the_constructor_copies_its_arrays() -> void:
	var diggers: Array[int] = [1, 2]
	var resources: Array[String] = ["gold"]
	var amounts: Array[int] = [25]
	var completed: DigCompletedEvent = DigCompletedEvent.new(
		1, SAMPLE_HEX, diggers, resources, amounts, CAVE_TERRAIN_ID
	)
	diggers.append(3)
	resources.append("stone")
	amounts.append(1)
	assert_eq(completed.digger_ids, FIXTURE_DIGGERS, "§11.1: the event copied the digger ids")
	assert_eq(completed.resource_ids, FIXTURE_RESOURCES, "§11.1: the event copied the resource ids")
	assert_eq(completed.amounts, FIXTURE_AMOUNTS, "§11.1: the event copied the amounts")


## §13.4 TOTALITY — a completion that yields NOTHING (a row whose profile names no yield, or an
## unconfigured table) is representable: both arrays are empty, and the event still announces the
## terrain flip and the freed diggers.
func test_a_completion_with_no_yield_is_representable() -> void:
	var completed: DigCompletedEvent = DigCompletedEvent.new(
		0, OTHER_HEX, [] as Array[int], [] as Array[String], [] as Array[int], CAVE_TERRAIN_ID
	)
	assert_eq(completed.resource_ids, [] as Array[String], "§13.4: an empty yield is legal")
	assert_eq(completed.amounts, [] as Array[int], "§13.4: and so is an empty amount list")
	assert_eq(completed.digger_ids, [] as Array[int], "§13.4: and a crewless completion")
	assert_eq(completed.terrain_id, CAVE_TERRAIN_ID, "§4.2: the flip is still announced")


# =============================================================================================
# B. to_dict() (§11.1 line 707 canonical serialization / line 708 "save = JSON snapshot")
# =============================================================================================

## §11.1 — "type" is the FIRST key and the payload follows in DECLARATION order, with the axial hex
## flattened into `hex_q`/`hex_r`.
func test_to_dict_puts_type_first_then_the_payload_in_declaration_order() -> void:
	var serialized: Dictionary = _event().to_dict()
	assert_eq(
		serialized.keys(),
		[
			"type", "player_index", "hex_q", "hex_r", "digger_ids", "resource_ids", "amounts",
			"terrain_id"
		] as Array,
		"§11.1: to_dict() is {\"type\" FIRST, player_index, hex_q, hex_r, digger_ids, "
			+ "resource_ids, amounts, terrain_id}"
	)
	assert_eq(EXPECTED_DICT_KEYS.size(), 8, "sanity: the documented key order has eight entries")
	assert_eq(serialized.get("type"), "dig_completed", "§11.1: the base renders type as a String")
	assert_eq(serialized.get("player_index"), 1, "(BA)(iv): the credited owner is serialized")
	assert_eq(serialized.get("hex_q"), SAMPLE_HEX.x, "§11.1 line 708: q is a JSON scalar")
	assert_eq(serialized.get("hex_r"), SAMPLE_HEX.y, "§11.1 line 708: r is a JSON scalar")
	assert_eq(serialized.get("terrain_id"), CAVE_TERRAIN_ID, "§4.2: the new terrain is serialized")


## §11.1 line 708 — every serialized value is a JSON scalar OR an array of JSON scalars, and the
## whole Dictionary survives a real `JSON.stringify` -> `JSON.parse_string` round trip WITH ITS KEY
## ORDER INTACT. `sort_keys` defaults to `true` on the pinned 4.7 build ((AW)(vii)(a)), so the
## third argument is `false`.
func test_every_serialized_value_is_json_safe_and_survives_a_round_trip() -> void:
	var serialized: Dictionary = _event().to_dict()
	for key: Variant in serialized.keys():
		assert_true(
			_is_json_safe(serialized[key]),
			"§11.1 line 708: \"%s\" must be a JSON scalar or an array of them" % str(key)
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
	var ids: Variant = round_tripped.get("resource_ids")
	assert_eq(typeof(ids), TYPE_ARRAY, "§11.1 line 708: the yielded ids survive as a JSON array")
	if typeof(ids) == TYPE_ARRAY:
		assert_eq((ids as Array).size(), 1, "§4.2: one yielded resource survives the round trip")


## §11.1 — a FRESH Dictionary AND fresh arrays every call, so a logger can never alias (and then
## mutate) the event's internals. The `is_same` IDENTITY assertion is the load-bearing half: an
## array handed out by reference is a live wire into a recorded replay.
func test_to_dict_returns_fresh_containers_every_call() -> void:
	var event: DigCompletedEvent = _event()
	var first: Dictionary = event.to_dict()
	var second: Dictionary = event.to_dict()
	assert_eq(first.keys(), second.keys(), "§11.1: the serialization is reproducible")
	assert_false(is_same(first, second), "§11.1: to_dict() hands back a fresh Dictionary")
	assert_false(
		is_same(first.get("digger_ids"), event.digger_ids),
		"§11.1: to_dict() must not hand out the event's own Array"
	)
	assert_false(
		is_same(first.get("resource_ids"), event.resource_ids),
		"§11.1: to_dict() must not hand out the event's own Array"
	)
	assert_false(
		is_same(first.get("amounts"), event.amounts),
		"§11.1: to_dict() must not hand out the event's own Array"
	)
	assert_eq(event.amounts, FIXTURE_AMOUNTS, "§11.1: the payload is unchanged by serialization")


## §11.1 determinism — the serialization is a pure function of the payload, and EVERY field
## distinguishes: the owner, both hex components, the crew, the yielded ids, the amounts and the
## new terrain id.
func test_to_dict_is_a_pure_function_of_every_payload_field() -> void:
	var base: Array[String] = _serialized_values(_event())
	assert_eq(base, _serialized_values(_event()), "§11.1: equal payloads serialize identically")
	var mutants: Array[DigCompletedEvent] = [
		DigCompletedEvent.new(
			0, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_RESOURCES, FIXTURE_AMOUNTS, CAVE_TERRAIN_ID
		),
		DigCompletedEvent.new(
			1,
			Vector2i(SAMPLE_HEX.x + 1, SAMPLE_HEX.y),
			FIXTURE_DIGGERS,
			FIXTURE_RESOURCES,
			FIXTURE_AMOUNTS,
			CAVE_TERRAIN_ID
		),
		DigCompletedEvent.new(
			1,
			Vector2i(SAMPLE_HEX.x, SAMPLE_HEX.y + 1),
			FIXTURE_DIGGERS,
			FIXTURE_RESOURCES,
			FIXTURE_AMOUNTS,
			CAVE_TERRAIN_ID
		),
		DigCompletedEvent.new(
			1, SAMPLE_HEX, [1] as Array[int], FIXTURE_RESOURCES, FIXTURE_AMOUNTS, CAVE_TERRAIN_ID
		),
		DigCompletedEvent.new(
			1,
			SAMPLE_HEX,
			FIXTURE_DIGGERS,
			["stone"] as Array[String],
			FIXTURE_AMOUNTS,
			CAVE_TERRAIN_ID
		),
		DigCompletedEvent.new(
			1, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_RESOURCES, [1] as Array[int], CAVE_TERRAIN_ID
		),
		DigCompletedEvent.new(
			1, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_RESOURCES, FIXTURE_AMOUNTS, "not_a_terrain"
		),
	]
	for mutant: DigCompletedEvent in mutants:
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
	bus.subscribe(DigCompletedEvent.TYPE_NAME, mine.on_event)
	for other: StringName in [
		DigStartedEvent.TYPE_NAME,
		DigCancelledEvent.TYPE_NAME,
		DigProgressedEvent.TYPE_NAME,
		TurnEndedEvent.TYPE_NAME,
	]:
		bus.subscribe(other, others.on_event)

	var event: DigCompletedEvent = _event()
	bus.emit(event)
	assert_eq(mine.calls, 1, "§11.1: a subscriber on dig_completed is delivered the event")
	assert_true(
		is_same(mine.last_event, event), "§11.1: the bus delivers the very instance emitted"
	)
	assert_eq(others.calls, 0, "M0-T3 (f): no other subscription hears it")

	bus.emit(DigProgressedEvent.new(0, OTHER_HEX, 1, 1))
	assert_eq(mine.calls, 1, "M0-T3 (f): the dig_completed subscriber is not disturbed")
	assert_eq(others.calls, 1, "M0-T3 (f): each subscriber hears exactly its own type")


# =============================================================================================
# D. MECHANICAL SOURCE SCANS on scripts/sim/events/dig_completed_event.gd
#    Written FRESH for this file — it inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(DIG_COMPLETED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_COMPLETED_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	assert_null(
		float_literal.search(code),
		"§11.1: integer math only — %s must contain no float literal" % DIG_COMPLETED_PATH
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % DIG_COMPLETED_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R); an event is a payload, so it
## names no renderer either — the EventBus -> MapRenderer seam is M2-T8 and lives on the OTHER side
## of the bus.
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(DIG_COMPLETED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_COMPLETED_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				DIG_COMPLETED_PATH, banned
			]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [
				DIG_COMPLETED_PATH, banned
			]
		)


## S3 §13.4/M1-T9 — an event carries a payload, nothing else: no loader (`RulesError`/`DigRules`
## ABSENT so a second source of §4.2 numbers cannot grow here), no `Object.hash()` override, no
## `GameState`/`DigSite`/`DigTick`/`PlayerState` reach-back (the event REPORTS the credit; it must
## not be able to APPLY one), and no knowledge of the Command that emitted it.
func test_source_is_payload_only() -> void:
	var code: String = _code_text(DIG_COMPLETED_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_COMPLETED_PATH)
	for banned: String in [
		"RulesError", "RulesLoader", "DigRules", "DigSite", "DigTick", "GameState", "PlayerState",
		"HexMap", "Command"
	]:
		assert_false(
			code.contains(banned),
			"M1-T9/(BA)(v): an event is a payload — %s must not name %s" % [
				DIG_COMPLETED_PATH, banned
			]
		)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			DIG_COMPLETED_PATH
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
		"dig_completed", "DigCompleted", "dig_progressed", "DigProgressed", "dig_started",
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
## This is the sharpest instance of the rule in the whole task: the event's payload IS a terrain id
## and a list of resource ids, and it still must never SPELL one.
func test_source_carries_no_vocabulary_and_hard_codes_no_gdd_number() -> void:
	var lowered: String = _code_text(DIG_COMPLETED_PATH).to_lower()
	assert_false(lowered.is_empty(), "sanity: %s must be readable" % DIG_COMPLETED_PATH)
	for banned: String in FORBIDDEN_VOCABULARY:
		assert_false(
			lowered.contains(banned),
			"(T)/(AH)/(AU)(iv): terrain and resource ids are DATA — %s must not name \"%s\"" % [
				DIG_COMPLETED_PATH, banned
			]
		)
	assert_false(lowered.contains("enum "), "(AU)(iv): the vocabulary is never an enum")

	var code: String = _code_text(DIG_COMPLETED_PATH)
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
				str(PERMITTED_NUMERALS), DIG_COMPLETED_PATH, found.get_string()
			]
		)
	assert_eq(FORBIDDEN_NUMERALS.size(), 11, "sanity: every §4.2/§3.2 numeral is covered")


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: one const, six payload fields
## and `to_dict`. A MISSING member fails, and an EXTRA one fails too. Every declaration is
## statically typed, INCLUDING the three array fields (`Array[int]`/`Array[String]`, never a bare
## `Array`).
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_COMPLETED_PATH, public_functions, undocumented)

	var event: DigCompletedEvent = _event()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, DIG_COMPLETED_PATH]
		)
		assert_true(
			event.has_method(required),
			"§11.2: %s must be callable on a DigCompletedEvent instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			DIG_COMPLETED_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(DIG_COMPLETED_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public FIELD surface of %s is exactly %s" % [
			DIG_COMPLETED_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)
	assert_eq(
		_collect_public_consts(DIG_COMPLETED_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.4: %s declares exactly one public const (its OWN type name)" % DIG_COMPLETED_PATH
	)
	assert_eq(
		_untyped_declarations(DIG_COMPLETED_PATH),
		[] as Array[String],
		"§11.3: static typing everywhere — every `var` in %s must be `var x: T = ...`" % [
			DIG_COMPLETED_PATH
		]
	)


## S7 §11.1/§11.2 — DigCompletedEvent is a pure [RefCounted] in `scripts/sim/events/`. Asserted
## through get_class() — `is Node` would be a PARSE ERROR here.
func test_dig_completed_event_is_a_pure_refcounted_in_scripts_sim_events() -> void:
	assert_true(
		FileAccess.file_exists(DIG_COMPLETED_PATH),
		"§11.2: DigCompletedEvent belongs at %s" % DIG_COMPLETED_PATH
	)
	assert_eq(
		_event().get_class(), "RefCounted", "§11.1: DigCompletedEvent must be a pure RefCounted"
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

## A fixture event: player 1's Gold Vein finished on SAMPLE_HEX, freeing diggers 1 and 2, paying
## §4.2's printed +25 Gold lump and leaving plain floor.
func _event() -> DigCompletedEvent:
	return DigCompletedEvent.new(
		1, SAMPLE_HEX, FIXTURE_DIGGERS, FIXTURE_RESOURCES, FIXTURE_AMOUNTS, CAVE_TERRAIN_ID
	)


## An event's canonical serialization flattened to a comparable String array.
func _serialized_values(event: DigCompletedEvent) -> Array[String]:
	var out: Array[String] = []
	var serialized: Dictionary = event.to_dict()
	for key: Variant in serialized.keys():
		out.append("%s=%s" % [str(key), str(serialized[key])])
	return out


## True for a JSON-safe serialized value: a scalar, or an array whose entries are all scalars
## (§11.1 line 708 — "save = JSON snapshot").
func _is_json_safe(value: Variant) -> bool:
	var kind: int = typeof(value)
	if kind == TYPE_STRING or kind == TYPE_INT or kind == TYPE_BOOL:
		return true
	if kind == TYPE_ARRAY or kind == TYPE_PACKED_INT32_ARRAY or kind == TYPE_PACKED_STRING_ARRAY:
		for entry: Variant in value:
			var entry_kind: int = typeof(entry)
			if entry_kind != TYPE_STRING and entry_kind != TYPE_INT and entry_kind != TYPE_BOOL:
				return false
		return true
	return false


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
