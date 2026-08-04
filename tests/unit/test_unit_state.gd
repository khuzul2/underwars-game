## UnitState — GDD §11.1 (Layered Design, **binding**), §12.2 (Unit definition), §12.7 (Trait &
## Active Primitives, **binding**), §3.4 step 2, §5.2, §3.1, §11.2 (`scripts/sim/`), §11.3,
## §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §11.1 (line 704): "**GameState**: single serializable object — map (hex array: type,
##         elevation, features, light, stress, knowledge per player), players (stockpiles, techs,
##         meters), **units**, buildings, nodes, turn counters, and **one**
##         **RandomNumberGenerator** **seeded at match start** ..."  — UNITS ARE A TOP-LEVEL
##         GameState COLLECTION, not a PlayerState field. A unit therefore CARRIES its owner as an
##         integer player index; `tests/unit/test_player_state.gd` stays untouched and green.
##   §11.1 (line 703): "No Node, no Scene Tree, no engine singletons, no rendering, no
##         **randi()** — the core must run headless byte-identically."
##   §11.1 (line 707): "**Determinism rules:** iterate collections in stable ID order; no float
##         accumulation in rules ... GameState.hash() (FNV over canonical serialization) must be
##         reproducible."
##   §12.2 (lines 834–852): the unit definition `{"id": "dwarf_crossbow", ... "hp": 70, ...}` —
##         an instance references its definition by the OPAQUE string `id`, and `hp` is a DATA
##         value. `data/units/*.json` is an **M6** deliverable, so `max_hp` is CALLER-SUPPLIED at
##         this slice and there is NO unit stat table and NO unit-type whitelist in engine code.
##   §12.7 (line 1015): "worker | dig\_mult | Can Dig/Build; dig-speed multiplier" — WORKER-NESS
##         IS A TRAIT (data), NOT A CLASS. There is deliberately no `UnitState.is_worker()`, and
##         the tokens `worker`/`dig_mult` are FORBIDDEN in the production file (scan S5).
##   §5.2  (line 293): "**Housing** is the unit cap: HQ +6, each housing building +4." — NOT
##         enforced here: `housing.hq` is already shipped in `data/ruleset.json` and must stay
##         UNUSED. `housing` is a forbidden token in the production files (M2-T4 is a container,
##         not a rule).
##   §3.1  (line 120): "3 Workers, 1 basic T1 combat unit, and stockpiles: 200 Gold, 100 Food,
##         50 Stone, 20 Iron, 0 Magestone, 0 Mithril" — §3.1's starting kit is STILL DEFERRED (it
##         needs its own §12.1 key, decisions.md (AU) item 8); pinned NEGATIVELY by scan S6's
##         forbidden numerals.
##   §3.4 step 2 (line 146): "Deficit: every unpaid unit loses **10% max HP** this turn" — the
##         reason a unit carries BOTH `hp` and `max_hp`. The bleed itself is a later slice.
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §11.1, §12.2, §12.7, §5.2 or §3.1.** (AU)/(AV)/(AW) are the M2 entries and none of them
## touches units. The binding prior resolutions are M1-T5 **(R)** (`scripts/core/rng.gd` is the
## single home of `RandomNumberGenerator`), M1-T5 **(T)** / M1-T7 **(AH)** / M2-T1 **(AU)(iv)**
## (opaque ids — NO vocabulary whitelist in engine code), M1-T8 **(AJ)** (an algorithmic constant
## is a NAMED PRIVATE const, not a §12.1 key), M2-T1 **(AU)** (the `Fnv` fold, `content_hash`
## never `hash`, the separator byte, `is_same()` freshness) and M2-T3 **(AW)** item 8 (a file that
## mutates nothing makes §13.6's *events* clause VACUOUS — that must be SAID, not assumed).
## §11.1 legislates *that* GameState holds units but prints no unit API, so the surface below is a
## §13.4 resolution lettered **(AX)** (M2-T3 ended the lettering at (AW)), to be recorded by Land.
##
## DELIBERATELY NOT BUILT AT M2-T4 (§13.4 — invent nothing ahead of its milestone): §3.1's
## starting kit, §5.2's housing cap, upkeep, income, movement, combat, dig assignment/idle state,
## the §12.7 trait set, buildings, nodes, Extractors and zones. No Command and no Event is added.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/unit_state.gd`. They are
## per-file and inherit NOTHING from the other scan suites.
extends GutTest

const UNIT_STATE_PATH: String = "res://scripts/sim/unit_state.gd"

