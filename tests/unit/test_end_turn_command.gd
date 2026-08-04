## EndTurnCommand — the project's FIRST real Command. GDD §11.1 (Layered Design, **binding**),
## §3.3 (Turn Model), §3.4 (Order of Operations, **binding; implement exactly**), §3.1, §3.2,
## §11.2, §11.3, §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 705): "**Commands** (command pattern): MoveUnit, AttackUnit, AttackHex, DigHex,
##         CancelDig, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein,
##         SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -> Error?
##         and apply(state) -> Array[Event]."
##   §3.3  (line 137): "Sequential player turns (IGOUGO, Civ-style), **fixed order by player
##         index**, then a **World phase**. Chosen over simultaneous resolution deliberately:
##         vastly simpler, deterministic, AI-friendly."
##   §3.1  (line 118): "**Skirmish:** 2–4 players (human + AI) ..."
##   §3.4  (lines 141–165): the nine per-player start-of-turn steps and the three World-phase
##         steps — ALL deliberately unimplemented in this slice and pinned NEGATIVELY below.
##
## `docs/decisions.md` was re-scanned end to end this iteration: the ONLY logged §12.1 override
## is (AU)(i) (`dig_yields.artificial_granite.stone = 2`, irrelevant here); **NO logged override
## touches §3.1, §3.2, §3.3, §3.4 or §11.1**, so the printed text governs unamended. §3.3 prints
## the rotation but not its arithmetic and no starting position, so the following are §13.4
## resolutions lettered **(AV)** ((AU) is cross-referenced by four files — do NOT renumber it):
##   (AV) TURN NUMBERING AND ROTATION.
##       - A fresh GameState starts at **turn 1, current_player_index 0**. §3.2 line 133 prints
##         "If turn 200 is reached", which counts from 1; §14/§13.2's "after N turns" is silent.
##       - `next_index = (current + 1) % player_count`; `turn += 1` **exactly when next_index
##         wraps to 0** — a full round of all players is ONE turn, which is what §3.2's turn
##         limit and §12.1's `victory.turn_limit` count.
##       - The rotation is a RULE and lives in the Command; `GameState` only stores the position.
##   (AV) REJECTION VOCABULARY — opaque StringNames authored by this Command at its own call
##       site: `null_state`, `no_players`, `not_current_player`. There is no enum and no const
##       list of codes anywhere (the (AU)(iv) / (T) / (AH) / M0-T3 (f) precedent). An out-of-range
##       player index is `not_current_player` too: the current index is always in range, so an
##       out-of-range index can never be the current one.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY; the base class is asserted through the script's
## own `get_base_script()`.
##
## The source scans at the bottom are written FRESH for
## `scripts/sim/commands/end_turn_command.gd`.
extends GutTest

const END_TURN_PATH: String = "res://scripts/sim/commands/end_turn_command.gd"
const COMMAND_PATH: String = "res://scripts/sim/commands/command.gd"

## §12.6's example seed, so this file's seeds come from the GDD rather than from invention.
const GOLDEN_SEED: int = 1337

## §3.1 line 118 "Skirmish: **2–4 players**" — the fixture range the rotation sweep runs over.
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

## §11.1 line 705's FOURTEEN printed command names, snake_cased. THE LIST LIVES IN THIS TEST and
## never in engine code (the (AU)(iv) / (T) / (AH) / M0-T3 (f) no-whitelist rule): the chosen name
## must be one of these, and the printed list must not silently gain or lose an entry.
const PRINTED_COMMAND_NAMES: Array[String] = [
	"move_unit",
	"attack_unit",
	"attack_hex",
	"dig_hex",
	"cancel_dig",
	"build_structure",
	"train_unit",
	"research_tech",
	"use_ability",
	"convert_depleted_vein",
	"set_zone",
	"set_rally",
	"garrison_ruin",
	"end_turn",
]

