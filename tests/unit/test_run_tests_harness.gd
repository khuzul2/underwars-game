## Harness-hardening suite — M0-T5 (GDD §13.1 as amended, §13.2, §13.6, §14 M0 acceptance).
##
## §14's M0 acceptance criterion — "Sentinel suite runs green headless AND a deliberately failing
## sentinel makes run_tests.sh exit non-zero" (as amended, docs/decisions.md 2026-08-04 SETUP-2
## item 3) — is worth exactly what the green signal is worth. This file pins the guards that make
## that signal honest, because a *skipped* test script is indistinguishable from a *passing* one
## by exit code alone.
##
## MEASURED this iteration on the pinned repo-local `godot/Godot_v4.7-stable_win64_console.exe`
## (4.7.stable.official.5b4e0cb0f), reproducing both variants recorded in docs/decisions.md
## M0-T2 item 11 and M0-T4 item (i):
##
##   healthy tree                                   -> exit 0, Scripts 6 / Tests 57 / Passing 57,
##                                                     6 `test_*.gd` files on disk (collected == disk)
##   + a `test_`-prefixed probe with `var x: int = (`
##     (SYNTACTIC parse error)                      -> exit 0, Scripts 6 / Tests 57 — FALSE GREEN,
##                                                     while 7 files sit on disk
##   + a `test_`-prefixed probe asserting `r is Node`
##     against a RefCounted
##     (STATICALLY-IMPOSSIBLE construct)            -> exit 0, Scripts 6 / Tests 57 — FALSE GREEN,
##                                                     while 7 files sit on disk
##
## **Correction to docs/decisions.md M0-T4 item (i):** BOTH variants DO print
## `ERROR: Failed to load script "res://…" with error "Parse error".` and
## `[GUT WARNING]:  Ignoring script res://… because it does not extend GutTest`. M0-T4's probe was
## named `_verify_parse_error.gd` — it lacked GUT's `test_` collection prefix, so GUT never
## attempted to load it, and "no diagnostic whatsoever" was an artefact of that. The diagnostics
## are therefore greppable (pinned below), but the *load-bearing* guard is the coverage check:
## the Scripts/Tests/Asserts totals are byte-identical to a healthy run in both variants, so only
## "every `test_*.gd` on disk was actually collected" can catch a newly-added broken file, and it
## does not depend on GUT choosing to mention a file it never managed to open.
##
## Strengthening only: every pre-existing guard of the harness contract is re-asserted here
## (CLAUDE.md — "make it pass, never weaken it"), so a future edit that trades a guard away goes
## red instead of quietly shrinking the contract.
##
## §13.2 tier 1 (tests/unit/). Reached only via `-ginclude_subdirs` (docs/decisions.md SETUP-2).
extends GutTest

const RUN_TESTS_PATH: String = "res://tools/run_tests.sh"
const VERIFY_HARNESS_PATH: String = "res://tools/verify_harness.sh"
const TESTS_ROOT: String = "res://tests"
const SELF_PATH: String = "res://tests/unit/test_run_tests_harness.gd"

## GUT 9.7.1's collection rule, read from the vendored source (addons/gut/gut.gd:229
## `_file_prefix = 'test_'`, :980 `begins_with(prefix) and ends_with(suffix)`, :1078
## `suffix = ".gd"`; addons/gut/gut_config.gd:45 `prefix = 'test_'`), applied recursively under
## `res://tests` because of `-ginclude_subdirs`. The runner's disk enumeration must use EXACTLY
## this rule, otherwise the two lists it compares are not comparable.
const GUT_FILE_PREFIX: String = "test_"
const GUT_FILE_SUFFIX: String = ".gd"
const GUT_GLOB: String = "test_*.gd"

## The label GUT prints in its Totals block (`Scripts               6`) — the only place the run
## reports how many scripts it actually collected.
const GUT_TOTALS_LABEL: String = "Scripts"

## Every committed test script, as GUT addresses it. This is a FLOOR, not a freeze: later
## milestones append to it. Its job is to make "the suite silently got smaller" a red test.
const REQUIRED_TEST_SCRIPTS: Array[String] = [
	"res://tests/golden/test_sentinel_golden.gd",
	"res://tests/sim/test_sentinel_sim.gd",
	"res://tests/unit/test_event_bus.gd",
	"res://tests/unit/test_rules_loader.gd",
	"res://tests/unit/test_run_tests_harness.gd",
	"res://tests/unit/test_sentinel.gd",
	"res://tests/unit/test_typing_gate.gd",
]

