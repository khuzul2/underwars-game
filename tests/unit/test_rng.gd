## Rng — GDD §11.1 (binding determinism contract), §11.2 (`scripts/core/` lists `Rng` among the
## pure, unit-tested core classes), §11.3, §13.2 tier 1 ("every core/ function"), §13.6, §14 M1.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md` §11.1 (line 704):
##   "**GameState**: single serializable object — ... and **one** **RandomNumberGenerator**
##    **seeded at match start** (the only RNG in the program; every roll goes through state.rng)."
##   (line 703) "No Node, no Scene Tree, no engine singletons, no rendering, no **randi()** — the
##    core must run headless byte-identically."
##   (line 707) "**Determinism rules:** iterate collections in stable ID order; no float
##    accumulation in rules (integers + fixed percent math, round-half-up at final step); no
##    wall-clock or frame-time inputs."
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §11.1**, so the printed text above governs unamended. §11.1 gives no roll API at all, so the
## surface below is a §13.4 resolution — continued as **(R)** after M1-T4's (Q):
##   (R) `Rng` is the single home of the engine [RandomNumberGenerator]. `_init(seed_value)` sets
##       the engine object's `seed` EXPLICITLY (a default-constructed RandomNumberGenerator is
##       RANDOMLY seeded, so omitting that assignment makes two `Rng.new(1337)` diverge — the
##       behavioural pin below is what catches it, not a source scan). The public surface is
##       EXACTLY `roll_percent()` (an integer 1..100 inclusive, drawn via `randi_range(1, 100)`
##       so no float ever enters a rule) and `rolls_drawn()` (the stream position, which is what
##       lets the generator prove "exactly one roll per hex, in canonical order").
##
## §13.6 clauses that are VACUOUS here, stated rather than assumed: this class reads **zero**
## §12.1 constants (a percent roll is 1..100 by definition of "percent", not a tunable), mutates
## no GameState and touches no EventBus, so "constants read from data" and "events emitted for
## every state change" have no subject matter. Goldens: this file records none — the project's
## first golden is `tests/golden/test_mapgen_golden.gd`.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Non-Node-ness is asserted via get_class() ONLY.
##
## The five source scans below are written FRESH for `scripts/core/rng.gd`. They are per-file and
## inherit NOTHING from `test_hex_math.gd`, `test_los.gd`, `test_hex_map.gd` or
## `test_map_generator.gd`.
extends GutTest

const RNG_PATH: String = "res://scripts/core/rng.gd"

## §12.6's example seed, so the golden's seed and this file's seed come from the GDD rather than
## from invention.
const GOLDEN_SEED: int = 1337
const OTHER_SEED: int = 1338

## A percent roll is an integer in 1..100 INCLUSIVE (§11.1 "fixed percent math").
const MIN_ROLL: int = 1
const MAX_ROLL: int = 100

## Sample sizes. 10,000 rolls make "every value 1..100 is reachable" overwhelming (the chance a
## given value is missed is 0.99^10000 ~ 2e-44), so this sweep cannot flake.
const COVERAGE_ROLLS: int = 10000
const SEQUENCE_ROLLS: int = 200

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is the ONE
## sanctioned exception and ONLY in this file (M1-T5 resolution (R)); `randi(`, `randf(` and
## `randomize(` stay forbidden even here, because the seeded integer path is the whole point.
const ENGINE_BOUND_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"extends Node",
	"SceneTree",
	"get_tree",
	"Engine.",
	"Time.",
	"OS.",
]

## §4.1's radii and hex counts are tunable content in data/mapgen/*.json — never in core code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface of Rng. Exactly these two — an extra `roll_range`,
## `shuffle` or `seed()` accessor would invent API ahead of the milestone that needs it (§13.4).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["roll_percent", "rolls_drawn"]

## The COMPLETE public FIELD surface: none. The engine object and the counter are both private,
## so no caller can reach past the two functions and desynchronise the stream.
const REQUIRED_PUBLIC_VARS: Array[String] = []