## (AV) — the three rejection codes this Command authors.
const CODE_NULL_STATE: StringName = &"null_state"
const CODE_NO_PLAYERS: StringName = &"no_players"
const CODE_NOT_CURRENT_PLAYER: StringName = &"not_current_player"

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

## §11.1 "Renderer/UI subscribe; **the sim never calls them**".
const RENDERER_TOKENS: Array[String] = [
	"MapRenderer",
	"CameraRig",
	"HexPicker",
	"HexLayout",
	"MultiMesh",
	"Camera3D",
	"Node3D",
]

## §3.2 line 133 "If turn 200 is reached (configurable)" / §12.1 `victory.turn_limit` — M6, and
## explicitly NOT this task.
const VICTORY_TURN_LIMIT_TOKEN: String = "200"

## The COMPLETE public surface of EndTurnCommand. `_init` is excluded from the collected list by
## the leading underscore and is pinned separately by construction.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"player_index", "command_name", "validate", "apply"
]
const REQUIRED_PUBLIC_VARS: Array[String] = []

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§3.3", "§3.4", "§3.1"]


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Counts deliveries and records the full payload of every TurnEndedEvent it receives.
class CountingHandler extends RefCounted:
	var calls: int = 0
	var payloads: Array[Vector3i] = []

	func on_event(event: Event) -> void:
		calls += 1
		var ended: TurnEndedEvent = event as TurnEndedEvent
		if ended != null:
			payloads.append(
				Vector3i(ended.player_index, ended.next_player_index, ended.turn)
			)


# =============================================================================================
# A. IDENTITY (§11.1 line 705: EndTurn is one of the fourteen printed commands)
# =============================================================================================

## §11.1 — EndTurnCommand IS a Command: it inherits the gate, so nothing can apply past
## validation. Asserted through the script's base script, never `is Node` (a parse-error trap).
func test_end_turn_is_a_command_and_inherits_the_gate() -> void:
	var command: EndTurnCommand = EndTurnCommand.new(0)
	var own_script: Script = command.get_script()
	assert_not_null(own_script, "sanity: the instance carries its script")
	if own_script == null:
		return
	var base_script: Script = own_script.get_base_script()
	assert_not_null(base_script, "§11.1: EndTurnCommand extends the Command base")
	if base_script == null:
		return
	assert_eq(
		base_script.resource_path,
		COMMAND_PATH,
		"§11.1: EndTurnCommand must extend %s so it inherits the validate/apply gate" % COMMAND_PATH
	)
	assert_true(command.has_method("execute"), "§11.1: the gate is inherited, not re-declared")


## §11.1 line 705 — the name is exactly `end_turn`, and it is one of the FOURTEEN printed command
## names. The printed list lives here, never in engine code.
func test_the_command_name_is_end_turn_and_is_one_of_the_printed_fourteen() -> void:
	assert_eq(
		PRINTED_COMMAND_NAMES.size(),
		14,
		"§11.1 line 705 prints exactly fourteen commands — this list must transcribe all of them"
	)
	var chosen: StringName = EndTurnCommand.new(0).command_name()
	assert_eq(chosen, &"end_turn", "§11.1: the command name is exactly \"end_turn\"")
	assert_true(
		PRINTED_COMMAND_NAMES.has(String(chosen)),
		"§11.1: \"%s\" must be one of the fourteen printed command names" % String(chosen)
	)


## (AV) — the command is an IMMUTABLE value object: every parameter is set in `_init` and read
## back unchanged.
func test_the_player_index_is_carried_verbatim_from_the_constructor() -> void:
	for index: int in [0, 1, 2, 3, -1, 99]:
		assert_eq(
			EndTurnCommand.new(index).player_index(),
			index,
			"(AV): player_index() answers exactly what _init was given (%d)" % index
		)


# =============================================================================================
# B. validate() ((AV) rejection vocabulary; §11.1 "validate(state) -> Error?")
# =============================================================================================