## §12.2's printed example definition id, and its printed `"hp": 70`. Both are used here as what
## they are at this slice: an OPAQUE string and a CALLER-SUPPLIED integer.
const SAMPLE_TYPE_ID: String = "dwarf_crossbow"
const SAMPLE_MAX_HP: int = 70

## A second id printed by the GDD (§12.3's `"trains": ["dwarf_shield_bearer", ...]`), so this
## suite invents no content of its own.
const OTHER_TYPE_ID: String = "dwarf_shield_bearer"

## The clamp fixture's max HP.
const CLAMP_MAX_HP: int = 60

## The unit ids used by the record tests. Ids are minted by `GameState.spawn_unit` (see
## `tests/unit/test_game_state.gd`); constructing a UnitState directly is how the RECORD is
## tested in isolation.
const SAMPLE_UNIT_ID: int = 1
const OTHER_UNIT_ID: int = 2

## The axial (q, r) positions used here. §4.1: "Flat-top hexes, axial coordinates (q, r)".
const SAMPLE_HEX: Vector2i = Vector2i(2, -3)
const OTHER_HEX: Vector2i = Vector2i(-1, 5)

## (AX) — the record separator byte, the `PlayerState._SEPARATOR` precedent (resolution (AU)).
## It is a PRIVATE const of the production file; the value is restated here because the fold
## ORACLE below re-derives the documented hash independently.
const SEPARATOR: int = 0x1f

## The 32-bit ceiling every content hash must respect (§11.1, M1-T5 (U)).
const HASH_MASK: int = 0xffffffff

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is on the
## list per M1-T5 (R): `scripts/core/rng.gd` is its SINGLE home in the whole project, and a unit
## record has no business owning randomness.
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

## (AV)/(AW) item 8 — a state RECORD names no command and emits nothing itself. The first
## unit-side consumer of the (AV) spine is a LATER slice's Command.
const SPINE_TOKENS: Array[String] = ["GameState", "Command", "Event", "EventBus"]

## §12.7 line 1015 / §12.6 — NO UNIT-TYPE, TRAIT OR FACTION WHITELIST IN ENGINE CODE. `worker` is
## a TRAIT key parameterised by `dig_mult`, i.e. DATA; the four faction ids are data too (§12.6).
## Scanned case-insensitively on comment-stripped source — watch incidental substrings, which is
## why the §5.1 resource ids below are scanned by the same pass ("environment" contains "iron").
const VOCABULARY_TOKENS: Array[String] = [
	"worker",
	"dig_mult",
	"sapper",
	"digger",
	"thrall",
	"dwarves",
	"elves",
	"goblins",
	"orcs",
]

## §5.1's seven resources. FORBIDDEN tokens: a unit record neither pays nor earns (resolution
## (AU)(iv) — the §4.2 terrain-type precedent (T)/(AH)).
const RESOURCE_IDS: Array[String] = [
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §13.6 "constants read from data, not code". Every one of these is a printed GDD number that a
## unit container might be tempted to hard-code: §5.2's housing `+6`/`+4` and Extractor `20`
## Stone, §12.2's `hp 70` / `cost 70 gold, 25 iron` neighbours, §3.1's `200/100/50/20` starting
## kit, §3.2's `turn 200` limit and §7.1's stat-block values. NONE may appear in the production
## file: `max_hp` is caller-supplied and every other number belongs to a later milestone.
const FORBIDDEN_NUMERALS: Array[String] = [
	"3",
	"4",
	"6",
	"20",
	"40",
	"45",
	"50",
	"55",
	"60",
	"70",
	"100",
	"130",
	"200",
	"1000",
]

## The ONLY standalone numerals a comment-stripped `unit_state.gd` may contain (hexadecimal
## literals — i.e. the private `0x1f` separator — are stripped before this pass).
const PERMITTED_NUMERALS: Array[String] = ["0", "1"]

## (AX) — the DOCUMENTED fold order of `UnitState.content_hash()`, as substrings that must appear
## in the function's body in exactly this sequence: the FIXED-WIDTH fields first and the
## VARIABLE-LENGTH `type_id` last, followed by the separator byte, so the record is obviously
## injective. A future golden will record this order; until then this scan is what stops it
## drifting silently (the S8/S9 precedent in `tests/unit/test_game_state.gd`).
const FOLD_ORDER_TOKENS: Array[String] = [
	"_unit_id",
	"_owner_index",
	"_hex.x",
	"_hex.y",
	"_hp",
	"_max_hp",
	"_type_id",
	"_SEPARATOR",
]

## The COMPLETE public surface of UnitState at M2-T4 scope: NINE functions, ZERO public vars and
## ZERO public consts. `_init` is private by name and therefore not listed. There is deliberately
## no `set_unit_id`/`set_owner_index`/`set_type_id` (identity is immutable), no `is_worker()`
## (§12.7: worker is a trait, i.e. data), no `damage()`/`heal()`/`move()` (those are §6/§4 RULES
## and belong to M4), and no `traits`/`tags`/`tier`/`atk`/`arm`/`mov`/`vision` accessor (§12.2
## unit definitions are `data/units/*.json` at M6).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"unit_id",
	"owner_index",
	"type_id",
	"hex",
	"set_hex",
	"hp",
	"max_hp",
	"set_hp",
	"content_hash",
]
const REQUIRED_PUBLIC_VARS: Array[String] = []
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## Doc-comment sections accepted by scan S7 for this file (§11.3 "public rule functions
## documented with the GDD section they implement").
const DOC_SECTIONS: Array[String] = ["§11.1", "§12.2"]


