## THE §13.2 TIER-3 GOLDEN — "fixed seed + recorded command log => recorded GameState.hash() after
## N turns. Any rules change that legitimately alters the hash must re-record goldens **in the same
## commit** with a docs/decisions.md entry". §13.6 ("goldens re-recorded only with a logged
## reason"); §11.1 ("**a match is fully described by (seed, command\_log)**" and "GameState.hash()
## (FNV over canonical serialization) must be reproducible"); §3.3, §3.4, §4.2, §5.1, §14 M2.
##
## THIS IS THE DEBT M2-T2 OPENED AND FOUR SLICES DEFERRED — decisions.md **(AV) item 7**, restated
## at **(AW) item 5**, **(AX) item 11**, **(AY) item 12** and **(AZ) item 9**. It could not be
## recorded before now: M2-T3 changes no state at all, M2-T4 and M2-T5 each EXTENDED the
## `GameState` fold (freezing it earlier would have cost a re-record twice over) and M2-T6 added no
## fold and no tick. §3.4 step 4 is the first rule whose state genuinely EVOLVES over N turns, so
## this is the slice that records it.
##
## WHAT IS RECORDED, and why each field is GDD-sourced rather than invented:
##   scenario     "dig_tick_20_turns" — §14 M2 acceptance criterion (a)'s own phrase, "Scripted
##                20-turn dig scenario".
##   seed         4242 — a free parameter of a golden, deliberately DIFFERENT from the mapgen
##                golden's §12.6 seed 1337 so the two recorded runs can never be confused, and so
##                §11.1's "(seed, command_log)" clause is exercised on a second seed.
##   map_radius   2 — a hand-built radius-2 disc; §4.1's real radii (24/32/40) belong to
##                `data/mapgen/*.json` and to the M1 mapgen golden, not here.
##   player_count 2 — §3.1 line 118, "Skirmish: 2–4 players".
##   turns        20 — §14 M2 (a), "20-turn dig scenario". A full round of both players is ONE turn
##                (§3.3), hence 2 × (20 - 1) = 38 End Turns.
##   commands     45 — the log length, recorded so a mismatch is diagnosable as "the log moved"
##                rather than "the rules moved".
##   content_hash `GameState.content_hash()` rendered as `"0x%08x"`, a lowercase 8-hex-digit STRING
##                and NEVER a JSON number, because Godot 4.7 parses EVERY JSON number as
##                TYPE_FLOAT (decisions.md M0-T2 item 8) and a 32-bit hash would round.
##
## RECORDING PROCEDURE (this file NEVER writes the golden itself — an auto-recording golden proves
## nothing at all, and there is NO record-mode flag): run the suite; the failure message below
## prints the observed hash and the exact JSON document to write to
## `tests/golden/dig_tick_scenario_seed4242.json`; write it, re-run, and the test goes green. **From
## the commit that first records it, §13.6 applies FOREVER: a re-record needs its own dated
## docs/decisions.md reason in the SAME commit.**
##
## Before trusting a mismatch, read `test_the_scenario_is_deterministic_before_the_hash_is_read`
## below: it re-proves determinism inside this file, so a red golden means the RULES moved, not that
## the sim became flaky.
extends GutTest

const RULESET_PATH: String = "res://data/ruleset.json"
const GOLDEN_PATH: String = "res://tests/golden/dig_tick_scenario_seed4242.json"

## The recorded run's identity. These literals are allowed HERE (a golden records concrete values by
## definition) and in `data/*.json` — never in engine code (§13.6).
const SCENARIO_ID: String = "dig_tick_20_turns"
const GOLDEN_SEED: int = 4242
const MAP_RADIUS: int = 2
const PLAYER_COUNT: int = 2
const SCENARIO_TURNS: int = 20
const END_TURN_COUNT: int = 38
const COMMAND_COUNT: int = 45