## Doc-comment sections accepted by scan S4 for this file (§11.3 "public rule functions
## documented with the GDD section they implement").
const DOC_SECTIONS: Array[String] = ["§11.1", "§11.2"]


# =============================================================================================
# A. THE SEEDED STREAM (§11.1 "one RandomNumberGenerator seeded at match start")
# =============================================================================================

## §11.1 — THE pin that catches a forgotten `_rng.seed = seed_value`: a default-constructed
## RandomNumberGenerator is RANDOMLY seeded, so two `Rng.new(1337)` would diverge almost surely.
## Compared over 200 consecutive rolls, as whole arrays.
func test_two_generators_with_the_same_seed_produce_identical_sequences() -> void:
	var first: Array[int] = _sequence(Rng.new(GOLDEN_SEED), SEQUENCE_ROLLS)
	var second: Array[int] = _sequence(Rng.new(GOLDEN_SEED), SEQUENCE_ROLLS)
	assert_eq(first.size(), SEQUENCE_ROLLS, "sanity: the sample is complete")
	assert_eq(
		first,
		second,
		"§11.1: two Rng.new(%d) must produce byte-identical roll streams" % GOLDEN_SEED
	)


## §11.1 — a different seed is a different stream, which is what makes "seed => terrain hash" a
## meaningful golden at all. Compared over 200 rolls: two independent streams agreeing everywhere
## would mean the seed is being ignored.
func test_a_different_seed_produces_a_different_sequence() -> void:
	var first: Array[int] = _sequence(Rng.new(GOLDEN_SEED), SEQUENCE_ROLLS)
	var other: Array[int] = _sequence(Rng.new(OTHER_SEED), SEQUENCE_ROLLS)
	assert_ne(
		first,
		other,
		"§11.1: seeds %d and %d must not produce the same stream" % [GOLDEN_SEED, OTHER_SEED]
	)


## §11.1 — the stream is a function of the seed ALONE, not of construction order or of how many
## other Rng objects exist: a generator built after another one has drawn 200 rolls still
## reproduces the same sequence from its own seed.
func test_streams_are_independent_of_construction_order() -> void:
	var expected: Array[int] = _sequence(Rng.new(GOLDEN_SEED), SEQUENCE_ROLLS)
	var noise: Rng = Rng.new(OTHER_SEED)
	var drained: Array[int] = _sequence(noise, SEQUENCE_ROLLS)
	assert_eq(drained.size(), SEQUENCE_ROLLS, "sanity: the noise stream was actually drawn")
	var late: Array[int] = _sequence(Rng.new(GOLDEN_SEED), SEQUENCE_ROLLS)
	assert_eq(late, expected, "§11.1: a stream depends on its seed alone")


# =============================================================================================
# B. THE PERCENT ROLL (§11.1 "integers + fixed percent math")
# =============================================================================================

## §11.1 — every roll is an integer in 1..100 INCLUSIVE, and every value in that range is
## reachable. Both bounds matter: `randi() % 100` yields 0..99 (never 100) and `randi_range(0,
## 100)` yields 101 distinct values; either would silently skew every composition table.
func test_every_roll_is_an_integer_between_one_and_one_hundred_inclusive() -> void:
	var rng: Rng = Rng.new(GOLDEN_SEED)
	var seen: Dictionary = {}
	var out_of_range: Array[String] = []
	for i: int in range(COVERAGE_ROLLS):
		var roll: int = rng.roll_percent()
		if roll < MIN_ROLL or roll > MAX_ROLL:
			out_of_range.append("roll %d -> %d" % [i, roll])
		seen[roll] = true
	assert_eq(out_of_range.size(), 0, "§11.1: every percent roll is 1..100; %s" % [
		str(out_of_range.slice(0, 5))
	])
	var missing: Array[int] = []
	for value: int in range(MIN_ROLL, MAX_ROLL + 1):
		if not seen.has(value):
			missing.append(value)
	assert_eq(
		missing.size(),
		0,
		"§11.1: every value 1..100 must be reachable over %d rolls; missing %s" % [
			COVERAGE_ROLLS, str(missing.slice(0, 10))
		]
	)
	assert_eq(seen.size(), MAX_ROLL, "§11.1: a percent roll takes exactly 100 distinct values")


