## Fnv — GDD §11.1 (binding determinism contract: "**GameState.hash()** (FNV over canonical
## serialization) must be reproducible"), §11.2 (`scripts/core/` holds the pure, unit-tested
## algorithm helpers), §11.3 (coding conventions), §13.2 tier 1, §13.6.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md` §11.1 (line 707):
##   "**Determinism rules:** iterate collections in stable ID order; no float accumulation in
##    rules (integers + fixed percent math, round-half-up at final step); no wall-clock or
##    frame-time inputs. GameState.hash() (FNV over canonical serialization) must be
##    reproducible."
##   (line 708) "**Save/load & replay:** ... replaying (seed, command_log) must reproduce the
##    hash."
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §11.1**. The binding prior resolution is M1-T5 **(U)** — `HexMap.content_hash()` is FNV-1a
## 32-bit with basis 2166136261, prime 16777619 and **every** step masked `& 0xffffffff`, named
## `content_hash` and never `hash` because overriding `Object.hash()` trips
## `native_method_override` (level 2 = a hard error under the live M0-T4 gate). §11.1 names the
## algorithm family but legislates no API, so `Fnv`'s surface is a §13.4 resolution, lettered
## **(AU)** (M1-T9 ended the lettering at (AT)); it is recorded by the Land stage.
##
## THE ORACLE IS EXTERNAL, WHICH IS THE WHOLE POINT. The expected values below are the published
## FNV-1a **32-bit** test vectors (the reference `test_fnv` table), not values this project
## measured from its own implementation. A hash suite that only checks self-consistency ("the
## same input hashes the same twice") passes for `return 0`; these twelve vectors are what
## actually proves the algorithm is FNV-1a and not FNV-1, not a different basis, not a 64-bit
## fold, and not an unmasked int64 multiply. They were re-derived independently at the Tests
## stage and agreed with the published table on all twelve entries.
##
## DELIBERATE DUPLICATION, RECORDED NOT FIXED: `scripts/sim/hex_map.gd` keeps its own PRIVATE
## `_fold_int`/`_fold_bytes`/`_fold_byte` (M1-T5 (U)). This task does **not** retrofit `Fnv` into
## it — `tests/golden/mapgen_concentric_bowl_small_seed1337.json` (`content_hash 0xcad24923`) is
## a §13.6 golden and must stay byte-untouched and green. Note `hex_map.gd` folds ints as **4**
## little-endian bytes while `Fnv.fold_int64` folds **8**: they are different helpers on purpose,
## and a later opportunistic task may collapse them with the golden as its proof.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/core/fnv.gd`. They are per-file
## and inherit NOTHING from `test_rng.gd`, `test_hex_map.gd` or `test_map_generator.gd`.
extends GutTest

const FNV_PATH: String = "res://scripts/core/fnv.gd"

## The published FNV-1a 32-bit parameters. Transcribed here independently of the implementation,
## so a drifted basis or prime fails against this file rather than against itself.
const EXPECTED_OFFSET_BASIS: int = 2166136261
const EXPECTED_PRIME: int = 16777619
const EXPECTED_MASK: int = 0xffffffff

## The published FNV-1a 32-bit test vectors, folded as UTF-8 starting from the offset basis.
## VECTOR_INPUTS[i] hashes to VECTOR_HASHES[i]. Kept as two parallel typed arrays rather than a
## Dictionary so every element stays statically typed (§11.3).
const VECTOR_INPUTS: Array[String] = [
	"",
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"fo",
	"foo",
	"foob",
	"fooba",
	"foobar",
]
const VECTOR_HASHES: Array[int] = [
	0x811c9dc5,
	0xe40c292c,
	0xe70c2de5,
	0xe60c2c52,
	0xe10c2473,
	0xe00c22e0,
	0xe30c2799,
	0x6222e842,
	0xa9f37ed7,
	0x3f5076ef,
	0x39aaa18a,
	0xbf9cf968,
]