# =============================================================================================
# A. RECORD SEMANTICS (§11.1 line 704 "units"; §12.2 the unit definition)
# =============================================================================================

## §11.1/§12.2 — a UnitState records EXACTLY what it was constructed with: a stable id, the owner
## player INDEX (units are a top-level GameState collection, so the unit carries its owner), the
## opaque definition id, an axial (q, r) position, and hp/max_hp.
func test_a_unit_records_exactly_what_it_was_constructed_with() -> void:
	var gunner: UnitState = UnitState.new(
		SAMPLE_UNIT_ID, 1, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP
	)
	assert_eq(gunner.unit_id(), SAMPLE_UNIT_ID, "§11.1: the unit keeps its stable id")
	assert_eq(gunner.owner_index(), 1, "§11.1 line 704: the OWNER is an integer player index")
	assert_eq(gunner.type_id(), SAMPLE_TYPE_ID, "§12.2: the definition id is an opaque String")
	assert_eq(gunner.hex(), SAMPLE_HEX, "§4.1: the position is an axial (q, r) Vector2i")
	assert_eq(gunner.max_hp(), SAMPLE_MAX_HP, "§12.2: max_hp is CALLER-SUPPLIED until M6")


## §12.2/§3.4 step 2 — a freshly built unit is at FULL health, and `max_hp` never moves: §3.4
## step 2's deficit bleed is "10% **max HP**", so max_hp is the invariant the bleed reads.
func test_hp_starts_at_max_hp_and_max_hp_never_changes() -> void:
	for ceiling: int in [1, CLAMP_MAX_HP, SAMPLE_MAX_HP]:
		var gunner: UnitState = _unit(ceiling)
		assert_eq(gunner.hp(), ceiling, "§12.2: a fresh unit starts at full health")
		assert_eq(gunner.max_hp(), ceiling, "§12.2: max_hp is what it was constructed with")
		gunner.set_hp(0)
		assert_eq(gunner.max_hp(), ceiling, "§3.4 step 2: max_hp is invariant under set_hp")
		gunner.set_hp(ceiling)
		assert_eq(gunner.max_hp(), ceiling, "§3.4 step 2: max_hp is invariant under set_hp")


## (AX) totality (the (B)/(L)/(AS)/(AU) spirit) — `set_hp` is TOTAL and CLAMPS into [0, max_hp]
## rather than refusing or crashing: an overheal saturates at max_hp and overkill floors at 0. A
## unit's hp is never negative and never above its ceiling, whatever a buggy caller asks for.
func test_set_hp_is_total_and_clamps_into_zero_to_max_hp() -> void:
	for requested: int in [-1000, -5, -1, 0, 1, 30, CLAMP_MAX_HP - 1, CLAMP_MAX_HP, 61, 999]:
		var gunner: UnitState = _unit(CLAMP_MAX_HP)
		gunner.set_hp(requested)
		assert_eq(
			gunner.hp(),
			clampi(requested, 0, CLAMP_MAX_HP),
			"(AX): set_hp(%d) clamps into [0, %d]" % [requested, CLAMP_MAX_HP]
		)


## (AX) — the four values the task spec names explicitly, asserted in sequence on ONE unit, so a
## clamp that only works from full health (or only downward) fails here.
func test_the_clamp_holds_across_a_sequence_of_writes() -> void:
	var gunner: UnitState = _unit(CLAMP_MAX_HP)
	gunner.set_hp(999)
	assert_eq(gunner.hp(), CLAMP_MAX_HP, "(AX): an overheal saturates at max_hp")
	gunner.set_hp(-5)
	assert_eq(gunner.hp(), 0, "(AX): overkill floors at 0, never negative")
	gunner.set_hp(CLAMP_MAX_HP)
	assert_eq(gunner.hp(), CLAMP_MAX_HP, "(AX): a unit can be restored to full from 0")
	gunner.set_hp(0)
	assert_eq(gunner.hp(), 0, "(AX): 0 is a legal, representable hp")