## (AV) — a null state is rejected with `null_state`, never a crash (the (B)/(L)/(AS) totality
## spirit).
func test_validate_rejects_a_null_state() -> void:
	var rejection: CommandError = EndTurnCommand.new(0).validate(null)
	assert_not_null(rejection, "(AV): a null state is rejected, not applied")
	if rejection == null:
		return
	assert_eq(rejection.code, CODE_NULL_STATE, "(AV): the code is exactly \"null_state\"")
	assert_false(rejection.message.is_empty(), "(AV): every rejection carries a message")


## (AV) — an empty roster is rejected with `no_players`: there is no current player to end a turn
## for, and `(current + 1) % 0` would be a division by zero.
func test_validate_rejects_an_empty_roster() -> void:
	for count: int in [0, -1]:
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		assert_eq(state.player_count(), 0, "sanity: a roster of %d clamps to empty" % count)
		var rejection: CommandError = EndTurnCommand.new(0).validate(state)
		assert_not_null(rejection, "(AV): an empty roster is rejected")
		if rejection == null:
			return
		assert_eq(rejection.code, CODE_NO_PLAYERS, "(AV): the code is exactly \"no_players\"")
		assert_false(rejection.message.is_empty(), "(AV): every rejection carries a message")


## §3.3 "fixed order by player index" — only the CURRENT player may end the turn. Every other
## in-range index is rejected with `not_current_player`.
func test_validate_rejects_a_player_who_is_not_the_current_one() -> void:
	for count: int in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		assert_eq(state.current_player_index(), 0, "(AV): a fresh state is on player 0")
		for index: int in range(count):
			var rejection: CommandError = EndTurnCommand.new(index).validate(state)
			if index == state.current_player_index():
				assert_null(rejection, "§3.3: the current player MAY end the turn")
			else:
				assert_not_null(
					rejection, "§3.3: player %d is not current in a %d-player match" % [index, count]
				)
				if rejection == null:
					return
				assert_eq(
					rejection.code,
					CODE_NOT_CURRENT_PLAYER,
					"(AV): the code is exactly \"not_current_player\""
				)
				assert_false(
					rejection.message.is_empty(), "(AV): every rejection carries a message"
				)


## (AV) — an OUT-OF-RANGE index is `not_current_player` too, not a fourth code: the current index
## is always inside 0..player_count()-1, so an out-of-range index can never be the current one.
func test_validate_rejects_an_out_of_range_player_index_as_not_current() -> void:
	var count: int = MAX_PLAYERS
	var state: GameState = GameState.new(GOLDEN_SEED, null, count)
	for index: int in [-1, -99, count, count + 1, 9999]:
		var rejection: CommandError = EndTurnCommand.new(index).validate(state)
		assert_not_null(rejection, "(AV): index %d is outside the roster and is rejected" % index)
		if rejection == null:
			return
		assert_eq(
			rejection.code,
			CODE_NOT_CURRENT_PLAYER,
			"(AV): an out-of-range index rejects as \"not_current_player\", not a new code"
		)


## §11.1 "validate(state) -> Error?" — NULL MEANS LEGAL. The current player of a populated roster
## is always accepted, at every §3.1 roster size.
func test_validate_answers_null_for_the_current_player() -> void:
	for count: int in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		assert_null(
			EndTurnCommand.new(state.current_player_index()).validate(state),
			"§11.1: null means legal — the current player may end the turn (%d players)" % count
		)


## §11.1 — validate is a PURE PREDICATE: asking does not move the state, whatever the answer.
func test_validate_never_mutates_the_state() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MAX_PLAYERS)
	var before: int = state.content_hash()
	for index: int in [-1, 0, 1, 2, 3, 4, 99]:
		EndTurnCommand.new(index).validate(state)
	assert_eq(state.content_hash(), before, "§11.1: validate is a predicate, never a mutation")
	assert_eq(state.turn(), 1, "§3.3: validate does not advance the turn")
	assert_eq(state.current_player_index(), 0, "§3.3: validate does not rotate the player")


# =============================================================================================
# C. THE ROTATION TABLE (§3.3 line 137) — hand-computed and pinned LITERALLY
# =============================================================================================

