## EventBus + Event — GDD §11.1 (layered design: "data/*.json → Sim Core (engine-free) →
## EventBus → Renderer/UI"), §11.2 (scripts/core), §11.3 (conventions), §13.2 tier 1 (unit
## tests), §14 M0 row (EventBus is an M0 deliverable).
##
## NO NUMERIC TABLE APPLIES. The EventBus carries zero §12.1 constants, so this file pins BINDING
## PROSE, not numbers — nothing here may be copied into data/ruleset.json and no literal in these
## tests is a game constant (§13.6 "constants read from data, not code" is vacuous here).
##
## The §11.1 text these tests pin, verbatim:
##   "EventBus: typed events emitted by apply() (hex_changed, unit_moved, combat_resolved,
##    breach_triggered, noise_ping, collapse, research_done, wave_spawned, victory, ...).
##    Renderer/UI subscribe; the sim never calls them."
##   "Sim Core (scripts/core, scripts/sim): pure GDScript RefCounted classes. No Node, no Scene
##    Tree, no engine singletons, no rendering, no randi()"
##   "Each implements validate(state) -> Error? and apply(state) -> Array[Event]."
##   "Determinism rules: iterate collections in stable ID order"
## The parenthesised event list is ILLUSTRATIVE and open-ended ("..."), so engine code may not
## whitelist those names; they appear below only as StringName literals in test fixtures.
##
## §13.4 ambiguity resolutions pinned here (the GDD legislates none of them; Land logs them in
## docs/decisions.md):
##   (a) delivery order = per-type registration order, oldest subscriber first;
##   (b) a nested emit from inside a handler is QUEUED and delivered after the current event
##       finishes — never depth-first/re-entrant;
##   (c) the subscriber list is snapshotted per event with a liveness re-check, so a subscribe or
##       unsubscribe performed inside a handler cannot affect the in-flight event;
##   (d) subscribe is idempotent per (type, Callable) pair; unsubscribing an unknown pair, an
##       unknown type, or emitting with no subscribers are silent no-ops (as is emit(null));
##   (e) Callables whose target has been freed are skipped AND pruned at dispatch.
##
## TRAP (hit live in M0-T2, docs/decisions.md item 11): `x is Node` against a RefCounted-typed
## variable is a statically impossible cast that GDScript rejects at PARSE time; GUT then logs
## "Ignoring script ..." and exits 0, silently deleting this whole file from the run. Non-Node-ness
## is therefore asserted via get_class() ONLY, never with `is`.
extends GutTest

const EVENT_PATH: String = "res://scripts/core/event.gd"
const EVENT_BUS_PATH: String = "res://scripts/core/event_bus.gd"

## §11.1 — tokens that would make the sim core engine-bound. Checked against source with comments
## stripped, so a doc comment quoting the rule ("no Node, no Scene Tree") is never a false failure.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"randi(",
	"randf(",
	"Time.",
	"OS.",
]

## §11.1 — the illustrative event names. None may appear in engine code: the vocabulary is open
## (supports the §13.5 "content requires zero engine-code changes" rule from M6 on).
const ILLUSTRATIVE_EVENT_NAMES: Array[String] = [
	"hex_changed",
	"unit_moved",
	"combat_resolved",
	"breach_triggered",
	"noise_ping",
	"collapse",
	"research_done",
	"wave_spawned",
	"victory",
]


# =============================================================================================
# Test-local fixtures. Concrete game event classes belong to the milestones that emit them
# (§13.4: invent nothing ahead of its milestone), so every Event subclass used here is an inner
# class of this test file and never a new file under scripts/. None of these inner classes may
# start with "Test" — GUT would collect them as inner test suites.
# =============================================================================================

## Shared, ordered log of what happened, in the order it happened (§11.1 determinism).
class Recorder extends RefCounted:
	var entries: Array[String] = []

	func record(label: String) -> void:
		entries.append(label)


## A payload-free event; exercises the Event base directly.
class SimpleEvent extends Event:
	func _init(p_type: StringName) -> void:
		super(p_type)


## An event carrying an identifying tag, so a single handler can log WHICH event it received.
class TaggedEvent extends Event:
	var tag: String = ""

	func _init(p_type: StringName, p_tag: String) -> void:
		super(p_type)
		tag = p_tag