## (AX)/§4.1 — `set_hex` moves the unit; the position is the only thing it touches. (That the
## GameState roster's `units_at` buckets follow the move is pinned by
## `tests/unit/test_game_state.gd`, which owns the container.)
func test_set_hex_moves_the_unit_and_touches_nothing_else() -> void:
	var gunner: UnitState = _unit(SAMPLE_MAX_HP)
	gunner.set_hp(CLAMP_MAX_HP)
	gunner.set_hex(OTHER_HEX)
	assert_eq(gunner.hex(), OTHER_HEX, "(AX): set_hex writes the axial position")
	assert_eq(gunner.unit_id(), SAMPLE_UNIT_ID, "(AX): a move does not re-mint the id")
	assert_eq(gunner.owner_index(), 0, "(AX): a move does not change ownership")
	assert_eq(gunner.type_id(), SAMPLE_TYPE_ID, "(AX): a move does not change the definition id")
	assert_eq(gunner.hp(), CLAMP_MAX_HP, "(AX): a move does not heal or hurt")
	assert_eq(gunner.max_hp(), SAMPLE_MAX_HP, "(AX): a move does not change max_hp")


## (AX)/§13.4 — IDENTITY IS READ-ONLY. There is no setter for the id, the owner or the definition
## id: a unit that could change owner or type mid-match would break §11.1's replay contract in a
## way no hash could show. The EXACT-SURFACE scan S8 is the mechanical enforcement; this is the
## readable statement of intent.
func test_identity_has_no_setters() -> void:
	var gunner: UnitState = _unit(SAMPLE_MAX_HP)
	for banned: String in ["set_unit_id", "set_owner_index", "set_type_id", "set_max_hp"]:
		assert_false(
			gunner.has_method(banned),
			"(AX)/§13.4: a unit's identity is immutable — %s must not exist" % banned
		)


## §12.7 line 1015 NEGATIVE PIN — "worker | dig\_mult | Can Dig/Build; dig-speed multiplier" makes
## WORKER-NESS A TRAIT (data), not a class. A UnitState therefore answers no trait question at
## all: the §12.7 primitive set is M4's deliverable and reaches the sim through `data/units/*.json`
## at M6 (§13.5's zero-engine-change canary).
func test_a_unit_answers_no_trait_question_yet() -> void:
	var gunner: UnitState = _unit(SAMPLE_MAX_HP)
	for banned: String in ["is_worker", "has_trait", "traits", "dig_mult", "tags", "tier"]:
		assert_false(
			gunner.has_method(banned),
			"§12.7: worker is a TRAIT, not a class — %s belongs to data, not to UnitState" % banned
		)


# =============================================================================================
# B. THE DOCUMENTED CONTENT HASH (§11.1 line 707 "FNV over canonical serialization")
# =============================================================================================

## §11.1 — two units built identically hash identically, and the hash is stable across calls (no
## wall clock, no counter, no roll drawn just to hash).
func test_identical_units_hash_identically_and_reproducibly() -> void:
	var first: UnitState = UnitState.new(
		SAMPLE_UNIT_ID, 1, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP
	)
	var second: UnitState = UnitState.new(
		SAMPLE_UNIT_ID, 1, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP
	)
	assert_eq(first.content_hash(), first.content_hash(), "§11.1: the hash is reproducible")
	assert_eq(first.content_hash(), second.content_hash(), "§11.1: identical units hash identically")


## §11.1 / M1-T5 (U) — the hash is a 32-bit value, like every other content hash in the project.
func test_content_hash_stays_within_thirty_two_bits() -> void:
	var samples: Array[UnitState] = [
		UnitState.new(0, 0, "", Vector2i.ZERO, 0),
		UnitState.new(SAMPLE_UNIT_ID, 1, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP),
		UnitState.new(9999, 3, OTHER_TYPE_ID, OTHER_HEX, CLAMP_MAX_HP),
	]
	for gunner: UnitState in samples:
		var observed: int = gunner.content_hash()
		assert_gte(observed, 0, "§11.1: a content hash is unsigned")
		assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")


## §11.1 — EVERY field is folded: seven one-field-at-a-time pins, each changing exactly one of
## unit_id / owner_index / hex.x / hex.y / hp / max_hp / type_id and requiring the hash to move.
## A fold that silently drops a field survives every other test in this suite and dies here.
func test_content_hash_folds_the_unit_id() -> void:
	assert_ne(
		UnitState.new(SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP).content_hash(),
		UnitState.new(OTHER_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP).content_hash(),
		"§11.1: the stable unit id is part of the replayable state"
	)


