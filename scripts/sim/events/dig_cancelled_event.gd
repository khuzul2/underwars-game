## DigCancelledEvent — the project's THIRD concrete [Event] subclass. GDD §11.1 ("EventBus: typed
## events emitted by apply() ... Renderer/UI subscribe; the sim never calls them"), §4.2 (the dig
## the cancel abandons).
##
## [constant TYPE_NAME] is this event's OWN name, not a vocabulary: `scripts/core/event.gd` and
## `scripts/core/event_bus.gd` stay free of every event name (the M0-T3 (f) precedent) and are NOT
## edited by this task.
##
## (AZ) — carries `player_index` (who cancelled), `unit_id` (which unit was unassigned), `hex`
## (the site's hex), `remaining_turns` (the site's remaining worker-turns at cancellation —
## UNCHANGED by the cancel itself, since `DigSite.remove_digger` never touches them) and
## `site_removed` (true when the LAST digger left and the site was removed with its progress LOST,
## false when a crew-mate remains). `to_dict()` calls the base FIRST so "type" stays the first key,
## then appends the payload in declaration order, flattening `hex` into the two JSON scalars
## `hex_q`/`hex_r` (§11.1 line 708's save is JSON — a raw Vector2i does not survive that round
## trip).
class_name DigCancelledEvent
extends Event

## §11.1 — this event's type name.
const TYPE_NAME: StringName = &"dig_cancelled"

## (AZ) — the player who cancelled.
var player_index: int = 0

## (AZ) — the unit unassigned by the cancel.
var unit_id: int = 0

## §4.1/(AZ) — the hex the cancelled site is on.
var hex: Vector2i = Vector2i.ZERO

## §4.2/(AZ) — the site's remaining worker-turns at cancellation.
var remaining_turns: int = 0

## (AZ) — true when the last digger left and the site was removed.
var site_removed: bool = false


func _init(
	p_player_index: int,
	p_unit_id: int,
	p_hex: Vector2i,
	p_remaining_turns: int,
	p_site_removed: bool
) -> void:
	super(TYPE_NAME)
	player_index = p_player_index
	unit_id = p_unit_id
	hex = p_hex
	remaining_turns = p_remaining_turns
	site_removed = p_site_removed


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
	out["site_removed"] = site_removed
	return out
