## Static-typing gate suite — M0-T4 (GDD §11.3, §13.6, §14 M0 row's "CI script" deliverable).
##
## §11.3 is binding *prose*, not a numeric table: "Static typing everywhere
## (--warnings-as-errors in CI where feasible)". Godot 4.7 ships **no** `--warnings-as-errors`
## CLI flag (measured on the pinned repo-local 4.7.stable.official.5b4e0cb0f binary — see
## docs/decisions.md M0-T4), so the gate is project-setting driven:
## `debug/gdscript/warnings/<name>=2` makes the engine refuse to *load* an offending script, and
## `tools/typecheck.sh` surfaces that headlessly via `--check-only --script`.
##
## This file pins the gate's *configuration*, because §13.6's "static typing clean" is one
## character away from becoming a silent no-op: flipping a level from 2 to 1 (or `enable` to
## false) disables the check while `tools/ci.sh` keeps reporting green. Every value below is a
## measured fact about the pinned engine, not a preference.
##
## Levels are effectively binary for a headless gate: a level-1 warning prints **nothing** under
## `--check-only` (measured), so only 0 (off) and 2 (error) mean anything here. The three level-0
## entries are the documented exclusions logged in docs/decisions.md (M0-T4); they are written
## explicitly in project.godot rather than left to Godot's default so that re-enabling one is a
## visible edit that has to carry its own logged decision (§13.4), not a silent drift.
##
## §13.2 tier 1 (tests/unit/). Reached only via `-ginclude_subdirs` (decisions.md SETUP-2).
extends GutTest

## The ProjectSettings path prefix every GDScript warning level lives under. In project.godot the
## first segment becomes the section header, so the same setting is written `[debug]` +
## `gdscript/warnings/<name>` — the text assertions below therefore match on the suffix.
const WARNING_PREFIX: String = "debug/gdscript/warnings/"

## §11.3 — the static-typing gate: every GDScript warning the pinned 4.7 build offers, minus the
## three documented exclusions, each pinned at level 2 (= error). Verified clean this iteration
## against every project .gd file with zero source changes, so the gate costs nothing to hold.
## `untyped_declaration` and `inferred_declaration` are the two that literally implement
## "static typing everywhere"; they are additionally asserted individually below so the intent
## survives any future edit to this list.
const GATE: Array[String] = [
	"assert_always_false",
	"assert_always_true",
	"confusable_capture_reassignment",
	"confusable_identifier",
	"confusable_local_declaration",
	"confusable_local_usage",
	"confusable_temporary_modification",
	"constant_used_as_function",
	"deprecated_keyword",
	"empty_file",
	"enum_variable_without_default",
	"function_used_as_property",
	"get_node_default_without_onready",
	"incompatible_ternary",
	"inference_on_variant",
	"inferred_declaration",
	"int_as_enum_without_cast",
	"int_as_enum_without_match",
	"integer_division",
	"missing_await",
	"missing_tool",
	"narrowing_conversion",
	"native_method_override",
	"onready_with_export",
	"property_used_as_function",
	"redundant_await",
	"redundant_static_unload",
	"shadowed_global_identifier",
	"shadowed_variable",
	"shadowed_variable_base_class",
	"standalone_expression",
	"standalone_ternary",
	"static_called_on_instance",
	"unassigned_variable",
	"unassigned_variable_op_assign",
	"unreachable_code",
	"unreachable_pattern",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return",
	"untyped_declaration",
	"unused_local_constant",
	"unused_parameter",
	"unused_private_class_variable",
	"unused_signal",
	"unused_variable",
]

