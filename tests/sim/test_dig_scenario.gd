## THE SCRIPTED 20-TURN DIG SCENARIO — GDD §14 M2 acceptance criterion (a): "**Scripted 20-turn dig
## scenario matches expected stockpiles exactly**". §13.2 tier 2 ("**System tests** (tests/sim/):
## scripted mini-scenarios"), §3.3 (Turn Model), §3.4 (Order of Operations, **binding; implement
## exactly**), §4.2 (Hex Types), §5.1 (Resources), §11.1 (Layered Design, **binding**), §13.6.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §14 M2 (line 1102): "Scripted 20-turn dig scenario matches expected stockpiles exactly; ..."
##   §3.4  (line 141): "**Per player, at start of their turn:**"
##   §3.4  (line 148, step 4): "Dig progress ticks; completed digs apply yields, then **Breach
##         checks** (§4.6), then **Noise pings** (§4.8)."
##   §4.2  (lines 184–193), the rows this scenario digs:
##             Soft Dirt       | 1 | \+1 Food (spores)
##             Dense Granite   | 4 | \+4 Stone
##             Rubble          | 1 | \+1 Stone
##             Gold Vein       | 2 | \+25 Gold lump + node
##             Iron Vein       | 2 | \+10 Iron lump + node
##             Magestone Crust | 2 | \+15 Magestone lump + node
##   §4.2  (line 197): "Dig time is **total worker-turns**; multiple workers on adjacent hexes may
##         work the same target (**max 2 simultaneous diggers per hex**)."
##   §5.1  (line 288): "No storage caps. Stockpiles are **per-player integers**."
##
## THE EXPECTED STOCKPILES ARE HAND-COMPUTED LITERALS, derived from the printed table above and
## NEVER read back from `DigRules` — a scenario that asked the code what it should expect would
## pass against any table at all. `docs/decisions.md` was re-scanned this iteration: **no logged
## override moves a printed §4.2 dig time or yield** ((AU)(i) sets `dig_yields.artificial_granite`
## to 2, which AGREES with the printed row and is not dug here anyway).
##
## THE SCENARIO, hand-run in `_expected_timeline()`'s comment below:
##   Two players. Player 0 works three targets (one of them with TWO diggers), player 1 works
##   three. Every dig is ordered on turn 1; §3.4 step 4 then runs at the start of each player's
##   turn and everything finishes inside the first three turns. The remaining seventeen turns are
##   the POINT: no income, no upkeep and no vein node exists yet, so a stockpile that keeps growing
##   after its dig finished is the exact failure this criterion is for.
extends GutTest

const RULESET_PATH: String = "res://data/ruleset.json"

## §12.6's example seed.
const SCENARIO_SEED: int = 1337

## §4.1 — a radius-2 disc holds every hex this scenario names; the real radii live in
## `data/mapgen/*.json`.
const MAP_RADIUS: int = 2

## §3.1 line 118 "Skirmish: 2–4 players".
const PLAYER_COUNT: int = 2

## §14 M2 — "**20-turn** dig scenario". A full round of both players is ONE turn (§3.3), so the log
## carries 2 × (20 - 1) = 38 End Turns and ends at (turn 20, index 0).
const SCENARIO_TURNS: int = 20
const END_TURN_COUNT: int = 38

## §4.1 "axial coordinates (q, r)" — THE SIX DUG HEXES, with the §4.2 row each carries and the
## player who orders it. Index-aligned tables (the §11.1 "no parallel truth" style used by
## `test_turn_replay.gd`'s hand tables).
const TARGET_HEXES: Array[Vector2i] = [
	Vector2i(0, 0),    # 0 — player 0, Dense Granite, TWO diggers
	Vector2i(2, -2),   # 1 — player 0, Gold Vein
	Vector2i(-2, 2),   # 2 — player 0, Soft Dirt
	Vector2i(0, -2),   # 3 — player 1, Iron Vein
	Vector2i(1, 1),    # 4 — player 1, Rubble
	Vector2i(-2, 1),   # 5 — player 1, Magestone Crust
]
const TARGET_TERRAINS: Array[String] = [
	"dense_granite",
	"gold_vein",
	"soft_dirt",
	"iron_vein",
	"rubble",
	"magestone_crust",
]
const TARGET_OWNERS: Array[int] = [0, 0, 0, 1, 1, 1]