## §11.1 line 704 — the OWNER is part of the state: the same unit under two flags is two states.
func test_content_hash_folds_the_owner_index() -> void:
	assert_ne(
		UnitState.new(SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP).content_hash(),
		UnitState.new(SAMPLE_UNIT_ID, 1, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP).content_hash(),
		"§11.1: which player owns a unit is part of the replayable state"
	)


## §4.1/§11.1 — BOTH axial coordinates are folded. A fold that folds only q (or only r) collides
## on the pair below and nowhere else.
func test_content_hash_folds_both_axial_coordinates() -> void:
	var base: int = _unit_at(Vector2i(2, -3)).content_hash()
	assert_ne(base, _unit_at(Vector2i(5, -3)).content_hash(), "§4.1: q (hex.x) is folded")
	assert_ne(base, _unit_at(Vector2i(2, 4)).content_hash(), "§4.1: r (hex.y) is folded")
	assert_ne(
		_unit_at(Vector2i(2, -3)).content_hash(),
		_unit_at(Vector2i(-3, 2)).content_hash(),
		"§4.1: q and r are folded in a FIXED order — swapping them is a different hex"
	)


## §3.4 step 2/§11.1 — current hp is part of the state (a damaged unit is not a fresh one).
func test_content_hash_folds_the_current_hp() -> void:
	var gunner: UnitState = _unit(SAMPLE_MAX_HP)
	var full: int = gunner.content_hash()
	gunner.set_hp(SAMPLE_MAX_HP - 1)
	assert_ne(full, gunner.content_hash(), "§3.4: a damaged unit is a different state")
	gunner.set_hp(SAMPLE_MAX_HP)
	assert_eq(full, gunner.content_hash(), "§11.1: restoring the hp restores the hash exactly")


## §3.4 step 2/§11.1 — max_hp is folded INDEPENDENTLY of hp: two units on the same current hp but
## with different ceilings bleed differently ("10% max HP"), so they are different states. A fold
## that folds only `hp` (because a fresh unit's hp equals its max_hp) dies exactly here.
func test_content_hash_folds_max_hp_independently_of_hp() -> void:
	var small: UnitState = UnitState.new(
		SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, CLAMP_MAX_HP
	)
	var large: UnitState = UnitState.new(
		SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP
	)
	small.set_hp(1)
	large.set_hp(1)
	assert_eq(small.hp(), large.hp(), "fixture: both units are on the same current hp")
	assert_ne(small.max_hp(), large.max_hp(), "fixture: only the ceiling differs")
	assert_ne(
		small.content_hash(),
		large.content_hash(),
		"§3.4 step 2: max_hp is folded independently of hp"
	)


## §12.2/§11.1 — the opaque definition id is folded, including between ids where one is a PREFIX
## of the other (a length-blind fold collides on that pair).
func test_content_hash_folds_the_opaque_type_id() -> void:
	var base: int = _unit_typed(SAMPLE_TYPE_ID).content_hash()
	assert_ne(base, _unit_typed(OTHER_TYPE_ID).content_hash(), "§12.2: the definition id is folded")
	assert_ne(
		_unit_typed("dwarf").content_hash(),
		_unit_typed("dwarf_crossbow").content_hash(),
		"§11.1: a prefix and its extension are different definitions"
	)
	assert_ne(
		_unit_typed("").content_hash(),
		_unit_typed("dwarf").content_hash(),
		"§11.1: the empty definition id is not the same state as a named one"
	)