## 2^32. Two int64 values that agree in their low 32 bits — a 4-byte fold collides on them, an
## 8-byte fold does not. This is the pin that keeps stockpiles honest at §5.1's "No storage caps".
const OVER_32: int = 4294967296

## Bytes per int64 fold (little-endian), per resolution (AU).
const INT64_BYTES: int = 8

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is on the
## list: M1-T5 item 6 made `scripts/core/rng.gd` its single home in the whole project, and every
## new core/sim file inherits that ban.
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
]

## §4.1's radii and hex counts are tunable content in data/mapgen/*.json — never in core code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface of Fnv. All four are `static`: Fnv is a namespace for a
## pure algorithm, never an object with state. An extra `fold_vector`, `hash_of` or a 64-bit
## variant would invent API ahead of the milestone that needs it (§13.4).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"fold_byte",
	"fold_int64",
	"fold_bytes",
	"fold_string",
]

## The COMPLETE public constant surface. Anything else an implementation needs (a byte count, a
## shift width) stays private.
const REQUIRED_PUBLIC_CONSTS: Array[String] = ["OFFSET_BASIS", "PRIME", "MASK"]

## The COMPLETE public FIELD surface: none. Fnv holds no state at all.
const REQUIRED_PUBLIC_VARS: Array[String] = []

## Doc-comment sections accepted by the S5 scan for this file (§11.3 "public rule functions
## documented with the GDD section they implement").
const DOC_SECTIONS: Array[String] = ["§11.1"]


# =============================================================================================
# A. THE ALGORITHM PARAMETERS (§11.1 "FNV over canonical serialization")
# =============================================================================================

## §11.1 / (AU) — the three FNV-1a 32-bit parameters, against the published values. A drifted
## basis or prime still produces a "reproducible" hash, so only an external transcription can
## catch it; the mask is what makes the fold 32-bit rather than an int64 overflow accident.
func test_algorithm_constants_are_the_published_fnv_1a_32_bit_parameters() -> void:
	assert_eq(Fnv.OFFSET_BASIS, EXPECTED_OFFSET_BASIS, "§11.1: FNV-1a 32-bit offset basis")
	assert_eq(Fnv.PRIME, EXPECTED_PRIME, "§11.1: FNV-1a 32-bit prime")
	assert_eq(Fnv.MASK, EXPECTED_MASK, "§11.1: the fold is masked to 32 bits after every step")


## (U)/(AU) — the shared helper must carry the SAME parameters M1-T5 already froze into
## `scripts/sim/hex_map.gd`, otherwise "one FNV for the project" is a fiction and the deliberate
## duplication recorded in this file's header becomes a silent divergence.
func test_algorithm_constants_agree_with_the_landed_hex_map_constants() -> void:
	assert_eq(Fnv.OFFSET_BASIS, HexMap.FNV_OFFSET_BASIS, "(U): one basis for the whole project")
	assert_eq(Fnv.PRIME, HexMap.FNV_PRIME, "(U): one prime for the whole project")
	assert_eq(Fnv.MASK, HexMap.FNV_MASK, "(U): one 32-bit mask for the whole project")


# =============================================================================================
# B. THE PUBLISHED TEST VECTORS — the external oracle
# =============================================================================================

## §11.1 — the twelve published FNV-1a 32-bit vectors, folded as UTF-8 from the offset basis.
## This is what proves the algorithm; every other test in this file only proves it is used
## consistently.
func test_fold_string_matches_the_published_fnv_1a_test_vectors() -> void:
	assert_eq(
		VECTOR_INPUTS.size(),
		VECTOR_HASHES.size(),
		"sanity: the vector table is a pair of parallel arrays"
	)
	var mismatches: Array[String] = []
	for i: int in range(VECTOR_INPUTS.size()):
		var text: String = VECTOR_INPUTS[i]
		var observed: int = Fnv.fold_string(EXPECTED_OFFSET_BASIS, text)
		if observed != VECTOR_HASHES[i]:
			mismatches.append(
				"\"%s\" -> 0x%08x, published 0x%08x" % [text, observed, VECTOR_HASHES[i]]
			)
	assert_eq(
		mismatches.size(),
		0,
		"§11.1: fold_string must reproduce the published FNV-1a 32-bit vectors; %s" % [
			str(mismatches)
		]
	)