## docs/decisions.md 2026-08-04 M0-T4 — the ONLY warnings deliberately left out of the gate,
## authorized by §11.3's own "where feasible" qualifier. Each is off (0), never 1, because level 1
## is invisible headless:
##   - `unsafe_call_argument`  — GUT 9.7.1's assert API (`assert_eq(v1, v2, text)`) is untyped, so
##     every assert call site in tests/ trips it; the callee is exempt (addons) but the call site
##     is project code. Unfixable without casting every assert argument.
##   - `unsafe_cast`           — trips only scripts/sim/rules_loader.gd's `as Dictionary` / `as
##     Array` sites, each already guarded by an immediately preceding `is` check. May be tightened
##     to 2 once that JSON Variant decoding is refactored — with its own decisions.md entry.
##   - `return_value_discarded`— not a typing warning; trips GUT-idiomatic `insert()` / `append()`.
const EXCLUSIONS: Array[String] = [
	"return_value_discarded",
	"unsafe_call_argument",
	"unsafe_cast",
]

## Keys sharing the warnings prefix that are NOT per-warning levels (a bool, a Dictionary and a
## bool respectively on 4.7-stable) and must therefore be excluded from the coverage arithmetic.
const NON_LEVEL_KEYS: Array[String] = [
	"directory_rules",
	"enable",
	"renamed_in_godot_4_hint",
]

## Measured on 4.7-stable: 52 keys under the prefix, 3 of them non-level ⇒ 49 warning levels.
const WARNING_LEVEL_COUNT: int = 49

## CLAUDE.md — `addons/` is read-only vendored GUT and must never be gated.
const ADDONS_TREE: String = "res://addons"

## The repo's own source trees: nothing here may ever be exempted from the gate.
const PROJECT_TREES: Array[String] = [
	"res://scripts",
	"res://tests",
	"res://tools",
]

const PROJECT_GODOT_PATH: String = "res://project.godot"
const TYPECHECK_PATH: String = "res://tools/typecheck.sh"
const CI_PATH: String = "res://tools/ci.sh"


## §11.3 / §13.6 — the master switch. Asserted both at runtime AND as an explicit line in
## project.godot: Godot's *default* is already true, so a runtime-only assertion would pass even
## if the gate were never configured at all. Writing it explicitly makes "the gate is on" a
## reviewable line in the diff rather than an engine default that a future engine may change.
func test_gdscript_warnings_are_enabled() -> void:
	var enabled: Variant = ProjectSettings.get_setting(WARNING_PREFIX + "enable", false)
	assert_eq(
		enabled,
		true,
		"§11.3/§13.6: '%senable' must be true — with it false every level below is inert and "
		% WARNING_PREFIX + "tools/ci.sh would report green while checking nothing"
	)
	var project_text: String = _read_project_godot()
	assert_true(
		project_text.contains("gdscript/warnings/enable=true"),
		"§14 M0: project.godot must switch the gate on explicitly in its [debug] section, "
		+ "not inherit Godot's default (docs/decisions.md M0-T4)"
	)


## §11.3 "Static typing everywhere (--warnings-as-errors in CI where feasible)" — the gate itself.
## Every listed warning must be level 2, i.e. a hard load failure, which is what makes
## `tools/typecheck.sh` a mechanical gate rather than advisory output (§13.6's "static typing
## clean" ceases to be a diff-review promise once this passes).
func test_static_typing_warnings_are_errors() -> void:
	assert_eq(
		GATE.size(),
		WARNING_LEVEL_COUNT - EXCLUSIONS.size(),
		"§11.3: the gate must cover every GDScript warning the pinned 4.7 build offers except "
		+ "the documented exclusions (docs/decisions.md M0-T4)"
	)
	for warning_name: String in GATE:
		var level: Variant = ProjectSettings.get_setting(WARNING_PREFIX + warning_name, -1)
		assert_eq(
			level,
			2,
			"§11.3/§13.6: warning '%s' must be level 2 (treated as error); " % warning_name
			+ "level 1 is invisible under --check-only, so anything but 2 disables it headless"
		)
	var untyped_level: Variant = ProjectSettings.get_setting(
		WARNING_PREFIX + "untyped_declaration", -1
	)
	assert_eq(
		untyped_level,
		2,
		"§11.3 'static typing everywhere' IS untyped_declaration=2 — an untyped `var` must not "
		+ "compile anywhere in project code"
	)
	var inferred_level: Variant = ProjectSettings.get_setting(
		WARNING_PREFIX + "inferred_declaration", -1
	)
	assert_eq(
		inferred_level,
		2,
		"§11.3 'static typing everywhere' also forbids inferred `:=` declarations — the declared "
		+ "type must be written out"
	)


