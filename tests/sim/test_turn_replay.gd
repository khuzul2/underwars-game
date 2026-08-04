## THE REPLAY PROOF — GDD §13.2 tier 2 ("**System tests** (tests/sim/): scripted mini-scenarios"),
## §11.1 (Layered Design, **binding**), §3.3 (Turn Model), §3.4, §11.3, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 705): "**Every mutation of GameState goes through a Command** — the UI, the AI,
##         zone macros, and tests all speak the same language, and **a match is fully described
##         by (seed, command\_log)**."
##   §11.1 (line 707): "GameState.hash() (FNV over canonical serialization) must be reproducible."
##   §11.1 (line 708): "**Save/load & replay:** save = JSON snapshot of GameState (+ ruleset
##         version + seed + command log). Load→save must be byte-identical; **replaying (seed,
##         command\_log) must reproduce the hash**."
##   §3.3  (line 137): "Sequential player turns (IGOUGO, Civ-style), **fixed order by player
##         index**, then a **World phase**."
##
## `docs/decisions.md` was re-scanned end to end this iteration: the only logged §12.1 override is
## (AU)(i) (irrelevant here), and **no logged override touches §11.1, §3.3 or §3.4**. Binding
## prior resolutions: (AU)(vi) (the `GameState.content_hash` fold, extended by (AV) with the turn
## position), (R) (`Rng` is the single home of the engine RandomNumberGenerator).
##
## WHY THIS IS A PROPERTY TEST AND NOT A RECORDED GOLDEN (§13.6 "goldens re-recorded only with a
## logged reason", logged as (AV)): §13.2 tier 3 wants "fixed seed + recorded command log =>
## recorded GameState.hash() after N turns", and a later M2 slice owes exactly that. Recording it
## NOW would freeze the fold before units, dig progress, income and §3.1's starting kit exist,
## guaranteeing a re-record every subsequent slice. The golden is **owed, not forgotten**; the
## replay contract lands here as a property instead: same seed + same log => equal hashes, at
## every step, on any number of fresh states.
extends GutTest

## §12.6's example seed, and the seed the project's first golden already uses.
const REPLAY_SEED: int = 1337
const OTHER_SEED: int = 1338

## §3.1 line 118 "Skirmish: 2–4 players" — three is the smallest roster where a wrap (index 2 ->
## index 0, turn + 1) is distinguishable from "advance the turn on every EndTurn".
const PLAYER_COUNT: int = 3

## How many independent fresh states the same log is replayed onto.
const REPLAY_RUNS: int = 3

## The player index each command in `_command_log()` is constructed for, in log order. Held
## separately so "the command objects are immutable" can be checked AFTER every replay.
const LOG_PLAYER_INDICES: Array[int] = [0, 0, 1, 5, 2, 0, 2, 1]

## Hand-computed acceptance of `_command_log()` against a fresh 3-player state:
##   #0 EndTurn(0) at (1,0) -> ACCEPTED, now (1,1)
##   #1 EndTurn(0) at (1,1) -> rejected (not_current_player)
##   #2 EndTurn(1) at (1,1) -> ACCEPTED, now (1,2)
##   #3 EndTurn(5) at (1,2) -> rejected (out of range, so never current)
##   #4 EndTurn(2) at (1,2) -> ACCEPTED, wraps to index 0, so turn + 1 -> (2,0)
##   #5 EndTurn(0) at (2,0) -> ACCEPTED, now (2,1)
##   #6 EndTurn(2) at (2,1) -> rejected (not_current_player)
##   #7 EndTurn(1) at (2,1) -> ACCEPTED, now (2,2)
const LOG_ACCEPTED: Array[bool] = [true, false, true, false, true, true, false, true]

## The (turn, current_player_index) position AFTER each command in `_command_log()`.
const LOG_POSITIONS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(1, 1),
	Vector2i(1, 2),
	Vector2i(1, 2),
	Vector2i(2, 0),
	Vector2i(2, 1),
	Vector2i(2, 1),
	Vector2i(2, 2),
]

## Indices of `_command_log()` whose command is REJECTED — the ones a "remove the rejected
## commands" filter drops.
const REJECTED_INDICES: Array[int] = [1, 3, 6]


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Records the canonical serialization of every event it is delivered, in delivery order, so two
## replays can be compared on their EVENT STREAM as well as on their hash.
class StreamRecorder extends RefCounted:
	var lines: Array[String] = []

	func on_event(event: Event) -> void:
		var serialized: Dictionary = event.to_dict()
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in serialized.keys():
			parts.append("%s=%s" % [str(key), str(serialized[key])])
		lines.append("|".join(parts))


# =============================================================================================
# A. THE HEADLINE PIN (§11.1 line 708: "replaying (seed, command_log) must reproduce the hash")
# =============================================================================================

