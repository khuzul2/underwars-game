## THE PROJECT'S FIRST GOLDEN — GDD §14 M1 acceptance criterion (a): "**Golden mapgen test
## (seed => terrain hash)**"; §13.2 tier 3 ("fixed seed + recorded command log => recorded
## GameState.hash() after N turns. Any rules change that legitimately alters the hash must
## re-record goldens **in the same commit** with a docs/decisions.md entry"); §13.6 ("goldens
## re-recorded only with a logged reason"); §11.1 ("GameState.hash() (FNV over canonical
## serialization) must be reproducible"); §4.1, §4.2, §4.4, §12.6.
##
## WHAT IS RECORDED, and why each field is GDD-sourced rather than invented:
##   generator "mapgen/concentric_bowl.json" — §12.6's own `"generator"` value (line 980).
##   size_id   "small", radius 24, hex_count 1801 — §4.1 line 174, "Small 24 (1,801 hexes)".
##   seed      1337 — §12.6's example scenario carries `"seed": 1337`.
##   content_hash — `HexMap.content_hash()` rendered as `"0x%08x"`, a lowercase 8-hex-digit
##                  STRING and never a JSON number, because Godot 4.7 parses EVERY JSON number as
##                  TYPE_FLOAT (decisions.md M0-T2 item 8) and a 32-bit hash would round.
##
## RECORDING PROCEDURE (this file NEVER writes the golden itself — an auto-recording golden proves
## nothing at all): run the suite; the failure message below prints the observed hash and the
## exact JSON document to write to `tests/golden/mapgen_concentric_bowl_small_seed1337.json`;
## write it, re-run, and the test goes green. **From the commit that first records it, §13.6
## applies FOREVER: a re-record needs its own dated docs/decisions.md reason in the SAME commit.**
##
## Before trusting a mismatch, read `test_the_generator_is_deterministic_before_the_hash_is_read`
## below: it re-proves determinism inside this file, so a red golden means the RULES moved, not
## that the generator became flaky.
extends GutTest

const PARAMS_PATH: String = "res://data/mapgen/concentric_bowl.json"
const GOLDEN_PATH: String = "res://tests/golden/mapgen_concentric_bowl_small_seed1337.json"

## §12.6 line 980 — the generator reference a map/scenario carries.
const GENERATOR_REF: String = "mapgen/concentric_bowl.json"

## §4.1 line 174 and §12.6's example seed. These literals are allowed HERE (a golden records
## concrete values by definition) and in data/*.json — never in engine code (§13.6).
const SIZE_ID: String = "small"
const EXPECTED_RADIUS: int = 24
const EXPECTED_HEX_COUNT: int = 1801
const GOLDEN_SEED: int = 1337

## The re-record rule, verbatim, so it is printed at the exact moment someone is deciding whether
## to overwrite the file (§13.6). Do not soften this sentence.
const RERECORD_RULE: String = (
	"re-record ONLY with a dated docs/decisions.md reason in the SAME commit (§13.6)"
)


## §14 M1 acceptance criterion (a) — SEED => TERRAIN HASH. The whole criterion in one assertion:
## the shipped params file, §4.1's Small radius, §12.6's seed 1337, and the recorded hash of the
## resulting map in HexMap's canonical order.
func test_small_map_at_seed_1337_matches_the_recorded_terrain_hash() -> void:
	var map: HexMap = _generate_golden_map()
	if map == null:
		return
	assert_eq(
		map.hex_count(),
		EXPECTED_HEX_COUNT,
		"§4.1 line 174: the Small map is %d hexes" % EXPECTED_HEX_COUNT
	)

	var observed: String = _render(map.content_hash())
	var recorded: Dictionary = _recorded()
	if recorded.is_empty():
		assert_true(
			false,
			(
				"§14 M1 (a): the golden file %s is MISSING (or unreadable/malformed). "
				+ "This test NEVER records it for you. Observed hash: %s. Write exactly:\n%s\n"
				+ "Once recorded, %s."
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
			"§14 M1 (a) seed => terrain hash MISMATCH. recorded=%s observed=%s. "
			+ "If the rules legitimately moved, %s — otherwise fix the code, not the golden."
		) % [expected, observed, RERECORD_RULE]
	)


