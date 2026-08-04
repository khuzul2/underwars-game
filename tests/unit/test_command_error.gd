## CommandError — GDD §11.1 (Layered Design, **binding**), §11.2 (`scripts/sim/`), §11.3,
## §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 705): "**Commands** (command pattern): MoveUnit, AttackUnit, AttackHex, DigHex,
##         CancelDig, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein,
##         SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -> Error?
##         and apply(state) -> Array[Event]. **Every mutation of GameState goes through a
##         Command** ... and a match is fully described by (seed, command\_log)."
##   §11.1 (line 703): "No Node, no Scene Tree, no engine singletons, no rendering, no
##         **randi()** — the core must run headless byte-identically."
##
## `docs/decisions.md` was re-scanned end to end this iteration: the ONLY logged §12.1 override
## is **(AU)(i)** (`dig_yields.artificial_granite.stone = 2`), which is irrelevant here, and **NO
## logged override touches §11.1, §3.2, §3.3, §3.4 or §13.2** — the printed text governs
## unamended. §11.1 prints "Error?" and no error API at all, so the shape below is a §13.4
## resolution lettered **(AV)** ((AU) is cross-referenced by four files and must NOT be
## renumbered), recorded by Land:
##   (AV) A command rejection is a NEW type, deliberately NOT `RulesError`.
##       - `RulesError.line` is 1-based over a DOCUMENT with **0 reserved** exclusively for
##         file-level failures (M0-T2 item 2), and `RulesError.path` is a dotted JSON key path.
##         A command rejection has neither a document nor a line, so reusing `RulesError` would
##         either abuse the reserved 0 forever or carry a permanently dead field.
##       - `CommandError` keeps `RulesError`'s SHAPE — a plain RefCounted of public data fields
##         plus a `format_for(source: String) -> String` renderer — with command-appropriate
##         contents: `code: StringName` + `message: String`.
##       - Codes are **OPAQUE StringNames authored by each Command at its own call site**. There
##         is NO enum, NO const list and NO whitelist (the (AU)(iv) / (T) / (AH) / M0-T3 (f)
##         precedent), so `command_error.gd` may not contain a single code-name literal.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/commands/command_error.gd`.
## They are per-file and inherit NOTHING from the other scan suites.
extends GutTest

const COMMAND_ERROR_PATH: String = "res://scripts/sim/commands/command_error.gd"
const RULES_ERROR_PATH: String = "res://scripts/sim/rules_error.gd"

## The four rejection codes this task's commands author. NONE of them may appear in
## `command_error.gd`: the vocabulary belongs to the rejecting Command's own call site, never to
## the error type (the (AU)(iv) / (T) / (AH) no-whitelist rule).
const REJECTION_CODES: Array[String] = [
	"null_state",
	"no_players",
	"not_current_player",
	"abstract_command",
]

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is on the
## list per M1-T5 (R): `scripts/core/rng.gd` is its SINGLE home in the whole project.
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
	"queue_free(",
]

## §3.2 line 133 "If turn 200 is reached (configurable)" / §12.1 `victory.turn_limit` — M6, and
## explicitly NOT this task. The literal must not appear in any file this task adds.
const VICTORY_TURN_LIMIT_TOKEN: String = "200"

## The COMPLETE public surface of CommandError. `_init` is excluded from the collected list by
## the leading underscore and is pinned separately by construction.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = ["format_for"]
const REQUIRED_PUBLIC_VARS: Array[String] = ["code", "message"]
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§11.1", "§3.3", "§3.4", "§13.4"]


# =============================================================================================
# A. THE SHAPE OF A REJECTION ((AV): code + message, and nothing else)
# =============================================================================================

## (AV)/§11.1 — a CommandError carries exactly the code and message it was constructed with.
func test_a_command_error_carries_its_code_and_message() -> void:
	var error: CommandError = CommandError.new(&"not_current_player", "player 2 may not end turn")
	assert_eq(
		error.code, &"not_current_player", "(AV): the code is the one the Command authored"
	)
	assert_eq(
		error.message, "player 2 may not end turn", "(AV): the message is carried verbatim"
	)