## §4.2 line 197 "multiple workers on **adjacent** hexes" — where each of the seven workers stands,
## which player owns it and which entry of TARGET_HEXES it is ordered onto. Workers 0–3 belong to
## player 0 and are spawned first, so (AX)'s ascending ids run 1..4 then 5..7.
const WORKER_HEXES: Array[Vector2i] = [
	Vector2i(1, 0),    # id 1 — player 0 -> target 0
	Vector2i(1, -1),   # id 2 — player 0 -> target 0 (the SECOND digger, §4.2 line 197's cap)
	Vector2i(2, -1),   # id 3 — player 0 -> target 1
	Vector2i(-1, 1),   # id 4 — player 0 -> target 2
	Vector2i(-1, -1),  # id 5 — player 1 -> target 3
	Vector2i(0, 2),    # id 6 — player 1 -> target 4
	Vector2i(-2, 0),   # id 7 — player 1 -> target 5
]
const WORKER_OWNERS: Array[int] = [0, 0, 0, 0, 1, 1, 1]
const WORKER_TARGETS: Array[int] = [0, 0, 1, 2, 3, 4, 5]

## §12.2's printed example definition id and `"hp": 70`. §12.7's `worker` trait is DATA and
## `data/units/*.json` is M6, so the type stays OPAQUE — any unit may be ordered to dig today.
const UNIT_TYPE_ID: String = "dwarf_worker"
const UNIT_MAX_HP: int = 70

## §14 M2 (a) THE ANSWER — hand-computed from §4.2's printed "Yield on dig" column:
##   player 0: Dense Granite \+4 Stone · Gold Vein \+25 Gold · Soft Dirt \+1 Food
##   player 1: Iron Vein \+10 Iron · Rubble \+1 Stone · Magestone Crust \+15 Magestone
const EXPECTED_PLAYER_0: Dictionary = {"food": 1, "gold": 25, "stone": 4}
const EXPECTED_PLAYER_1: Dictionary = {"iron": 10, "magestone": 15, "stone": 1}

## §5.1's six printed player resources plus Goblin-only Scrap — every one of them is asserted, so a
## resource that should be ZERO cannot hide.
const ALL_RESOURCE_IDS: Array[String] = [
	"food", "gold", "stone", "iron", "magestone", "mithril", "scrap"
]

## §4.2's Cave-hex table row "Plain floor" — what all six dug hexes must be at the end.
const CAVE_TERRAIN_ID: String = "plain_floor"

## §13.6 — the event stream this scenario must produce, hand-counted in `_expected_timeline()`.
const EXPECTED_DIG_STARTED: int = 7
const EXPECTED_DIG_PROGRESSED: int = 10
const EXPECTED_DIG_COMPLETED: int = 6

## Cached across tests: `data/ruleset.json` is parsed once and `DigRules` mutates nothing (M2-T3).
var _rules_cache: DigRules = null


# =============================================================================================
# Test-local fixtures — never start with "Test" (GUT would collect them as inner suites).
# =============================================================================================

## Counts deliveries per event type, in delivery order.
class StreamRecorder extends RefCounted:
	var types: Array[String] = []

	func on_event(event: Event) -> void:
		types.append(String(event.type))

	func count_of(type_name: String) -> int:
		return types.count(type_name)


# =============================================================================================
# A. §14 M2 ACCEPTANCE CRITERION (a) — THE STOCKPILES, EXACTLY
# =============================================================================================

## §14 M2 (a) — "Scripted 20-turn dig scenario matches expected stockpiles exactly". The whole
## criterion in one test: run the scripted log, then assert EVERY §5.1 resource of EVERY player
## against a hand-written literal — including the ones that must be exactly ZERO, because "exactly"
## is the load-bearing word.
func test_the_twenty_turn_scenario_matches_the_expected_stockpiles_exactly() -> void:
	var state: GameState = _run_scenario(null)
	assert_eq(
		Vector2i(state.turn(), state.current_player_index()),
		Vector2i(SCENARIO_TURNS, 0),
		"§3.3: %d End Turns at %d players end the scenario at (turn %d, index 0)" % [
			END_TURN_COUNT, PLAYER_COUNT, SCENARIO_TURNS
		]
	)
	_assert_stockpile(state, 0, EXPECTED_PLAYER_0)
	_assert_stockpile(state, 1, EXPECTED_PLAYER_1)