## docs/decisions.md 2026-08-04 M0-T4 — the exclusions are a logged §13.4 resolution, so they must
## be *present at level 0*, never merely absent. Godot's default for all three happens to be 0, so
## the explicit project.godot line is the load-bearing half of this test: it forces a future agent
## who wants them on to edit a visible line (and log the decision) instead of drifting into it.
func test_documented_exclusions_are_explicitly_off() -> void:
	var project_text: String = _read_project_godot()
	for warning_name: String in EXCLUSIONS:
		var level: Variant = ProjectSettings.get_setting(WARNING_PREFIX + warning_name, -1)
		assert_eq(
			level,
			0,
			"docs/decisions.md M0-T4: '%s' is a documented exclusion and must be 0 (off); " % warning_name
			+ "level 1 would print nothing under --check-only, so it is not a softer setting"
		)
		assert_true(
			project_text.contains("gdscript/warnings/%s=0" % warning_name),
			"docs/decisions.md M0-T4: exclusion '%s' must be written explicitly in " % warning_name
			+ "project.godot, so re-enabling it is a visible edit carrying its own logged decision (§13.4)"
		)


## Anti-rot: the gate is defined as a whitelist, so a warning added by a future Godot patch would
## silently fall outside it and stop being checked. This test enumerates what the *engine* offers
## and requires that GATE + EXCLUSIONS account for every one of them — when 4.8 adds a warning the
## suite goes red and a human decides which side it belongs on, instead of coverage quietly rotting.
func test_gate_covers_every_gdscript_warning_setting() -> void:
	var found_levels: Array[String] = []
	var props: Array = ProjectSettings.get_property_list()
	for prop_variant: Variant in props:
		var prop: Dictionary = prop_variant
		var key: String = str(prop.get("name", ""))
		if not key.begins_with(WARNING_PREFIX):
			continue
		var short_name: String = key.substr(WARNING_PREFIX.length())
		if NON_LEVEL_KEYS.has(short_name):
			continue
		if not found_levels.has(short_name):
			found_levels.append(short_name)
	found_levels.sort()

	var expected_levels: Array[String] = []
	expected_levels.append_array(GATE)
	expected_levels.append_array(EXCLUSIONS)
	expected_levels.sort()

	assert_eq(
		found_levels.size(),
		WARNING_LEVEL_COUNT,
		"§11.3: the pinned 4.7 build exposes %d GDScript warning levels; " % WARNING_LEVEL_COUNT
		+ "a different count means the engine changed and the gate must be re-curated"
	)
	assert_eq(
		expected_levels.size(),
		WARNING_LEVEL_COUNT,
		"§11.3: GATE + EXCLUSIONS must partition the engine's warning set exactly once"
	)
	assert_eq(
		found_levels,
		expected_levels,
		"§11.3/§13.6: every GDScript warning must be either gated (level 2) or a documented "
		+ "exclusion (docs/decisions.md M0-T4) — an unaccounted warning is uncovered code"
	)


## CLAUDE.md ("addons/ is read-only") + measured semantics: `directory_rules` maps a res://
## directory prefix to an exemption, and writing the setting REPLACES Godot's default
## `{ "res://addons": 0 }` wholesale. So the exemption for vendored GUT must survive whatever
## M0-T4 writes — and, symmetrically, no tree of the repo's OWN code may ever appear here, which
## would exempt project code from the gate it exists to enforce.
func test_addons_are_exempt_and_project_code_is_not() -> void:
	var rules_variant: Variant = ProjectSettings.get_setting(WARNING_PREFIX + "directory_rules", {})
	var rules: Dictionary = rules_variant
	assert_true(
		rules.has(ADDONS_TREE),
		"CLAUDE.md: %s is vendored, read-only GUT 9.7.1 and must stay exempt — writing " % ADDONS_TREE
		+ "directory_rules replaces the default, so the exemption has to be carried over"
	)
	assert_eq(
		rules.get(ADDONS_TREE, -1),
		0,
		"CLAUDE.md/§11.3: %s must map to 0 (fully exempt); measured on 4.7-stable, " % ADDONS_TREE
		+ "a value of 1 does NOT downgrade a level-2 warning, so 0 is the only exemption"
	)
	for project_tree: String in PROJECT_TREES:
		assert_false(
			rules.has(project_tree),
			"§11.3 'static typing everywhere': %s is project code and must never be " % project_tree
			+ "exempted from the gate"
		)