## docs/decisions.md SETUP-2 item 2 — the runner's original refusal set. None of these may ever be
## dropped; M0-T5 only ADDS to the alternation.
const RUNNER_REFUSALS_EXISTING: Array[String] = [
	"Nothing was run",
	"does not exist",
	"have not been imported",
]

## M0-T5 — the two diagnostics GUT emits when a `test_`-prefixed script fails to load (both
## measured this iteration, on both parse-error variants).
const RUNNER_REFUSALS_ADDED: Array[String] = [
	"Failed to load script",
	"Ignoring script",
]

## Guards the harness already carries. Re-asserted so hardening can never become rewriting.
##   `--import`              — GUT 9.7.1 exits 0 doing nothing without .godot/ (SETUP-2 item 1)
##   `-ginclude_subdirs`     — without it `-gdir=res://tests` collects ZERO scripts (§11.2/§13.2)
##   `-gdir=res://tests`     — the §13.1 command's collection root
##   `-gexit`                — GUT must quit, not idle, headless
##   `exit 2`                — harness-unavailable code (missing project.godot / missing engine)
##   `-o pipefail`           — a failure mid-pipeline must not read as success
##   the repo-local binary   — docs/decisions.md SETUP-3: never the `godot` PATH shim
const RUNNER_PRESERVED_GUARDS: Array[String] = [
	"--import",
	"-ginclude_subdirs",
	"-gdir=res://tests",
	"-gexit",
	"exit 2",
	"-o pipefail",
	"godot/Godot_v4.7-stable_win64_console.exe",
]

## The two probes tools/verify_harness.sh must plant, transcribed from the reproductions above.
## Variant 1 is a syntactic parse error; variant 2 is a statically-impossible construct (the
## M0-T2 live case, reproduced dependency-free). They fail in different engine phases, so proving
## one proves nothing about the other.
const PROBE_SYNTACTIC: String = "var x: int = ("
const PROBE_IMPOSSIBLE: String = "is Node"

## Phases A and B already exist (SETUP-2 item 3 / M0-T1). M0-T5 adds one phase per variant.
const VERIFIER_ADDED_PHASES: Array[String] = [
	"Phase C",
	"Phase D",
]

## Three files are planted across the verifier's red phases (red canary + both parse-error
## probes); each generates a `.gd.uid` sidecar that must also be swept by the EXIT trap.
const PLANTED_FILE_COUNT: int = 3

## Phases A(green) + B(red) + A(post-cleanup green) capture the runner's exit code three times
## today; C and D each add at least one more capture that must require NON-zero.
const MIN_EXIT_CODE_CAPTURES: int = 5


## §13.1 (amended) + §14 M0 clause (a) — THE load-bearing guard of this task.
##
## Both measured parse-error variants leave GUT's Totals byte-identical to a healthy run
## (Scripts 6 / Tests 57 / Passing 57), so no threshold on the counts alone can notice a newly
## added broken file. The only discriminator is: how many `test_*.gd` files are on disk, and was
## every one of them collected. The runner must therefore enumerate the tests tree itself, using
## GUT's own prefix/suffix rule, and reconcile that list against what the run reported.
func test_runner_enumerates_expected_test_scripts() -> void:
	var runner: String = _read_tool(RUN_TESTS_PATH)
	assert_true(
		runner.contains(GUT_GLOB),
		"§13.1 (amended): run_tests.sh must enumerate `%s` under tests/ itself — that glob IS " % GUT_GLOB
		+ "GUT 9.7.1's collection rule (prefix 'test_', suffix '.gd'), and only a list built by the "
		+ "same rule is comparable with GUT's"
	)
	assert_true(
		runner.contains("find") and runner.contains("-name"),
		"§13.1 (amended)/§11.2: the enumeration must walk the tests/ tree recursively (find … "
		+ "-name), because `-ginclude_subdirs` collects tests/unit, tests/sim and tests/golden"
	)
	assert_true(
		runner.contains(GUT_TOTALS_LABEL),
		"§13.1 (amended): run_tests.sh must read GUT's `%s` total — that is the run's own " % GUT_TOTALS_LABEL
		+ "count of collected scripts, and it must equal the number of files on disk. An absent "
		+ "or non-numeric Totals block must never read as success"
	)

	var guard_index: int = runner.find(GUT_TOTALS_LABEL)
	var final_exit_index: int = runner.rfind("exit \"$CODE\"")
	assert_true(
		guard_index >= 0 and final_exit_index >= 0 and guard_index < final_exit_index,
		"§13.6: the coverage guard must run BEFORE `exit \"$CODE\"` so it can override GUT's own "
		+ "exit code — a suite that silently skipped a script is not green no matter what GUT says"
	)