## §14 M2 (a) — the stockpiles are already final at TURN 4 and do not move for the remaining
## sixteen turns. §3.4 steps 1 and 2 (income and upkeep) and §5.2's Extractors are LATER slices, so
## a stockpile that keeps climbing is the precise regression this criterion exists to catch.
func test_the_stockpiles_stop_moving_once_every_dig_is_finished() -> void:
	var state: GameState = _scenario_state()
	var command_log: Array[Command] = _command_log()
	var settled_at: int = -1
	var settled: Array[String] = []
	for step: int in range(command_log.size()):
		command_log[step].execute(state, null)
		var snapshot: Array[String] = _stockpile_fingerprint(state)
		if settled_at == -1 and _matches_expected(state):
			settled_at = step
			settled = snapshot
		elif settled_at != -1:
			assert_eq(
				snapshot,
				settled,
				"§3.4: no income, no upkeep and no Extractor exists — nothing may move after step %d" % [
					settled_at
				]
			)
	assert_gte(settled_at, 0, "§14 M2 (a): the scenario must actually reach the expected stockpiles")
	assert_lte(
		state.turn(),
		SCENARIO_TURNS,
		"§14 M2 (a): and it must settle well inside the twenty turns"
	)


## §4.2 / §3.4 step 4 — every dug hex is now §4.2's Cave row "Plain floor", every dig site is gone,
## and all seven workers are alive, un-mutated and holding no dig job.
func test_every_dug_hex_became_cave_and_every_worker_was_freed() -> void:
	var state: GameState = _run_scenario(null)
	for index: int in range(TARGET_HEXES.size()):
		assert_eq(
			state.map.get_terrain_type(TARGET_HEXES[index]),
			CAVE_TERRAIN_ID,
			"§4.2: %s was \"%s\" and is now Cave" % [
				str(TARGET_HEXES[index]), TARGET_TERRAINS[index]
			]
		)
	assert_eq(state.dig_site_hexes(), [] as Array[Vector2i], "§3.4 step 4: every site completed")
	assert_eq(
		state.unit_ids().size(), WORKER_HEXES.size(), "(BA)(iv): no worker was consumed by a dig"
	)
	for id: int in state.unit_ids():
		assert_null(state.dig_site_of_digger(id), "(BA)(iv): worker %d holds no dig job" % id)
		var unit: UnitState = state.unit(id)
		assert_not_null(unit, "(BA)(iv): worker %d is still on the roster" % id)
		if unit == null:
			return
		assert_eq(unit.hp(), UNIT_MAX_HP, "(BA)(iv): a completion is not a casualty")
		assert_eq(
			unit.hex(), WORKER_HEXES[id - 1], "(BA)(iv): and it does not move the worker"
		)


# =============================================================================================
# B. THE TIMELINE (§3.4 "Per player, at start of their turn"; §4.2's dig times)
# =============================================================================================

## §3.4 / §4.2 — THE HAND-RUN TIMELINE, asserted turn by turn rather than only at the end, so a
## scenario that reaches the right totals by the wrong route is caught. See `_expected_timeline()`
## for the full derivation.
func test_the_scenario_follows_the_hand_computed_timeline() -> void:
	var state: GameState = _scenario_state()
	var command_log: Array[Command] = _command_log()
	var timeline: Array[Dictionary] = _expected_timeline()
	var checkpoint: int = 0
	for step: int in range(command_log.size()):
		command_log[step].execute(state, null)
		if checkpoint >= timeline.size():
			continue
		var expected: Dictionary = timeline[checkpoint]
		if step != int(expected["after_step"]):
			continue
		assert_eq(
			state.turn(), int(expected["turn"]), "§3.3: checkpoint %d is on turn %d" % [
				checkpoint, int(expected["turn"])
			]
		)
		assert_eq(
			state.dig_site_hexes().size(),
			int(expected["sites"]),
			"§3.4 step 4: checkpoint %d has %d dig sites left" % [
				checkpoint, int(expected["sites"])
			]
		)
		assert_eq(
			_stockpile_fingerprint(state),
			expected["stockpiles"],
			"§4.2: checkpoint %d's hand-computed stockpiles" % checkpoint
		)
		checkpoint += 1
	assert_eq(checkpoint, timeline.size(), "sanity: every hand-computed checkpoint was reached")