## §11.1 — the empty string folds to the offset basis itself (the published `""` vector). An
## implementation that seeded a length prefix, or that folded a terminator, fails here.
func test_the_empty_string_is_the_identity_fold() -> void:
	assert_eq(
		Fnv.fold_string(EXPECTED_OFFSET_BASIS, ""),
		EXPECTED_OFFSET_BASIS,
		"§11.1: folding no bytes must leave the accumulator alone (published \"\" vector)"
	)


## (AU) — the fold is INCREMENTAL: folding "foo" then "bar" equals folding "foobar" in one go.
## That composability is what lets GameState/PlayerState thread one accumulator through a whole
## canonical serialization instead of building a giant intermediate buffer.
func test_folding_is_incremental() -> void:
	var split: int = Fnv.fold_string(Fnv.fold_string(EXPECTED_OFFSET_BASIS, "foo"), "bar")
	assert_eq(
		split,
		Fnv.fold_string(EXPECTED_OFFSET_BASIS, "foobar"),
		"(AU): fold(fold(h, \"foo\"), \"bar\") must equal fold(h, \"foobar\")"
	)


## §11.1 — order matters. A fold that summed or xor'd its bytes commutatively would make
## "canonical serialization" meaningless: two different states could collide by permutation.
func test_folding_is_order_sensitive() -> void:
	assert_ne(
		Fnv.fold_string(EXPECTED_OFFSET_BASIS, "ab"),
		Fnv.fold_string(EXPECTED_OFFSET_BASIS, "ba"),
		"§11.1: a canonical serialization must not be permutation-invariant"
	)


## (AU) — fold_string is exactly fold_bytes over the string's UTF-8 buffer, including for
## multi-byte code points. The `to_utf8_buffer()` encoding is the one M1-T5 (U) already froze for
## terrain-type ids, so resource ids fold the same way.
func test_fold_string_is_fold_bytes_over_the_utf8_buffer() -> void:
	var samples: Array[String] = ["", "a", "foobar", "magestone", "Ünterwars", "§11.1"]
	var mismatches: Array[String] = []
	for text: String in samples:
		var via_string: int = Fnv.fold_string(EXPECTED_OFFSET_BASIS, text)
		var via_bytes: int = Fnv.fold_bytes(EXPECTED_OFFSET_BASIS, text.to_utf8_buffer())
		if via_string != via_bytes:
			mismatches.append("\"%s\": 0x%08x vs 0x%08x" % [text, via_string, via_bytes])
	assert_eq(
		mismatches.size(),
		0,
		"(AU): fold_string(h, s) == fold_bytes(h, s.to_utf8_buffer()); %s" % [str(mismatches)]
	)


# =============================================================================================
# C. fold_bytes / fold_byte
# =============================================================================================

## (AU) — fold_bytes is exactly the per-byte fold applied left to right. Pinning it this way is
## what lets the state classes mix buffers and single separator bytes in one accumulator.
func test_fold_bytes_equals_folding_one_byte_at_a_time() -> void:
	var data: PackedByteArray = PackedByteArray([0, 1, 2, 31, 127, 128, 200, 255])
	var stepwise: int = EXPECTED_OFFSET_BASIS
	for byte_value: int in data:
		stepwise = Fnv.fold_byte(stepwise, byte_value)
	assert_eq(
		Fnv.fold_bytes(EXPECTED_OFFSET_BASIS, data),
		stepwise,
		"(AU): fold_bytes must be the left-to-right composition of fold_byte"
	)