## (AV) — the code is a StringName (an opaque, interned id), not a String and not an enum value.
func test_the_code_is_an_opaque_string_name() -> void:
	var error: CommandError = CommandError.new(&"no_players", "the roster is empty")
	assert_eq(
		typeof(error.code),
		TYPE_STRING_NAME,
		"(AV): rejection codes are opaque StringNames, never enum ints"
	)
	assert_eq(
		typeof(error.message), TYPE_STRING, "(AV): the message is a plain String"
	)


## (AV) — `format_for` mirrors `RulesError.format_for`'s job with command-appropriate contents:
## "<source>: <code>: <message>". The source is the caller's label (a command name, a test name),
## never a file path, because a command rejection has no document.
func test_format_for_renders_source_then_code_then_message() -> void:
	var error: CommandError = CommandError.new(&"null_state", "no state was supplied")
	assert_eq(
		error.format_for("EndTurnCommand"),
		"EndTurnCommand: null_state: no state was supplied",
		"(AV): format_for renders \"<source>: <code>: <message>\""
	)
	assert_eq(
		CommandError.new(&"no_players", "the roster is empty").format_for("replay"),
		"replay: no_players: the roster is empty",
		"(AV): format_for is a pure function of source, code and message"
	)


## (AV) totality (the (B)/(L)/(AS) spirit) — an empty code and an empty message still render,
## rather than tearing down a headless run.
func test_format_for_is_total_on_empty_fields() -> void:
	var error: CommandError = CommandError.new(&"", "")
	assert_eq(error.code, &"", "(AV): an empty code is carried, not rewritten")
	assert_eq(error.message, "", "(AV): an empty message is carried, not rewritten")
	assert_eq(error.format_for(""), ": : ", "(AV): format_for stays total on empty fields")


## (AV) — two errors are independent objects: constructing one must not disturb another.
func test_two_errors_are_independent_objects() -> void:
	var first: CommandError = CommandError.new(&"null_state", "first")
	var second: CommandError = CommandError.new(&"no_players", "second")
	assert_false(is_same(first, second), "(AV): each rejection is its own object")
	assert_eq(first.code, &"null_state", "(AV): the first error keeps its own code")
	assert_eq(second.code, &"no_players", "(AV): the second error keeps its own code")


# =============================================================================================
# B. DELIBERATELY NOT RulesError ((AV): a rejection has no document and no line)
# =============================================================================================

## (AV) — CommandError has NO `line` and NO `path`. `RulesError`'s line 0 is reserved for
## file-level failures (M0-T2 item 2); a command rejection would occupy that reserved value
## forever, and `path` would be permanently dead. This is the whole reason a second error type
## exists, so it is pinned mechanically.
func test_a_command_error_has_no_document_line_and_no_key_path() -> void:
	var declared: Array[String] = _collect_public_vars(COMMAND_ERROR_PATH)
	assert_false(declared.has("line"), "(AV): a command rejection has no document line")
	assert_false(declared.has("path"), "(AV): a command rejection has no dotted key path")
	var error: CommandError = CommandError.new(&"null_state", "no state was supplied")
	assert_null(error.get("line"), "(AV): `line` is not a property of a command rejection")
	assert_null(error.get("path"), "(AV): `path` is not a property of a command rejection")


## (AV) — the fork is genuine in both directions: `RulesError` is UNTOUCHED and still carries the
## document fields that make it the wrong type for a command. If a later task ever merges the two
## vocabularies it has to delete this test and log the reason.
func test_rules_error_is_untouched_and_still_document_shaped() -> void:
	var rules_error: RulesError = RulesError.new()
	assert_eq(rules_error.line, 0, "M0-T2 item 2: RulesError.line 0 is reserved for file-level")
	assert_eq(rules_error.path, "", "M0-T2: RulesError carries a dotted JSON key path")
	assert_eq(rules_error.message, "", "M0-T2: RulesError carries a message")
	assert_false(
		is_same(CommandError, RulesError), "(AV): CommandError and RulesError are distinct types"
	)


