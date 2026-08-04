## Sentinel unit suite — M0 bootstrap (GDD §14 M0 row; §13.2 pyramid tier 1 "unit tests").
##
## M0 is bootstrap only, so this file pins the *contract the whole loop rests on*, never game
## rules (no rules constants exist before M0-T2's ruleset.json — §14 M0 deliverables):
##   - the pinned toolchain: repo-local Godot 4.7-stable (docs/decisions.md 2026-08-04 SETUP,
##     SETUP-3);
##   - §11.1 determinism: one seeded RandomNumberGenerator, same seed ⇒ same rolls;
##   - §11.2 directory structure;
##   - §13.2 three-tier test layout + the `-ginclude_subdirs` amendment (decisions.md SETUP-2).
##
## Flag-drop safety net: no test script sits directly in res://tests, so if `-ginclude_subdirs`
## is ever dropped from tools/run_tests.sh, GUT collects zero scripts and the hardened runner
## exits 1 ("GUT collected/ran no tests") — the amendment is mechanically enforced end to end.
extends GutTest


## §14 (M0 row) + docs/decisions.md 2026-08-04 SETUP and SETUP-3 — the engine is pinned to the
## repo-local Godot 4.7 stable build (4.7.stable.official.5b4e0cb0f, godot/ in the repo root).
## The GDD header asks for "Godot 4.3+"; 4.7 satisfies it. Fails loudly if the loop is ever run
## on a PATH shim or a machine-global install instead of the pinned binary.
func test_engine_is_godot_4_7() -> void:
	var version: Dictionary = Engine.get_version_info()
	assert_eq(int(version.get("major", -1)), 4, "engine major version must be 4")
	assert_eq(int(version.get("minor", -1)), 7, "engine minor version must be 7 (pinned 4.7-stable)")


## §11.1 — GameState carries exactly ONE RandomNumberGenerator, seeded at match start, and every
## roll goes through state.rng. Determinism is the invariant every golden test (§13.2 tier 3) and
## every replay (§11.1 save/load) depends on: same seed ⇒ identical sequence, and the seed must
## actually matter. Sequences are compared against each other, never against hardcoded integers —
## no GDD table specifies engine RNG output, so hardcoding it would pin the build, not the rule.
func test_seeded_rng_is_reproducible() -> void:
	var draws: int = 8
	var match_seed: int = 42  # the seed §13.1's sim_smoke command runs with
	var first: Array[int] = _draw_sequence(match_seed, draws)
	var replay: Array[int] = _draw_sequence(match_seed, draws)
	var other: Array[int] = _draw_sequence(match_seed + 1, draws)
	assert_eq(first.size(), draws, "sanity: the sequence was actually drawn")
	assert_eq(first, replay, "§11.1: the same seed must replay an identical sequence")
	assert_ne(first, other, "§11.1: a different seed must produce a different sequence")


## §11.2 — binding directory structure. The layout is pinned in git (via .gitkeep) before any
## milestone drops files into it, so later tasks cannot quietly invent a different tree.
func test_directory_structure_matches_gdd_11_2() -> void:
	var required_dirs: Array[String] = [
		"res://scripts/core",
		"res://scripts/sim",
		"res://scripts/ai",
		"res://scripts/render",
		"res://scripts/ui",
		"res://scenes",
		"res://data",
		"res://tools",
		"res://tests",
		"res://docs",
	]
	for dir_path: String in required_dirs:
		assert_true(
			DirAccess.dir_exists_absolute(dir_path),
			"§11.2 requires the directory %s" % dir_path
		)


## §13.2 pyramid tier 1 + docs/decisions.md 2026-08-04 SETUP-2 — this script must be collected
## out of res://tests/unit by `-gdir=res://tests -ginclude_subdirs`; a plain `-gdir` run does not
## recurse. Also pins that all three tiers (unit/sim/golden) actually have a sentinel on disk.
func test_collected_from_unit_subdir() -> void:
	var own_script: Script = get_script()
	assert_eq(
		own_script.resource_path.get_base_dir(),
		"res://tests/unit",
		"§13.2 tier 1 lives in tests/unit and is reached only via -ginclude_subdirs"
	)
	var tier_scripts: Array[String] = [
		"res://tests/unit/test_sentinel.gd",
		"res://tests/sim/test_sentinel_sim.gd",
		"res://tests/golden/test_sentinel_golden.gd",
	]
	for script_path: String in tier_scripts:
		assert_true(
			FileAccess.file_exists(script_path),
			"§13.2 requires a sentinel in every tier: %s" % script_path
		)


## Helper — draws `count` integers from a freshly seeded generator (§11.1: rolls go through an
## RNG instance, never the global randi(), which the sim core is forbidden to call).
func _draw_sequence(rng_seed: int, count: int) -> Array[int]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var rolls: Array[int] = []
	for _i: int in range(count):
		rolls.append(rng.randi())
	return rolls