## §13.1 (amended) — the greppable half. Measured this iteration: a `test_`-prefixed script that
## fails to parse makes GUT print `Failed to load script … "Parse error"` AND
## `Ignoring script … because it does not extend GutTest`, in BOTH variants, while the process
## still exits 0. Refusing those strings is cheap and names the offending file for free.
##
## Strengthening only: the three original alternatives (SETUP-2 item 2) must survive verbatim.
func test_runner_refuses_load_and_parse_diagnostics() -> void:
	var runner: String = _read_tool(RUN_TESTS_PATH)
	for diagnostic: String in RUNNER_REFUSALS_ADDED:
		assert_true(
			runner.contains(diagnostic),
			"§13.1 (amended)/§14 M0: run_tests.sh must refuse a run whose output contains '%s' — " % diagnostic
			+ "measured on the pinned 4.7 binary, a test script that fails to parse is silently "
			+ "un-collected while the process exits 0 (docs/decisions.md M0-T2 item 11, as corrected)"
		)
	for diagnostic: String in RUNNER_REFUSALS_EXISTING:
		assert_true(
			runner.contains(diagnostic),
			"docs/decisions.md SETUP-2 item 2: the pre-existing refusal alternative '%s' must " % diagnostic
			+ "survive — CLAUDE.md allows STRENGTHENING the harness contract, never weakening it"
		)


## CLAUDE.md ("this script is the harness contract — make it pass, do not weaken it") — the
## anti-weakening test. Every guard the runner already carried is re-asserted, so M0-T5's edit
## cannot silently trade an old guard for a new one. Each entry is documented at its constant.
func test_runner_keeps_its_pre_existing_guards() -> void:
	var runner: String = _read_tool(RUN_TESTS_PATH)
	for guard: String in RUNNER_PRESERVED_GUARDS:
		assert_true(
			runner.contains(guard),
			"§13.1/§14 M0 + docs/decisions.md SETUP-2/SETUP-3: run_tests.sh must still carry '%s' " % guard
			+ "— hardening the harness may only add guards, never remove one"
		)


## §13.1 (amended)/§13.2 — the ORACLE for the shell guard, expressed as the same rule from inside
## the engine: enumerate `res://tests` recursively for GUT's `test_` + `.gd` files. Because this
## very file is running, GUT demonstrably collected it, so finding it here proves the enumeration
## rule and GUT's collection rule agree. A file that disappears from disk (or is renamed out of
## the `test_` prefix, which un-collects it) turns this red.
func test_collected_scripts_match_the_files_on_disk() -> void:
	var found: Array[String] = []
	_collect_test_scripts(TESTS_ROOT, found)
	found.sort()

	assert_gte(
		found.size(),
		REQUIRED_TEST_SCRIPTS.size(),
		"§13.2: at least the %d committed test scripts must be on disk; " % REQUIRED_TEST_SCRIPTS.size()
		+ "found %d — the suite may only grow" % found.size()
	)
	for required: String in REQUIRED_TEST_SCRIPTS:
		assert_true(
			found.has(required),
			"§13.2/§14 M0: committed test script '%s' must exist and match GUT's collection " % required
			+ "rule (prefix '%s', suffix '%s')" % [GUT_FILE_PREFIX, GUT_FILE_SUFFIX]
		)
	assert_true(
		found.has(SELF_PATH),
		"§13.1 (amended): this running file must appear in the enumeration — GUT collected it, so "
		+ "its absence would mean the enumeration rule and GUT's rule disagree, which is exactly "
		+ "the mismatch run_tests.sh relies on to detect a silently skipped script"
	)
	for path: String in found:
		assert_true(
			path.begins_with(TESTS_ROOT + "/"),
			"§11.2: every collected test script must live under %s — " % TESTS_ROOT
			+ "'%s' does not" % path
		)
		var file_name: String = path.get_file()
		assert_true(
			file_name.begins_with(GUT_FILE_PREFIX) and file_name.ends_with(GUT_FILE_SUFFIX),
			"§13.2: '%s' must satisfy GUT's prefix/suffix rule exactly — the enumeration and " % file_name
			+ "GUT must never disagree about what counts as a test script"
		)