## (AV) — a fresh state starts at turn 1, player 0, at EVERY roster size including the empty one.
func test_a_fresh_state_starts_at_turn_one_player_zero() -> void:
	for count: int in [0, -1, MIN_PLAYERS, 3, MAX_PLAYERS]:
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		assert_eq(state.turn(), 1, "(AV): a fresh state is on turn 1 (roster %d)" % count)
		assert_eq(
			state.current_player_index(), 0, "(AV): a fresh state is on player 0 (roster %d)" % count
		)


## §3.3 THE ROTATION TABLE FOR THREE PLAYERS, hand-computed, k = accepted EndTurns so far:
##   k=0 -> (turn 1, index 0) · k=1 -> (1,1) · k=2 -> (1,2) · k=3 -> (2,0) · k=4 -> (2,1)
##   k=5 -> (2,2) · k=6 -> (3,0) · k=7 -> (3,1)
## A full round of all players is ONE turn. An implementation that increments the turn on EVERY
## EndTurn passes nothing here from k=1 onward.
func test_the_rotation_table_for_three_players() -> void:
	var expected: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(1, 2),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(2, 2),
		Vector2i(3, 0),
		Vector2i(3, 1),
	]
	var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
	for k: int in range(expected.size()):
		assert_eq(
			Vector2i(state.turn(), state.current_player_index()),
			expected[k],
			"§3.3: after %d accepted EndTurns a 3-player match is at (turn %d, index %d)" % [
				k, expected[k].x, expected[k].y
			]
		)
		if k < expected.size() - 1:
			_accept_end_turn(state)


## §3.3 THE ROTATION TABLE FOR TWO PLAYERS, hand-computed:
##   k=0 -> (1,0) · k=1 -> (1,1) · k=2 -> (2,0) · k=3 -> (2,1) · k=40 -> (21,0)
func test_the_rotation_table_for_two_players() -> void:
	var expected: Dictionary = {
		0: Vector2i(1, 0),
		1: Vector2i(1, 1),
		2: Vector2i(2, 0),
		3: Vector2i(2, 1),
		40: Vector2i(21, 0),
	}
	var state: GameState = GameState.new(GOLDEN_SEED, null, 2)
	for k: int in range(41):
		if expected.has(k):
			var want: Vector2i = expected[k]
			assert_eq(
				Vector2i(state.turn(), state.current_player_index()),
				want,
				"§3.3: after %d accepted EndTurns a 2-player match is at (turn %d, index %d)" % [
					k, want.x, want.y
				]
			)
		if k < 40:
			_accept_end_turn(state)


## §3.3 THE ROTATION TABLE FOR FOUR PLAYERS, hand-computed: k=4 -> (2,0) · k=20 -> (6,0).
func test_the_rotation_table_for_four_players() -> void:
	var expected: Dictionary = {4: Vector2i(2, 0), 20: Vector2i(6, 0)}
	var state: GameState = GameState.new(GOLDEN_SEED, null, MAX_PLAYERS)
	for k: int in range(21):
		if expected.has(k):
			var want: Vector2i = expected[k]
			assert_eq(
				Vector2i(state.turn(), state.current_player_index()),
				want,
				"§3.3: after %d accepted EndTurns a 4-player match is at (turn %d, index %d)" % [
					k, want.x, want.y
				]
			)
		if k < 20:
			_accept_end_turn(state)


## §3.3/§3.1 — the general rule the three hand tables encode, swept over the whole "2–4 players"
## fixture range: index = k % n, turn = 1 + k / n.
func test_the_rotation_rule_holds_across_the_two_to_four_player_range() -> void:
	for count: int in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		var state: GameState = GameState.new(GOLDEN_SEED, null, count)
		for k: int in range(3 * count + 3):
			@warning_ignore("integer_division")
			var expected_turn: int = 1 + k / count
			assert_eq(
				state.turn(),
				expected_turn,
				"§3.3: %d players, %d accepted EndTurns -> turn %d" % [count, k, expected_turn]
			)
			assert_eq(
				state.current_player_index(),
				k % count,
				"§3.3: %d players, %d accepted EndTurns -> index %d" % [count, k, k % count]
			)
			_accept_end_turn(state)


