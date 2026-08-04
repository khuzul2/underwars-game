## Sentinel golden suite — M0 bootstrap (GDD §13.2 pyramid tier 3 "golden tests").
##
## Tier 3 records `fixed seed + command log ⇒ GameState.hash() after N turns`; no GameState,
## Command or hash exists before M1+, so at M0 this file's job is to prove tests/golden/ is part
## of the collected suite — `-gdir=res://tests` reaches it only with `-ginclude_subdirs`
## (docs/decisions.md 2026-08-04 SETUP-2, which amended the §13.1 command). Recorded hashes land
## here later and may only be re-recorded in the same commit as a decisions.md entry (§13.2/§13.6).
extends GutTest


## §13.2 tier 3 + docs/decisions.md 2026-08-04 SETUP-2 — this script must be collected out of
## res://tests/golden by the amended §13.1 invocation.
func test_collected_from_golden_subdir() -> void:
	var own_script: Script = get_script()
	assert_eq(
		own_script.resource_path.get_base_dir(),
		"res://tests/golden",
		"§13.2 tier 3 lives in tests/golden and is reached only via -ginclude_subdirs"
	)
