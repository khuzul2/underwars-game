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
##
## EXTENDED BY M2-T5, resolution **(AY)**: sections A-C replay a log of EndTurns ALONE and are
## UNTOUCHED; section D adds a log that MIXES `DigHexCommand` and `EndTurnCommand`. §11.1 line
## 705's replay clause is over the whole command vocabulary, so the moment a second Command exists
## the property has to be re-proven over an INTERLEAVING — two commands can each be replayable in
## isolation while their combination is not (a Command caching state across `apply()` calls is the
## obvious way that happens).
##
## EXTENDED AGAIN BY M2-T6, resolution **(AZ)**: sections A-C are STILL byte-untouched, and
## section D's mixed log now carries all THREE built commands — `DigHex` (create) -> `DigHex`
## (join) -> **`CancelDig`** -> a full `EndTurn` round -> `DigHex` again. A cancel is the first
## command in the project that REMOVES something from a `GameState` collection, which is exactly
## the shape that breaks a replay when a container's iteration order depends on insertion history;
## the property is therefore re-proven over the interleaving rather than assumed. §13.2 tier 3's
## golden is STILL OWED, now for the FIFTH time: M2-T5 added a Command and a registry, M2-T6 adds
## the command that undoes it, and NEITHER adds a TICK — freezing the fold here would force a
## re-record when slice 4 lands §3.4 step 4, so the slice that lands the tick records it, or says
## in `docs/decisions.md` why not. **This slice extends no fold** (no new `GameState` field), so no
## re-record is triggered and none is due here.
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

## --- M2-T5 (AY): the MIXED log's fixture -----------------------------------------------------
const RULESET_PATH: String = "res://data/ruleset.json"

## Big enough that the target's neighbours are all in bounds; §4.1's real radii live in
## data/mapgen/*.json.
const MAP_RADIUS: int = 2

## §4.1 "axial coordinates (q, r)" — the dug hex and the two hexes its workers stand on (E and NE
## of the target, `HexMath.DIRECTIONS` 0 and 1).
const TARGET_HEX: Vector2i = Vector2i(0, 0)
const FIRST_DIGGER_HEX: Vector2i = Vector2i(1, 0)
const SECOND_DIGGER_HEX: Vector2i = Vector2i(1, -1)

## §4.2 line 185 "Hard Rock | 2 | \+2 Stone | Baseline" — the row the mixed log digs, and the
## `total_turns` its site must therefore carry (read by the Command from §12.1 via `DigRules`).
const FIXTURE_TERRAIN_ID: String = "hard_rock"
const FIXTURE_TURNS: int = 2

## §12.2's printed example definition id and `"hp": 70`. §12.7's `worker` trait is DATA and
## `data/units/*.json` is M6, so the type is OPAQUE here.
const UNIT_TYPE_ID: String = "dwarf_crossbow"
const UNIT_MAX_HP: int = 70

## (AX) — ids are minted from 1 upward in spawn order.
const FIRST_UNIT_ID: int = 1
const SECOND_UNIT_ID: int = 2

## Hand-computed acceptance of `_mixed_log()` against a fresh `_dig_state()` — M2-T6 (AZ) inserts
## the `CancelDig` at step #2:
##   #0 DigHex(0, 1, target) at (1,0) -> ACCEPTED (site created, 2 worker-turns, digger 1)
##   #1 DigHex(0, 2, target) at (1,0) -> ACCEPTED (digger 2 JOINS; §4.2 line 197's cap is 2)
##   #2 CancelDig(0, 1)      at (1,0) -> ACCEPTED (digger 1 leaves; a crew-mate remains, so the
##                                      site SURVIVES with its 2 worker-turns UNCHANGED — (AZ)(iii))
##   #3 EndTurn(0) at (1,0) -> ACCEPTED, now (1,1)
##   #4 EndTurn(1) at (1,1) -> ACCEPTED, now (1,2)
##   #5 EndTurn(2) at (1,2) -> ACCEPTED, wraps to index 0, so turn + 1 -> (2,0)
##   #6 DigHex(0, 1, target) at (2,0) -> ACCEPTED (unit 1 is free again and RE-JOINS the site)
const MIXED_LOG_ACCEPTED: Array[bool] = [true, true, true, true, true, true, true]