## §3.3 — a REJECTED EndTurn advances nothing: the position and the hash are byte-identical
## before and after.
func test_a_rejected_end_turn_advances_nothing() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
	_accept_end_turn(state)
	assert_eq(state.current_player_index(), 1, "sanity: the match is on player 1")
	var before: int = state.content_hash()
	for index: int in [0, 2, -1, 3]:
		var rejection: CommandError = EndTurnCommand.new(index).execute(state, null)
		assert_not_null(rejection, "§3.3: player %d may not end player 1's turn" % index)
	assert_eq(state.turn(), 1, "§3.3: a rejected EndTurn does not advance the turn")
	assert_eq(state.current_player_index(), 1, "§3.3: a rejected EndTurn does not rotate")
	assert_eq(state.content_hash(), before, "§11.1: a rejected command leaves the state identical")


# =============================================================================================
# D. THE EMITTED EVENT (§11.1 line 706; §13.6 "events emitted for every state change")
# =============================================================================================

## §13.6 — the ONLY state change in this slice is the turn advance, and it emits EXACTLY ONE
## TurnEndedEvent. §11.1 line 706: "typed events emitted by apply()".
func test_each_accepted_end_turn_emits_exactly_one_turn_ended_event() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(TurnEndedEvent.TYPE_NAME, handler.on_event)
	for k: int in range(3):
		assert_null(
			EndTurnCommand.new(state.current_player_index()).execute(state, bus),
			"sanity: the current player's EndTurn is accepted"
		)
		assert_eq(handler.calls, k + 1, "§13.6: exactly one event per accepted EndTurn")


## §11.1/§3.3 — THE PAYLOAD, hand-computed for the k=2 -> k=3 transition at three players: the
## acting player is index 2, the next player is index 0, and the turn number carried is the one
## AFTER the advance (turn 2).
func test_the_emitted_payload_is_actor_next_and_the_turn_after_the_advance() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
	var bus: EventBus = EventBus.new()
	var handler: CountingHandler = CountingHandler.new()
	bus.subscribe(TurnEndedEvent.TYPE_NAME, handler.on_event)
	_accept_end_turn(state)
	_accept_end_turn(state)
	assert_eq(
		Vector2i(state.turn(), state.current_player_index()),
		Vector2i(1, 2),
		"sanity: two accepted EndTurns put a 3-player match at (turn 1, index 2)"
	)
	assert_null(EndTurnCommand.new(2).execute(state, bus), "sanity: player 2 may end the turn")
	assert_eq(handler.calls, 1, "§13.6: exactly one event")
	assert_eq(
		handler.payloads,
		[Vector3i(2, 0, 2)] as Array[Vector3i],
		"§3.3: the event carries player_index 2, next_player_index 0 and turn 2"
	)


## §11.1 — apply() itself returns the Array[Event]; the bus is how the renderer hears about it,
## never a return channel into the sim.
func test_apply_returns_exactly_one_typed_event() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
	var events: Array[Event] = EndTurnCommand.new(0).apply(state)
	assert_eq(events.size(), 1, "§11.1: apply(state) -> Array[Event], one per turn advance")
	if events.size() != 1:
		return
	var ended: TurnEndedEvent = events[0] as TurnEndedEvent
	assert_not_null(ended, "§11.1: the emitted event is a TurnEndedEvent")
	if ended == null:
		return
	assert_eq(ended.type, TurnEndedEvent.TYPE_NAME, "§11.1: the event's type is turn_ended")
	assert_eq(ended.player_index, 0, "§3.3: the acting player")
	assert_eq(ended.next_player_index, 1, "§3.3: the next player index")
	assert_eq(ended.turn, 1, "§3.3: a 3-player match is still on turn 1 after one EndTurn")


