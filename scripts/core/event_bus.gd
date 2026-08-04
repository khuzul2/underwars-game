## EventBus — GDD §11.1: "typed events emitted by apply() ... Renderer/UI subscribe; the sim
## never calls them". One-way: observers are invoked, never queried, and nothing they return
## flows back into the sim.
##
## §11.3 conventions: pure RefCounted (no Node, no scene tree, no engine singletons, no randi(),
## no wall-clock), static typing everywhere, one class per file.
##
## §11.1 determinism: delivery order is a pure function of the subscribe/emit sequence — never of
## Dictionary key order — so the same command log always produces the same observer stream.
##
## A handler is a Callable taking exactly one Event parameter.
class_name EventBus
extends RefCounted

## StringName -> Array[Callable]. Only ever accessed by key lookup during dispatch — never
## iterated as a whole — so Dictionary key order can never leak into delivery order (§11.1).
var _subscribers: Dictionary = {}

## FIFO queue of events awaiting dispatch. A nested emit() issued from inside a handler appends
## here and returns immediately instead of dispatching depth-first (decisions.md M0-T3 (b)).
var _queue: Array[Event] = []

## True for the whole duration of the outer emit()/emit_all() call that is draining `_queue`,
## including while a handler nested inside it is running.
var _dispatching: bool = false


## §11.1 — register a handler for one event type. Idempotent per (type, Callable) pair
## (decisions.md M0-T3 (d)).
func subscribe(event_type: StringName, handler: Callable) -> void:
	if not _subscribers.has(event_type):
		_subscribers[event_type] = [] as Array[Callable]
	var handlers: Array[Callable] = _subscribers[event_type]
	if not handlers.has(handler):
		handlers.append(handler)


## §11.1 — remove a handler from one event type. Unknown pair, or unknown type, is a silent
## no-op (decisions.md M0-T3 (d)).
func unsubscribe(event_type: StringName, handler: Callable) -> void:
	if not _subscribers.has(event_type):
		return
	var handlers: Array[Callable] = _subscribers[event_type]
	var index: int = handlers.find(handler)
	if index != -1:
		handlers.remove_at(index)


## §11.1 — deliver one event to its subscribers. Nested emits are queued, never re-entrant
## (decisions.md M0-T3 (b)). emit(null) is a no-op.
func emit(event: Event) -> void:
	if event == null:
		return
	_queue.append(event)
	_drain()


## §11.1 — deliver a Command's Array[Event] result in array order (decisions.md M0-T3 (b): the
## whole batch is queued before draining, so it is delivered as one atomic unit even if a handler
## triggered by an earlier element nests a further emit).
func emit_all(events: Array[Event]) -> void:
	for event: Event in events:
		if event != null:
			_queue.append(event)
	_drain()


## §11.1 — drop every subscription for every event type.
func clear() -> void:
	_subscribers.clear()


## §11.1 — how many handlers are registered for one event type.
func subscriber_count(event_type: StringName) -> int:
	if not _subscribers.has(event_type):
		return 0
	var handlers: Array[Callable] = _subscribers[event_type]
	return handlers.size()


## §11.1 — true while the bus is draining its queue (i.e. inside a handler call).
func is_dispatching() -> bool:
	return _dispatching


## §11.1 — drain `_queue` in FIFO order. If a drain is already in progress (this call was reached
## from inside a handler), do nothing: the outer drain will pick up whatever was just queued.
func _drain() -> void:
	if _dispatching:
		return
	_dispatching = true
	while not _queue.is_empty():
		var next_event: Event = _queue.pop_front()
		_dispatch(next_event)
	_dispatching = false


## §11.1 — deliver one event to the current subscribers of its type. Invalid (freed-target)
## Callables are pruned from the live list first (decisions.md M0-T3 (e)); the remaining live
## list is snapshotted with duplicate() and each entry is re-checked against the LIVE table
## immediately before calling it, so a subscribe(), unsubscribe() or clear() performed by an
## earlier handler in this same dispatch cannot retroactively add or block delivery for this
## event (decisions.md M0-T3 (c)). The pre-call check re-tests validity too, so a target freed by
## an earlier handler in this same dispatch is skipped rather than called (decisions.md M0-T3 (e));
## it is pruned on the next dispatch of that type.
func _dispatch(event: Event) -> void:
	var event_type: StringName = event.type
	if not _subscribers.has(event_type):
		return
	var handlers: Array[Callable] = _subscribers[event_type]
	var index: int = handlers.size() - 1
	while index >= 0:
		if not handlers[index].is_valid():
			handlers.remove_at(index)
		index -= 1
	var snapshot: Array[Callable] = handlers.duplicate()
	for handler: Callable in snapshot:
		if not _subscribers.has(event_type):
			return
		var live: Array[Callable] = _subscribers[event_type]
		if live.has(handler) and handler.is_valid():
			handler.call(event)