## How many of `_mixed_log()`'s entries are DigHex orders, and how many are CancelDig orders.
const MIXED_LOG_DIG_STEPS: int = 3
const MIXED_LOG_CANCEL_STEPS: int = 1

## The step at which the cancel sits, so the "a rejected CancelDig changes nothing" probe can be
## aimed at a log position whose state is hand-known.
const MIXED_LOG_CANCEL_STEP: int = 2

## Cached across tests: `data/ruleset.json` is parsed once, and `DigRules` mutates nothing (M2-T3).
var _rules_cache: DigRules = null


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
# D. THE MIXED LOG ((AY), M2-T5) — EndTurn AND DigHex in ONE (seed, command_log)
#    §11.1 line 705's replay clause is over the WHOLE command vocabulary, not one command at a
#    time: the moment a second Command exists, "the same log reproduces the hash" has to be
#    re-proven over a log that MIXES them, or two commands could each be replayable alone while
#    their interleaving is not.
# =============================================================================================

## §11.1 line 708 — TWO fresh states built identically on the SAME seed, fed the SAME mixed log
## (DigHex, a full EndTurn round, DigHex again), agree on `content_hash()` AT EVERY STEP.
func test_two_fresh_states_on_one_mixed_log_agree_at_every_step() -> void:
	var first: GameState = _dig_state()
	var second: GameState = _dig_state()
	var log_a: Array[Command] = _mixed_log()
	var log_b: Array[Command] = _mixed_log()
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: two identically-built states on the same seed start identical"
	)
	for step: int in range(log_a.size()):
		var rejection_a: CommandError = log_a[step].execute(first, null)
		var rejection_b: CommandError = log_b[step].execute(second, null)
		assert_eq(
			rejection_a == null,
			rejection_b == null,
			"§11.1: mixed step %d is accepted (or rejected) identically on both states" % step
		)
		assert_eq(
			rejection_a == null,
			MIXED_LOG_ACCEPTED[step],
			"§4.2/§3.3: mixed step %d must be %s" % [
				step, "accepted" if MIXED_LOG_ACCEPTED[step] else "rejected"
			]
		)
		assert_eq(
			first.content_hash(),
			second.content_hash(),
			"§11.1: replaying (seed, command_log) must reproduce the hash — diverged at step %d" % [
				step
			]
		)


## §11.1 "a match is fully described by (seed, command\_log)" — the SAME mixed log object replays
## onto fresh states any number of times and produces the identical hash sequence every run, and
## the command objects are unchanged afterwards. A DigHexCommand that mutated `self` in `apply()`
## (caching the site it created, say) would diverge on the second pass.
func test_one_mixed_log_object_replays_identically_many_times() -> void:
	var command_log: Array[Command] = _mixed_log()
	var runs: Array = []
	for run: int in range(REPLAY_RUNS):
		runs.append(_run(command_log, _dig_state(), null))
	for run: int in range(1, REPLAY_RUNS):
		assert_eq(
			runs[run],
			runs[0],
			"§11.1: mixed replay %d produced a different hash sequence than replay 0" % run
		)

	var dig_steps: int = 0
	var cancel_steps: int = 0
	for command: Command in command_log:
		var order: DigHexCommand = command as DigHexCommand
		if order != null:
			dig_steps += 1
			assert_eq(order.hex(), TARGET_HEX, "§11.1: a Command is an IMMUTABLE value object")
			assert_eq(order.player_index(), 0, "§11.1: a Command is an IMMUTABLE value object")
			continue
		var cancel: CancelDigCommand = command as CancelDigCommand
		if cancel == null:
			continue
		cancel_steps += 1
		assert_eq(cancel.player_index(), 0, "§11.1: a Command is an IMMUTABLE value object")
		assert_eq(
			cancel.unit_id(), FIRST_UNIT_ID, "§11.1: a Command is an IMMUTABLE value object"
		)
	assert_eq(dig_steps, MIXED_LOG_DIG_STEPS, "sanity: the log really does carry three dig orders")
	assert_eq(cancel_steps, MIXED_LOG_CANCEL_STEPS, "sanity: and exactly one CancelDig ((AZ))")


