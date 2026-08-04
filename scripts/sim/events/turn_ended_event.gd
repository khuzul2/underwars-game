## TurnEndedEvent — the project's FIRST concrete [Event] subclass. GDD §11.1: "EventBus: typed
## events emitted by apply() ... Renderer/UI subscribe; the sim never calls them"; §3.3
## ("Sequential player turns ... fixed order by player index, then a World phase").
##
## [constant TYPE_NAME] is this event's OWN name, not a vocabulary: `scripts/core/event.gd` and
## `scripts/core/event_bus.gd` stay free of every event name (the M0-T3 (f) precedent) and are
## NOT edited by this task.
class_name TurnEndedEvent
extends Event

## §11.1 — this event's type name.
const TYPE_NAME: StringName = &"turn_ended"

## §3.3 — the player index whose turn just ended.
var player_index: int = 0

## §3.3 — the player index whose turn begins next.
var next_player_index: int = 0

## §3.3 — the turn number AFTER the advance.
var turn: int = 0


func _init(p_player_index: int, p_next_player_index: int, p_turn: int) -> void:
	super(TYPE_NAME)
	player_index = p_player_index
	next_player_index = p_next_player_index
	turn = p_turn


## §11.1 — calls the base FIRST so "type" stays the first key, then appends the three payload
## keys in declaration order.
func to_dict() -> Dictionary:
	var out: Dictionary = super.to_dict()
	out["player_index"] = player_index
	out["next_player_index"] = next_player_index
	out["turn"] = turn
	return out
