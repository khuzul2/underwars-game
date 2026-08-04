## EndTurnCommand — GDD §11.1 (EndTurn is one of the fourteen printed commands) and §3.3
## ("Sequential player turns (IGOUGO, Civ-style), fixed order by player index, then a World
## phase").
##
## An IMMUTABLE value object: every parameter is set in `_init` and neither `validate` nor
## `apply` ever mutates `self`, because §11.1's replay contract executes the same command_log
## more than once.
##
## THE ROTATION (§3.3, resolution (AV)): `next_index = (current + 1) % player_count`, and
## `turn += 1` exactly when `next_index` wraps to 0 — a full round of all players is one turn.
## The rotation is a RULE and lives here; [GameState] only stores the position.
##
## REJECTION VOCABULARY (resolution (AV)), opaque StringNames authored at their own call sites
## below: `null_state`, `no_players`, `not_current_player` (an out-of-range player index rejects
## as `not_current_player` too — the current index is always in range, so an out-of-range index
## can never be the current one).
##
## DELIBERATELY OUT OF SCOPE at M2-T2 (§13.4): §3.4's nine per-player start-of-turn steps
## (income, upkeep, construction/training ticks, dig ticks + Breach + Noise, healing,
## status/cooldown ticks, structural stress, light/vision recompute, action phase) and its three
## World-phase steps (creep AI, Wrath, victory checks); §3.2/§12.1's victory turn limit and the
## victory checks (M6); workers, dig progress, yields, vein nodes, Extractors, income, upkeep,
## housing, Mining Zones; §3.1's starting kit.
class_name EndTurnCommand
extends Command

## §3.3 — the player index this End Turn is issued by. Private and read-only via
## [method player_index]: the command is an immutable value object.
var _player_index: int = 0


func _init(p_player_index: int) -> void:
	_player_index = p_player_index


## §3.3 — the player index this command was constructed for.
func player_index() -> int:
	return _player_index


## §11.1 — one of the fourteen printed §11.1 command names.
func command_name() -> StringName:
	return &"end_turn"


## §11.1/§3.3 — rejects a null state (`null_state`), an empty roster (`no_players`, since there
## is no current player to end a turn for and `(current + 1) % 0` would divide by zero), and any
## player index other than the current one (`not_current_player`, which also covers an
## out-of-range index). Null means legal.
func validate(state: GameState) -> CommandError:
	if state == null:
		return CommandError.new(&"null_state", "EndTurnCommand requires a GameState")
	if state.player_count() == 0:
		return CommandError.new(&"no_players", "EndTurnCommand requires at least one player")
	if _player_index != state.current_player_index():
		return CommandError.new(
			&"not_current_player",
			"player %d may not end player %d's turn" % [
				_player_index, state.current_player_index()
			]
		)
	return null


## §3.3 — rotates the turn position (§3.3 THE ROTATION TABLE) and emits exactly one
## TurnEndedEvent carrying the acting player, the next player and the turn number AFTER the
## advance.
func apply(state: GameState) -> Array[Event]:
	var next: int = (state.current_player_index() + 1) % state.player_count()
	var next_turn: int = state.turn() + 1 if next == 0 else state.turn()
	state.set_turn_position(next_turn, next)
	var out: Array[Event] = [TurnEndedEvent.new(_player_index, next, next_turn)]
	return out