## A one-line human description of the log, recorded alongside the hash so the document describes
## the run it hashes (§13.2 tier 3) instead of being one opaque number.
const COMMAND_LOG_SHAPE: String = (
	"4x DigHex(player 0) -> EndTurn(0) -> 3x DigHex(player 1) -> 37 more EndTurns"
)

## The re-record rule, verbatim, so it is printed at the exact moment someone is deciding whether to
## overwrite the file (§13.6). Do not soften this sentence.
const RERECORD_RULE: String = (
	"re-record ONLY with a dated docs/decisions.md reason in the SAME commit (§13.6)"
)

## §4.1 "axial coordinates (q, r)" — the six dug hexes, their §4.2 rows and their owners.
const TARGET_HEXES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(2, -2),
	Vector2i(-2, 2),
	Vector2i(0, -2),
	Vector2i(1, 1),
	Vector2i(-2, 1),
]
const TARGET_TERRAINS: Array[String] = [
	"dense_granite",
	"gold_vein",
	"soft_dirt",
	"iron_vein",
	"rubble",
	"magestone_crust",
]

## §4.2 line 197 "multiple workers on **adjacent** hexes" — the seven workers, their owners and the
## target each is ordered onto.
const WORKER_HEXES: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(2, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(0, 2),
	Vector2i(-2, 0),
]
const WORKER_OWNERS: Array[int] = [0, 0, 0, 0, 1, 1, 1]
const WORKER_TARGETS: Array[int] = [0, 0, 1, 2, 3, 4, 5]

## §12.2's printed example `"hp": 70`; the type id is OPAQUE (`data/units/*.json` is M6).
const UNIT_TYPE_ID: String = "dwarf_worker"
const UNIT_MAX_HP: int = 70

## Cached across tests: `data/ruleset.json` is parsed once and `DigRules` mutates nothing.
var _rules_cache: DigRules = null


# =============================================================================================
# THE GOLDEN (§13.2 tier 3)
# =============================================================================================

## §13.2 tier 3 — SEED + RECORDED COMMAND LOG => RECORDED HASH AFTER N TURNS. The whole tier in one
## assertion: seed 4242, the scripted dig log, twenty turns, and the recorded
## `GameState.content_hash()` of the state it ends in.
func test_the_twenty_turn_dig_scenario_matches_the_recorded_hash() -> void:
	var state: GameState = _run_scenario()
	if state == null:
		return
	assert_eq(
		Vector2i(state.turn(), state.current_player_index()),
		Vector2i(SCENARIO_TURNS, 0),
		"§3.3: the recorded log ends at (turn %d, index 0)" % SCENARIO_TURNS
	)

	var observed: String = _render(state.content_hash())
	var recorded: Dictionary = _recorded()
	if recorded.is_empty():
		assert_true(
			false,
			(
				"§13.2 tier 3: the golden file %s is MISSING (or unreadable/malformed). "
				+ "This test NEVER records it for you and has no record mode. Observed hash: %s. "
				+ "Write exactly:\n%s\nOnce recorded, %s."
			) % [GOLDEN_PATH, observed, _document_for(observed), RERECORD_RULE]
		)
		return

	var expected: String = str(recorded.get("content_hash", ""))
	assert_true(
		_is_rendered_hash(expected),
		"§13.2 tier 3: the recorded hash must be a lowercase 8-hex-digit string like 0x0badc0de, got %s" % [
			expected
		]
	)
	assert_eq(
		observed,
		expected,
		(
			"§13.2 tier 3: (seed, command_log) => hash MISMATCH. recorded=%s observed=%s. "
			+ "If the rules legitimately moved, %s — otherwise fix the code, not the golden."
		) % [expected, observed, RERECORD_RULE]
	)