## A subclass with typed payload that appends its own keys after the base "type" key.
class MovedEvent extends Event:
	var unit_id: int = 0
	var to_hex: String = ""

	func _init(p_unit_id: int, p_to_hex: String) -> void:
		super(&"unit_moved")
		unit_id = p_unit_id
		to_hex = p_to_hex

	func to_dict() -> Dictionary:
		var out: Dictionary = super()
		out["unit_id"] = unit_id
		out["to_hex"] = to_hex
		return out


## Records its own label — used to pin registration order.
class LabeledHandler extends RefCounted:
	var recorder: Recorder = null
	var label: String = ""
	var calls: int = 0
	var last_event: Event = null

	func _init(p_recorder: Recorder, p_label: String) -> void:
		recorder = p_recorder
		label = p_label

	func on_event(event: Event) -> void:
		calls += 1
		last_event = event
		recorder.record(label)


## Records the tag of the event it received — used to pin per-event delivery order.
class TagHandler extends RefCounted:
	var recorder: Recorder = null
	var calls: int = 0

	func _init(p_recorder: Recorder) -> void:
		recorder = p_recorder

	func on_event(event: Event) -> void:
		calls += 1
		var tagged: TaggedEvent = event as TaggedEvent
		recorder.record(tagged.tag if tagged != null else "<untagged>")


## Emits a further event from inside a handler — used to pin nested-emit ordering.
class EmittingHandler extends RefCounted:
	var bus: EventBus = null
	var recorder: Recorder = null
	var label: String = ""
	var payload: Event = null
	var saw_dispatching: bool = false

	func _init(p_bus: EventBus, p_recorder: Recorder, p_label: String, p_payload: Event) -> void:
		bus = p_bus
		recorder = p_recorder
		label = p_label
		payload = p_payload

	func on_event(_event: Event) -> void:
		recorder.record(label)
		saw_dispatching = bus.is_dispatching()
		if payload != null:
			bus.emit(payload)


## Mutates the subscriber table from inside a handler — used to pin snapshot semantics.
class MutatingHandler extends RefCounted:
	var bus: EventBus = null
	var recorder: Recorder = null
	var label: String = ""
	var subscribe_type: StringName = &""
	var subscribe_target: Callable = Callable()
	var unsubscribe_type: StringName = &""
	var unsubscribe_target: Callable = Callable()

	func _init(p_bus: EventBus, p_recorder: Recorder, p_label: String) -> void:
		bus = p_bus
		recorder = p_recorder
		label = p_label

	func on_event(_event: Event) -> void:
		recorder.record(label)
		if subscribe_target.is_valid():
			bus.subscribe(subscribe_type, subscribe_target)
		if unsubscribe_target.is_valid():
			bus.unsubscribe(unsubscribe_type, unsubscribe_target)


## Calls clear() from inside a handler — used to pin mass-unsubscribe during dispatch.
class ClearingHandler extends RefCounted:
	var bus: EventBus = null
	var recorder: Recorder = null
	var label: String = ""

	func _init(p_bus: EventBus, p_recorder: Recorder, p_label: String) -> void:
		bus = p_bus
		recorder = p_recorder
		label = p_label

	func on_event(_event: Event) -> void:
		recorder.record(label)
		bus.clear()


## A handler on a plain Object so that free() makes its Callable deterministically invalid
## (a RefCounted target could still be kept alive by another reference).
class FreeableHandler extends Object:
	var calls: int = 0

	func on_event(_event: Event) -> void:
		calls += 1


## Frees another subscriber's target from inside a handler — used to pin that a Callable which
## goes invalid mid-dispatch is skipped rather than called.
class FreeingHandler extends RefCounted:
	var recorder: Recorder = null
	var label: String = ""
	var victim: FreeableHandler = null

	func _init(p_recorder: Recorder, p_label: String, p_victim: FreeableHandler) -> void:
		recorder = p_recorder
		label = p_label
		victim = p_victim

	func on_event(_event: Event) -> void:
		recorder.record(label)
		if is_instance_valid(victim):
			victim.free()


# =============================================================================================
# A. PURITY & PLACEMENT (§11.1, §11.2, §11.3)
# =============================================================================================