## §14 M0 acceptance (as amended by docs/decisions.md SETUP-2 item 3, extended by M0-T5) — the
## two-way proof must now cover BOTH silent-skip variants, not just an honestly failing assert.
## Phase B (a red canary) proves the runner catches a FAILING test; it says nothing about a test
## that never ran. Phase C plants the syntactic parse error and Phase D the statically-impossible
## construct — they fail in different engine phases, so neither substitutes for the other — and
## each must require a NON-zero exit, then remove its probe and re-verify green.
##
## The end-to-end proof is `bash tools/verify_harness.sh` at Verify (it must exit 0 with Phases
## A/B/C/D reported, and leave `git status --short` empty); this test pins that the script really
## contains both phases, plants both canaries, and still sweeps everything through its EXIT trap.
func test_verify_harness_proves_both_parse_error_variants() -> void:
	var verifier: String = _read_tool(VERIFY_HARNESS_PATH)

	for phase: String in VERIFIER_ADDED_PHASES:
		assert_true(
			verifier.contains(phase),
			"§14 M0 (amended): verify_harness.sh must report '%s' — one phase per measured " % phase
			+ "parse-error variant, because the two variants fail in different engine phases"
		)
	assert_true(
		verifier.contains(PROBE_SYNTACTIC),
		"§14 M0 (amended): the syntactic-parse-error canary `%s` must be planted — " % PROBE_SYNTACTIC
		+ "measured: it leaves Scripts/Tests/Passing identical to a healthy run while exit is 0"
	)
	assert_true(
		verifier.contains(PROBE_IMPOSSIBLE),
		"§14 M0 (amended): the statically-impossible-construct canary (`%s` against a " % PROBE_IMPOSSIBLE
		+ "RefCounted — docs/decisions.md M0-T2 item 11's live case) must be planted too"
	)

	assert_gte(
		verifier.count("$?"),
		MIN_EXIT_CODE_CAPTURES,
		"§14 M0 (amended): each new phase must capture the runner's exit code and require it to be "
		+ "NON-zero; %d captures are expected (A, B, A-again, C, D at minimum), found %d"
		% [MIN_EXIT_CODE_CAPTURES, verifier.count("$?")]
	)

	var trap_index: int = verifier.find("trap cleanup EXIT")
	var first_plant_index: int = verifier.find("cat > ")
	assert_true(
		trap_index >= 0 and (first_plant_index < 0 or trap_index < first_plant_index),
		"M0-T1: the EXIT trap must be armed BEFORE the first canary is written, or an interrupted "
		+ "run leaves a probe in tests/ — which would poison every later run of the suite"
	)

	var cleanup_body: String = _cleanup_region(verifier)
	assert_true(
		cleanup_body.contains("rm -f"),
		"M0-T1: cleanup() must delete the planted files — verify_harness.sh has to leave the tree "
		+ "clean (`git status --short` empty) on success, failure and interruption alike"
	)
	assert_gte(
		cleanup_body.count(".uid"),
		PLANTED_FILE_COUNT,
		"§14 M0 (amended): %d files are planted across the red phases (canary + both " % PLANTED_FILE_COUNT
		+ "parse-error probes) and Godot 4.4+ writes a .gd.uid sidecar next to each, so cleanup() "
		+ "must sweep %d sidecars; found %d" % [PLANTED_FILE_COUNT, cleanup_body.count(".uid")]
	)


## Helper — reads one of the harness scripts as text, failing loudly (rather than asserting
## against an empty string) if it is missing, exactly as tests/unit/test_typing_gate.gd does.
func _read_tool(path: String) -> String:
	assert_true(
		FileAccess.file_exists(path),
		"§13.1: %s must exist — it is the harness contract this suite pins" % path
	)
	var text: String = FileAccess.get_file_as_string(path)
	assert_gt(
		text.length(),
		0,
		"sanity: %s must be readable as text" % path
	)
	return text


## Helper — GUT 9.7.1's collection rule, re-implemented as the oracle: recurse `res://tests` and
## keep every file whose name begins with `test_` and ends with `.gd`. Deliberately identical to
## the rule tools/run_tests.sh must use; `.gd.uid` sidecars are excluded by the suffix test.
func _collect_test_scripts(dir_path: String, found: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var child_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_test_scripts(child_path, found)
		elif entry.begins_with(GUT_FILE_PREFIX) and entry.ends_with(GUT_FILE_SUFFIX):
			found.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


## Helper — the body of verify_harness.sh's `cleanup()` function, so the sweep can be asserted
## where it actually has to happen (inside the function the EXIT trap calls) rather than anywhere
## in the file. Returns "" when the function cannot be located, which fails the callers' asserts.
func _cleanup_region(text: String) -> String:
	var start_index: int = text.find("cleanup()")
	if start_index < 0:
		return ""
	var end_index: int = text.find("}", start_index)
	if end_index < 0:
		return ""
	return text.substr(start_index, end_index - start_index)