## §14 M0 row — the milestone's last deliverable is a "CI script"; §13.1 lists the commands it has
## to drive. This pins that both scripts exist and are what they claim to be: typecheck.sh drives
## the engine's `--check-only` gate via the pinned repo-local binary (docs/decisions.md SETUP-3 —
## never the `godot` PATH shim) and proves itself both ways with `--self-test`; ci.sh composes
## typecheck.sh with the §13.1 harness command and names the §13.1 tools that are not built yet,
## which is how CLAUDE.md's applicability rule stops being a thing agents remember by hand.
func test_ci_scripts_exist_and_drive_the_gate() -> void:
	assert_true(
		FileAccess.file_exists(TYPECHECK_PATH),
		"§14 M0 / §13.6: %s must exist — it is the mechanical §11.3 gate" % TYPECHECK_PATH
	)
	assert_true(
		FileAccess.file_exists(CI_PATH),
		"§14 M0: %s must exist — it is the milestone's 'CI script' deliverable" % CI_PATH
	)

	if FileAccess.file_exists(TYPECHECK_PATH):
		var typecheck_text: String = FileAccess.get_file_as_string(TYPECHECK_PATH)
		assert_true(
			typecheck_text.contains("--check-only"),
			"§11.3: typecheck.sh must run the engine's `--check-only` pass — that is the only "
			+ "headless surface on which a level-2 warning becomes a non-zero exit"
		)
		assert_true(
			typecheck_text.contains("--self-test"),
			"§14 M0: typecheck.sh must offer `--self-test` (plant a violation ⇒ gate rejects it ⇒ "
			+ "remove ⇒ green), mirroring tools/verify_harness.sh's two-way proof"
		)
		assert_true(
			typecheck_text.contains("godot/Godot_v4.7-stable_win64_console.exe"),
			"docs/decisions.md SETUP-3: the repo-local binary is the ONLY engine any tool may "
			+ "invoke — never the `godot` PATH shim or a machine-global install"
		)

	if FileAccess.file_exists(CI_PATH):
		var ci_text: String = FileAccess.get_file_as_string(CI_PATH)
		assert_true(
			ci_text.contains("typecheck.sh"),
			"§13.6: the CI script must run the static-typing gate"
		)
		assert_true(
			ci_text.contains("run_tests.sh"),
			"§13.1: the CI script must run the harness command that always applies from M0"
		)
		for pending_tool: String in ["sim_smoke", "content_cli", "balance_lab"]:
			assert_true(
				ci_text.contains(pending_tool),
				"§13.1 + CLAUDE.md applicability rule: ci.sh must know about `%s` so it can " % pending_tool
				+ "SKIP it non-fatally until the milestone that builds it (§14) — a tool that is "
				+ "not due yet is never a failure"
			)


## Helper — reads project.godot as text. The gate's configuration is asserted against the FILE as
## well as against ProjectSettings, because several of the pinned values coincide with Godot's own
## defaults and a runtime-only assertion could not tell "configured" from "never configured".
func _read_project_godot() -> String:
	var project_text: String = FileAccess.get_file_as_string(PROJECT_GODOT_PATH)
	assert_true(
		project_text.length() > 0,
		"sanity: %s must be readable — the gate lives in its [debug] section" % PROJECT_GODOT_PATH
	)
	return project_text