## §11.1 — TWO fresh states on the SAME seed, fed the SAME command log, agree on
## `content_hash()` AT EVERY STEP — not merely at the end, where two different divergences could
## cancel out.
func test_two_fresh_states_on_one_log_agree_at_every_step() -> void:
	var first: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var second: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var log_a: Array[Command] = _command_log()
	var log_b: Array[Command] = _command_log()
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: two fresh states on the same seed start identical"
	)
	for step: int in range(log_a.size()):
		var rejection_a: CommandError = log_a[step].execute(first, null)
		var rejection_b: CommandError = log_b[step].execute(second, null)
		assert_eq(
			rejection_a == null,
			rejection_b == null,
			"§11.1: step %d is accepted (or rejected) identically on both states" % step
		)
		assert_eq(
			first.content_hash(),
			second.content_hash(),
			"§11.1: replaying (seed, command_log) must reproduce the hash — diverged at step %d" % [
				step
			]
		)


## §3.3 — the log really does exercise BOTH outcomes: without this the "identical at every step"
## property could hold over a log where nothing is ever accepted, or nothing ever rejected.
func test_the_log_mixes_accepted_and_rejected_commands() -> void:
	assert_eq(
		LOG_ACCEPTED.size(), LOG_PLAYER_INDICES.size(), "sanity: the hand tables line up"
	)
	assert_eq(LOG_POSITIONS.size(), LOG_ACCEPTED.size(), "sanity: the hand tables line up")
	assert_true(LOG_ACCEPTED.has(true), "sanity: the log accepts at least one command")
	assert_true(LOG_ACCEPTED.has(false), "sanity: the log rejects at least one command")

	var state: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var command_log: Array[Command] = _command_log()
	for step: int in range(command_log.size()):
		var rejection: CommandError = command_log[step].execute(state, null)
		assert_eq(
			rejection == null,
			LOG_ACCEPTED[step],
			"§3.3: step %d must be %s" % [
				step, "accepted" if LOG_ACCEPTED[step] else "rejected"
			]
		)
		if rejection != null:
			assert_false(
				rejection.message.is_empty(), "(AV): every rejection carries a message"
			)
		assert_eq(
			Vector2i(state.turn(), state.current_player_index()),
			LOG_POSITIONS[step],
			"§3.3: after step %d the match is at (turn %d, index %d)" % [
				step, LOG_POSITIONS[step].x, LOG_POSITIONS[step].y
			]
		)


## §11.1 "a match is fully described by (seed, command\_log)" — the SAME command objects replay
## onto fresh states any number of times and produce the identical hash sequence every run. A
## Command that mutated `self` in `apply()` would diverge on the second pass.
func test_one_log_object_replays_identically_many_times() -> void:
	var command_log: Array[Command] = _command_log()
	var runs: Array = []
	for run: int in range(REPLAY_RUNS):
		runs.append(_run(command_log, GameState.new(REPLAY_SEED, null, PLAYER_COUNT), null))
	for run: int in range(1, REPLAY_RUNS):
		assert_eq(
			runs[run],
			runs[0],
			"§11.1: replay %d produced a different hash sequence than replay 0" % run
		)

	for step: int in range(command_log.size()):
		var command: EndTurnCommand = command_log[step] as EndTurnCommand
		assert_not_null(command, "sanity: the log holds EndTurnCommands")
		if command == null:
			return
		assert_eq(
			command.player_index(),
			LOG_PLAYER_INDICES[step],
			"§11.1: a Command is an IMMUTABLE value object — step %d changed itself" % step
		)


## §11.1 — the EVENT STREAM is replayable too, not just the hash: the same log emits the same
## typed events, in the same order, with the same payloads, on every replay.
func test_the_event_stream_is_identical_across_replays() -> void:
	var command_log: Array[Command] = _command_log()
	var streams: Array = []
	for run: int in range(REPLAY_RUNS):
		var bus: EventBus = EventBus.new()
		var recorder: StreamRecorder = StreamRecorder.new()
		bus.subscribe(TurnEndedEvent.TYPE_NAME, recorder.on_event)
		_run(command_log, GameState.new(REPLAY_SEED, null, PLAYER_COUNT), bus)
		streams.append(recorder.lines)
	var first_stream: Array = streams[0]
	assert_eq(
		first_stream.size(),
		LOG_ACCEPTED.count(true),
		"§13.6: exactly one event per ACCEPTED command, and none for a rejected one"
	)
	for run: int in range(1, REPLAY_RUNS):
		assert_eq(streams[run], streams[0], "§11.1: replay %d emitted a different stream" % run)


# =============================================================================================
# B. REJECTED COMMANDS ARE INVISIBLE TO THE STATE (§11.1 + (AV) the one gate)
# =============================================================================================

