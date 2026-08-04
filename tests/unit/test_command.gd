## Command — the §11.1 COMMAND SPINE. GDD §11.1 (Layered Design, **binding**), §11.2
## (`scripts/sim/commands/`), §11.3, §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 705): "**Commands** (command pattern): MoveUnit, AttackUnit, AttackHex, DigHex,
##         CancelDig, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein,
##         SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -> Error?
##         and apply(state) -> Array[Event]. **Every mutation of GameState goes through a
##         Command** — the UI, the AI, zone macros, and tests all speak the same language, and a
##         match is fully described by (seed, command\_log)."
##   §11.1 (line 706): "**EventBus**: typed events emitted by apply() (hex\_changed, unit\_moved,
##         combat\_resolved, breach\_triggered, noise\_ping, collapse, research\_done,
##         wave\_spawned, victory, ...). Renderer/UI subscribe; **the sim never calls them**."
##   §11.1 (line 703): "No Node, no Scene Tree, no engine singletons, no rendering, no
##         **randi()** — the core must run headless byte-identically."
##
## `docs/decisions.md` was re-scanned end to end this iteration: the ONLY logged §12.1 override
## is (AU)(i) (irrelevant here), and **NO logged override touches §11.1** — the printed text
## governs unamended. §11.1 gives `validate` and `apply` but **composes them nowhere**, so the
## composition below is a §13.4 resolution lettered **(AV)** ((AU) must NOT be renumbered):
##   (AV) `execute(state, bus) -> CommandError` is THE ONE GATE.
##       - Without a single composed entry point, any caller could `apply()` past validation, and
##         §11.1's "**every** mutation of GameState goes through a Command" would be enforced by
##         convention alone.
##       - Contract: call `validate`; on a non-null return, return it IMMEDIATELY having mutated
##         nothing and emitted nothing; otherwise call `apply(state)`, then
##         `if bus != null: bus.emit_all(events)`, then return null.
##       - `bus == null` is LEGAL (headless) and is a SILENT DROP, never a crash.
##       - `execute` never hands the events back: callers who want them subscribe to the bus.
##         The sim emits; the sim never calls the renderer.
##       - The base `validate` REJECTS (code authored at its own call site) so a subclass that
##         forgets to override is rejected rather than silently applied.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/commands/command.gd`.
extends GutTest

const COMMAND_PATH: String = "res://scripts/sim/commands/command.gd"

## §12.6's example seed, so this file's seeds come from the GDD rather than from invention.
const GOLDEN_SEED: int = 1337

## §3.1 line 118 "Skirmish: **2–4 players**" — the fixture roster for gate probing.
const PROBE_PLAYERS: int = 3