## §11.1 "pure GDScript RefCounted classes ... No Node, no Scene Tree" + §11.2 (core lives in
## scripts/core/). Non-Node-ness is asserted through get_class() — see the TRAP note above.
func test_event_and_bus_are_pure_refcounted() -> void:
	var bus: EventBus = EventBus.new()
	var event: SimpleEvent = SimpleEvent.new(&"collapse")
	assert_eq(bus.get_class(), "RefCounted", "§11.1: EventBus must be a pure RefCounted")
	assert_eq(event.get_class(), "RefCounted", "§11.1: an Event must be a pure RefCounted")
	assert_true(FileAccess.file_exists(EVENT_PATH), "§11.2: %s" % EVENT_PATH)
	assert_true(FileAccess.file_exists(EVENT_BUS_PATH), "§11.2: %s" % EVENT_BUS_PATH)


## §11.1 "the core must run headless byte-identically": no Node, no Scene Tree, no engine
## singletons, no randi(), and (determinism rules) no wall-clock input. Scans the shipped source
## with comments stripped, so quoting the rule in a doc comment is safe.
func test_core_sources_are_engine_free() -> void:
	for path: String in [EVENT_PATH, EVENT_BUS_PATH]:
		var code: String = _code_text(path)
		assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % path)
		for token: String in ENGINE_BOUND_TOKENS:
			assert_false(
				code.contains(token),
				"§11.1: sim core must be engine-free — %s contains %s" % [path, token]
			)


# =============================================================================================
# B. THE TYPED EVENT (§11.1)
# =============================================================================================

## §11.1 "typed events" — an event carries the type name it was constructed with, as a StringName.
func test_event_carries_its_type() -> void:
	var event: SimpleEvent = SimpleEvent.new(&"unit_moved")
	assert_eq(event.type, &"unit_moved", "§11.1: the event exposes its construction type")
	assert_eq(
		typeof(event.type),
		TYPE_STRING_NAME,
		"§11.1: event types are StringNames (cheap, interned, comparison-stable)"
	)


## §11.1 "GameState.hash() (FNV over canonical serialization) must be reproducible" — the same
## determinism requirement applies to the event stream that logs/replays a match: to_dict() must
## put "type" FIRST (as a plain String) and then the subclass payload in declaration order.
func test_event_to_dict_is_canonically_ordered() -> void:
	var base: Dictionary = SimpleEvent.new(&"collapse").to_dict()
	var base_keys: Array = base.keys()
	assert_eq(base_keys, ["type"] as Array, "§11.1: the base event serializes to its type alone")
	assert_eq(base.get("type"), "collapse", "§11.1: type is written as a plain String")
	assert_eq(typeof(base.get("type")), TYPE_STRING, "§11.1: canonical form uses String, not StringName")

	var moved: Dictionary = MovedEvent.new(7, "q3r-4").to_dict()
	assert_eq(
		moved.keys(),
		["type", "unit_id", "to_hex"] as Array,
		"§11.1: canonical key order is type first, then payload in declaration order"
	)
	assert_eq(moved.get("type"), "unit_moved", "§11.1: subclass keeps its type key")
	assert_eq(moved.get("unit_id"), 7, "§11.1: payload survives serialization")
	assert_eq(moved.get("to_hex"), "q3r-4", "§11.1: payload survives serialization")


# =============================================================================================
# C. ROUTING & ORDER (§11.1)
# =============================================================================================

## §11.1 "Renderer/UI subscribe" — an emit reaches exactly the handlers of that type, and the
## handler receives the very object that was emitted (no copy: identity is what lets a renderer
## read typed payload fields).
func test_emit_routes_only_to_subscribers_of_that_type() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var listener: LabeledHandler = LabeledHandler.new(recorder, "hex")
	var bystander: LabeledHandler = LabeledHandler.new(recorder, "unit")
	bus.subscribe(&"hex_changed", listener.on_event)
	bus.subscribe(&"unit_moved", bystander.on_event)

	var event: SimpleEvent = SimpleEvent.new(&"hex_changed")
	bus.emit(event)

	assert_eq(listener.calls, 1, "§11.1: the matching subscriber is called exactly once")
	assert_same(listener.last_event, event, "§11.1: the emitted event object is delivered by identity")
	assert_eq(bystander.calls, 0, "§11.1: a subscriber of another type is never called")