# =============================================================================================
# E. IMMUTABILITY AND THE §3.4 NEGATIVE PINS
# =============================================================================================

## §11.1 "a match is fully described by (seed, command\_log)" — a Command is an IMMUTABLE value
## object. Executing the SAME object against two fresh states gives identical results, and the
## object's own parameter is unchanged afterwards. A command that mutates `self` in apply()
## diverges on the second pass of a replay.
func test_the_same_command_object_replays_identically() -> void:
	var command: EndTurnCommand = EndTurnCommand.new(0)
	var first: GameState = GameState.new(GOLDEN_SEED, null, 3)
	var second: GameState = GameState.new(GOLDEN_SEED, null, 3)
	assert_null(command.execute(first, null), "sanity: the first execution is accepted")
	assert_null(command.execute(second, null), "sanity: the second execution is accepted")
	assert_eq(command.player_index(), 0, "§11.1: validate/apply never mutate the command")
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: the same command on two fresh states yields the same state"
	)


## §3.4 (lines 141–165) NEGATIVE PIN — the nine per-player start-of-turn steps (income, upkeep,
## construction/training ticks, dig ticks + Breach + Noise, healing, status/cooldown ticks,
## structural stress, light/vision recompute, action phase) and the three World-phase steps
## (creep AI, Wrath, victory checks) are ALL deliberately unimplemented in this slice. Pinned
## negatively so a later slice cannot claim they were forgotten (§13.4): after any number of
## EndTurns every stockpile is still EMPTY.
func test_ending_turns_runs_none_of_the_section_three_four_steps_yet() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, MAX_PLAYERS)
	for k: int in range(3 * MAX_PLAYERS):
		_accept_end_turn(state)
	for index: int in range(MAX_PLAYERS):
		var holder: PlayerState = state.player(index)
		assert_not_null(holder, "sanity: player(%d) exists" % index)
		if holder == null:
			return
		assert_eq(
			holder.resource_ids(),
			[] as Array[String],
			"§3.4: income/upkeep are a LATER slice — player %d still holds nothing" % index
		)


## §3.4 / §11.1 NEGATIVE PIN — EndTurn draws NO roll. Nothing in this slice is random, so the one
## seeded stream must still be at position 0 after any number of turns; a stray draw would make
## every later replay diverge.
func test_ending_turns_draws_no_random_roll() -> void:
	var state: GameState = GameState.new(GOLDEN_SEED, null, 3)
	for k: int in range(9):
		_accept_end_turn(state)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1: EndTurn is deterministic — the single seeded stream must not advance"
	)


## §11.1 — the turn position is the ONLY thing an accepted EndTurn changes, so two states that
## agree on the position agree on the hash, and one that does not disagrees.
func test_the_turn_advance_is_the_only_state_change() -> void:
	var advanced: GameState = GameState.new(GOLDEN_SEED, null, 3)
	var positioned: GameState = GameState.new(GOLDEN_SEED, null, 3)
	_accept_end_turn(advanced)
	_accept_end_turn(advanced)
	_accept_end_turn(advanced)
	positioned.set_turn_position(2, 0)
	assert_eq(
		advanced.content_hash(),
		positioned.content_hash(),
		"§11.1: three accepted EndTurns at 3 players are exactly the position (turn 2, index 0)"
	)
	var untouched: GameState = GameState.new(GOLDEN_SEED, null, 3)
	assert_ne(
		advanced.content_hash(),
		untouched.content_hash(),
		"§11.1: the turn position is part of the replayable state"
	)


# =============================================================================================
# F. MECHANICAL SOURCE SCANS ON scripts/sim/commands/end_turn_command.gd
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(END_TURN_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % END_TURN_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			END_TURN_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % END_TURN_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R).
func test_source_is_engine_free() -> void:
	var code: String = _code_text(END_TURN_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % END_TURN_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [END_TURN_PATH, banned]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [
				END_TURN_PATH, banned
			]
		)