## (AU) — an empty buffer is the identity, so "this field is absent" and "this field is empty"
## are the same fold only when the caller folds no separator. GameState/PlayerState rely on it.
func test_fold_bytes_over_an_empty_buffer_is_the_identity() -> void:
	assert_eq(
		Fnv.fold_bytes(EXPECTED_OFFSET_BASIS, PackedByteArray()),
		EXPECTED_OFFSET_BASIS,
		"(AU): folding zero bytes must leave the accumulator alone"
	)


## §11.1 — a single fold step actually changes the accumulator, and different byte values give
## different results. A `fold_byte` that ignored its argument would keep every other test in this
## file green except the vector table.
func test_fold_byte_distinguishes_byte_values() -> void:
	var zero: int = Fnv.fold_byte(EXPECTED_OFFSET_BASIS, 0)
	var one: int = Fnv.fold_byte(EXPECTED_OFFSET_BASIS, 1)
	var high: int = Fnv.fold_byte(EXPECTED_OFFSET_BASIS, 255)
	assert_ne(zero, EXPECTED_OFFSET_BASIS, "§11.1: folding a byte must move the accumulator")
	assert_ne(zero, one, "§11.1: distinct bytes must fold distinctly")
	assert_ne(one, high, "§11.1: distinct bytes must fold distinctly")


# =============================================================================================
# D. fold_int64 — EIGHT little-endian bytes (the "No storage caps" pin, §5.1)
# =============================================================================================

## (AU) — an int is folded as EIGHT little-endian bytes. §5.1 says "No storage caps", so a
## stockpile is an honest 64-bit integer; a 4-byte fold (the shape `hex_map.gd` uses for its
## 0..3 elevations) would make two amounts differing only above 2^32 hash identically.
func test_fold_int64_folds_eight_little_endian_bytes() -> void:
	var samples: Array[int] = [0, 1, 255, 256, 1000000, OVER_32, OVER_32 + 1, -1, -2]
	var mismatches: Array[String] = []
	for value: int in samples:
		var expected: int = Fnv.fold_bytes(EXPECTED_OFFSET_BASIS, _little_endian_64(value))
		var observed: int = Fnv.fold_int64(EXPECTED_OFFSET_BASIS, value)
		if observed != expected:
			mismatches.append("%d: 0x%08x vs 0x%08x" % [value, observed, expected])
	assert_eq(
		mismatches.size(),
		0,
		"(AU): fold_int64 must fold %d little-endian bytes; %s" % [INT64_BYTES, str(mismatches)]
	)


## §5.1 "No storage caps" + (AU) — THE pin a 4-byte fold cannot survive: two values that agree in
## their low 32 bits must hash differently.
func test_fold_int64_separates_values_that_differ_only_above_thirty_two_bits() -> void:
	assert_ne(
		Fnv.fold_int64(EXPECTED_OFFSET_BASIS, 1),
		Fnv.fold_int64(EXPECTED_OFFSET_BASIS, 1 + OVER_32),
		"§5.1: 1 and 1 + 2^32 are different stockpiles and must fold differently"
	)
	assert_ne(
		Fnv.fold_int64(EXPECTED_OFFSET_BASIS, 0),
		Fnv.fold_int64(EXPECTED_OFFSET_BASIS, OVER_32),
		"§5.1: 0 and 2^32 are different stockpiles and must fold differently"
	)


## (AU) — folding an int moves the accumulator and distinguishes neighbouring values; the fold is
## injective enough that 0 and 1 never collide.
func test_fold_int64_distinguishes_neighbouring_values() -> void:
	var zero: int = Fnv.fold_int64(EXPECTED_OFFSET_BASIS, 0)
	assert_ne(zero, EXPECTED_OFFSET_BASIS, "(AU): folding an int must move the accumulator")
	assert_ne(
		zero,
		Fnv.fold_int64(EXPECTED_OFFSET_BASIS, 1),
		"(AU): 0 and 1 must fold to different accumulators"
	)