## §13.2 tier 3 — the recorded document must describe the run it hashes, so a mismatch is
## diagnosable (wrong size? wrong seed? wrong generator?) instead of being one opaque number.
func test_the_recorded_document_describes_the_run_it_hashes() -> void:
	var recorded: Dictionary = _recorded()
	if recorded.is_empty():
		assert_true(
			false,
			"§14 M1 (a): %s must exist before this suite can be green; %s" % [GOLDEN_PATH, RERECORD_RULE]
		)
		return
	assert_eq(str(recorded.get("generator", "")), GENERATOR_REF, "§12.6: the generator reference")
	assert_eq(str(recorded.get("size_id", "")), SIZE_ID, "§4.1 line 174: the map size id")
	assert_eq(_integral(recorded.get("radius", -1)), EXPECTED_RADIUS, "§4.1 line 174: the hex radius")
	assert_eq(_integral(recorded.get("seed", -1)), GOLDEN_SEED, "§12.6: the recorded seed")
	assert_eq(
		_integral(recorded.get("hex_count", -1)),
		EXPECTED_HEX_COUNT,
		"§4.1 line 174: the recorded hex count"
	)


## §11.1 — determinism is re-proven INSIDE the golden file, so a red golden can be read
## correctly: two fresh generators fed two fresh `Rng.new(1337)` must agree before the recorded
## value is consulted at all. A flaky generator would otherwise be misdiagnosed as a rules change
## and "fixed" by re-recording — the one move §13.6 exists to prevent.
func test_the_generator_is_deterministic_before_the_hash_is_read() -> void:
	var first: HexMap = _generate_golden_map()
	var second: HexMap = _generate_golden_map()
	if first == null or second == null:
		return
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: the seeded generator must be reproducible before any hash is recorded"
	)
	var terrain_breaks: int = 0
	for hex: Vector2i in first.hexes():
		if first.get_terrain_type(hex) != second.get_terrain_type(hex):
			terrain_breaks += 1
		if first.get_elevation(hex) != second.get_elevation(hex):
			terrain_breaks += 1
	assert_eq(terrain_breaks, 0, "§11.1: both runs must agree hex for hex, not merely in the hash")


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## §12.6/§4.1 — the exact run the golden records: shipped params, size id "small", seed 1337.
## Returns null (having already reported why) when the params file itself is unusable.
func _generate_golden_map() -> HexMap:
	var generator: MapGenerator = MapGenerator.new()
	var loaded: bool = generator.load_params_file(PARAMS_PATH)
	assert_true(loaded, "§12.6: %s must load before a golden means anything" % PARAMS_PATH)
	if not loaded:
		return null
	var radius: int = generator.radius_for_size(SIZE_ID)
	assert_eq(radius, EXPECTED_RADIUS, "§4.1 line 174: \"%s\" is hex radius %d" % [SIZE_ID, EXPECTED_RADIUS])
	return generator.generate(radius, Rng.new(GOLDEN_SEED))


## The canonical rendering of a content hash: lowercase, zero-padded to 8 hex digits.
func _render(value: int) -> String:
	return "0x%08x" % value


## True for the canonical rendering above — a recorded hash may never be a JSON number.
func _is_rendered_hash(text: String) -> bool:
	var pattern: RegEx = RegEx.new()
	if pattern.compile("^0x[0-9a-f]{8}$") != OK:
		return false
	return pattern.search(text) != null


## The recorded golden document, or {} when the file is absent, unreadable or malformed. Never
## creates it — recording is a human/agent decision that carries a decisions.md entry (§13.6).
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


## The exact document to write when recording, printed inside the failure message so the
## procedure is the message rather than tribal knowledge.
func _document_for(observed: String) -> String:
	return (
		"{\n"
		+ "  \"generator\": \"%s\",\n" % GENERATOR_REF
		+ "  \"size_id\": \"%s\",\n" % SIZE_ID
		+ "  \"radius\": %d,\n" % EXPECTED_RADIUS
		+ "  \"seed\": %d,\n" % GOLDEN_SEED
		+ "  \"hex_count\": %d,\n" % EXPECTED_HEX_COUNT
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