## §11.1 "Determinism rules" + decisions.md M0-T3 (a): handlers of one type run in registration
## order, oldest first. Order must never depend on Dictionary key order or object addresses.
func test_delivery_follows_registration_order() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var first: LabeledHandler = LabeledHandler.new(recorder, "a")
	var second: LabeledHandler = LabeledHandler.new(recorder, "b")
	var third: LabeledHandler = LabeledHandler.new(recorder, "c")
	bus.subscribe(&"combat_resolved", first.on_event)
	bus.subscribe(&"combat_resolved", second.on_event)
	bus.subscribe(&"combat_resolved", third.on_event)

	bus.emit(SimpleEvent.new(&"combat_resolved"))

	assert_eq(
		recorder.entries,
		["a", "b", "c"] as Array[String],
		"§11.1: oldest subscriber first, always"
	)
	assert_eq(bus.subscriber_count(&"combat_resolved"), 3, "§11.1: all three stayed registered")


## §11.1 "apply(state) -> Array[Event]" — a Command returns an ORDERED array, so the bus must
## deliver that array in its own order (the renderer replays exactly what the sim decided).
func test_emit_all_delivers_in_array_order() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var handler: TagHandler = TagHandler.new(recorder)
	bus.subscribe(&"hex_changed", handler.on_event)

	var batch: Array[Event] = [
		TaggedEvent.new(&"hex_changed", "e1"),
		TaggedEvent.new(&"hex_changed", "e2"),
		TaggedEvent.new(&"hex_changed", "e3"),
	]
	bus.emit_all(batch)

	assert_eq(
		recorder.entries,
		["e1", "e2", "e3"] as Array[String],
		"§11.1: Array[Event] from apply() is delivered in array order"
	)


# =============================================================================================
# D. RE-ENTRANCY & SNAPSHOT SEMANTICS (§11.1 + decisions.md M0-T3 (b), (c))
# =============================================================================================

## decisions.md M0-T3 (b): an emit issued from inside a handler is QUEUED and delivered after the
## current event has finished with every one of its handlers — never depth-first. Depth-first
## delivery would make observer order depend on handler internals, which §11.1's determinism rule
## forbids. Pinned exactly: ["A1", "A2", "N1", "N2"], never ["A1", "N1", "A2", "N2"].
func test_nested_emit_is_queued_fifo() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var first: EmittingHandler = EmittingHandler.new(
		bus, recorder, "A1", TaggedEvent.new(&"noise_ping", "N1")
	)
	var second: EmittingHandler = EmittingHandler.new(
		bus, recorder, "A2", TaggedEvent.new(&"noise_ping", "N2")
	)
	var pings: TagHandler = TagHandler.new(recorder)
	bus.subscribe(&"collapse", first.on_event)
	bus.subscribe(&"collapse", second.on_event)
	bus.subscribe(&"noise_ping", pings.on_event)

	assert_false(bus.is_dispatching(), "§11.1: the bus is idle before any emit")
	bus.emit(SimpleEvent.new(&"collapse"))

	assert_eq(
		recorder.entries,
		["A1", "A2", "N1", "N2"] as Array[String],
		"decisions.md M0-T3 (b): nested emits are queued FIFO, not delivered depth-first"
	)
	assert_true(first.saw_dispatching, "§11.1: is_dispatching() is true inside a handler")
	assert_false(bus.is_dispatching(), "§11.1: the queue is fully drained when emit() returns")


## decisions.md M0-T3 (b): emit_all() queues the WHOLE Array[Event] a Command returned before it
## drains, so the batch is delivered as one atomic unit — an event nested by a handler while the
## batch is in flight lands after the batch, never between its elements. apply() -> Array[Event]
## (§11.1) is one coherent result; interleaving would make observer order depend on handler
## internals, which §11.1's determinism rule forbids.
func test_emit_all_batch_is_atomic_against_nested_emits() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var tags: TagHandler = TagHandler.new(recorder)
	var emitter: EmittingHandler = EmittingHandler.new(
		bus, recorder, "E", TaggedEvent.new(&"noise_ping", "ping")
	)
	bus.subscribe(&"collapse", tags.on_event)
	bus.subscribe(&"collapse", emitter.on_event)
	bus.subscribe(&"noise_ping", tags.on_event)

	bus.emit_all([
		TaggedEvent.new(&"collapse", "c1"),
		TaggedEvent.new(&"collapse", "c2"),
	] as Array[Event])

	assert_eq(
		recorder.entries,
		["c1", "E", "c2", "E", "ping", "ping"] as Array[String],
		"decisions.md M0-T3 (b): the whole emit_all batch drains before any event nested inside it"
	)
	assert_false(bus.is_dispatching(), "§11.1: the queue is fully drained when emit_all() returns")