# =============================================================================================
# C. MECHANICAL SOURCE SCANS ON scripts/sim/commands/command_error.gd
#    Written FRESH for this file — a new file inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)". Comment stripping
## is LOAD-BEARING: the doc block above cites "§11.1", which `\.[0-9]` would hit.
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(COMMAND_ERROR_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_ERROR_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			COMMAND_ERROR_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % COMMAND_ERROR_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R).
func test_source_is_engine_free() -> void:
	var code: String = _code_text(COMMAND_ERROR_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_ERROR_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				COMMAND_ERROR_PATH, banned
			]
		)


## S3 (AV)/§13.5 — NO CODE-NAME LITERAL AND NO WHITELIST. The error type is a carrier; every code
## is authored at the rejecting Command's own call site (the (AU)(iv) / (T) / (AH) precedent).
func test_source_carries_no_rejection_code_vocabulary() -> void:
	var code: String = _code_text(COMMAND_ERROR_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_ERROR_PATH)
	for rejection: String in REJECTION_CODES:
		assert_false(
			code.contains(rejection),
			"(AV)/§13.5: rejection codes are opaque — %s must not name \"%s\"" % [
				COMMAND_ERROR_PATH, rejection
			]
		)
	assert_false(code.contains("enum "), "(AV): rejection codes are never an enum")


## S4 (AV)/M1-T9 — this file loads no document, so `RulesError` must be ABSENT: a second loader
## must not be able to grow here, and reusing the document error type is exactly what (AV)
## forbids. It must not override `Object.hash()` either (native_method_override, level 2 = a hard
## error under the M0-T4 gate), and §3.2/§12.1's turn limit belongs to M6, not here.
func test_source_declares_no_loader_and_overrides_no_native_method() -> void:
	var code: String = _code_text(COMMAND_ERROR_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % COMMAND_ERROR_PATH)
	assert_false(
		code.contains("RulesError"),
		"(AV): %s must not reuse the document error type" % COMMAND_ERROR_PATH
	)
	assert_false(
		code.contains("func hash("),
		"M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			COMMAND_ERROR_PATH
		]
	)
	assert_false(
		code.contains(VICTORY_TURN_LIMIT_TOKEN),
		"§3.2/§12.1: the turn limit is M6 — %s must not contain %s" % [
			COMMAND_ERROR_PATH, VICTORY_TURN_LIMIT_TOKEN
		]
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % COMMAND_ERROR_PATH
	)


## S5 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (a line, a path, a severity enum, a code
## whitelist) fails too.
func test_public_api_is_exactly_the_documented_members() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(COMMAND_ERROR_PATH, public_functions, undocumented)

	var error: CommandError = CommandError.new(&"null_state", "no state was supplied")
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, COMMAND_ERROR_PATH]
		)
		assert_true(
			error.has_method(required),
			"§11.2: %s must be callable on a CommandError instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			COMMAND_ERROR_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); absent on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(COMMAND_ERROR_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public FIELD surface of %s is exactly %s" % [
			COMMAND_ERROR_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)
	assert_eq(
		_collect_public_consts(COMMAND_ERROR_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"(AV): %s declares NO public const — a code list is exactly what must not exist" % [
			COMMAND_ERROR_PATH
		]
	)


## S6 §11.1/§11.2 — CommandError is a pure [RefCounted] living beside the commands it rejects,
## exactly as `RulesError` sits beside `rules_loader.gd`. Asserted through get_class() — `is Node`
## would be a PARSE ERROR here (M0-T2 item 11 / M0-T5 item (a)).
func test_command_error_is_a_pure_refcounted_beside_the_commands() -> void:
	assert_true(
		FileAccess.file_exists(COMMAND_ERROR_PATH),
		"§11.2: CommandError belongs at %s" % COMMAND_ERROR_PATH
	)
	assert_true(
		FileAccess.file_exists(RULES_ERROR_PATH),
		"sanity: %s is still on disk and untouched" % RULES_ERROR_PATH
	)
	assert_eq(
		CommandError.new(&"null_state", "x").get_class(),
		"RefCounted",
		"§11.1: CommandError must be a pure RefCounted"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

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


## Every top-level public `const` declared by a source file, in source order, so an EXTRA public
## const (a code list, a severity table) fails the scan.
func _collect_public_consts(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with("const "):
			continue
		var rest: String = raw_line.substr(6)
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