## §11.1 — a percent roll is not a constant. A stub or a mis-wired seed that answers one value
## forever would satisfy "in range" and "deterministic" but destroy every composition table.
func test_rolls_actually_vary() -> void:
	var rng: Rng = Rng.new(GOLDEN_SEED)
	var rolls: Array[int] = _sequence(rng, SEQUENCE_ROLLS)
	var distinct: Dictionary = {}
	for roll: int in rolls:
		distinct[roll] = true
	assert_true(
		distinct.size() > 10,
		"§11.1: %d rolls must not collapse onto %d value(s)" % [SEQUENCE_ROLLS, distinct.size()]
	)


# =============================================================================================
# C. STREAM ACCOUNTING (what lets the generator prove "exactly one roll per hex")
# =============================================================================================

## (R) — `rolls_drawn()` starts at 0 and increments by EXACTLY one per `roll_percent()`. The
## generator's "one roll per hex, always drawn" property is measured through this counter, so a
## counter that lags, double-counts or is never incremented would make that proof vacuous.
func test_rolls_drawn_counts_exactly_one_per_roll() -> void:
	var rng: Rng = Rng.new(GOLDEN_SEED)
	assert_eq(rng.rolls_drawn(), 0, "(R): a fresh Rng has drawn nothing")
	var mismatches: Array[String] = []
	for i: int in range(SEQUENCE_ROLLS):
		var roll: int = rng.roll_percent()
		if roll < MIN_ROLL:
			mismatches.append("roll %d was not drawn" % i)
		if rng.rolls_drawn() != i + 1:
			mismatches.append("after %d rolls the counter reads %d" % [i + 1, rng.rolls_drawn()])
	assert_eq(mismatches.size(), 0, "(R): rolls_drawn() increments once per roll; %s" % [
		str(mismatches.slice(0, 5))
	])
	assert_eq(rng.rolls_drawn(), SEQUENCE_ROLLS, "(R): the final stream position")


## (R) — `rolls_drawn()` is a pure observer: reading it never advances the stream.
func test_reading_the_counter_does_not_advance_the_stream() -> void:
	var quiet: Rng = Rng.new(GOLDEN_SEED)
	var noisy: Rng = Rng.new(GOLDEN_SEED)
	var expected: Array[int] = []
	var observed: Array[int] = []
	var counter_breaks: Array[String] = []
	for i: int in range(SEQUENCE_ROLLS):
		expected.append(quiet.roll_percent())
		if noisy.rolls_drawn() != i:
			counter_breaks.append("before roll %d the counter read %d" % [i, noisy.rolls_drawn()])
		observed.append(noisy.roll_percent())
	assert_eq(counter_breaks.size(), 0, "(R): reading the counter leaves it alone; %s" % [
		str(counter_breaks.slice(0, 3))
	])
	assert_eq(observed, expected, "(R): rolls_drawn() must not consume the stream")


## §11.1 — two Rng instances share no state. A `static`/`const` engine object would make the
## whole sim non-deterministic the moment two matches (or two maps) exist — the M1-T2 trap-1
## family, re-pinned in its fifth file.
func test_two_instances_share_no_state() -> void:
	var first: Rng = Rng.new(GOLDEN_SEED)
	var second: Rng = Rng.new(GOLDEN_SEED)
	var drained: Array[int] = _sequence(first, SEQUENCE_ROLLS)
	assert_eq(drained.size(), SEQUENCE_ROLLS, "sanity: the first stream was drawn")
	assert_eq(second.rolls_drawn(), 0, "§11.1: drawing from one Rng must not advance another")
	assert_eq(
		_sequence(second, SEQUENCE_ROLLS),
		drained,
		"§11.1: a second Rng on the same seed reproduces the sequence from its own start"
	)