## decisions.md M0-T3 (c): subscribing from inside a handler must not retro-add the new handler to
## the event already in flight (the subscriber list is snapshotted per event); it takes effect from
## the next emit of that type.
func test_subscribe_during_dispatch_skips_the_in_flight_event() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var late: LabeledHandler = LabeledHandler.new(recorder, "late")
	var early: MutatingHandler = MutatingHandler.new(bus, recorder, "early")
	early.subscribe_type = &"victory"
	early.subscribe_target = late.on_event
	bus.subscribe(&"victory", early.on_event)

	bus.emit(SimpleEvent.new(&"victory"))
	assert_eq(late.calls, 0, "decisions.md M0-T3 (c): a handler added mid-dispatch misses that event")
	assert_eq(bus.subscriber_count(&"victory"), 2, "§11.1: it IS registered for the next emit")

	bus.emit(SimpleEvent.new(&"victory"))
	assert_eq(late.calls, 1, "decisions.md M0-T3 (c): it receives the next emit of that type")
	assert_eq(
		recorder.entries,
		["early", "early", "late"] as Array[String],
		"§11.1: registration order still holds on the second emit"
	)


## decisions.md M0-T3 (c): unsubscribing from inside a handler takes effect immediately for the
## event in flight — a handler removed by an earlier handler must NOT be called for that event
## (the snapshot is re-checked against the live list before each call).
func test_unsubscribe_during_dispatch_cancels_delivery() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var victim: LabeledHandler = LabeledHandler.new(recorder, "B")
	var remover: MutatingHandler = MutatingHandler.new(bus, recorder, "A")
	remover.unsubscribe_type = &"breach_triggered"
	remover.unsubscribe_target = victim.on_event
	bus.subscribe(&"breach_triggered", remover.on_event)
	bus.subscribe(&"breach_triggered", victim.on_event)

	bus.emit(SimpleEvent.new(&"breach_triggered"))

	assert_eq(victim.calls, 0, "decisions.md M0-T3 (c): a handler removed mid-dispatch is skipped")
	assert_eq(recorder.entries, ["A"] as Array[String], "§11.1: only the surviving handler ran")
	assert_eq(bus.subscriber_count(&"breach_triggered"), 1, "§11.1: the removal is permanent")


# =============================================================================================
# E. SUBSCRIPTION BOOKKEEPING (decisions.md M0-T3 (d), (e))
# =============================================================================================

## decisions.md M0-T3 (d): subscribe is idempotent per (type, Callable) pair — a double subscribe
## must not double-deliver (which would double-animate a renderer), and one unsubscribe removes it.
func test_subscribe_is_idempotent_per_callable() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var handler: LabeledHandler = LabeledHandler.new(recorder, "once")
	bus.subscribe(&"victory", handler.on_event)
	bus.subscribe(&"victory", handler.on_event)
	assert_eq(bus.subscriber_count(&"victory"), 1, "decisions.md M0-T3 (d): duplicate subscribe is a no-op")

	bus.emit(SimpleEvent.new(&"victory"))
	assert_eq(handler.calls, 1, "decisions.md M0-T3 (d): exactly one invocation per emit")

	bus.unsubscribe(&"victory", handler.on_event)
	assert_eq(bus.subscriber_count(&"victory"), 0, "decisions.md M0-T3 (d): one unsubscribe suffices")
	bus.emit(SimpleEvent.new(&"victory"))
	assert_eq(handler.calls, 1, "decisions.md M0-T3 (d): an unsubscribed handler is never called again")