## §11.1 "FNV over **canonical serialization**" — THE ORACLE. The expected hash is re-derived
## here, independently, from the DOCUMENTED fold order using the shared `Fnv` primitives (which
## are themselves pinned against the published FNV-1a 32-bit test vectors in
## `tests/unit/test_fnv.gd` — an EXTERNAL oracle, so this is not a hash pinned against itself):
##
##     OFFSET_BASIS -> unit_id -> owner_index -> hex.x -> hex.y -> hp -> max_hp
##                  -> type_id's UTF-8 bytes -> the separator byte 0x1f
##
## This is what makes every part of the record's serialization LOAD-BEARING at once: the field
## set, the fixed-width-fields-first ordering, the variable-length `type_id` last, and the
## terminating separator (the `PlayerState` precedent, resolution (AU)). Deleting or reordering
## any step reds this test. NOTE FOR VERIFY: unlike `PlayerState`, a UnitState's separator cannot
## be killed by a confusable-id fixture — every field before `type_id` is fixed-width, so the
## record is already injective without it; the separator is kept for symmetry with `PlayerState`
## and is pinned HERE (and by scan S3) rather than by a construction that cannot exist.
func test_content_hash_matches_the_documented_fold_exactly() -> void:
	var samples: Array[UnitState] = [
		UnitState.new(SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP),
		UnitState.new(OTHER_UNIT_ID, 3, OTHER_TYPE_ID, OTHER_HEX, CLAMP_MAX_HP),
		UnitState.new(1, 0, "", Vector2i.ZERO, 1),
	]
	for gunner: UnitState in samples:
		assert_eq(
			gunner.content_hash(),
			_expected_hash(gunner),
			"(AX): content_hash() must equal the DOCUMENTED fold for %s" % gunner.type_id()
		)

	var moved: UnitState = UnitState.new(
		SAMPLE_UNIT_ID, 1, SAMPLE_TYPE_ID, SAMPLE_HEX, SAMPLE_MAX_HP
	)
	moved.set_hex(OTHER_HEX)
	moved.set_hp(CLAMP_MAX_HP)
	assert_eq(
		moved.content_hash(),
		_expected_hash(moved),
		"(AX): the documented fold still holds after set_hex/set_hp"
	)


# =============================================================================================
# C. MECHANICAL SOURCE SCANS on scripts/sim/unit_state.gd (§11.1, §11.2, §11.3, §13.4, §13.6)
#    NINE scans, written FRESH for this file — a new file inherits NOTHING from the other suites.
#    Comment stripping is LOAD-BEARING everywhere below: the header quotes the very rules the
#    scans enforce ("§11.1", "worker | dig\_mult", "hp": 70, ...).
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(UNIT_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % UNIT_STATE_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			UNIT_STATE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % UNIT_STATE_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R): there is exactly ONE
## RandomNumberGenerator in the program and it lives in `scripts/core/rng.gd`.
func test_source_is_engine_free_and_builds_no_second_rng() -> void:
	var code: String = _code_text(UNIT_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % UNIT_STATE_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [
				UNIT_STATE_PATH, banned
			]
		)


## S3 M1-T9 / M0-T4 — this file loads NO document, so `RulesError` must be ABSENT (a second
## loader must not be able to grow here) and there is no `errors` var; and it must NOT override
## `Object.hash()` (`native_method_override` is level 2 = a hard error under the live typing
## gate, which is why the member is `content_hash` — M1-T5 (U)). The shared `Fnv` fold and the
## private separator const are required PRESENT: one algorithm for the whole project (AU).
func test_source_declares_no_loader_and_overrides_no_native_method() -> void:
	var code: String = _code_text(UNIT_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % UNIT_STATE_PATH)
	assert_false(
		code.contains("RulesError"),
		"M1-T9: %s loads no document and must not carry the document error type" % UNIT_STATE_PATH
	)
	assert_false(
		code.contains("load_file"),
		"M1-T9: %s must not load a document — RulesLoader is the one validator" % UNIT_STATE_PATH
	)
	assert_false(
		code.contains("func hash("),
		"(U)/M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			UNIT_STATE_PATH
		]
	)
	assert_true(
		code.contains("content_hash"),
		"(U): the reproducible §11.1 hash is named content_hash in %s" % UNIT_STATE_PATH
	)
	assert_true(
		code.contains("Fnv."),
		"(AU): %s must fold through the shared Fnv helper, never a private copy" % UNIT_STATE_PATH
	)
	var separator: RegEx = RegEx.new()
	assert_eq(
		separator.compile("const\\s+_[A-Z][A-Z0-9_]*\\s*:\\s*int\\s*=\\s*0x1f\\b"),
		OK,
		"sanity: the separator-const pattern compiles"
	)
	assert_not_null(
		separator.search(code),
		(
			"(AU)/(AJ): the record separator must be a NAMED PRIVATE const "
			+ "(`const _SOME_NAME: int = 0x1f`) in %s, never a bare literal" % UNIT_STATE_PATH
		)
	)


## S4 (AV)/(AW) item 8 NEGATIVE PIN — a state RECORD names no command and emits nothing itself.
## M2-T4 adds NO Command and NO Event at all, so §13.6's "events emitted for every state change"
## clause is VACUOUS for this slice; that has to be SAID (decisions.md (AX)), not assumed.
func test_source_names_no_command_and_no_event() -> void:
	var code: String = _code_text(UNIT_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % UNIT_STATE_PATH)
	for banned: String in SPINE_TOKENS:
		assert_false(
			code.contains(banned),
			"(AW) item 8: a unit RECORD emits nothing — %s must not name %s" % [
				UNIT_STATE_PATH, banned
			]
		)