## §4.2 line 197 "Dig time is TOTAL worker-turns" — THE TWO-DIGGER SITE IS THE POINT OF THE
## SCENARIO. "Dense Granite | 4" with two workers finishes in TWO of player 0's turns; the same row
## with one worker would need four, so a rule that decremented by a fixed 1 lands on a different
## timeline (and, at turn 20, on the same totals — which is why the timeline above is asserted).
func test_the_two_digger_site_finishes_in_half_the_worker_turns() -> void:
	var state: GameState = _scenario_state()
	var command_log: Array[Command] = _command_log()
	# Steps 0-3 are player 0's dig orders, 4 is their EndTurn, 5-7 are player 1's orders, 8 is
	# player 1's EndTurn — the first tick player 0 receives.
	for step: int in range(9):
		command_log[step].execute(state, null)
	var granite: DigSite = state.dig_site(TARGET_HEXES[0])
	assert_not_null(granite, "§4.2: \"Dense Granite | 4\" is not finished after one tick")
	if granite == null:
		return
	assert_eq(granite.digger_ids(), [1, 2] as Array[int], "§4.2 line 197: two diggers, ascending")
	assert_eq(granite.remaining_turns(), 2, "§4.2 line 197: 4 total worker-turns minus TWO")

	# Steps 9 (player 0's EndTurn) and 10 (player 1's EndTurn) bring player 0's second tick.
	command_log[9].execute(state, null)
	command_log[10].execute(state, null)
	assert_null(state.dig_site(TARGET_HEXES[0]), "§4.2 line 197: the second tick finishes it")
	assert_eq(state.player(0).amount_of("stone"), 4, "§4.2: \"Dense Granite | 4 | \\+4 Stone\"")


# =============================================================================================
# C. §13.6 EVENTS AND §11.1 DETERMINISM
# =============================================================================================

## §13.6 "events emitted for every state change" — the whole scenario's event stream, counted by
## type: one `dig_started` per accepted order, one `dig_progressed` per site that MOVED, one
## `dig_completed` per finished dig, and one `turn_ended` per End Turn.
func test_the_scenario_emits_the_hand_counted_event_stream() -> void:
	var bus: EventBus = EventBus.new()
	var recorder: StreamRecorder = StreamRecorder.new()
	for type_name: StringName in [
		TurnEndedEvent.TYPE_NAME,
		DigStartedEvent.TYPE_NAME,
		DigCancelledEvent.TYPE_NAME,
		DigProgressedEvent.TYPE_NAME,
		DigCompletedEvent.TYPE_NAME,
	]:
		bus.subscribe(type_name, recorder.on_event)
	_run_scenario(bus)

	assert_eq(
		recorder.count_of("dig_started"),
		EXPECTED_DIG_STARTED,
		"§13.6: one dig_started per accepted order (four for player 0, three for player 1)"
	)
	assert_eq(
		recorder.count_of("dig_progressed"),
		EXPECTED_DIG_PROGRESSED,
		"§13.6: one dig_progressed per site that actually moved"
	)
	assert_eq(
		recorder.count_of("dig_completed"),
		EXPECTED_DIG_COMPLETED,
		"§13.6: one dig_completed per finished dig — six digs, six completions"
	)
	assert_eq(
		recorder.count_of("turn_ended"), END_TURN_COUNT, "§3.3: one turn_ended per accepted End Turn"
	)
	assert_eq(recorder.count_of("dig_cancelled"), 0, "§13.6: this scenario cancels nothing")


## §11.1 line 708 "replaying (seed, command\_log) must reproduce the hash" — the scenario is a
## `(seed, command_log)` pair, so two fresh states fed the same log agree on `content_hash()` AT
## EVERY STEP, and a third run agrees again.
func test_the_scenario_replays_to_an_identical_hash_sequence() -> void:
	var first: GameState = _scenario_state()
	var second: GameState = _scenario_state()
	var log_a: Array[Command] = _command_log()
	var log_b: Array[Command] = _command_log()
	assert_eq(
		first.content_hash(), second.content_hash(), "§11.1: two identical states start identical"
	)
	for step: int in range(log_a.size()):
		var rejection_a: CommandError = log_a[step].execute(first, null)
		var rejection_b: CommandError = log_b[step].execute(second, null)
		assert_null(rejection_a, "§14 M2 (a): scenario step %d must be ACCEPTED" % step)
		assert_eq(
			rejection_a == null, rejection_b == null, "§11.1: step %d agrees on both states" % step
		)
		assert_eq(
			first.content_hash(),
			second.content_hash(),
			"§11.1: the scenario diverged at step %d" % step
		)
	var third: GameState = _run_scenario(null)
	assert_eq(
		third.content_hash(), first.content_hash(), "§11.1: a third replay agrees as well"
	)