## decisions.md M0-T3 (d): the bus tolerates the boring cases in silence — unsubscribing something
## never subscribed, unsubscribing on an unknown type, emitting with no subscribers, and emit(null).
## None may error or crash; the run continuing to the asserts below is itself part of the proof.
func test_unknown_unsubscribe_and_empty_emit_are_no_ops() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var stranger: LabeledHandler = LabeledHandler.new(recorder, "stranger")

	bus.unsubscribe(&"research_done", stranger.on_event)
	bus.unsubscribe(&"no_such_type_at_all", stranger.on_event)
	bus.emit(SimpleEvent.new(&"research_done"))
	bus.emit(null)
	bus.emit_all([] as Array[Event])

	assert_eq(stranger.calls, 0, "decisions.md M0-T3 (d): nothing was delivered")
	assert_eq(recorder.entries, [] as Array[String], "decisions.md M0-T3 (d): nothing was recorded")
	assert_eq(bus.subscriber_count(&"research_done"), 0, "decisions.md M0-T3 (d): no phantom entries")
	assert_false(bus.is_dispatching(), "§11.1: the bus is idle again after the no-ops")


## decisions.md M0-T3 (e): a Callable whose target has been freed is skipped and pruned at
## dispatch, and a dead sibling never blocks a live subscriber (an observer being torn down must
## not be able to break the sim's event stream — §11.1 "the sim never calls them" is one-way).
func test_invalid_callables_are_skipped_and_pruned() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var doomed: FreeableHandler = FreeableHandler.new()
	var live: LabeledHandler = LabeledHandler.new(recorder, "live")
	bus.subscribe(&"wave_spawned", doomed.on_event)
	bus.subscribe(&"wave_spawned", live.on_event)
	assert_eq(bus.subscriber_count(&"wave_spawned"), 2, "sanity: both handlers registered")

	doomed.free()
	bus.emit(SimpleEvent.new(&"wave_spawned"))

	assert_eq(live.calls, 1, "decisions.md M0-T3 (e): a dead sibling must not block a live handler")
	assert_eq(
		bus.subscriber_count(&"wave_spawned"),
		1,
		"decisions.md M0-T3 (e): the invalid Callable is pruned, the live one kept"
	)


## decisions.md M0-T3 (e): a Callable whose target is freed BY AN EARLIER HANDLER of the very same
## event is skipped, not called — validity is re-checked immediately before each call, not only at
## the pre-dispatch prune. It is then pruned on the next dispatch of that type.
func test_target_freed_during_dispatch_is_skipped() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var doomed: FreeableHandler = FreeableHandler.new()
	var killer: FreeingHandler = FreeingHandler.new(recorder, "killer", doomed)
	var live: LabeledHandler = LabeledHandler.new(recorder, "live")
	bus.subscribe(&"wave_spawned", killer.on_event)
	bus.subscribe(&"wave_spawned", doomed.on_event)
	bus.subscribe(&"wave_spawned", live.on_event)

	bus.emit(SimpleEvent.new(&"wave_spawned"))

	assert_eq(
		recorder.entries,
		["killer", "live"] as Array[String],
		"decisions.md M0-T3 (e): the freed target is skipped and the live sibling after it still runs"
	)
	assert_eq(live.calls, 1, "§11.1: one-way delivery survives an observer dying mid-dispatch")

	bus.emit(SimpleEvent.new(&"wave_spawned"))

	assert_eq(
		bus.subscriber_count(&"wave_spawned"),
		2,
		"decisions.md M0-T3 (e): the dead entry is pruned by the next dispatch"
	)
	assert_eq(live.calls, 2, "§11.1: the surviving subscribers keep receiving")


## decisions.md M0-T3 (c): clear() is a mass-unsubscribe, so — exactly like unsubscribe() — calling
## it from inside a handler takes effect immediately for the event in flight: handlers that have
## not run yet are skipped. Anything else would make clear() and unsubscribe() disagree about the
## in-flight event, i.e. make delivery depend on which teardown call an observer happened to use.
func test_clear_during_dispatch_cancels_the_rest_of_the_event() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var wiper: ClearingHandler = ClearingHandler.new(bus, recorder, "wiper")
	var later: LabeledHandler = LabeledHandler.new(recorder, "later")
	bus.subscribe(&"victory", wiper.on_event)
	bus.subscribe(&"victory", later.on_event)

	bus.emit(SimpleEvent.new(&"victory"))

	assert_eq(later.calls, 0, "decisions.md M0-T3 (c): clear() mid-dispatch skips the handlers not yet run")
	assert_eq(
		recorder.entries,
		["wiper"] as Array[String],
		"§11.1: only the handler that ran before clear() was invoked"
	)
	assert_eq(bus.subscriber_count(&"victory"), 0, "§11.1: clear() emptied the table")
	assert_false(bus.is_dispatching(), "§11.1: the bus is idle again afterwards")