# =============================================================================================
# E. THE 32-BIT INVARIANT (§11.1 "no float accumulation", masked after every multiply)
# =============================================================================================

## §11.1 — EVERY fold result is a 32-bit unsigned value. An unmasked multiply relies on int64
## overflow, which is neither 32-bit nor portable, and would put values outside this range into a
## golden. Swept over every entry point and a spread of inputs, including negatives.
func test_every_fold_result_stays_within_thirty_two_bits() -> void:
	var accumulators: Array[int] = [EXPECTED_OFFSET_BASIS, 0, 1, EXPECTED_MASK]
	var offenders: Array[String] = []
	for start: int in accumulators:
		for value: int in [0, 1, 255, 65535, OVER_32, -1]:
			_require_in_32_bits(Fnv.fold_int64(start, value), "fold_int64", offenders)
		for byte_value: int in [0, 1, 127, 255]:
			_require_in_32_bits(Fnv.fold_byte(start, byte_value), "fold_byte", offenders)
		for text: String in VECTOR_INPUTS:
			_require_in_32_bits(Fnv.fold_string(start, text), "fold_string", offenders)
		_require_in_32_bits(
			Fnv.fold_bytes(start, PackedByteArray([1, 2, 3])), "fold_bytes", offenders
		)
	assert_eq(
		offenders.size(),
		0,
		"§11.1: every fold is masked to 32 bits; out of range: %s" % [str(offenders.slice(0, 8))]
	)


## §11.1 — a long chain stays in range too: 4,096 successive folds must never drift out of 32
## bits (an unmasked multiply escapes within a handful of steps).
func test_a_long_fold_chain_stays_within_thirty_two_bits() -> void:
	var accumulator: int = EXPECTED_OFFSET_BASIS
	var offenders: Array[String] = []
	for i: int in range(4096):
		accumulator = Fnv.fold_int64(accumulator, i)
		_require_in_32_bits(accumulator, "chain step %d" % i, offenders)
	assert_eq(
		offenders.size(),
		0,
		"§11.1: a long fold chain stays 32-bit; out of range: %s" % [str(offenders.slice(0, 4))]
	)


## §11.1 — the fold is a PURE function: the same inputs give the same output every time and
## nothing accumulates between calls (no static state, no wall clock).
func test_folding_is_pure_and_repeatable() -> void:
	for i: int in range(VECTOR_INPUTS.size()):
		var text: String = VECTOR_INPUTS[i]
		assert_eq(
			Fnv.fold_string(EXPECTED_OFFSET_BASIS, text),
			Fnv.fold_string(EXPECTED_OFFSET_BASIS, text),
			"§11.1: folding \"%s\" twice must give the same answer" % text
		)


# =============================================================================================
# F. MECHANICAL SOURCE SCANS ON scripts/core/fnv.gd (§11.1, §11.2, §11.3, §13.6)
#    Written FRESH for this file — a new file inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)". Comment stripping
## is LOAD-BEARING: the doc block above cites "§11.1", which the `\.[0-9]` pattern would hit.
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(FNV_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % FNV_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			FNV_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % FNV_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" — engine-free source. The
## `RandomNumberGenerator` ban is M1-T5 item 6's negative-token rule, inherited by every new
## core/sim file: `scripts/core/rng.gd` is its single home in the project.
func test_source_is_engine_free() -> void:
	var code: String = _code_text(FNV_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % FNV_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim core must be engine-free — %s contains %s" % [FNV_PATH, banned]
		)


## S3 §4.4 line 238 / §13.6 — map sizes are tunable content in data/mapgen/*.json. A hash helper
## has no business naming one. `integer_division` is included because no fold divides anything:
## an `@warning_ignore("integer_division")` here would mean a rounding step crept in (M0-T4 (d)).
func test_source_carries_no_map_size_constant_and_no_division() -> void:
	var code: String = _code_text(FNV_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % FNV_PATH)
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
			FNV_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): a fold divides nothing — %s must not suppress that warning" % FNV_PATH
	)