## (AV)/§11.1 — a log containing REJECTED commands hashes identically to the same log with those
## commands REMOVED, at every accepted step and at the end. A rejection is a no-op on the state,
## so it cannot be recorded into the replayable surface by accident.
func test_dropping_the_rejected_commands_changes_nothing() -> void:
	var full: Array[Command] = _command_log()
	var filtered: Array[Command] = _accepted_only(_command_log())
	assert_eq(
		filtered.size(),
		full.size() - REJECTED_INDICES.size(),
		"sanity: the filter drops exactly the rejected commands"
	)

	var with_rejections: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var without: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var full_hashes: Array = _run(full, with_rejections, null)
	var filtered_hashes: Array = _run(filtered, without, null)

	var expected_accepted: Array[int] = []
	for step: int in range(full.size()):
		if LOG_ACCEPTED[step]:
			expected_accepted.append(full_hashes[step])
	assert_eq(
		filtered_hashes,
		expected_accepted as Array,
		"§11.1: a rejected command is invisible — the accepted hash sequence is identical"
	)
	assert_eq(
		with_rejections.content_hash(),
		without.content_hash(),
		"§11.1: the two logs end in the same state"
	)
	assert_eq(
		Vector2i(without.turn(), without.current_player_index()),
		LOG_POSITIONS[LOG_POSITIONS.size() - 1],
		"§3.3: the filtered log ends at the same (turn, index)"
	)


## §11.1 — the SEED is half of `(seed, command_log)`: the same log on a different seed must not
## collide, or a replay could silently validate against the wrong match.
func test_the_same_log_on_a_different_seed_does_not_collide() -> void:
	var same: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var other: GameState = GameState.new(OTHER_SEED, null, PLAYER_COUNT)
	_run(_command_log(), same, null)
	_run(_command_log(), other, null)
	assert_ne(
		same.content_hash(),
		other.content_hash(),
		"§11.1: (seed, command_log) — the seed is part of the replayable state"
	)


## §11.1/§3.3 — a log replayed onto a state with a DIFFERENT roster size is a different match:
## the rotation itself depends on the player count, so the hash must not collide.
func test_the_same_log_on_a_different_roster_does_not_collide() -> void:
	var three: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var four: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT + 1)
	_run(_command_log(), three, null)
	_run(_command_log(), four, null)
	assert_ne(
		three.content_hash(),
		four.content_hash(),
		"§3.3: the rotation is a function of the roster size — these are different matches"
	)


# =============================================================================================
# C. §3.4 NEGATIVE PINS — everything the turn sequence does NOT do yet
# =============================================================================================

## §3.4 (lines 141–165) — the nine per-player start-of-turn steps and the three World-phase steps
## are ALL deliberately unimplemented in this slice (§13.4: invent nothing ahead of its
## milestone). Pinned negatively so a later slice cannot claim they were forgotten: after the
## whole log, every player still holds NOTHING and the one seeded stream has drawn NOTHING.
func test_the_replay_runs_none_of_the_section_three_four_steps_yet() -> void:
	var state: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	_run(_command_log(), state, null)
	for index: int in range(PLAYER_COUNT):
		var holder: PlayerState = state.player(index)
		assert_not_null(holder, "sanity: player(%d) exists" % index)
		if holder == null:
			return
		assert_eq(
			holder.resource_ids(),
			[] as Array[String],
			"§3.4: income/upkeep are a LATER slice — player %d still holds nothing" % index
		)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1: nothing in this slice is random — the seeded stream must not advance"
	)


## §11.1 — the whole difference between a fresh state and a replayed one is the TURN POSITION.
## Setting the position directly reproduces the replayed hash exactly, which is what makes the
## fold's new members (and only those) the recorded surface of this slice.
func test_the_replayed_state_is_exactly_its_turn_position() -> void:
	var replayed: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	_run(_command_log(), replayed, null)
	var positioned: GameState = GameState.new(REPLAY_SEED, null, PLAYER_COUNT)
	var last: Vector2i = LOG_POSITIONS[LOG_POSITIONS.size() - 1]
	positioned.set_turn_position(last.x, last.y)
	assert_eq(
		replayed.content_hash(),
		positioned.content_hash(),
		"§11.1: the only state change this slice makes is the turn position"
	)
	assert_ne(
		replayed.content_hash(),
		GameState.new(REPLAY_SEED, null, PLAYER_COUNT).content_hash(),
		"§11.1: and it IS a change — the replayed state differs from a fresh one"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## §11.1 — the command log under test: a mix of accepted and rejected EndTurns for a 3-player
## match, hand-computed in LOG_ACCEPTED / LOG_POSITIONS above. A FRESH set of command objects
## every call, so a caller can compare two independently-built logs.
func _command_log() -> Array[Command]:
	var out: Array[Command] = []
	for index: int in LOG_PLAYER_INDICES:
		out.append(EndTurnCommand.new(index))
	return out


## The same log with every REJECTED command removed (hand-listed in REJECTED_INDICES).
func _accepted_only(command_log: Array[Command]) -> Array[Command]:
	var out: Array[Command] = []
	for step: int in range(command_log.size()):
		if not REJECTED_INDICES.has(step):
			out.append(command_log[step])
	return out


## Executes `log` against `state` through the ONE gate, returning `state.content_hash()` after
## every step so two runs can be compared step by step rather than only at the end.
func _run(command_log: Array[Command], state: GameState, bus: EventBus) -> Array:
	var hashes: Array = []
	for command: Command in command_log:
		command.execute(state, bus)
		hashes.append(state.content_hash())
	return hashes