## S3 §3.2/§12.1/§13.6 — the victory turn limit (200) is M6 and MUST NOT be implemented here. The
## rotation is STRUCTURAL, not tunable, so this file reads no §12.1 constant at all; the moment it
## needs one, §13.6's "constants read from data, not code" stops being vacuous.
func test_source_implements_no_victory_turn_limit() -> void:
	var code: String = _code_text(END_TURN_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % END_TURN_PATH)
	assert_false(
		code.contains(VICTORY_TURN_LIMIT_TOKEN),
		"§3.2/§12.1: the turn limit is M6 — %s must not contain %s" % [
			END_TURN_PATH, VICTORY_TURN_LIMIT_TOKEN
		]
	)
	assert_false(
		code.contains("RulesLoader"),
		"§13.4: this slice reads no ruleset constant — %s must not load one" % END_TURN_PATH
	)


## S4 (AV)/M1-T9 — this file loads no document, so `RulesError` must be ABSENT (a second loader
## must not be able to grow here), and it must not override `Object.hash()`.
func test_source_declares_no_loader_and_overrides_no_native_method() -> void:
	var code: String = _code_text(END_TURN_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % END_TURN_PATH)
	assert_false(
		code.contains("RulesError"),
		"M1-T9/(AV): %s rejects with CommandError, never the document error type" % END_TURN_PATH
	)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % END_TURN_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): modulo on positive ints needs no suppression — %s must not divide" % [
			END_TURN_PATH
		]
	)


## S5 (AV)/§13.5 — the Command authors its OWN codes at its own call site, and authors no other
## command's. There is no enum and no const list of codes.
func test_source_authors_only_its_own_rejection_codes() -> void:
	var code: String = _code_text(END_TURN_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % END_TURN_PATH)
	for authored: StringName in [CODE_NULL_STATE, CODE_NO_PLAYERS, CODE_NOT_CURRENT_PLAYER]:
		assert_true(
			code.contains(String(authored)),
			"(AV): %s authors \"%s\" at its own call site" % [END_TURN_PATH, String(authored)]
		)
	assert_false(
		code.contains("abstract_command"),
		"(AV): the base's own code belongs to the base — %s must not repeat it" % END_TURN_PATH
	)
	assert_false(code.contains("enum "), "(AV): rejection codes are never an enum")


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY: a MISSING member fails
## instead of passing vacuously and an EXTRA member (a mutable setter, a to_dict, a public
## player_index field) fails too. ZERO public vars: the command is an immutable value object.
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(END_TURN_PATH, public_functions, undocumented)

	var command: EndTurnCommand = EndTurnCommand.new(0)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, END_TURN_PATH]
		)
		assert_true(
			command.has_method(required),
			"§11.2: %s must be callable on an EndTurnCommand instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			END_TURN_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(END_TURN_PATH),
		REQUIRED_PUBLIC_VARS,
		"(AV): %s declares ZERO public vars — it is an immutable value object" % END_TURN_PATH
	)


## S7 §11.1/§11.2 — EndTurnCommand is a pure [RefCounted] in `scripts/sim/commands/`. Asserted
## through get_class() — `is Node` would be a PARSE ERROR here.
func test_end_turn_command_is_a_pure_refcounted_in_scripts_sim_commands() -> void:
	assert_true(
		FileAccess.file_exists(END_TURN_PATH),
		"§11.2: EndTurnCommand belongs at %s" % END_TURN_PATH
	)
	assert_eq(
		EndTurnCommand.new(0).get_class(),
		"RefCounted",
		"§11.1: EndTurnCommand must be a pure RefCounted"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## Executes one EndTurn for the state's CURRENT player, asserting it is accepted.
func _accept_end_turn(state: GameState) -> void:
	var rejection: CommandError = EndTurnCommand.new(state.current_player_index()).execute(
		state, null
	)
	assert_null(
		rejection,
		"§3.3: the current player's EndTurn must be accepted (turn %d, index %d)" % [
			state.turn(), state.current_player_index()
		]
	)


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
