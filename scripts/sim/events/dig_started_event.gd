## DigStartedEvent — the project's SECOND concrete [Event] subclass. GDD §11.1 ("EventBus: typed
## events emitted by apply() ... Renderer/UI subscribe; the sim never calls them"), §4.2 (the dig
## the event announces).
##
## [constant TYPE_NAME] is this event's OWN name, not a vocabulary: `scripts/core/event.gd` and
## `scripts/core/event_bus.gd` stay free of every event name (the M0-T3 (f) precedent) and are NOT
## edited by this task.
##
## (AY) — carries `player_index` (who ordered the dig), `unit_id` (which unit was assigned), `hex`
## (the target), `remaining_turns` (the site's remaining worker-turns AFTER the assignment) and
## `site_created` (true when this order CREATED the site, false when it joined an existing one:
## §4.2 line 197 — a second digger joining is also a state change, so §13.6 wants an event for it
## too). `to_dict()` calls the base FIRST so "type" stays the first key, then appends the payload
## in declaration order, flattening `hex` into the two JSON scalars `hex_q`/`hex_r` (§11.1 line
## 708's save is JSON — a raw Vector2i does not survive that round trip).
class_name DigStartedEvent
extends Event

## §11.1 — this event's type name.
const TYPE_NAME: StringName = &"dig_started"

## (AY) — the player who ordered the dig.
var player_index: int = 0

## (AY) — the unit assigned by this order.
var unit_id: int = 0

## §4.1/(AY) — the target hex being dug.
var hex: Vector2i = Vector2i.ZERO

## §4.2/(AY) — the site's remaining worker-turns AFTER this assignment.
var remaining_turns: int = 0

## (AY) — true when this order CREATED the site, false when it joined an existing one.
var site_created: bool = false


func _init(
	p_player_index: int,
	p_unit_id: int,
	p_hex: Vector2i,
	p_remaining_turns: int,
	p_site_created: bool
) -> void:
	super(TYPE_NAME)
	player_index = p_player_index
	unit_id = p_unit_id
	hex = p_hex
	remaining_turns = p_remaining_turns
	site_created = p_site_created


## §11.1 — calls the base FIRST so "type" stays the first key, then appends the payload in
## declaration order; `hex` is flattened into `hex_q`/`hex_r` since a Vector2i is not a JSON
## scalar (§11.1 line 708's save is JSON).
func to_dict() -> Dictionary:
	var out: Dictionary = super.to_dict()
	out["player_index"] = player_index
	out["unit_id"] = unit_id
	out["hex_q"] = hex.x
	out["hex_r"] = hex.y
	out["remaining_turns"] = remaining_turns
	out["site_created"] = site_created
	return out
