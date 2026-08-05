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
## §3.4 STEP 4, resolution (BA): after the rotation, this command DELEGATES to [DigTick] for the
## INCOMING player (`next_index` — "at start of their turn" read literally, so player 0's first
## turn of a match runs no step-4 pass at all). `p_dig_rules` is OPTIONAL and INJECTED
## already-loaded (the [DigHexCommand] precedent); null (the default) leaves the command
## UNCONFIGURED and it runs NO step-4 pass, exactly as an unconfigured [DigHexCommand] creates no
## site. The step-4 RULE itself — decrementing worker-turns, applying a yield, flipping a hex —
## does not live here: §3.4 lists twelve steps and this Command will gain eleven more siblings, so
## it composes [DigTick] rather than inlining its mutations.
##
## DELIBERATELY OUT OF SCOPE at M2-T7 (§13.4): §3.4's other eight per-player start-of-turn steps
## (income, upkeep, construction/training ticks, healing, status/cooldown ticks, structural
## stress, light/vision recompute, action phase) and its three World-phase steps (creep AI, Wrath,
## victory checks); §3.4 step 4's own Breach checks (§4.6) and Noise pings (§4.8), which are M5;
## §3.2/§12.1's victory turn limit and the victory checks (M6); vein nodes, Extractors, income,
## upkeep, housing, Mining Zones; §3.1's starting kit.
class_name EndTurnCommand
extends Command

## §3.3 — the player index this End Turn is issued by. Private and read-only via
## [method player_index]: the command is an immutable value object.
var _player_index: int = 0

## §3.4 step 4/(BA) — the OPTIONAL injected, already-loaded dig table the start-of-turn dig tick
## reads through. Null (the default) leaves the command UNCONFIGURED and it runs NO step-4 pass.
var _dig_rules: DigRules = null


## §3.4 step 4 — the OPTIONAL injected, already-loaded dig table the start-of-turn dig tick reads
## through. Null (the default) leaves the command UNCONFIGURED and it runs NO step-4 pass, exactly
## as an unconfigured [DigHexCommand] creates no site.
func _init(p_player_index: int, p_dig_rules: DigRules = null) -> void:
	_player_index = p_player_index
	_dig_rules = p_dig_rules


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


## §3.3/§3.4 step 4 — rotates the turn position (§3.3 THE ROTATION TABLE), emits exactly one
## TurnEndedEvent carrying the acting player, the next player and the turn number AFTER the
## advance, THEN — when a [DigTick] table is injected — delegates §3.4 step 4 to it for the
## INCOMING player, appending whatever it announces after the rotation event (BA)(i).
func apply(state: GameState) -> Array[Event]:
	var next: int = (state.current_player_index() + 1) % state.player_count()
	var next_turn: int = state.turn() + 1 if next == 0 else state.turn()
	state.set_turn_position(next_turn, next)
	var out: Array[Event] = [TurnEndedEvent.new(_player_index, next, next_turn)]
	if _dig_rules != null:
		out.append_array(DigTick.new(_dig_rules).tick_digs(state, next))
	return out