## Rejection codes authored by EndTurnCommand at ITS own call site. None may appear in the BASE:
## the base authors only its own (the (AU)(iv) / (T) / (AH) / M0-T3 (f) no-whitelist rule).
const SUBCLASS_REJECTION_CODES: Array[String] = [
	"null_state",
	"no_players",
	"not_current_player",
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

## §11.1 "Renderer/UI subscribe; **the sim never calls them**" — a Command may not name a
## renderer class or hold a Node.
const RENDERER_TOKENS: Array[String] = [
	"MapRenderer",
	"CameraRig",
	"HexPicker",
	"HexLayout",
	"GreyboxBoot",
	"MultiMesh",
	"Camera3D",
	"Node3D",
]

## §3.2 line 133 "If turn 200 is reached (configurable)" / §12.1 `victory.turn_limit` — M6.
const VICTORY_TURN_LIMIT_TOKEN: String = "200"

## The COMPLETE public surface of Command: four functions and ZERO public vars. `to_dict()`,
## serialization and a CommandLog class are §11.1 save/load = M7 (§13.4).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["command_name", "validate", "apply", "execute"]
const REQUIRED_PUBLIC_VARS: Array[String] = []

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§3.3", "§3.4"]


# =============================================================================================
# Test-local fixtures. Real Commands belong to the milestones that emit them (§13.4), so the
# gate probes below are inner classes of this test file and never new files under scripts/.
# None may start with "Test" — GUT would collect them as inner test suites.
# =============================================================================================

## Shared, ordered log of what happened, in the order it happened (§11.1 determinism).
class Recorder extends RefCounted:
	var entries: Array[String] = []

	func record(label: String) -> void:
		entries.append(label)


## A Command double that records the order in which the gate calls it, can be made to reject on
## demand, and MUTATES the state inside apply() — so "a rejected command mutates nothing" is
## observable rather than asserted about an implementation that never mutates anything.
class GateProbe extends Command:
	## An opaque resource id; §5.1's vocabulary is pinned by tests/unit/test_player_state.gd.
	const MUTATED_ID: String = "gold"

	var recorder: Recorder = null
	var rejection: CommandError = null
	var payload: Array[Event] = []
	var validate_calls: int = 0
	var apply_calls: int = 0

	func _init(p_recorder: Recorder) -> void:
		recorder = p_recorder

	func command_name() -> StringName:
		return &"gate_probe"

	func validate(_state: GameState) -> CommandError:
		validate_calls += 1
		recorder.record("validate")
		return rejection

	func apply(state: GameState) -> Array[Event]:
		apply_calls += 1
		recorder.record("apply")
		if state != null:
			var mutated: PlayerState = state.player(0)
			if mutated != null:
				mutated.add(MUTATED_ID, 1)
		return payload


## Counts deliveries and records the payload turn of every TurnEndedEvent it receives, so both
## "emitted nothing" and "emitted in array order" are observable.
class CountingHandler extends RefCounted:
	var calls: int = 0
	var turns: Array[int] = []

	func on_event(event: Event) -> void:
		calls += 1
		var ended: TurnEndedEvent = event as TurnEndedEvent
		if ended != null:
			turns.append(ended.turn)


# =============================================================================================
# A. THE BASE CLASS (§11.1 "Each implements validate(state) -> Error? and apply(state) ->
#    Array[Event]")
# =============================================================================================

## §11.1 — the base carries no name: a name belongs to a concrete command.
func test_the_base_command_has_no_name() -> void:
	assert_eq(
		Command.new().command_name(), &"", "§11.1: the abstract base answers the empty name"
	)


## (AV) — THE BASE REJECTS. A subclass that forgets to override `validate` must be REJECTED, never
## silently applied: §11.1 makes every mutation flow through a Command, so an unimplemented
## command must fail closed.
func test_the_base_validate_rejects_so_an_unoverridden_subclass_fails_closed() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var rejection: CommandError = Command.new().validate(state)
	assert_not_null(
		rejection, "(AV): the base validate must REJECT, so an unoverridden subclass fails closed"
	)
	if rejection == null:
		return
	assert_ne(rejection.code, &"", "(AV): the rejection carries a code")
	assert_false(rejection.message.is_empty(), "(AV): every rejection carries a message")


## §11.1 "apply(state) -> Array[Event]" — the base emits nothing, and hands back a FRESH array
## every call so a caller can never alias the command's internals (the M1-T9 item 6 lesson).
func test_the_base_apply_returns_a_fresh_empty_event_array() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var command: Command = Command.new()
	var first: Array[Event] = command.apply(state)
	var second: Array[Event] = command.apply(state)
	assert_eq(first.size(), 0, "§11.1: the base emits nothing")
	assert_eq(second.size(), 0, "§11.1: the base emits nothing")
	assert_false(is_same(first, second), "§11.1: every returned Array[Event] is fresh per call")


## (AV) — the base is fail-closed end to end: `execute` on a bare Command rejects, applies
## nothing and emits nothing.
func test_executing_a_bare_base_command_rejects_and_emits_nothing() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(TurnEndedEvent.TYPE_NAME, handler.on_event)
	var before: int = state.content_hash()
	var rejection: CommandError = Command.new().execute(state, bus)
	assert_not_null(rejection, "(AV): a bare base Command is rejected by the gate")
	assert_eq(handler.calls, 0, "(AV): a rejected command emits NOTHING")
	assert_eq(state.content_hash(), before, "(AV): a rejected command mutates NOTHING")


# =============================================================================================
# B. execute() IS THE ONE GATE ((AV): validate -> apply -> EventBus.emit_all)
# =============================================================================================

## (AV)/§11.1 — the gate calls validate FIRST and apply SECOND, exactly once each, on the legal
## path. The ORDER is the whole point: applying before validating would let an illegal command
## mutate the state and then report the rejection.
func test_execute_validates_before_it_applies_exactly_once_each() -> void:
	var recorder: Recorder = Recorder.new()
	var probe: GateProbe = GateProbe.new(recorder)
	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var accepted: CommandError = probe.execute(state, null)
	assert_null(accepted, "(AV): a legal command answers null")
	assert_eq(
		recorder.entries,
		["validate", "apply"] as Array[String],
		"(AV): the gate is validate THEN apply — never apply first"
	)
	assert_eq(probe.validate_calls, 1, "(AV): validate runs exactly once per execute")
	assert_eq(probe.apply_calls, 1, "(AV): apply runs exactly once per execute")


## (AV) — A REJECTED COMMAND MUTATES NOTHING AND EMITS NOTHING. The probe's apply() deliberately
## moves a stockpile, so this is measured behaviour, not a property of an inert double.
func test_a_rejected_command_never_reaches_apply_and_changes_nothing() -> void:
	var recorder: Recorder = Recorder.new()
	var probe: GateProbe = GateProbe.new(recorder)
	probe.rejection = CommandError.new(&"probe_rejected", "the probe was told to reject")
	probe.payload = [TurnEndedEvent.new(0, 1, 1)] as Array[Event]

	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(TurnEndedEvent.TYPE_NAME, handler.on_event)
	var before: int = state.content_hash()

	var returned: CommandError = probe.execute(state, bus)
	assert_true(
		is_same(returned, probe.rejection),
		"(AV): execute returns the very rejection validate produced"
	)
	assert_eq(probe.apply_calls, 0, "(AV): a rejected command NEVER reaches apply")
	assert_eq(
		recorder.entries, ["validate"] as Array[String], "(AV): only validate ran"
	)
	assert_eq(handler.calls, 0, "§11.1: a rejected command emits NOTHING on the bus")
	assert_eq(state.content_hash(), before, "(AV): a rejected command leaves the state identical")


## (AV) — the accepted path is the mirror image: apply runs and the state really does move, so
## the previous test is not passing because the probe is inert.
func test_an_accepted_command_reaches_apply_and_changes_the_state() -> void:
	var probe: GateProbe = GateProbe.new(Recorder.new())
	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var before: int = state.content_hash()
	assert_null(probe.execute(state, null), "(AV): the probe is legal by default")
	assert_eq(probe.apply_calls, 1, "(AV): the accepted path reaches apply")
	assert_ne(
		state.content_hash(),
		before,
		"sanity: the probe's apply really mutates — the rejection test is not vacuous"
	)


## §11.1 line 706 — the gate routes apply()'s array through `EventBus.emit_all` IN ARRAY ORDER.
## Delivery order is a pure function of the array, never of a Dictionary's key order.
func test_execute_routes_the_event_array_through_the_bus_in_order() -> void:
	var probe: GateProbe = GateProbe.new(Recorder.new())
	probe.payload = [
		TurnEndedEvent.new(0, 1, 7),
		TurnEndedEvent.new(1, 2, 9),
		TurnEndedEvent.new(2, 0, 11),
	] as Array[Event]

	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(TurnEndedEvent.TYPE_NAME, handler.on_event)
	assert_null(
		probe.execute(GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS), bus),
		"sanity: the probe is legal"
	)
	assert_eq(handler.calls, 3, "§11.1: every event apply() returned is delivered")
	assert_eq(
		handler.turns,
		[7, 9, 11] as Array[int],
		"§11.1: events are delivered in the order apply() returned them"
	)