## §13.2 tier 3 — the recorded document must DESCRIBE the run it hashes, so a mismatch is
## diagnosable (wrong seed? wrong roster? a log that grew a command?) instead of being one opaque
## number.
func test_the_recorded_document_describes_the_run_it_hashes() -> void:
	var recorded: Dictionary = _recorded()
	if recorded.is_empty():
		assert_true(
			false,
			"§13.2 tier 3: %s is MISSING and must be recorded before this suite can be green; %s" % [
				GOLDEN_PATH, RERECORD_RULE
			]
		)
		return
	assert_eq(str(recorded.get("scenario", "")), SCENARIO_ID, "§14 M2 (a): the scenario id")
	assert_eq(_integral(recorded.get("seed", -1)), GOLDEN_SEED, "§11.1: the recorded seed")
	assert_eq(_integral(recorded.get("map_radius", -1)), MAP_RADIUS, "§4.1: the recorded map radius")
	assert_eq(
		_integral(recorded.get("player_count", -1)), PLAYER_COUNT, "§3.1: the recorded roster size"
	)
	assert_eq(_integral(recorded.get("turns", -1)), SCENARIO_TURNS, "§14 M2 (a): the turn count")
	assert_eq(
		_integral(recorded.get("commands", -1)), COMMAND_COUNT, "§11.1: the command-log length"
	)
	assert_eq(
		str(recorded.get("command_log", "")), COMMAND_LOG_SHAPE, "§11.1: the command-log shape"
	)


## §11.1 — determinism is re-proven INSIDE the golden file, so a red golden can be read correctly:
## three fresh states on the same seed fed three independently-built logs must agree BEFORE the
## recorded value is consulted at all. A flaky sim would otherwise be misdiagnosed as a rules change
## and "fixed" by re-recording — the one move §13.6 exists to prevent.
func test_the_scenario_is_deterministic_before_the_hash_is_read() -> void:
	var hashes: Array[int] = []
	for run: int in range(3):
		var state: GameState = _run_scenario()
		if state == null:
			return
		hashes.append(state.content_hash())
	for run: int in range(1, hashes.size()):
		assert_eq(
			hashes[run],
			hashes[0],
			"§11.1: the sim must be reproducible before any hash is recorded (run %d)" % run
		)


## §11.1 "(seed, command\_log)" — THE SEED IS HALF OF IT. The same log on a DIFFERENT seed must not
## hash the same, or a replay could silently validate against the wrong match and the golden would
## be recording the log alone.
func test_the_same_log_on_a_different_seed_does_not_collide() -> void:
	var recorded_seed: GameState = _run_scenario()
	var other_seed: GameState = _run_scenario_with_seed(GOLDEN_SEED + 1)
	if recorded_seed == null or other_seed == null:
		return
	assert_ne(
		recorded_seed.content_hash(),
		other_seed.content_hash(),
		"§11.1: the seed is part of the replayable state"
	)