## §11.1/§13.6 — the EVENT STREAM of the mixed log is replayable too: the same log emits the same
## typed events, in the same order, with the same payloads, on every replay — and exactly one
## event per accepted command, across BOTH vocabularies.
func test_the_mixed_event_stream_is_identical_across_replays() -> void:
	var command_log: Array[Command] = _mixed_log()
	var streams: Array = []
	for run: int in range(REPLAY_RUNS):
		var bus: EventBus = EventBus.new()
		var recorder: StreamRecorder = StreamRecorder.new()
		bus.subscribe(TurnEndedEvent.TYPE_NAME, recorder.on_event)
		bus.subscribe(DigStartedEvent.TYPE_NAME, recorder.on_event)
		bus.subscribe(DigCancelledEvent.TYPE_NAME, recorder.on_event)
		_run(command_log, _dig_state(), bus)
		streams.append(recorder.lines)
	var first_stream: Array = streams[0]
	assert_eq(
		first_stream.size(),
		MIXED_LOG_ACCEPTED.count(true),
		"§13.6: exactly one event per ACCEPTED command, and none for a rejected one"
	)
	for run: int in range(1, REPLAY_RUNS):
		assert_eq(
			streams[run], streams[0], "§11.1: mixed replay %d emitted a different stream" % run
		)


## §4.2/§4.2 line 197 — the mixed log's END STATE, hand-computed: one dig site on the target, owned
## by player 0, sized at §4.2's Hard Rock 2 worker-turns, with BOTH spawned units assigned (unit 1
## having been cancelled at step #2 and having RE-JOINED at step #6 — (AZ)(iii): the site survived
## because a crew-mate remained), and the match back at (turn 2, index 0) after the full EndTurn
## round.
func test_the_mixed_log_ends_in_the_hand_computed_state() -> void:
	var state: GameState = _dig_state()
	_run(_mixed_log(), state, null)
	assert_eq(
		Vector2i(state.turn(), state.current_player_index()),
		Vector2i(2, 0),
		"§3.3: one full round of %d players is one turn" % PLAYER_COUNT
	)
	assert_eq(
		state.dig_site_hexes(), [TARGET_HEX] as Array[Vector2i], "§4.2: exactly one dig site"
	)
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "§4.2: the site is on the target hex")
	if site == null:
		return
	assert_eq(site.owner_index(), 0, "(AY): the site belongs to the ordering player")
	assert_eq(site.total_turns(), FIXTURE_TURNS, "§4.2: \"Hard Rock | 2\" worker-turns")
	assert_eq(
		site.digger_ids(),
		[FIRST_UNIT_ID, SECOND_UNIT_ID] as Array[int],
		"§4.2 line 197: both workers are on the same target, ascending by id"
	)