## (AV) — `bus == null` is LEGAL (the headless sim, the replay harness, the balance lab) and is a
## SILENT DROP: apply still runs, the state still moves, nothing crashes.
func test_a_null_bus_is_a_silent_drop_not_a_crash() -> void:
	var probe: GateProbe = GateProbe.new(Recorder.new())
	probe.payload = [TurnEndedEvent.new(0, 1, 1)] as Array[Event]
	var state: GameState = GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS)
	var before: int = state.content_hash()
	assert_null(probe.execute(state, null), "(AV): a null bus is legal headless")
	assert_eq(probe.apply_calls, 1, "(AV): a null bus does not stop apply from running")
	assert_ne(state.content_hash(), before, "(AV): the state still moves with no bus attached")


## (AV)/§11.1 — the gate NEVER hands the events back: its return type is a rejection, and on the
## legal path it is null. Callers who want the events subscribe to the bus — the sim emits, it
## never calls the renderer.
func test_execute_answers_null_on_success_and_never_returns_the_events() -> void:
	var probe: GateProbe = GateProbe.new(Recorder.new())
	probe.payload = [TurnEndedEvent.new(0, 1, 1), TurnEndedEvent.new(1, 2, 1)] as Array[Event]
	var returned: CommandError = probe.execute(GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS), null)
	assert_null(returned, "§11.1: a successful execute answers null, not the event array")