## S4 §13.4 — this file loads no document, so it must not grow a second loader; and it must not
## override `Object.hash()` (M1-T5 (U): `native_method_override` is level 2 = an error).
func test_source_declares_no_loader_and_never_overrides_object_hash() -> void:
	var code: String = _code_text(FNV_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % FNV_PATH)
	assert_false(
		code.contains("RulesError"),
		"§13.4: %s loads no document and must not carry a loader" % FNV_PATH
	)
	assert_false(
		code.contains("func hash("),
		"(U)/M0-T4: overriding Object.hash() trips native_method_override — %s must not" % FNV_PATH
	)


## S5 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member fails too. All four functions must be
## `static`: Fnv is a namespace for a pure algorithm, never an object with state, so it also
## declares NO public vars and NO `_init`.
func test_public_api_is_exactly_the_four_static_folds_and_three_constants() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	var non_static: Array[String] = []
	_collect_public_functions(FNV_PATH, public_functions, undocumented, non_static)

	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, FNV_PATH]
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			FNV_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		non_static.size(),
		0,
		"(AU): every fold is `static func` — instance methods found: %s" % [str(non_static)]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); absent on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_consts(FNV_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.4: the public constant surface of %s is exactly %s" % [
			FNV_PATH, str(REQUIRED_PUBLIC_CONSTS)
		]
	)
	assert_eq(
		_collect_public_vars(FNV_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: Fnv holds no state — its public FIELD surface is empty"
	)
	assert_false(
		_code_text(FNV_PATH).contains("func _init("),
		"(AU): Fnv is a static namespace and is never instantiated — it declares no _init"
	)


## S6 §11.1/§11.2 — Fnv is a pure [RefCounted] living in `scripts/core/`, §11.2's own directory
## for the pure unit-tested helpers. Asserted through get_class() — `is Node` is a PARSE ERROR
## here (M0-T2 item 11 / M0-T5 item (a)).
func test_fnv_is_a_pure_refcounted_in_scripts_core() -> void:
	assert_true(FileAccess.file_exists(FNV_PATH), "§11.2: Fnv lives at %s" % FNV_PATH)
	var instance: Fnv = Fnv.new()
	assert_eq(instance.get_class(), "RefCounted", "§11.1: Fnv must be a pure RefCounted")


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## The eight little-endian bytes of a 64-bit integer — the test side's own transcription of
## resolution (AU)'s byte order, so the implementation is compared against a stated convention
## rather than against itself.
func _little_endian_64(value: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for i: int in range(INT64_BYTES):
		out.append((value >> (8 * i)) & 0xff)
	return out


## Records `label` in `offenders` unless `value` is a 32-bit unsigned integer.
func _require_in_32_bits(value: int, label: String, offenders: Array[String]) -> void:
	if value < 0 or value > EXPECTED_MASK:
		offenders.append("%s -> %d" % [label, value])


## Walks a source file and fills `public_functions` with every public function name (in source
## order), `undocumented` with those whose preceding comment block cites no DOC_SECTIONS entry,
## and `non_static` with those not declared `static func`.
func _collect_public_functions(
	path: String,
	public_functions: Array[String],
	undocumented: Array[String],
	non_static: Array[String]
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
		if not stripped.begins_with("static func "):
			non_static.append(function_name)
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


## Every top-level public `const` declared by a source file, in source order.
func _collect_public_consts(path: String) -> Array[String]:
	return _collect_declarations(path, "const ")


## Every top-level public `var` declared by a source file, in source order.
func _collect_public_vars(path: String) -> Array[String]:
	return _collect_declarations(path, "var ")


## Shared body of the two declaration scanners: names declared at column 0 with `keyword `,
## excluding `_`-prefixed (private) ones.
func _collect_declarations(path: String, keyword: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with(keyword):
			continue
		var rest: String = raw_line.substr(keyword.length())
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
