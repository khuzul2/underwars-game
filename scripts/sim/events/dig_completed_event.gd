## DigCompletedEvent — the project's FIFTH concrete [Event] subclass. GDD §11.1 ("EventBus: typed
## events emitted by apply() ... Renderer/UI subscribe; the sim never calls them"), §3.4 step 4
## ("completed digs apply yields"), §4.2 (the "Yield on dig" column and the Cave hex the Solid hex
## becomes), §5.1 (per-player integer stockpiles).
##
## (BA)(iv)(v) — ONE completion changes FOUR things (worker-turns spent, a stockpile credited, a
## hex flipped and a site removed, freeing its diggers); this event's rich payload makes every one
## of them observable without four separate events. Carries `player_index` (the SITE'S OWNER, who
## is credited — not necessarily whoever's turn it is), `hex` (the hex that finished), `digger_ids`
## (the freed unit ids, ASCENDING), `resource_ids`/`amounts` (the §4.2 yield, ids ASCENDING and
## index-aligned with their amounts) and `terrain_id` (the Cave id the hex became). `to_dict()`
## calls the base FIRST so "type" stays the first key, then appends the payload in declaration
## order, flattening `hex` into the two JSON scalars `hex_q`/`hex_r` (§11.1 line 708's save is
## JSON — a raw Vector2i does not survive that round trip).
class_name DigCompletedEvent
extends Event

## §11.1 — this event's type name.
const TYPE_NAME: StringName = &"dig_completed"

## §5.1/(BA)(iv) — the player the yield was credited to: the SITE'S owner, not necessarily
## whoever's turn it is.
var player_index: int = 0

## §4.1/(BA)(iv) — the hex that finished being dug.
var hex: Vector2i = Vector2i.ZERO

## §4.2 line 197/(BA)(iv) — the unit ids freed by the completion, ASCENDING.
var digger_ids: Array[int] = []

## §5.1/§4.2 — the resource ids yielded, ASCENDING, aligned with [member amounts].
var resource_ids: Array[String] = []

## §4.2 "Yield on dig" — the amount yielded for each entry of [member resource_ids].
var amounts: Array[int] = []

## §4.2 — the Cave terrain id the hex became.
var terrain_id: String = ""


func _init(
	p_player_index: int,
	p_hex: Vector2i,
	p_digger_ids: Array[int],
	p_resource_ids: Array[String],
	p_amounts: Array[int],
	p_terrain_id: String
) -> void:
	super(TYPE_NAME)
	player_index = p_player_index
	hex = p_hex
	digger_ids = p_digger_ids.duplicate()
	resource_ids = p_resource_ids.duplicate()
	amounts = p_amounts.duplicate()
	terrain_id = p_terrain_id


## §11.1 — calls the base FIRST so "type" stays the first key, then appends the payload in
## declaration order; `hex` is flattened into `hex_q`/`hex_r` since a Vector2i is not a JSON
## scalar (§11.1 line 708's save is JSON), and the array fields are handed out as fresh
## duplicates so a logger can never mutate the event's own arrays through the returned Dictionary.
func to_dict() -> Dictionary:
	var out: Dictionary = super.to_dict()
	out["player_index"] = player_index
	out["hex_q"] = hex.x
	out["hex_r"] = hex.y
	out["digger_ids"] = digger_ids.duplicate()
	out["resource_ids"] = resource_ids.duplicate()
	out["amounts"] = amounts.duplicate()
	out["terrain_id"] = terrain_id
	return out