## (AV) totality — a null state is rejected by whatever the command's own validate says, and the
## gate must not reach apply with it (the M1-T1 (B) / M1-T3 (L) / M1-T9 (AS) spirit).
func test_a_null_state_is_refused_by_the_gate_without_reaching_apply() -> void:
	var probe: GateProbe = GateProbe.new(Recorder.new())
	probe.rejection = CommandError.new(&"probe_rejected", "no state")
	var returned: CommandError = probe.execute(null, null)
	assert_not_null(returned, "(AV): the gate reports the command's own rejection")
	assert_eq(probe.apply_calls, 0, "(AV): apply is never reached past a rejection")


## (AV) — the gate is re-entrant over the SAME command object: executing it twice validates twice
## and applies twice. §11.1's replay contract runs one command_log more than once, so a command
## must never "spend" itself.
func test_the_same_command_object_can_be_executed_again() -> void:
	var probe: GateProbe = GateProbe.new(Recorder.new())
	assert_null(probe.execute(GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS), null), "sanity")
	assert_null(probe.execute(GameState.new(GOLDEN_SEED, null, PROBE_PLAYERS), null), "sanity")
	assert_eq(probe.validate_calls, 2, "§11.1: a command is replayable, never single-use")
	assert_eq(probe.apply_calls, 2, "§11.1: a command is replayable, never single-use")


# =============================================================================================
# C. MECHANICAL SOURCE SCANS ON scripts/sim/commands/command.gd
#    Written FRESH for this file — a new file inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)". Comment stripping is
## LOAD-BEARING: the doc block cites "§11.1", which `\.[0-9]` would hit.
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(COMMAND_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			COMMAND_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % COMMAND_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % COMMAND_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R).
func test_source_is_engine_free() -> void:
	var code: String = _code_text(COMMAND_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [COMMAND_PATH, banned]
		)


## S3 §11.1 line 706 "Renderer/UI subscribe; **the sim never calls them**" — the spine holds no
## Node and names no renderer class. It reaches the renderer through the [EventBus] or not at all.
func test_source_holds_no_node_and_names_no_renderer() -> void:
	var code: String = _code_text(COMMAND_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_PATH)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [COMMAND_PATH, banned]
		)
	var node_token: RegEx = RegEx.new()
	assert_eq(node_token.compile("\\bNode\\b"), OK, "sanity: the Node pattern compiles")
	assert_null(
		node_token.search(code), "§11.1: a Command must not reference a Node at all"
	)
	assert_true(
		code.contains("EventBus"),
		"§11.1: the gate hands apply()'s events to the EventBus — the sim emits, it never calls"
	)
	assert_true(
		code.contains("emit_all"),
		"§11.1: the gate routes the whole Array[Event] through EventBus.emit_all"
	)