# =============================================================================================
# D. MECHANICAL SOURCE SCANS ON scripts/core/rng.gd (§11.1, §11.2, §11.3, §13.6)
#    Written FRESH for this file — a new file inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)". The percent roll is
## `randi_range(1, 100)`, an integer path; `randf()`/`randf_range()` would put a float in the
## middle of every rule that rolls. Comment stripping is LOAD-BEARING: the doc block contains
## "§11.1", which the `\.[0-9]` pattern would otherwise hit.
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(RNG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RNG_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			RNG_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % RNG_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"§11.1: a percent roll needs no division — %s must not suppress that warning" % RNG_PATH
	)


## S2 §11.1 "the core must run headless byte-identically". `RandomNumberGenerator` is the ONE
## sanctioned engine type in the project and it is sanctioned HERE ONLY (resolution (R)) — so this
## file must actually contain it, while `randi(`, `randf(`, `randomize(` and every Node/singleton
## token stay forbidden. `tests/unit/test_map_generator.gd` carries the mirror image of this rule:
## the generator must NEVER name RandomNumberGenerator, it receives an Rng.
func test_source_is_engine_free_except_the_sanctioned_seeded_generator() -> void:
	var code: String = _code_text(RNG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RNG_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim core must be engine-free — %s contains %s" % [RNG_PATH, banned]
		)
	assert_true(
		code.contains("RandomNumberGenerator"),
		"(R)/§11.1: %s is the single home of the one seeded RandomNumberGenerator" % RNG_PATH
	)
	assert_true(
		code.contains("randi_range("),
		"§11.1: the percent roll takes the INTEGER path — %s must call randi_range(" % RNG_PATH
	)


## S3 §4.4 line 238 / §13.6 — map sizes are tunable content in data/mapgen/*.json. Nothing in
## core may re-type one, and a roll bound is not a map size (100 is not in the pattern).
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(RNG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RNG_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"),
		OK,
		"sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(
		hit,
		"§4.4/§13.6: map sizes live in data/mapgen/*.json — %s must not hard-code %s" % [
			RNG_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S4 §11.3 "public rule functions documented with the GDD section they implement", tightened the
## M1-T2 item 11 / M1-T3 item 13 way: the expected public surface is listed EXPLICITLY, so a
## MISSING member fails instead of passing vacuously and an EXTRA member (a float roll, a shuffle,
## a seed accessor) fails too.
func test_public_api_is_exactly_the_two_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(RNG_PATH, public_functions, undocumented)

	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2/§11.1: %s must be a public function of %s" % [required, RNG_PATH]
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			RNG_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §11.1'/'## §11.2' doc comment; missing on: %s" % [
			str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(RNG_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public field surface of %s is exactly %s (the engine object stays private)" % [
			RNG_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)


## S5 §11.1 "pure GDScript RefCounted classes ... No Node, no Scene Tree" + §11.2 (`Rng` is named
## in the `scripts/core/` list). Asserted through get_class() — `is Node` is a PARSE ERROR here.
func test_rng_is_a_pure_refcounted_in_scripts_core() -> void:
	assert_true(FileAccess.file_exists(RNG_PATH), "§11.2: Rng lives at %s" % RNG_PATH)
	var instance: Rng = Rng.new(GOLDEN_SEED)
	assert_eq(instance.get_class(), "RefCounted", "§11.1: Rng must be a pure RefCounted")


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## `count` consecutive rolls from `rng`, as a typed array.
func _sequence(rng: Rng, count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(count):
		out.append(rng.roll_percent())
	return out


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


## Every top-level public `var` declared by a source file, in source order, so an EXTRA public
## field fails the scan.
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
