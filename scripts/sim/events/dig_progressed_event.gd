## DigProgressedEvent — the project's FOURTH concrete [Event] subclass. GDD §11.1 ("EventBus:
## typed events emitted by apply() ... Renderer/UI subscribe; the sim never calls them"), §3.4
## step 4 ("Dig progress ticks"), §4.2 (the worker-turns being spent).
##
## (BA)(v) — carries `player_index` (whose start-of-turn tick spent the worker-turns), `hex` (the
## site that progressed), `digger_count` (the worker-turns spent — the site's crew size at the
## moment of the tick) and `remaining_turns` (the site's remainder AFTER the tick, so a completing
## tick reports exactly 0). `to_dict()` calls the base FIRST so "type" stays the first key, then
## appends the payload in declaration order, flattening `hex` into the two JSON scalars
## `hex_q`/`hex_r` (§11.1 line 708's save is JSON — a raw Vector2i does not survive that round
## trip).
class_name DigProgressedEvent
extends Event

## §11.1 — this event's type name.
const TYPE_NAME: StringName = &"dig_progressed"

## §3.4 step 4/(BA)(v) — the player whose start-of-turn tick spent the worker-turns.
var player_index: int = 0

## §4.1/(BA)(v) — the hex whose dig site progressed.
var hex: Vector2i = Vector2i.ZERO

## §4.2 line 197/(BA)(v) — how many worker-turns this tick spent, i.e. the site's digger count.
var digger_count: int = 0

## §4.2/(BA)(v) — the site's remaining worker-turns AFTER this tick.
var remaining_turns: int = 0


func _init(
	p_player_index: int,
	p_hex: Vector2i,
	p_digger_count: int,
	p_remaining_turns: int
) -> void:
	super(TYPE_NAME)
	player_index = p_player_index
	hex = p_hex
	digger_count = p_digger_count
	remaining_turns = p_remaining_turns


## §11.1 — calls the base FIRST so "type" stays the first key, then appends the payload in
## declaration order; `hex` is flattened into `hex_q`/`hex_r` since a Vector2i is not a JSON
## scalar (§11.1 line 708's save is JSON).
func to_dict() -> Dictionary:
	var out: Dictionary = super.to_dict()
	out["player_index"] = player_index
	out["hex_q"] = hex.x
	out["hex_r"] = hex.y
	out["digger_count"] = digger_count
	out["remaining_turns"] = remaining_turns
	return out