## S5 §12.7 line 1015 / §12.6 / (T)/(AH)/(AU)(iv)/§13.5 — NO UNIT-TYPE, TRAIT, FACTION OR
## RESOURCE WHITELIST IN ENGINE CODE. `type_id` is an OPAQUE String exactly as terrain ids and
## resource ids are; adding a unit type must stay a DATA edit (§13.5's M6 canary).
func test_source_carries_no_unit_type_trait_or_resource_whitelist() -> void:
	var code: String = _code_text(UNIT_STATE_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % UNIT_STATE_PATH)
	for token: String in VOCABULARY_TOKENS:
		assert_false(
			code.contains(token),
			"§12.7/§12.6: traits and factions are DATA — %s must not name \"%s\"" % [
				UNIT_STATE_PATH, token
			]
		)
	for token: String in RESOURCE_IDS:
		assert_false(
			code.contains(token),
			"(AU)(iv): resource ids are opaque data — %s must not name \"%s\"" % [
				UNIT_STATE_PATH, token
			]
		)
	assert_false(code.contains("housing"), "§5.2: the housing cap is a LATER slice, not a record")
	assert_false(code.contains("enum "), "(AU)(iv): the vocabulary is never an enum")


## S6 §13.6 "constants read from data, not code" — NOT ONE printed GDD number may appear in
## `unit_state.gd`. `max_hp` is CALLER-SUPPLIED (§12.2's `data/units/*.json` is M6), §5.2's
## housing numbers and §3.1's starting kit belong to later slices, and the container holds no
## stat table at all. The ONLY standalone numerals permitted are 0 and 1 (clamp bounds), plus the
## private `0x1f` separator, which is stripped as a hexadecimal literal before the second pass.
func test_source_hard_codes_no_printed_gdd_number() -> void:
	var code: String = _code_text(UNIT_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % UNIT_STATE_PATH)

	var forbidden: RegEx = RegEx.new()
	assert_eq(
		forbidden.compile(
			"(?<![0-9._])(3|4|6|20|40|45|50|55|60|70|100|130|200|1000)(?![0-9._])"
		),
		OK,
		"sanity: the forbidden-numeral pattern compiles"
	)
	var hit: RegExMatch = forbidden.search(code)
	assert_null(
		hit,
		"§13.6: unit numbers live in data/units/*.json (M6) — %s must not hard-code %s" % [
			UNIT_STATE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(FORBIDDEN_NUMERALS.size(), 14, "sanity: every printed GDD numeral is covered")

	var hex_literal: RegEx = RegEx.new()
	assert_eq(hex_literal.compile("0[xX][0-9a-fA-F]+"), OK, "sanity: the hex pattern compiles")
	var without_hex: String = hex_literal.sub(code, " ", true)
	var numeral: RegEx = RegEx.new()
	assert_eq(
		numeral.compile("(?<![0-9A-Za-z._])([0-9]+)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the standalone-numeral pattern compiles"
	)
	for found: RegExMatch in numeral.search_all(without_hex):
		assert_true(
			PERMITTED_NUMERALS.has(found.get_string()),
			"§13.6: only %s are permitted in %s — found \"%s\"" % [
				str(PERMITTED_NUMERALS), UNIT_STATE_PATH, found.get_string()
			]
		)


## S7 §11.3 "public rule functions documented with the GDD section they implement (e.g. ## §6.1)".
func test_every_public_function_cites_its_gdd_section() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(UNIT_STATE_PATH, public_functions, undocumented)
	assert_gt(public_functions.size(), 0, "sanity: %s declares public functions" % UNIT_STATE_PATH)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); absent on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)


## S8 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (an identity setter, a trait query, a §12.2
## stat accessor, a serializer) fails too. ZERO public vars and ZERO public consts: a unit's
## numbers are caller-supplied and its separator is a private algorithmic constant ((AJ)).
func test_public_api_is_exactly_the_nine_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(UNIT_STATE_PATH, public_functions, undocumented)

	var gunner: UnitState = _unit(SAMPLE_MAX_HP)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, UNIT_STATE_PATH]
		)
		assert_true(
			gunner.has_method(required),
			"§11.2: %s must be callable on a UnitState instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			UNIT_STATE_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		_collect_public_vars(UNIT_STATE_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: %s declares ZERO public vars — the record is reached through its functions" % [
			UNIT_STATE_PATH
		]
	)
	assert_eq(
		_collect_public_consts(UNIT_STATE_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.6: %s declares ZERO public consts — its numbers are caller-supplied" % UNIT_STATE_PATH
	)


## S9 §11.1/§11.2 + (AX) — UnitState is a pure [RefCounted] living in `scripts/sim/` (§11.2 line
## 724's printed list is illustrative — the (f)/(AT) precedent — and `player_state.gd`/`hex_map.gd`
## already live there), and its `content_hash` folds in the DOCUMENTED order, documented in the
## file's own header because that is where a later golden's author will read it. Class kind is
## asserted through get_class() — `is Node` would be a PARSE ERROR here (M0-T2 item 11).
func test_unit_state_is_a_pure_refcounted_that_folds_in_the_documented_order() -> void:
	assert_true(
		FileAccess.file_exists(UNIT_STATE_PATH), "§11.2: UnitState belongs at %s" % UNIT_STATE_PATH
	)
	assert_eq(
		_unit(SAMPLE_MAX_HP).get_class(),
		"RefCounted",
		"§11.1: UnitState must be a pure RefCounted — never Node/SceneTree"
	)

	var code: String = _code_text(UNIT_STATE_PATH)
	var at: int = code.find("func content_hash(")
	assert_ne(at, -1, "sanity: %s declares content_hash()" % UNIT_STATE_PATH)
	if at == -1:
		return
	var body: String = code.substr(at)
	var previous: int = -1
	for token: String in FOLD_ORDER_TOKENS:
		var found: int = body.find(token)
		assert_ne(
			found,
			-1,
			"(AX): content_hash() must fold \"%s\" — the documented order is %s" % [
				token, str(FOLD_ORDER_TOKENS)
			]
		)
		if found == -1:
			return
		assert_gt(
			found,
			previous,
			"(AX): the fold order is %s — \"%s\" is out of place" % [
				str(FOLD_ORDER_TOKENS), token
			]
		)
		previous = found

	var raw: String = _raw_text(UNIT_STATE_PATH)
	var class_at: int = raw.find("class_name UnitState")
	assert_ne(class_at, -1, "sanity: %s declares class_name UnitState" % UNIT_STATE_PATH)
	if class_at == -1:
		return
	var header: String = raw.substr(0, class_at)
	assert_true(
		header.contains("_SEPARATOR"),
		"(AX): %s's header must document the separator in the content_hash fold" % UNIT_STATE_PATH
	)
	assert_true(
		header.contains("type_id"),
		"(AX): %s's header must document the fold order, type_id LAST" % UNIT_STATE_PATH
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A unit owned by player 0, of §12.2's printed definition id, at SAMPLE_HEX, with `ceiling` max
## HP (and therefore `ceiling` current HP).
func _unit(ceiling: int) -> UnitState:
	return UnitState.new(SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, SAMPLE_HEX, ceiling)


## The same unit at a different axial position.
func _unit_at(where: Vector2i) -> UnitState:
	return UnitState.new(SAMPLE_UNIT_ID, 0, SAMPLE_TYPE_ID, where, SAMPLE_MAX_HP)


## The same unit under a different opaque definition id.
func _unit_typed(definition_id: String) -> UnitState:
	return UnitState.new(SAMPLE_UNIT_ID, 0, definition_id, SAMPLE_HEX, SAMPLE_MAX_HP)


## THE ORACLE — the documented (AX) fold, re-derived here from the shared `Fnv` primitives:
## unit_id -> owner_index -> hex.x -> hex.y -> hp -> max_hp -> type_id's UTF-8 bytes -> the
## separator byte. Fixed-width fields first, the variable-length id last.
func _expected_hash(gunner: UnitState) -> int:
	var hash_value: int = Fnv.OFFSET_BASIS
	hash_value = Fnv.fold_int64(hash_value, gunner.unit_id())
	hash_value = Fnv.fold_int64(hash_value, gunner.owner_index())
	hash_value = Fnv.fold_int64(hash_value, gunner.hex().x)
	hash_value = Fnv.fold_int64(hash_value, gunner.hex().y)
	hash_value = Fnv.fold_int64(hash_value, gunner.hp())
	hash_value = Fnv.fold_int64(hash_value, gunner.max_hp())
	hash_value = Fnv.fold_string(hash_value, gunner.type_id())
	hash_value = Fnv.fold_byte(hash_value, SEPARATOR)
	return hash_value


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


## Every top-level public `var` declared by a source file, in source order.
func _collect_public_vars(path: String) -> Array[String]:
	return _collect_declarations(path, "var ")


## Every top-level public `const` declared by a source file, in source order.
func _collect_public_consts(path: String) -> Array[String]:
	return _collect_declarations(path, "const ")


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
