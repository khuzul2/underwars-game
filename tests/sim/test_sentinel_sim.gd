## Sentinel system suite — M0 bootstrap (GDD §13.2 pyramid tier 2 "system tests").
##
## Tier 2 holds scripted mini-scenarios (collapse kills a stack, upkeep deficit bleeds HP, …);
## none of those exist before M2, so at M0 this file's job is to prove that tests/sim/ is part of
## the collected suite at all — `-gdir=res://tests` reaches it only with `-ginclude_subdirs`
## (docs/decisions.md 2026-08-04 SETUP-2, which amended the §13.1 command).
extends GutTest


## §13.2 tier 2 + docs/decisions.md 2026-08-04 SETUP-2 — this script must be collected out of
## res://tests/sim by the amended §13.1 invocation.
func test_collected_from_sim_subdir() -> void:
	var own_script: Script = get_script()
	assert_eq(
		own_script.resource_path.get_base_dir(),
		"res://tests/sim",
		"§13.2 tier 2 lives in tests/sim and is reached only via -ginclude_subdirs"
	)