## §11.1 — clear() drops every subscription for every type (the teardown a renderer swap needs).
func test_clear_removes_every_subscription() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var one: LabeledHandler = LabeledHandler.new(recorder, "one")
	var two: LabeledHandler = LabeledHandler.new(recorder, "two")
	bus.subscribe(&"hex_changed", one.on_event)
	bus.subscribe(&"noise_ping", two.on_event)
	assert_eq(bus.subscriber_count(&"hex_changed"), 1, "sanity: registered before clear()")
	assert_eq(bus.subscriber_count(&"noise_ping"), 1, "sanity: registered before clear()")

	bus.clear()

	assert_eq(bus.subscriber_count(&"hex_changed"), 0, "§11.1: clear() empties every type")
	assert_eq(bus.subscriber_count(&"noise_ping"), 0, "§11.1: clear() empties every type")
	bus.emit(SimpleEvent.new(&"hex_changed"))
	bus.emit(SimpleEvent.new(&"noise_ping"))
	assert_eq(recorder.entries, [] as Array[String], "§11.1: nothing is delivered after clear()")


# =============================================================================================
# F. DETERMINISM & OPEN VOCABULARY (§11.1, §13.5)
# =============================================================================================

## §11.1 "the core must run headless byte-identically" — the same subscribe/emit script on two
## fresh buses produces the identical delivery order. Compared run-against-run, never against a
## hardcoded expectation of engine internals, so this pins the rule and not the build.
func test_repeat_runs_deliver_identical_order() -> void:
	var first_run: Array[String] = _delivery_scenario()
	var second_run: Array[String] = _delivery_scenario()
	assert_false(first_run.is_empty(), "sanity: the scenario actually delivered something")
	assert_eq(first_run, second_run, "§11.1: identical input ⇒ identical delivery order")


## §11.1's event list ends in "..." — the vocabulary is open, so the bus must route a type name
## that appears nowhere in engine code, and engine code must contain no whitelist of names. This
## is the §13.5 "adding content requires zero engine-code changes" rule, guarded from M0 on.
func test_event_vocabulary_is_open() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var handler: LabeledHandler = LabeledHandler.new(recorder, "novel")
	bus.subscribe(&"totally_new_type_xyz", handler.on_event)

	bus.emit(SimpleEvent.new(&"totally_new_type_xyz"))

	assert_eq(handler.calls, 1, "§11.1: an unknown-to-the-engine event type routes normally")
	for path: String in [EVENT_PATH, EVENT_BUS_PATH]:
		var code: String = _code_text(path)
		for event_name: String in ILLUSTRATIVE_EVENT_NAMES:
			assert_false(
				code.contains(event_name),
				"§11.1/§13.5: %s must not hard-code the event name %s" % [path, event_name]
			)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## Runs one fixed subscribe/emit script on a fresh bus and returns the delivery order.
func _delivery_scenario() -> Array[String]:
	var bus: EventBus = EventBus.new()
	var recorder: Recorder = Recorder.new()
	var alpha: LabeledHandler = LabeledHandler.new(recorder, "alpha")
	var beta: LabeledHandler = LabeledHandler.new(recorder, "beta")
	var tags: TagHandler = TagHandler.new(recorder)
	var nested: EmittingHandler = EmittingHandler.new(
		bus, recorder, "nested", TaggedEvent.new(&"noise_ping", "ping")
	)
	bus.subscribe(&"hex_changed", alpha.on_event)
	bus.subscribe(&"hex_changed", nested.on_event)
	bus.subscribe(&"hex_changed", beta.on_event)
	bus.subscribe(&"noise_ping", tags.on_event)
	bus.emit_all([
		TaggedEvent.new(&"hex_changed", "h1"),
		TaggedEvent.new(&"hex_changed", "h2"),
	] as Array[Event])
	return recorder.entries


## Reads a source file with every comment stripped, so asserting on source content can never be
## tripped by a doc comment that quotes the very rule being enforced.
func _code_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "source must be readable: %s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	var code_lines: PackedStringArray = PackedStringArray()
	for raw_line: String in text.split("\n"):
		var comment_at: int = raw_line.find("#")
		code_lines.append(raw_line if comment_at == -1 else raw_line.substr(0, comment_at))
	return "\n".join(code_lines)