## (AZ) — THE CANCEL IS REALLY IN THE LOG AND REALLY DOES SOMETHING. Replaying only the log's
## PREFIX up to and including the cancel leaves the site standing with exactly ONE digger and its
## §4.2 worker-turns UNCHANGED ((AZ)(iii)), and the cancelled unit holding no job — so the mixed
## log above is not merely "three dig orders with a no-op wedged between them".
func test_the_cancel_step_of_the_mixed_log_frees_exactly_one_digger() -> void:
	var state: GameState = _dig_state()
	var prefix: Array[Command] = []
	var command_log: Array[Command] = _mixed_log()
	for step: int in range(MIXED_LOG_CANCEL_STEP + 1):
		prefix.append(command_log[step])
	_run(prefix, state, null)

	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "(AZ)(iii): a crew-mate remained, so the site SURVIVED the cancel")
	if site == null:
		return
	assert_eq(
		site.digger_ids(), [SECOND_UNIT_ID] as Array[int], "(AZ)(iii): exactly one digger is left"
	)
	assert_eq(site.owner_index(), 0, "(AZ)(iii): the ordering player is unchanged")
	assert_eq(site.total_turns(), FIXTURE_TURNS, "§4.2: \"Hard Rock | 2\" is unchanged")
	assert_eq(
		site.remaining_turns(),
		FIXTURE_TURNS,
		"(AZ)(iii): a PARTIAL cancel spends and refunds nothing"
	)
	assert_null(
		state.dig_site_of_digger(FIRST_UNIT_ID), "(AZ)(i): the cancelled unit holds no dig job"
	)


## (AV)/§11.1 — A REJECTED `CancelDig` IS INVISIBLE TO THE STATE, exactly as section B proved for
## `EndTurn`. Three rejections are probed against the log's end state — the wrong player, an
## enemy-owned unit and a unit that is not digging — and none of them moves `content_hash()`,
## removes a site or unassigns a digger.
func test_a_rejected_cancel_in_the_log_changes_nothing() -> void:
	var state: GameState = _dig_state()
	_run(_mixed_log(), state, null)
	var before: int = state.content_hash()
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the mixed log ends with a site")
	if site == null:
		return
	var diggers_before: Array[int] = site.digger_ids()

	var their_unit: UnitState = state.spawn_unit(1, UNIT_TYPE_ID, SECOND_DIGGER_HEX, UNIT_MAX_HP)
	assert_not_null(their_unit, "fixture: an enemy unit is spawned")
	if their_unit == null:
		return
	var after_spawn: int = state.content_hash()

	var probes: Array[CancelDigCommand] = [
		CancelDigCommand.new(1, FIRST_UNIT_ID),
		CancelDigCommand.new(0, their_unit.unit_id()),
		CancelDigCommand.new(0, 9999),
	]
	for probe: CancelDigCommand in probes:
		var rejection: CommandError = probe.execute(state, null)
		assert_not_null(rejection, "(AV): the probe must be REJECTED")
		if rejection == null:
			return
		assert_false(rejection.message.is_empty(), "(AV): every rejection carries a message")
	assert_eq(
		state.content_hash(), after_spawn, "§11.1: a rejected cancel leaves the state identical"
	)
	assert_eq(
		state.dig_site_hexes(), [TARGET_HEX] as Array[Vector2i], "(AV): no site was removed"
	)
	assert_eq(site.digger_ids(), diggers_before, "(AV): no digger was unassigned")
	assert_ne(after_spawn, before, "sanity: the enemy spawn IS a state change, so the pin is live")


## §3.4 step 4 NEGATIVE PIN over the mixed log — a FULL EndTurn round happens between the dig
## orders and NOTHING ticks: the site still has all its worker-turns, the hex still carries its
## §4.2 Solid terrain, every stockpile is still EMPTY and the seeded stream has drawn NOTHING.
func test_the_mixed_replay_still_runs_none_of_the_section_three_four_steps() -> void:
	var state: GameState = _dig_state()
	_run(_mixed_log(), state, null)
	var site: DigSite = state.dig_site(TARGET_HEX)
	assert_not_null(site, "sanity: the site exists")
	if site == null:
		return
	assert_eq(
		site.remaining_turns(),
		FIXTURE_TURNS,
		"§3.4 step 4: \"Dig progress ticks\" is a LATER slice — no worker-turn was spent"
	)
	assert_eq(
		state.map.get_terrain_type(TARGET_HEX),
		FIXTURE_TERRAIN_ID,
		"§3.4 step 4: the hex-becomes-Cave transition is a LATER slice"
	)
	for index: int in range(PLAYER_COUNT):
		var holder: PlayerState = state.player(index)
		assert_not_null(holder, "sanity: player(%d) exists" % index)
		if holder == null:
			return
		assert_eq(
			holder.resource_ids(),
			[] as Array[String],
			"§3.4 step 4: yield APPLICATION is a LATER slice — player %d holds nothing" % index
		)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1: nothing in this slice is random — the seeded stream must not advance"
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