## §11.1 "no randi()" / §3.4 — the twenty turns draw NOTHING from the one seeded stream: step 4's
## Breach checks (§4.6) and Noise pings (§4.8) are M5, and every rule in this scenario is integer
## arithmetic over §12.1 data.
func test_the_scenario_draws_no_random_roll() -> void:
	var state: GameState = _run_scenario(null)
	assert_eq(
		state.rng.rolls_drawn(),
		0,
		"§11.1/§3.4: Breach (§4.6) and Noise (§4.8) are M5 — the seeded stream must not advance"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## The shipped ruleset, asserted loaded so a data failure reports once and clearly.
func _loaded() -> RulesLoader:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(RULESET_PATH)
	assert_true(ok, "§12.1: %s must load before the scenario means anything" % RULESET_PATH)
	if not ok:
		for err: RulesError in loader.errors:
			assert_false(true, "§12.1: %s" % err.format_for(RULESET_PATH))
	return loader


## The injected, already-loaded §4.2 dig table (M2-T3), shared by every command in the log — M7's
## command-log reader re-injects exactly this, which is why it is a constructor argument.
func _dig_rules() -> DigRules:
	if _rules_cache == null:
		_rules_cache = DigRules.new(_loaded())
	return _rules_cache


## §11.1 — the state the scenario runs on, built IDENTICALLY every call: a radius-2 map carrying
## the six §4.2 Solid rows, two players, and seven workers spawned player-0-first so (AX)'s
## ascending ids match WORKER_HEXES index + 1.
func _scenario_state() -> GameState:
	var map: HexMap = HexMap.new(MAP_RADIUS)
	for index: int in range(TARGET_HEXES.size()):
		map.set_terrain_type(TARGET_HEXES[index], TARGET_TERRAINS[index])
	var state: GameState = GameState.new(SCENARIO_SEED, map, PLAYER_COUNT)
	for index: int in range(WORKER_HEXES.size()):
		var unit: UnitState = state.spawn_unit(
			WORKER_OWNERS[index], UNIT_TYPE_ID, WORKER_HEXES[index], UNIT_MAX_HP
		)
		assert_not_null(unit, "fixture: worker %d is spawned" % index)
		if unit != null:
			assert_eq(unit.unit_id(), index + 1, "fixture (AX): ids are minted 1..7 in spawn order")
	return state


## §11.1 line 705 — THE SCRIPTED COMMAND LOG. A FRESH set of command objects every call, so a
## caller can compare two independently-built logs:
##   [0..3]  player 0's four dig orders (two of them onto the same Dense Granite target)
##   [4]     player 0's End Turn — player 1 has no site yet, so their tick does nothing
##   [5..7]  player 1's three dig orders
##   [8..]   38 End Turns, alternating, ending at (turn 20, index 0)
func _command_log() -> Array[Command]:
	var out: Array[Command] = []
	for index: int in range(WORKER_HEXES.size()):
		if WORKER_OWNERS[index] != 0:
			continue
		out.append(
			DigHexCommand.new(0, index + 1, TARGET_HEXES[WORKER_TARGETS[index]], _dig_rules())
		)
	out.append(EndTurnCommand.new(0, _dig_rules()))
	for index: int in range(WORKER_HEXES.size()):
		if WORKER_OWNERS[index] != 1:
			continue
		out.append(
			DigHexCommand.new(1, index + 1, TARGET_HEXES[WORKER_TARGETS[index]], _dig_rules())
		)
	for step: int in range(END_TURN_COUNT - 1):
		out.append(EndTurnCommand.new((step + 1) % PLAYER_COUNT, _dig_rules()))
	return out


## Builds a fresh state and runs the whole scripted log against it through the ONE gate.
func _run_scenario(bus: EventBus) -> GameState:
	var state: GameState = _scenario_state()
	for command: Command in _command_log():
		command.execute(state, bus)
	return state


## §4.2/§14 M2 (a) THE HAND-RUN TIMELINE. Step indices refer to `_command_log()` above.
##   after step  4 — player 0 ends turn 1; player 1's tick finds NO site. 3 sites (player 0's, the
##                   Dense Granite one carrying TWO diggers), nothing yielded.
##   after step  7 — player 1's three orders land. 6 sites, still nothing yielded.
##   after step  8 — player 1 ends turn 1 (turn 2 begins for player 0). Player 0's FIRST tick:
##                   Gold Vein 2->1, Dense Granite 4->2, Soft Dirt 1->0 COMPLETE \+1 Food.
##                   5 sites; player 0 holds Food 1.
##   after step  9 — player 0 ends turn 2. Player 1's FIRST tick: Iron Vein 2->1, Magestone 2->1,
##                   Rubble 1->0 COMPLETE \+1 Stone. 4 sites; player 1 holds Stone 1.
##   after step 10 — player 1 ends turn 2 (turn 3). Player 0's SECOND tick: Dense Granite 2->0
##                   COMPLETE \+4 Stone, Gold Vein 1->0 COMPLETE \+25 Gold. 2 sites.
##   after step 11 — player 0 ends turn 3. Player 1's SECOND tick: Iron Vein 1->0 COMPLETE \+10
##                   Iron, Magestone 1->0 COMPLETE \+15 Magestone. 0 sites — everything is final.
##   after step 44 — the last End Turn (turn 20, index 0). Nothing has moved for seventeen turns.
func _expected_timeline() -> Array[Dictionary]:
	return [
		{"after_step": 4, "turn": 1, "sites": 3, "stockpiles": _fingerprint_of({}, {})},
		{"after_step": 7, "turn": 1, "sites": 6, "stockpiles": _fingerprint_of({}, {})},
		{"after_step": 8, "turn": 2, "sites": 5, "stockpiles": _fingerprint_of({"food": 1}, {})},
		{
			"after_step": 9,
			"turn": 2,
			"sites": 4,
			"stockpiles": _fingerprint_of({"food": 1}, {"stone": 1}),
		},
		{
			"after_step": 10,
			"turn": 3,
			"sites": 2,
			"stockpiles": _fingerprint_of({"food": 1, "stone": 4, "gold": 25}, {"stone": 1}),
		},
		{
			"after_step": 11,
			"turn": 3,
			"sites": 0,
			"stockpiles": _fingerprint_of(EXPECTED_PLAYER_0, EXPECTED_PLAYER_1),
		},
		{
			"after_step": 44,
			"turn": SCENARIO_TURNS,
			"sites": 0,
			"stockpiles": _fingerprint_of(EXPECTED_PLAYER_0, EXPECTED_PLAYER_1),
		},
	]


## Asserts every §5.1 resource of `player_index` against `expected`, INCLUDING the ones that must be
## exactly zero, and pins the ascending `resource_ids()` surface too (§5.1: a zero entry is removed,
## so an unyielded resource must not even be listed).
func _assert_stockpile(state: GameState, player_index: int, expected: Dictionary) -> void:
	var holder: PlayerState = state.player(player_index)
	assert_not_null(holder, "sanity: player(%d) exists" % player_index)
	if holder == null:
		return
	for resource_id: String in ALL_RESOURCE_IDS:
		var want: int = expected[resource_id] if expected.has(resource_id) else 0
		assert_eq(
			holder.amount_of(resource_id),
			want,
			"§14 M2 (a)/§4.2: player %d must hold exactly %d %s" % [player_index, want, resource_id]
		)
	var ids: Array[String] = []
	for key: Variant in expected.keys():
		ids.append(str(key))
	ids.sort()
	assert_eq(
		holder.resource_ids(),
		ids,
		"§5.1: player %d's stockpile lists exactly %s, ascending" % [player_index, str(ids)]
	)


## Both players' stockpiles as one comparable String array, so a checkpoint is one assertion.
func _stockpile_fingerprint(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for index: int in range(PLAYER_COUNT):
		var holder: PlayerState = state.player(index)
		if holder == null:
			continue
		for resource_id: String in ALL_RESOURCE_IDS:
			out.append("%d.%s=%d" % [index, resource_id, holder.amount_of(resource_id)])
	return out


## The same fingerprint built from two hand-written expectation Dictionaries.
func _fingerprint_of(player_0: Dictionary, player_1: Dictionary) -> Array[String]:
	var expectations: Array[Dictionary] = [player_0, player_1]
	var out: Array[String] = []
	for index: int in range(PLAYER_COUNT):
		var expected: Dictionary = expectations[index]
		for resource_id: String in ALL_RESOURCE_IDS:
			var want: int = expected[resource_id] if expected.has(resource_id) else 0
			out.append("%d.%s=%d" % [index, resource_id, want])
	return out


## True when both stockpiles have reached their final hand-computed values.
func _matches_expected(state: GameState) -> bool:
	return _stockpile_fingerprint(state) == _fingerprint_of(EXPECTED_PLAYER_0, EXPECTED_PLAYER_1)
