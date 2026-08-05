## DigSite — the §4.2 DIG-SITE PROGRESS RECORD. GDD §4.2 (Hex Types, **the authority for every
## number below**), §7.1 (the Artificial-Granite owner variant that makes `total_turns` a
## per-order value rather than a per-terrain one), §11.1 (pure sim core, stable ID order,
## reproducible FNV content hash), §11.2, §11.3, §13.2 tier 1, §13.4, §13.6, §14 M2.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §4.2 (line 197): "Dig time is total worker-turns; multiple workers on adjacent hexes may work
##        the same target (**max 2 simultaneous diggers per hex**). \"Dig 2x\" halves remaining
##        time (round up)."
##   §4.2 (lines 184-193): the nine Solid rows whose "Dig time (worker-turns)" column is what a
##        site's `total_turns` is CONSTRUCTED from — Hard Rock 2 and Dense Granite 4 are the two
##        the fixtures below use. THE TABLE IS READ THROUGH `DigRules`, never here: this record
##        holds a caller-supplied integer exactly as `UnitState` holds a caller-supplied `max_hp`.
##   §11.1 (line 703): "No Node, no Scene Tree, no engine singletons, no rendering, no
##        **randi()** — the core must run headless byte-identically."
##   §11.1 (line 707): "**Determinism rules:** iterate collections in stable ID order ...
##        GameState.hash() (FNV over canonical serialization) must be reproducible."
##
## `docs/decisions.md` was re-scanned END TO END this iteration: the only logged overrides touching
## §12.1/§4.2 in the whole project are **(AU)(i)** (`dig_yields.artificial_granite.stone = 2`, a
## transcription of §4.2's own "\+2 Stone") and **(AW)(i)** (the new top-level `dig` group binding
## §4.2's terrain ids to §12.1's dig keys — no numeric value moved). NOTHING overrides §4.2's dig
## times, §4.2 line 197, §4.1, §7.1, §3.4 or §11.1, so every printed value below governs unamended.
##
## §4.2 legislates the dig but prints no progress-record API, so the surface below is a §13.4
## resolution lettered **(AY)** ((AU)/(AV)/(AW)/(AX) are cross-referenced by many files — do NOT
## renumber any of them):
##   (AY) THE DIG SITE IS A PURE RECORD, the `UnitState` shape.
##       - IDENTITY IS READ-ONLY: `hex`, `owner_index` and `total_turns` have no setters (the (AX)
##         immutable-identity rule). ONE OWNER PER SITE — a hex being dug is dug *for* somebody.
##       - `remaining_turns` starts at `total_turns` and is written only by `set_remaining_turns`,
##         which is TOTAL and CLAMPS into `[0, total_turns]` (the `UnitState.set_hp` precedent).
##         REACHING 0 DOES NOT REMOVE THE SITE — completion is a RULE (§3.4 step 4), slice 4.
##       - Diggers are a set of unit ids: `digger_ids()` is FRESH and ASCENDING every call,
##         `add_digger` refuses a duplicate and any id <= 0 (roster ids start at 1, 0 means "no
##         unit" — (AX)), `remove_digger` answers true exactly once.
##       - THE CAP IS NOT HERE. §4.2 line 197's "max 2 simultaneous diggers" is a RULE and lives in
##         `DigHexCommand`, read from §12.1 through `DigRules.max_diggers_per_hex()`; the record
##         itself accepts a third digger, and that is pinned POSITIVELY below so the cap cannot
##         quietly migrate into the record where no data feeds it.
##       - THE DOCUMENTED content_hash FOLD ORDER: hex.x -> hex.y -> owner_index -> total_turns ->
##         remaining_turns -> the digger COUNT -> the digger ids ASCENDING. It is COUNT-PREFIXED,
##         so it is injective without a separator byte (contrast `UnitState._SEPARATOR`, which
##         exists only because `type_id` is a variable-length STRING).
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/dig_site.gd`. They are
## per-file and inherit NOTHING from the other scan suites.
extends GutTest

const DIG_SITE_PATH: String = "res://scripts/sim/dig_site.gd"

## §4.1 "axial coordinates (q, r)" — the hexes the fixtures below sit on.
const SAMPLE_HEX: Vector2i = Vector2i(1, -1)
const OTHER_HEX: Vector2i = Vector2i(-2, 3)
const ORIGIN_HEX: Vector2i = Vector2i(0, 0)

## §4.2 line 185 "Hard Rock | 2" and line 186 "Dense Granite | 4" — the two dig times the fixtures
## construct sites with. They are transcribed from the GDD table, but they reach `DigSite` as a
## CALLER-SUPPLIED integer: the record holds no table (`DigRules` owns it, M2-T3).
const HARD_ROCK_TURNS: int = 2
const DENSE_GRANITE_TURNS: int = 4

## (AX) — roster ids start at 1 and 0 means "no unit", so 0 and every negative id are refused.
const NO_UNIT_ID: int = 0

## The 32-bit ceiling every content hash in the project respects (§11.1, M1-T5 (U)).
const HASH_MASK: int = 0xffffffff

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is on the list
## per M1-T5 item 6: `scripts/core/rng.gd` is its SINGLE home in the whole project.
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

## §11.1 "Renderer/UI subscribe; **the sim never calls them**".
const RENDERER_TOKENS: Array[String] = [
	"MapRenderer",
	"CameraRig",
	"HexPicker",
	"HexLayout",
	"MultiMesh",
	"Camera3D",
	"Node3D",
]

## (AW) item 8 / (AX) item 10 — a state RECORD runs no rule and emits nothing. A dig site does not
## know what a Command is, and it must not reach for the dig TABLE either: `DigRules` is the
## Command's dependency, not the record's.
const SPINE_TOKENS: Array[String] = [
	"Command",
	"Event",
	"EventBus",
	"GameState",
	"DigRules",
	"RulesLoader",
	"RulesError",
]

## §4.2's nine Solid-hex terrain ids. FORBIDDEN tokens: there is no terrain-type whitelist in
## engine code (M1-T5 (T) / M1-T7 (AH) / (AU)(iv) / §13.5's M6 canary).
const TERRAIN_IDS: Array[String] = [
	"soft_dirt",
	"hard_rock",
	"dense_granite",
	"artificial_granite",
	"rubble",
	"gold_vein",
	"iron_vein",
	"magestone_crust",
	"mithril_seam",
]

## §5.1's SEVEN resources (lines 277-284). FORBIDDEN tokens: a dig site holds no yield — §3.4 step
## 4's yield APPLICATION is slice 4.
const RESOURCE_IDS: Array[String] = [
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## §12.7 line 1015 ("worker | dig\_mult | Can Dig/Build; dig-speed multiplier"), §5.2 line 293's
## housing cap and §7's four factions. ALL FORBIDDEN: worker-ness is a TRAIT (data), the housing
## cap is a later slice, and `data/units/*.json` is M6.
const VOCABULARY_TOKENS: Array[String] = [
	"worker",
	"dig_mult",
	"housing",
	"dwarves",
	"elves",
	"goblins",
	"orcs",
]

## §13.6 — the printed §4.2/§4.5/§5.1 numbers that must never appear in this record. Only 0 and 1
## are permitted standalone: `total_turns` and every digger id are CALLER-SUPPLIED.
const FORBIDDEN_NUMERALS: Array[String] = [
	"2", "3", "4", "10", "15", "25", "60", "120", "150", "250",
]
const PERMITTED_NUMERALS: Array[String] = ["0", "1"]

## The COMPLETE public surface of DigSite: NINE functions, ZERO public vars, ZERO public consts.
## `_init` is excluded from the collected list by the leading underscore and is pinned separately
## by construction. There is deliberately NO `is_complete()`, NO `tick()` and NO `digger_count()`:
## progress is §3.4 step 4 (slice 4) and the count is `digger_ids().size()`.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"hex",
	"owner_index",
	"total_turns",
	"remaining_turns",
	"set_remaining_turns",
	"digger_ids",
	"add_digger",
	"remove_digger",
	"content_hash",
]
const REQUIRED_PUBLIC_VARS: Array[String] = []
const REQUIRED_PUBLIC_CONSTS: Array[String] = []

## (AY) — the DOCUMENTED fold order, as substrings that must appear in `content_hash()`'s body in
## exactly this sequence. The ORACLE test below is the load-bearing pin; this scan is what stops
## the order drifting silently in a way the oracle's own fixtures happen not to distinguish.
const FOLD_ORDER_TOKENS: Array[String] = [
	"hex.x",
	"hex.y",
	"owner_index",
	"total_turns",
	"remaining_turns",
	"size(",
]

## Doc-comment sections accepted by the S7 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§4.2", "§11.1", "§7.1", "§3.4"]


# =============================================================================================
# A. IDENTITY (§4.2; (AY) "identity is read-only")
# =============================================================================================

## (AY) — every constructor argument is read back VERBATIM, and a fresh site's remaining time is
## its total time: no dig has been done yet.
func test_the_identity_is_carried_verbatim_and_remaining_starts_at_total() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 1, HARD_ROCK_TURNS)
	assert_eq(site.hex(), SAMPLE_HEX, "§4.1: the site knows which hex it is on")
	assert_eq(site.owner_index(), 1, "(AY): ONE owner per dig site — the ordering player")
	assert_eq(site.total_turns(), HARD_ROCK_TURNS, "§4.2: total worker-turns, supplied by the rule")
	assert_eq(
		site.remaining_turns(),
		site.total_turns(),
		"§4.2: \"Dig time is total worker-turns\" — a fresh site has all of them left"
	)

	var deeper: DigSite = DigSite.new(OTHER_HEX, 0, DENSE_GRANITE_TURNS)
	assert_eq(deeper.hex(), OTHER_HEX, "(AY): a second site carries its own hex")
	assert_eq(deeper.owner_index(), 0, "(AY): a second site carries its own owner")
	assert_eq(deeper.total_turns(), DENSE_GRANITE_TURNS, "§4.2: Dense Granite is 4 worker-turns")
	assert_eq(deeper.remaining_turns(), DENSE_GRANITE_TURNS, "§4.2: nothing has been dug yet")


## (AY)/§13.4 — a FRESH site holds NO digger. The order that creates it adds the first one; the
## record never invents one.
func test_a_fresh_site_holds_no_digger() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_eq(site.digger_ids(), [] as Array[int], "(AY): a fresh site has no digger assigned")


## §13.6 — the record holds no TABLE: `total_turns` is whatever the caller supplied, including the
## §7.1 owner variant's 1. Pinned so nobody is tempted to re-derive the dig time in here (that is
## `DigRules`, M2-T3, reading §12.1 data).
func test_the_record_holds_no_dig_table_and_accepts_any_total() -> void:
	for total: int in [1, HARD_ROCK_TURNS, 3, DENSE_GRANITE_TURNS, 99]:
		var site: DigSite = DigSite.new(SAMPLE_HEX, 0, total)
		assert_eq(
			site.total_turns(),
			total,
			"§13.6: the dig TABLE lives in DigRules over §12.1 data — the record just holds %d" % total
		)
		assert_eq(site.remaining_turns(), total, "§4.2: remaining starts at total, whatever it is")


# =============================================================================================
# B. THE DIGGER SET ((AY); §11.1 line 707 "iterate collections in stable ID order")
# =============================================================================================

## §11.1 line 707 — `digger_ids()` is ASCENDING regardless of assignment order. An implementation
## that hands back insertion order passes every other test in this section and dies here.
func test_digger_ids_are_ascending_regardless_of_assignment_order() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(site.add_digger(7), "(AY): the first assignment is accepted")
	assert_eq(site.digger_ids(), [7] as Array[int], "§11.1: one digger, ascending")
	assert_true(site.add_digger(3), "(AY): a second assignment is accepted")
	assert_eq(site.digger_ids(), [3, 7] as Array[int], "§11.1: ASCENDING, not insertion order")
	assert_true(site.add_digger(5), "(AY): the record itself enforces no cap")
	assert_eq(site.digger_ids(), [3, 5, 7] as Array[int], "§11.1: still ascending")


## §11.1/M1-T9 — `digger_ids()` builds a FRESH Array every call. Pinned with an `is_same()`
## IDENTITY assertion AND a mutate-then-re-read pollution check, because a SELF-CLEARING member
## cache passes a pollution-only check (the M1-T9 lesson).
func test_digger_ids_is_a_fresh_array_every_call() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(site.add_digger(1), "sanity: the first assignment is accepted")
	assert_true(site.add_digger(2), "sanity: the second assignment is accepted")
	assert_false(
		is_same(site.digger_ids(), site.digger_ids()),
		"§11.1: digger_ids() must build a FRESH array every call, never hand out a cache"
	)
	var pulled: Array[int] = site.digger_ids()
	pulled.clear()
	pulled.append(-1)
	assert_eq(
		site.digger_ids(),
		[1, 2] as Array[int],
		"§11.1: mutating the returned array must not reach the record"
	)


## (AY) — a DUPLICATE assignment is refused: a unit digs a site once, so "two diggers" always
## means two distinct units (which is what makes §4.2 line 197's cap countable at all).
func test_add_digger_refuses_a_duplicate() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(site.add_digger(4), "(AY): the first assignment is accepted")
	assert_false(site.add_digger(4), "(AY): assigning the same unit twice is refused")
	assert_eq(site.digger_ids(), [4] as Array[int], "(AY): the refusal changed nothing")
	var before: int = site.content_hash()
	assert_false(site.add_digger(4), "(AY): still refused on a third attempt")
	assert_eq(site.content_hash(), before, "(AY): a refused assignment is ATOMIC")


## (AX)/(AY) — 0 means "NO UNIT" and roster ids start at 1, so 0 and every negative id are refused.
## A site holding id 0 would make `dig_site_of_digger(0)` answer a site for "no unit".
func test_add_digger_refuses_id_zero_and_negative_ids() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	var before: int = site.content_hash()
	for bad_id: int in [NO_UNIT_ID, -1, -99]:
		assert_false(
			site.add_digger(bad_id),
			"(AX): ids start at 1 and 0 means \"no unit\" — %d is refused" % bad_id
		)
	assert_eq(site.digger_ids(), [] as Array[int], "(AY): a refused assignment creates no digger")
	assert_eq(site.content_hash(), before, "(AY): every refusal is ATOMIC")


## (AY) totality — `remove_digger` answers true EXACTLY ONCE for an assigned id, false on the
## second call and false for a unit that never dug here (the `GameState.remove_unit` precedent).
func test_remove_digger_is_total_and_answers_true_exactly_once() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(site.add_digger(1), "sanity: id 1 is assigned")
	assert_true(site.add_digger(2), "sanity: id 2 is assigned")
	assert_true(site.remove_digger(1), "(AY): the first removal succeeds")
	assert_false(site.remove_digger(1), "(AY): the second removal is refused")
	for unknown: int in [NO_UNIT_ID, -1, 3, 9999]:
		assert_false(site.remove_digger(unknown), "(AY): removing id %d is refused" % unknown)
	assert_eq(site.digger_ids(), [2] as Array[int], "(AY): only the removed id is gone")
	var before: int = site.content_hash()
	assert_false(site.remove_digger(1), "(AY): still refused")
	assert_eq(site.content_hash(), before, "(AY): a refused removal is ATOMIC")


## §4.2 line 197 NEGATIVE PIN — "max 2 simultaneous diggers per hex" is a RULE read from §12.1
## through `DigRules.max_diggers_per_hex()` and enforced by `DigHexCommand`. THE RECORD ITSELF
## ENFORCES NO CAP: pinned positively so the cap cannot quietly migrate into a file that has no
## data source to read it from (§13.6 — "constants read from data, not code").
func test_the_record_enforces_no_digger_cap() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	for id: int in [1, 2, 3, 4]:
		assert_true(
			site.add_digger(id),
			"§4.2 line 197: the CAP is a Command rule — the record accepts digger %d" % id
		)
	assert_eq(site.digger_ids(), [1, 2, 3, 4] as Array[int], "(AY): the record is a pure container")


# =============================================================================================
# C. PROGRESS ((AY); the `UnitState.set_hp` clamping precedent; §3.4 step 4 is SLICE 4)
# =============================================================================================

## (AY) — `set_remaining_turns` writes the value back verbatim inside the legal band.
func test_set_remaining_turns_writes_inside_the_band() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, DENSE_GRANITE_TURNS)
	for value: int in [DENSE_GRANITE_TURNS, 3, HARD_ROCK_TURNS, 1, 0]:
		site.set_remaining_turns(value)
		assert_eq(site.remaining_turns(), value, "(AY): %d is inside [0, total]" % value)
	assert_eq(site.total_turns(), DENSE_GRANITE_TURNS, "(AY): the total is IDENTITY — it never moves")


## (AY) — TOTAL and CLAMPING, exactly like `UnitState.set_hp`: an overshoot saturates at
## `total_turns` and a negative value floors at 0. Refusing instead of clamping would leave a
## caller's arithmetic error silently invisible in the record.
func test_set_remaining_turns_clamps_into_the_band() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	for overshoot: int in [HARD_ROCK_TURNS + 1, DENSE_GRANITE_TURNS, 9999]:
		site.set_remaining_turns(overshoot)
		assert_eq(
			site.remaining_turns(),
			HARD_ROCK_TURNS,
			"(AY): %d saturates at total_turns, it does not extend the dig" % overshoot
		)
	for undershoot: int in [-1, -99]:
		site.set_remaining_turns(undershoot)
		assert_eq(site.remaining_turns(), 0, "(AY): %d floors at 0" % undershoot)
	assert_eq(site.total_turns(), HARD_ROCK_TURNS, "(AY): the total is never touched by a clamp")


## (AY)/§3.4 step 4 NEGATIVE PIN — REACHING 0 DOES NOT COMPLETE THE DIG. Whether an exhausted site
## applies its yields, turns the hex into Cave and disappears is a RULE (§3.4 step 4: "Dig progress
## ticks; completed digs apply yields, then Breach checks (§4.6), then Noise pings (§4.8)") and is
## SLICE 4. Pinned negatively so this record never grows a hidden rule (the (AX) `set_hp(0)`
## precedent).
func test_reaching_zero_does_not_complete_or_empty_the_site() -> void:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(site.add_digger(1), "sanity: a digger is assigned")
	site.set_remaining_turns(0)
	assert_eq(site.remaining_turns(), 0, "(AY): 0 remaining is representable")
	assert_eq(site.total_turns(), HARD_ROCK_TURNS, "(AY): the total still reads its §4.2 value")
	assert_eq(site.hex(), SAMPLE_HEX, "(AY): the site still knows its hex")
	assert_eq(site.owner_index(), 0, "(AY): the site still knows its owner")
	assert_eq(site.digger_ids(), [1] as Array[int], "§3.4 step 4 is SLICE 4 — the digger stays put")


## (AY) — a total of 0 or less is a DEGENERATE record rather than a crash. `GameState.add_dig_site`
## is the gate that refuses it (pinned in `tests/unit/test_game_state.gd`); the record itself stays
## total in the (B)/(L)/(AS) spirit, and its clamp band collapses to exactly {0}.
func test_a_non_positive_total_is_a_degenerate_but_total_record() -> void:
	for total: int in [0, -1]:
		var site: DigSite = DigSite.new(SAMPLE_HEX, 0, total)
		assert_eq(site.total_turns(), total, "(AY): the record holds what it was given (%d)" % total)
		site.set_remaining_turns(5)
		assert_lte(
			site.remaining_turns(),
			maxi(total, 0),
			"(AY): the clamp band never exceeds max(total, 0) — a degenerate site cannot grow"
		)
		var observed: int = site.content_hash()
		assert_gte(observed, 0, "§11.1: a degenerate record still hashes")
		assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")


# =============================================================================================
# D. content_hash (§11.1 line 707 "FNV over canonical serialization ... must be reproducible")
# =============================================================================================

## §11.1 — identical records hash identically and reproducibly, within 32 bits.
func test_identical_records_hash_identically_and_reproducibly() -> void:
	var first: DigSite = _populated()
	var second: DigSite = _populated()
	assert_eq(first.content_hash(), first.content_hash(), "§11.1: the hash is reproducible")
	assert_eq(first.content_hash(), second.content_hash(), "§11.1: identical records collide")
	var observed: int = first.content_hash()
	assert_gte(observed, 0, "§11.1: a content hash is unsigned")
	assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit (M1-T5 (U))")


## §11.1 — EVERY field of the record reaches the hash: the hex (both components), the owner, the
## total, the remaining time and the digger set. A fold that drops any one of them survives every
## other test in this file and dies here.
func test_every_field_reaches_the_content_hash() -> void:
	var base: int = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS).content_hash()
	assert_ne(
		base,
		DigSite.new(Vector2i(SAMPLE_HEX.x + 1, SAMPLE_HEX.y), 0, HARD_ROCK_TURNS).content_hash(),
		"§11.1: the hex's q is part of the record"
	)
	assert_ne(
		base,
		DigSite.new(Vector2i(SAMPLE_HEX.x, SAMPLE_HEX.y + 1), 0, HARD_ROCK_TURNS).content_hash(),
		"§11.1: the hex's r is part of the record"
	)
	assert_ne(
		base,
		DigSite.new(SAMPLE_HEX, 1, HARD_ROCK_TURNS).content_hash(),
		"(AY): the ORDERING PLAYER is part of the record"
	)
	assert_ne(
		base,
		DigSite.new(SAMPLE_HEX, 0, DENSE_GRANITE_TURNS).content_hash(),
		"§4.2: the total dig time is part of the record"
	)

	var progressed: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	progressed.set_remaining_turns(1)
	assert_ne(base, progressed.content_hash(), "§4.2: the REMAINING time is part of the record")

	var staffed: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(staffed.add_digger(1), "sanity: a digger is assigned")
	assert_ne(base, staffed.content_hash(), "§4.2 line 197: the digger set is part of the record")


## §11.1 line 707 — THE HEX IS FOLDED AS AN ORDERED PAIR, never as an unordered one: the site on
## (1, -1) and the site on (-1, 1) are different sites. A fold that adds or xors the two components
## collides on exactly this pair.
func test_the_hex_is_folded_as_an_ordered_pair() -> void:
	assert_ne(
		DigSite.new(Vector2i(1, -1), 0, HARD_ROCK_TURNS).content_hash(),
		DigSite.new(Vector2i(-1, 1), 0, HARD_ROCK_TURNS).content_hash(),
		"§4.1: (q, r) is ORDERED — a component-symmetric fold collides here"
	)
	assert_ne(
		DigSite.new(Vector2i(2, 0), 0, HARD_ROCK_TURNS).content_hash(),
		DigSite.new(Vector2i(0, 2), 0, HARD_ROCK_TURNS).content_hash(),
		"§4.1: (2, 0) and (0, 2) are different hexes"
	)


## §11.1 — the DIGGER SET is folded as a set of ids, so two sites staffed by different units do not
## collide, and the fold is INDEPENDENT of assignment order (because `digger_ids()` is ascending).
func test_the_digger_set_is_folded_by_id_and_not_by_assignment_order() -> void:
	var one: DigSite = DigSite.new(SAMPLE_HEX, 0, DENSE_GRANITE_TURNS)
	assert_true(one.add_digger(1), "sanity")
	var two: DigSite = DigSite.new(SAMPLE_HEX, 0, DENSE_GRANITE_TURNS)
	assert_true(two.add_digger(2), "sanity")
	assert_ne(
		one.content_hash(), two.content_hash(), "§11.1: WHICH unit digs is part of the record"
	)

	var forwards: DigSite = DigSite.new(SAMPLE_HEX, 0, DENSE_GRANITE_TURNS)
	assert_true(forwards.add_digger(1), "sanity")
	assert_true(forwards.add_digger(2), "sanity")
	var backwards: DigSite = DigSite.new(SAMPLE_HEX, 0, DENSE_GRANITE_TURNS)
	assert_true(backwards.add_digger(2), "sanity")
	assert_true(backwards.add_digger(1), "sanity")
	assert_eq(
		forwards.content_hash(),
		backwards.content_hash(),
		"§11.1 line 707: stable ID order — assignment order is not part of the state"
	)


## §11.1 — THE COUNT PREFIX IS LOAD-BEARING. Without it, "one digger, id 1, remaining 2" and "two
## diggers 1 and 2, remaining 1" could be made to fold the same byte sequence; the count is what
## makes the record injective WITHOUT a separator byte (contrast `UnitState._SEPARATOR`, which
## exists only because `type_id` is variable-length). Also: adding then removing every digger must
## not hash like never having staffed the site's CURRENT digger set — it does, and that is correct,
## because a digger set has no dangling identity to protect.
func test_the_digger_count_prefix_separates_confusable_records() -> void:
	var short_set: DigSite = DigSite.new(ORIGIN_HEX, 0, DENSE_GRANITE_TURNS)
	assert_true(short_set.add_digger(1), "sanity")
	short_set.set_remaining_turns(HARD_ROCK_TURNS)

	var long_set: DigSite = DigSite.new(ORIGIN_HEX, 0, DENSE_GRANITE_TURNS)
	assert_true(long_set.add_digger(1), "sanity")
	assert_true(long_set.add_digger(HARD_ROCK_TURNS), "sanity")
	long_set.set_remaining_turns(1)
	assert_ne(
		short_set.content_hash(),
		long_set.content_hash(),
		"§11.1: the digger COUNT prefix keeps the fold injective without a separator byte"
	)

	var churned: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	assert_true(churned.add_digger(1), "sanity")
	assert_true(churned.remove_digger(1), "sanity")
	assert_eq(
		churned.content_hash(),
		DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS).content_hash(),
		"(AY): a digger set has no dangling identity — assign-then-unassign is the empty set"
	)


## §11.1 "FNV over **canonical serialization**" — THE ORACLE. The expected hash is re-derived here,
## independently, from the DOCUMENTED (AY) fold order using the shared `Fnv` primitives (which are
## themselves pinned against the published FNV-1a 32-bit test vectors in `tests/unit/test_fnv.gd`
## — an EXTERNAL oracle, so this is not a hash pinned against itself):
##
##     OFFSET_BASIS -> hex.x -> hex.y -> owner_index -> total_turns -> remaining_turns
##                  -> digger COUNT -> each digger id, ASCENDING
##
## Deleting or reordering any step reds this test.
func test_content_hash_matches_the_documented_fold_exactly() -> void:
	var samples: Array[DigSite] = [
		DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS),
		DigSite.new(OTHER_HEX, 1, DENSE_GRANITE_TURNS),
		DigSite.new(ORIGIN_HEX, 3, 1),
		_populated(),
	]
	for site: DigSite in samples:
		assert_eq(
			site.content_hash(),
			_expected_hash(site),
			"(AY): content_hash() must equal the DOCUMENTED fold for the site on %s" % str(site.hex())
		)

	var worked: DigSite = _populated()
	worked.set_remaining_turns(1)
	assert_eq(
		worked.content_hash(),
		_expected_hash(worked),
		"(AY): the documented fold still holds after set_remaining_turns"
	)
	var staffed: Array[int] = worked.digger_ids()
	assert_false(staffed.is_empty(), "sanity: the populated fixture carries diggers")
	if staffed.is_empty():
		return
	assert_true(worked.remove_digger(staffed[0]), "sanity: a digger is unassigned")
	assert_eq(
		worked.content_hash(),
		_expected_hash(worked),
		"(AY): the documented fold still holds after remove_digger"
	)


# =============================================================================================
# E. MECHANICAL SOURCE SCANS on scripts/sim/dig_site.gd (§11.1, §11.2, §11.3, §13.4, §13.6)
#    Written FRESH for this file — it inherits NOTHING from the other scan suites. Comment
#    stripping is LOAD-BEARING everywhere below: the header quotes the very rules the scans
#    enforce ("§4.2", "max 2 simultaneous diggers", the terrain ids, ...).
# =============================================================================================

## S1 §11.1 "no float accumulation in rules (integers + fixed percent math)".
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(DIG_SITE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_SITE_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§11.1: integer math only — %s must contain no float literal (found %s)" % [
			DIG_SITE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§11.1: integer math only — %s must not use the float type" % DIG_SITE_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): nothing here divides — %s must not suppress that warning" % DIG_SITE_PATH
	)


## S2 §11.1 "the core must run headless byte-identically" + M1-T5 (R): the ONE
## RandomNumberGenerator lives in `scripts/core/rng.gd`, and the sim never names the renderer.
func test_source_is_engine_free_and_names_no_renderer() -> void:
	var code: String = _code_text(DIG_SITE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_SITE_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/(R): the sim core must be engine-free — %s contains %s" % [DIG_SITE_PATH, banned]
		)
	for banned: String in RENDERER_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim never calls the renderer — %s must not name %s" % [DIG_SITE_PATH, banned]
		)


## S3 (AW) item 8 / (AX) item 10 — A RECORD RUNS NO RULE. `DigSite` names no Command, no Event, no
## EventBus, no GameState and — crucially — no `DigRules`: the §4.2 table is the COMMAND's
## dependency, injected there, and a record that could reach it would be a second place for a dig
## number to live (§13.6).
func test_source_names_no_command_no_event_and_no_rule_source() -> void:
	var code: String = _code_text(DIG_SITE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_SITE_PATH)
	for banned: String in SPINE_TOKENS:
		assert_false(
			code.contains(banned),
			"(AY): a dig-site RECORD holds data only — %s must not name %s" % [DIG_SITE_PATH, banned]
		)
	assert_false(
		code.contains("load_file"),
		"M1-T9: %s loads no document — RulesLoader is the one validator" % DIG_SITE_PATH
	)


## S4 (T)/(AH)/(AU)(iv)/§13.5 — NO TERRAIN, RESOURCE, TRAIT OR FACTION WHITELIST IN ENGINE CODE.
## Adding content must stay a DATA edit (§13.5's M6 zero-engine-change canary). NOTE the
## incidental-substring trap the (AX) scans found: "environment" contains "iron", so this pass runs
## on the COMMENT-STRIPPED, lower-cased source.
func test_source_carries_no_terrain_resource_trait_or_faction_whitelist() -> void:
	var code: String = _code_text(DIG_SITE_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_SITE_PATH)
	for id: String in TERRAIN_IDS:
		assert_false(
			code.contains(id),
			"(T)/(AH): terrain ids are opaque data — %s must not name \"%s\"" % [DIG_SITE_PATH, id]
		)
	for id: String in RESOURCE_IDS:
		assert_false(
			code.contains(id),
			"(AU)(iv): resource ids are opaque data — %s must not name \"%s\"" % [DIG_SITE_PATH, id]
		)
	for token: String in VOCABULARY_TOKENS:
		assert_false(
			code.contains(token),
			"§12.7/§5.2/§7: traits, housing and factions are DATA — %s must not name \"%s\"" % [
				DIG_SITE_PATH, token
			]
		)
	assert_false(code.contains("enum "), "(AU)(iv): the vocabulary is never an enum")


## S5 §13.6 "constants read from data, not code" — NOT ONE printed GDD number may appear in
## `dig_site.gd`. `total_turns` and every digger id are CALLER-SUPPLIED, so the only standalone
## numerals permitted are 0 and 1 (the clamp floor and the lowest legal unit id).
func test_source_hard_codes_no_printed_gdd_number() -> void:
	var code: String = _code_text(DIG_SITE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_SITE_PATH)

	var forbidden: RegEx = RegEx.new()
	assert_eq(
		forbidden.compile("(?<![0-9A-Za-z._])(2|3|4|10|15|25|60|120|150|250)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the forbidden-numeral pattern compiles"
	)
	var hit: RegExMatch = forbidden.search(code)
	assert_null(
		hit,
		"§13.6: §4.2's dig numbers live in data/ruleset.json — %s must not hard-code %s" % [
			DIG_SITE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(FORBIDDEN_NUMERALS.size(), 10, "sanity: every §4.2 dig/vein numeral is covered")

	var numeral: RegEx = RegEx.new()
	assert_eq(
		numeral.compile("(?<![0-9A-Za-z._])([0-9]+)(?![0-9A-Za-z._])"),
		OK,
		"sanity: the standalone-numeral pattern compiles"
	)
	for found: RegExMatch in numeral.search_all(code):
		assert_true(
			PERMITTED_NUMERALS.has(found.get_string()),
			"§13.6: only %s are permitted in %s — found \"%s\"" % [
				str(PERMITTED_NUMERALS), DIG_SITE_PATH, found.get_string()
			]
		)


## S6 M0-T4/(U) — this record must not override `Object.hash()` (`native_method_override` is level
## 2 = a HARD ERROR under the live typing gate, which is why the member is `content_hash`), and it
## must fold through the SHARED `Fnv` helper rather than growing a private copy of the algorithm
## (resolution (AU): one algorithm for the whole project).
func test_source_folds_through_the_shared_helper_and_overrides_no_native_method() -> void:
	var code: String = _code_text(DIG_SITE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % DIG_SITE_PATH)
	assert_false(
		code.contains("func hash("),
		"(U)/M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			DIG_SITE_PATH
		]
	)
	assert_true(
		code.contains("content_hash"),
		"(U): the reproducible §11.1 hash is named content_hash in %s" % DIG_SITE_PATH
	)
	assert_true(
		code.contains("Fnv."),
		"(AU): %s must fold through the shared Fnv helper, never a private copy" % DIG_SITE_PATH
	)


## S7 §11.3 "public rule functions documented with the GDD section they implement (e.g. ## §6.1)".
func test_every_public_function_cites_its_gdd_section() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_SITE_PATH, public_functions, undocumented)
	assert_gt(public_functions.size(), 0, "sanity: %s declares public functions" % DIG_SITE_PATH)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); absent on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)


## S8 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (an identity setter, an `is_complete()`, a
## `tick()`, a `digger_count()`, a serializer) fails too. ZERO public vars and ZERO public consts:
## the record's numbers are caller-supplied and it owns no vocabulary.
func test_public_api_is_exactly_the_nine_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(DIG_SITE_PATH, public_functions, undocumented)

	var site: DigSite = DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS)
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, DIG_SITE_PATH]
		)
		assert_true(
			site.has_method(required), "§11.2: %s must be callable on a DigSite instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			DIG_SITE_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		_collect_public_vars(DIG_SITE_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: %s declares ZERO public vars — the record is reached through its functions" % [
			DIG_SITE_PATH
		]
	)
	assert_eq(
		_collect_public_consts(DIG_SITE_PATH),
		REQUIRED_PUBLIC_CONSTS,
		"§13.6: %s declares ZERO public consts — its numbers are caller-supplied" % DIG_SITE_PATH
	)


## S9 §11.1/§11.2 + (AY) — DigSite is a pure [RefCounted] living in `scripts/sim/` (§11.2 line
## 724's printed list is illustrative — the M0-T3 (f) / M1-T9 (AT) precedent; `unit_state.gd`,
## `player_state.gd` and `hex_map.gd` already live there), and its `content_hash` folds in the
## DOCUMENTED order, which is written into the file's own header because that is where a later
## golden's author will read it. Class kind via get_class() — `is Node` would be a PARSE ERROR.
func test_dig_site_is_a_pure_refcounted_that_folds_in_the_documented_order() -> void:
	assert_true(
		FileAccess.file_exists(DIG_SITE_PATH), "§11.2: DigSite belongs at %s" % DIG_SITE_PATH
	)
	assert_eq(
		DigSite.new(SAMPLE_HEX, 0, HARD_ROCK_TURNS).get_class(),
		"RefCounted",
		"§11.1: DigSite must be a pure RefCounted — never Node/SceneTree"
	)

	var code: String = _code_text(DIG_SITE_PATH)
	var at: int = code.find("func content_hash(")
	assert_ne(at, -1, "sanity: %s declares content_hash()" % DIG_SITE_PATH)
	if at == -1:
		return
	var body: String = code.substr(at)
	var previous: int = -1
	for token: String in FOLD_ORDER_TOKENS:
		var found: int = body.find(token)
		assert_ne(
			found,
			-1,
			"(AY): content_hash() must fold \"%s\" — the documented order is %s" % [
				token, str(FOLD_ORDER_TOKENS)
			]
		)
		if found == -1:
			return
		assert_gt(
			found,
			previous,
			"(AY): the fold order is %s — \"%s\" is out of place" % [str(FOLD_ORDER_TOKENS), token]
		)
		previous = found

	var raw: String = _raw_text(DIG_SITE_PATH)
	var class_at: int = raw.find("class_name DigSite")
	assert_ne(class_at, -1, "sanity: %s declares class_name DigSite" % DIG_SITE_PATH)
	if class_at == -1:
		return
	var header: String = raw.substr(0, class_at)
	assert_true(
		header.contains("remaining_turns"),
		"(AY): %s's header must document remaining_turns in the content_hash fold" % DIG_SITE_PATH
	)
	assert_true(
		header.contains("digger"),
		"(AY): %s's header must document the digger fold (count, then ids ascending)" % DIG_SITE_PATH
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A site with a non-trivial record: a hex with both components non-zero, a non-zero owner, a §4.2
## Dense Granite total, partial progress and two diggers assigned out of order. Built the same way
## every time, so two calls must hash identically.
func _populated() -> DigSite:
	var site: DigSite = DigSite.new(SAMPLE_HEX, 1, DENSE_GRANITE_TURNS)
	assert_true(site.add_digger(5), "fixture: digger 5 is assigned")
	assert_true(site.add_digger(1), "fixture: digger 1 is assigned")
	site.set_remaining_turns(HARD_ROCK_TURNS)
	return site


## THE ORACLE — the documented (AY) fold, re-derived here from the shared `Fnv` primitives:
## hex.x -> hex.y -> owner_index -> total_turns -> remaining_turns -> the digger COUNT -> each
## digger id ascending. Count-prefixed, so no separator byte is needed.
func _expected_hash(site: DigSite) -> int:
	var hash_value: int = Fnv.OFFSET_BASIS
	hash_value = Fnv.fold_int64(hash_value, site.hex().x)
	hash_value = Fnv.fold_int64(hash_value, site.hex().y)
	hash_value = Fnv.fold_int64(hash_value, site.owner_index())
	hash_value = Fnv.fold_int64(hash_value, site.total_turns())
	hash_value = Fnv.fold_int64(hash_value, site.remaining_turns())
	var ids: Array[int] = site.digger_ids()
	hash_value = Fnv.fold_int64(hash_value, ids.size())
	for id: int in ids:
		hash_value = Fnv.fold_int64(hash_value, id)
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


## Every top-level public `const` declared by a source file, in source order.
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