## The shipped ruleset, asserted loaded so a data failure reports once and clearly.
func _loaded() -> RulesLoader:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(RULESET_PATH)
	assert_true(ok, "§12.1: %s must load before DigRules can read it" % RULESET_PATH)
	if not ok:
		for err: RulesError in loader.errors:
			assert_false(true, "§12.1: %s" % err.format_for(RULESET_PATH))
	return loader


## The injected, already-loaded §4.2 dig table (M2-T3). A serialized DigHex would carry only
## `(player_index, unit_id, hex)`, so M7's command-log reader re-injects this — which is exactly
## why it is a constructor argument and not state.
func _dig_rules() -> DigRules:
	if _rules_cache == null:
		_rules_cache = DigRules.new(_loaded())
	return _rules_cache


## §11.1 — the state the MIXED log replays onto, built IDENTICALLY every call: a radius-2 map with
## §4.2 Hard Rock on the target, PLAYER_COUNT players, and two of player 0's units standing on two
## different neighbours of the target (ids 1 and 2, minted in that order — (AX)).
func _dig_state() -> GameState:
	var map: HexMap = HexMap.new(MAP_RADIUS)
	map.set_terrain_type(TARGET_HEX, FIXTURE_TERRAIN_ID)
	var state: GameState = GameState.new(REPLAY_SEED, map, PLAYER_COUNT)
	var first: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, FIRST_DIGGER_HEX, UNIT_MAX_HP)
	var second: UnitState = state.spawn_unit(0, UNIT_TYPE_ID, SECOND_DIGGER_HEX, UNIT_MAX_HP)
	assert_not_null(first, "fixture: the first worker is spawned")
	assert_not_null(second, "fixture: the second worker is spawned")
	if first != null:
		assert_eq(first.unit_id(), FIRST_UNIT_ID, "fixture: ids are minted from 1 (AX)")
	if second != null:
		assert_eq(second.unit_id(), SECOND_UNIT_ID, "fixture: ids ascend in spawn order (AX)")
	return state


## §11.1 line 705 — a log MIXING all THREE implemented commands ((AZ)): dig (create), dig (join),
## CANCEL, a full EndTurn round, dig again. A FRESH set of command objects every call, so a caller
## can compare two independently-built logs.
func _mixed_log() -> Array[Command]:
	var out: Array[Command] = []
	out.append(DigHexCommand.new(0, FIRST_UNIT_ID, TARGET_HEX, _dig_rules()))
	out.append(DigHexCommand.new(0, SECOND_UNIT_ID, TARGET_HEX, _dig_rules()))
	out.append(CancelDigCommand.new(0, FIRST_UNIT_ID))
	for index: int in range(PLAYER_COUNT):
		out.append(EndTurnCommand.new(index))
	out.append(DigHexCommand.new(0, FIRST_UNIT_ID, TARGET_HEX, _dig_rules()))
	return out


## Executes `log` against `state` through the ONE gate, returning `state.content_hash()` after
## every step so two runs can be compared step by step rather than only at the end.
func _run(command_log: Array[Command], state: GameState, bus: EventBus) -> Array:
	var hashes: Array = []
	for command: Command in command_log:
		command.execute(state, bus)
		hashes.append(state.content_hash())
	return hashes