## §13.2 tier 3 "after N turns" — the hash is taken at the END of the recorded log and nowhere else.
## Pinned by showing the state at turn 3 (where every dig has just finished) hashes DIFFERENTLY from
## the recorded end state, so a golden recorded off a truncated log is caught.
func test_the_recorded_hash_is_the_end_of_the_log_not_the_middle() -> void:
	var full: GameState = _run_scenario()
	var partial: GameState = _scenario_state(GOLDEN_SEED)
	if full == null or partial == null:
		return
	var command_log: Array[Command] = _command_log()
	for step: int in range(12):
		command_log[step].execute(partial, null)
	assert_eq(partial.dig_site_hexes(), [] as Array[Vector2i], "§4.2: every dig has finished by then")
	assert_ne(
		full.content_hash(),
		partial.content_hash(),
		"§13.2 tier 3: the recorded hash is taken after ALL %d turns" % SCENARIO_TURNS
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## The shipped ruleset, asserted loaded so a data failure reports once and clearly.
func _loaded() -> RulesLoader:
	var loader: RulesLoader = RulesLoader.new()
	var ok: bool = loader.load_file(RULESET_PATH)
	assert_true(ok, "§12.1: %s must load before a golden means anything" % RULESET_PATH)
	if not ok:
		for err: RulesError in loader.errors:
			assert_false(true, "§12.1: %s" % err.format_for(RULESET_PATH))
	return loader


## The injected, already-loaded §4.2 dig table.
func _dig_rules() -> DigRules:
	if _rules_cache == null:
		_rules_cache = DigRules.new(_loaded())
	return _rules_cache


## The state the recorded run starts from, built IDENTICALLY every call.
func _scenario_state(seed_value: int) -> GameState:
	var map: HexMap = HexMap.new(MAP_RADIUS)
	for index: int in range(TARGET_HEXES.size()):
		map.set_terrain_type(TARGET_HEXES[index], TARGET_TERRAINS[index])
	var state: GameState = GameState.new(seed_value, map, PLAYER_COUNT)
	for index: int in range(WORKER_HEXES.size()):
		var unit: UnitState = state.spawn_unit(
			WORKER_OWNERS[index], UNIT_TYPE_ID, WORKER_HEXES[index], UNIT_MAX_HP
		)
		assert_not_null(unit, "fixture: worker %d is spawned" % index)
	return state


## THE RECORDED COMMAND LOG, a FRESH set of command objects every call.
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


## Builds a fresh state on the recorded seed and runs the whole recorded log through the ONE gate.
func _run_scenario() -> GameState:
	return _run_scenario_with_seed(GOLDEN_SEED)


## The same run on an arbitrary seed, for the "(seed, command_log)" probe.
func _run_scenario_with_seed(seed_value: int) -> GameState:
	var state: GameState = _scenario_state(seed_value)
	var command_log: Array[Command] = _command_log()
	assert_eq(command_log.size(), COMMAND_COUNT, "§13.2 tier 3: the recorded log length")
	for command: Command in command_log:
		var rejection: CommandError = command.execute(state, null)
		assert_null(rejection, "§13.2 tier 3: every command in the recorded log must be ACCEPTED")
	return state


## The canonical rendering of a content hash: lowercase, zero-padded to 8 hex digits.
func _render(value: int) -> String:
	return "0x%08x" % value


## True for the canonical rendering above — a recorded hash may never be a JSON number.
func _is_rendered_hash(text: String) -> bool:
	var pattern: RegEx = RegEx.new()
	if pattern.compile("^0x[0-9a-f]{8}$") != OK:
		return false
	return pattern.search(text) != null


## The recorded golden document, or {} when the file is absent, unreadable or malformed. NEVER
## creates it — recording is a deliberate decision that carries a decisions.md entry (§13.6).
func _recorded() -> Dictionary:
	if not FileAccess.file_exists(GOLDEN_PATH):
		return {}
	var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	if not (data is Dictionary):
		return {}
	return data


## The exact document to write when recording, printed inside the failure message so the procedure
## is the message rather than tribal knowledge.
func _document_for(observed: String) -> String:
	return (
		"{\n"
		+ "  \"scenario\": \"%s\",\n" % SCENARIO_ID
		+ "  \"seed\": %d,\n" % GOLDEN_SEED
		+ "  \"map_radius\": %d,\n" % MAP_RADIUS
		+ "  \"player_count\": %d,\n" % PLAYER_COUNT
		+ "  \"turns\": %d,\n" % SCENARIO_TURNS
		+ "  \"commands\": %d,\n" % COMMAND_COUNT
		+ "  \"command_log\": \"%s\",\n" % COMMAND_LOG_SHAPE
		+ "  \"content_hash\": \"%s\"\n" % observed
		+ "}"
	)


## An integral JSON number as an int. Godot parses every JSON number as TYPE_FLOAT, so this also
## asserts the value has no fractional part rather than truncating it (M0-T2 item 8).
func _integral(value: Variant) -> int:
	var number: float = 0.0
	if value is float:
		number = value
	elif value is int:
		number = float(value)
	else:
		assert_true(false, "§13.2 tier 3: expected a JSON number, got %s" % [value])
		return -1
	var truncated: int = int(number)
	assert_eq(number, float(truncated), "M0-T2 item 8: %s must be an integral JSON number" % [value])
	return truncated