## S4 (AV)/§13.5 — NO REJECTION-CODE VOCABULARY IN THE BASE. Every code is authored at the
## rejecting Command's own call site (the (AU)(iv) / (T) / (AH) / M0-T3 (f) precedent), so the
## base may not name a SUBCLASS's code and must declare no enum and no code list.
func test_source_carries_no_subclass_rejection_vocabulary() -> void:
	var code: String = _code_text(COMMAND_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_PATH)
	for rejection: String in SUBCLASS_REJECTION_CODES:
		assert_false(
			code.contains(rejection),
			"(AV)/§13.5: %s must not name a subclass's rejection code \"%s\"" % [
				COMMAND_PATH, rejection
			]
		)
	assert_false(code.contains("enum "), "(AV): rejection codes are never an enum")


## S5 §13.4 + M0-T4 — this file loads no document (the M1-T9 rule: where a file has no loader,
## assert `RulesError` ABSENT so a second loader cannot grow here), it must not override
## `Object.hash()` (native_method_override, level 2 = a hard error), and §3.2/§12.1's turn limit
## belongs to M6.
func test_source_declares_no_loader_and_overrides_no_native_method() -> void:
	var code: String = _code_text(COMMAND_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_PATH)
	assert_false(
		code.contains("RulesError"),
		"M1-T9: %s loads no document — the command rejection type is CommandError" % COMMAND_PATH
	)
	assert_true(
		code.contains("CommandError"), "(AV): the base rejects with a CommandError"
	)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % COMMAND_PATH
	)
	assert_false(
		code.contains(VICTORY_TURN_LIMIT_TOKEN),
		"§3.2/§12.1: the turn limit is M6 — %s must not contain %s" % [
			COMMAND_PATH, VICTORY_TURN_LIMIT_TOKEN
		]
	)


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (to_dict, serialize, undo, a CommandLog
## accessor, any public var) fails too.
func test_public_api_is_exactly_the_four_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(COMMAND_PATH, public_functions, undocumented)

	var command: Command = Command.new()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, COMMAND_PATH]
		)
		assert_true(
			command.has_method(required),
			"§11.2: %s must be callable on a Command instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			COMMAND_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(COMMAND_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: %s declares ZERO public vars — a Command is behaviour, not state" % COMMAND_PATH
	)


## S7 §11.1/§11.2 — Command is a pure [RefCounted] living in `scripts/sim/commands/` (§11.2 lists
## `commands/` under `sim/`). Asserted through get_class() — `is Node` would be a PARSE ERROR here
## (M0-T2 item 11 / M0-T5 item (a)).
func test_command_is_a_pure_refcounted_in_scripts_sim_commands() -> void:
	assert_true(
		FileAccess.file_exists(COMMAND_PATH), "§11.2: Command belongs at %s" % COMMAND_PATH
	)
	assert_eq(
		Command.new().get_class(), "RefCounted", "§11.1: Command must be a pure RefCounted"
	)


## S8 §11.1 line 706 / M0-T3 (f) — the EventBus infrastructure stays free of every event name and
## is NOT edited by this task: concrete events carry sim payloads, `scripts/core/event.gd` and
## `event_bus.gd` stay pure infrastructure.
func test_the_event_infrastructure_names_no_concrete_event() -> void:
	var event_code: String = _code_text("res://scripts/core/event.gd")
	var bus_code: String = _code_text("res://scripts/core/event_bus.gd")
	assert_false(event_code.is_empty(), "sanity: scripts/core/event.gd must be readable")
	assert_false(bus_code.is_empty(), "sanity: scripts/core/event_bus.gd must be readable")
	assert_false(
		event_code.contains("turn_ended"),
		"M0-T3 (f): the Event base declares no vocabulary — the name lives on the subclass"
	)
	assert_false(
		bus_code.contains("turn_ended"),
		"M0-T3 (f): the EventBus declares no vocabulary"
	)
	assert_false(
		event_code.contains("Command"), "§11.1: the Event base knows nothing about Commands"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

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
