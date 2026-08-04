## PlayerState — GDD §5.1 (Resources; "No storage caps. Stockpiles are per-player integers"),
## §3.4 step 2 (upkeep deficit), §11.1 (the single serializable state object and its reproducible
## FNV content hash), §11.2 (`scripts/sim/`), §11.3, §13.2 tier 1, §13.6.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §5.1 (line 288): "No storage caps. Stockpiles are per-player integers; income/expense
##                     preview shown in HUD."
##   §5.1 table (lines 277-285): the SEVEN resources — **Food**, **Gold**, **Stone**, **Iron**,
##                     **Magestone**, **Mithril**, and **Scrap** *(Goblin-only)*.
##   §3.4 step 2 (line 146): "Upkeep: pay Food/Gold per unit. **Deficit: every unpaid unit loses
##                     10% max HP this turn** (prioritize paying highest-tier first
##                     automatically)." — a shortage is paid in HP, so a stockpile NEVER goes
##                     negative and `spend` must refuse ATOMICALLY instead.
##   §11.1 (line 707): "GameState.hash() (FNV over canonical serialization) must be reproducible."
##   §11.1 (line 707): "**Determinism rules:** iterate collections in stable ID order".
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §5.1 or §3.4**. §5.1 legislates the resource VOCABULARY and the "no caps, per-player integers"
## shape, and nothing else — no API, no order, no negative-balance rule — so the surface below is
## a §13.4 resolution lettered **(AU)** (M1-T9 ended the lettering at (AT)), recorded by Land:
##   (AU) PlayerState stockpiles.
##       - A stockpile is an honest 64-bit integer (§5.1 "No storage caps"), never a
##         PackedInt32Array slot.
##       - `add(id, amount)` is TOTAL (the M1-T1 (B) / M1-T3 (L) spirit): `amount <= 0` or an
##         EMPTY id is REFUSED (false) and creates no entry, rather than aborting a headless run.
##       - `spend(id, amount)` REFUSES ATOMICALLY rather than going negative — §3.4 step 2 pays a
##         shortage in HP, so a negative stockpile is not a state this game has.
##       - ZERO ENTRIES ARE REMOVED: "never had it" and "spent it all" are indistinguishable, so
##         `content_hash` is a function of the OBSERVABLE stockpile only.
##       - `can_afford` is EXACTLY the `spend` predicate.
##       - CANONICAL ORDER is ASCENDING id (String order), independent of insertion order, and
##         `resource_ids()` is a FRESH array per call.
##       - RESOURCE IDS ARE OPAQUE STRINGS: there is NO whitelist in engine code, on the §4.2
##         terrain-type precedent (M1-T5 (T) / M1-T7 (AH)). §5.1's seven-id vocabulary is pinned
##         BY TEST, never by an enum or a `const` in `.gd`.
##
## DELIBERATELY NOT IN M2-T1 (§13.4 — invent nothing ahead of its milestone): §3.1's starting kit
## (200 Gold / 100 Food / 50 Stone / 20 Iron / 0 Magestone / 0 Mithril) needs a NEW ruleset key
## and therefore its own §12.1 amendment in a later task, so every player starts EMPTY here; and
## techs, meters, units, buildings, housing and upkeep all belong to later M2/M3/M6 slices.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY.
##
## The source scans at the bottom are written FRESH for `scripts/sim/player_state.gd`. They are
## per-file and inherit NOTHING from `test_hex_map.gd` or `test_map_generator.gd`.
extends GutTest

const PLAYER_STATE_PATH: String = "res://scripts/sim/player_state.gd"

## §5.1's seven resources, as lowercase snake ids. These are the SAME ids §12.1's `dig_yields`
## and `vein_nodes` already use in `data/ruleset.json` ("food", "stone", "gold", "iron",
## "magestone", "mithril"), so the vocabulary is data-sourced, not invented; "scrap" is §5.1's
## seventh row (§7.3, Goblin-only — still just an id to this container).
const RESOURCE_IDS: Array[String] = [
	"food",
	"gold",
	"stone",
	"iron",
	"magestone",
	"mithril",
	"scrap",
]

## An id §5.1 does not name. It must round-trip exactly like the seven above: ids are OPAQUE.
const UNKNOWN_ID: String = "zzz_not_a_gdd_resource"

## Working amount for the spend/afford sweeps.
const HELD: int = 200

## §5.1 "No storage caps" — larger than 2^31-1, so a PackedInt32Array store goes red here.
const BIG_AMOUNT: int = 5000000000

## 2^32. Two amounts differing only ABOVE 32 bits must hash differently (a 4-byte fold collides).
const OVER_32: int = 4294967296

## Bytes an amount occupies in the canonical serialization (resolution (AU): `Fnv.fold_int64`).
const AMOUNT_BYTES: int = 8

## Fixture for the SEPARATOR pin below. `RUN_TOGETHER_AMOUNT`'s eight little-endian bytes are all
## `0x78` = "x", so the id/amount pair `("a", RUN_TOGETHER_AMOUNT)` serialises to the very bytes
## that spell the single id `"a" + "xxxxxxxx" + "b"`. Two DIFFERENT stockpiles, one byte stream —
## unless a separator ends each pair. Ids are opaque (resolution (AU)), so these are legal ids.
const RUN_TOGETHER_FIRST_ID: String = "a"
const RUN_TOGETHER_SECOND_ID: String = "b"
const RUN_TOGETHER_AMOUNT: int = 0x7878787878787878

## The 32-bit ceiling every content hash must respect (§11.1, M1-T5 (U)).
const HASH_MASK: int = 0xffffffff

## §11.1 — tokens that would make the sim core engine-bound. `RandomNumberGenerator` is on the
## list per M1-T5 item 6: `scripts/core/rng.gd` is its single home in the whole project, and a
## stockpile container has no business owning randomness.
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

## §4.1's radii and hex counts are tunable content in data/mapgen/*.json — never in sim code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface of PlayerState. Six, no more: an `income`, `upkeep`,
## `set_amount`, `clear` or `to_dict` would invent API ahead of the milestone that needs it
## (§13.4). Deliberately no `set_amount`: every mutation is add/spend, so no caller can write a
## negative balance past the atomic refusal.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"amount_of",
	"add",
	"spend",
	"can_afford",
	"resource_ids",
	"content_hash",
]

## The COMPLETE public FIELD surface: none. The storage stays private so canonical order can
## never be bypassed by a caller iterating the raw container (§11.1 "stable ID order").
const REQUIRED_PUBLIC_VARS: Array[String] = []

## Doc-comment sections accepted by the S6 scan for this file (§11.3).
const DOC_SECTIONS: Array[String] = ["§5.1", "§3.4", "§11.1"]


# =============================================================================================
# A. A FRESH PLAYER (§5.1; §3.1's starting kit is DEFERRED — see the header)
# =============================================================================================

## §5.1 — a fresh player holds nothing at all, and asking about an id it never heard of answers
## 0 rather than failing. `add`/`spend` are the only ways stock ever appears.
func test_a_fresh_player_holds_nothing() -> void:
	var player: PlayerState = PlayerState.new()
	assert_eq(
		player.resource_ids(),
		[] as Array[String],
		"§5.1: a fresh PlayerState holds no resources (§3.1's starting kit is a later task)"
	)
	for id: String in RESOURCE_IDS:
		assert_eq(player.amount_of(id), 0, "§5.1: a fresh player holds 0 %s" % id)
	assert_eq(player.amount_of(UNKNOWN_ID), 0, "(AU): an unknown id answers 0, it does not fail")
	assert_eq(player.amount_of(""), 0, "(AU): the empty id answers 0, it does not fail")


## §11.1 — two fresh players are the same state, so they hash the same. This is the baseline the
## "spent it all == never had it" pin below compares against.
func test_two_fresh_players_hash_identically() -> void:
	assert_eq(
		PlayerState.new().content_hash(),
		PlayerState.new().content_hash(),
		"§11.1: identical state must hash identically"
	)


## §11.1 — two PlayerStates share no storage. A `static`/`const` Dictionary would make every
## player in a match the same player (the M1-T2 trap-1 family, re-pinned in its sixth file).
func test_two_players_share_no_storage() -> void:
	var first: PlayerState = PlayerState.new()
	var second: PlayerState = PlayerState.new()
	assert_true(first.add("gold", HELD), "sanity: the deposit is accepted")
	assert_eq(first.amount_of("gold"), HELD, "§5.1: the deposit landed in the first player")
	assert_eq(second.amount_of("gold"), 0, "§11.1: two players must not share storage")
	assert_eq(
		second.resource_ids(), [] as Array[String], "§11.1: two players must not share storage"
	)


# =============================================================================================
# B. THE §5.1 VOCABULARY, AS OPAQUE IDS
# =============================================================================================

## §5.1 — all SEVEN resources round-trip, and so does an id §5.1 never named: ids are OPAQUE
## strings to this container (resolution (AU), the §4.2 terrain-type precedent M1-T5 (T)). The
## vocabulary is pinned here, by test, and NOWHERE in engine code — scan S3 enforces that.
func test_every_resource_id_round_trips_and_ids_are_opaque() -> void:
	var player: PlayerState = PlayerState.new()
	var amount: int = 1
	for id: String in RESOURCE_IDS:
		assert_true(player.add(id, amount), "§5.1: %s must be storable" % id)
		amount += 1
	assert_true(player.add(UNKNOWN_ID, 99), "(AU): resource ids are opaque — no whitelist")

	var expected: int = 1
	for id: String in RESOURCE_IDS:
		assert_eq(player.amount_of(id), expected, "§5.1: %s round-trips exactly" % id)
		expected += 1
	assert_eq(player.amount_of(UNKNOWN_ID), 99, "(AU): an unnamed id round-trips like any other")
	assert_eq(
		player.resource_ids().size(),
		RESOURCE_IDS.size() + 1,
		"§5.1: all seven resources plus the opaque id are held simultaneously"
	)


## §5.1 "No storage caps" — a stockpile is an honest 64-bit integer. 5,000,000,000 exceeds
## 2^31-1, so a PackedInt32Array store (or a 32-bit clamp) goes red here.
func test_stockpiles_have_no_storage_cap() -> void:
	var player: PlayerState = PlayerState.new()
	assert_true(player.add("gold", BIG_AMOUNT), "§5.1: no storage caps")
	assert_eq(player.amount_of("gold"), BIG_AMOUNT, "§5.1: no storage caps — 64-bit exact")
	assert_true(player.add("gold", BIG_AMOUNT), "§5.1: no storage caps")
	assert_eq(
		player.amount_of("gold"),
		BIG_AMOUNT + BIG_AMOUNT,
		"§5.1: repeated deposits accumulate exactly, with no cap"
	)


# =============================================================================================
# C. add — TOTAL, AND STRICTLY POSITIVE (resolution (AU), the M1-T1 (B) spirit)
# =============================================================================================

## (AU) — `add` accepts a strictly positive amount under a non-empty id, and REFUSES anything
## else without creating an entry. Totality: a bad argument must never tear down a headless run.
func test_add_refuses_non_positive_amounts_and_the_empty_id() -> void:
	var player: PlayerState = PlayerState.new()
	for amount: int in [0, -1, -HELD]:
		assert_false(player.add("gold", amount), "(AU): add(%d) must be refused" % amount)
	assert_false(player.add("", 1), "(AU): the empty id is not a resource")
	assert_false(player.add("", 0), "(AU): the empty id is not a resource")
	assert_eq(player.amount_of("gold"), 0, "(AU): a refused add creates nothing")
	assert_eq(player.amount_of(""), 0, "(AU): a refused add creates nothing")
	assert_eq(
		player.resource_ids(),
		[] as Array[String],
		"(AU): a refused add must not create an entry — the player is still empty"
	)


## (AU) — a refused add leaves an EXISTING balance untouched too, and reports false.
func test_a_refused_add_leaves_an_existing_balance_untouched() -> void:
	var player: PlayerState = PlayerState.new()
	assert_true(player.add("iron", HELD), "sanity: the deposit is accepted")
	var before: int = player.content_hash()
	assert_false(player.add("iron", 0), "(AU): add(0) must be refused")
	assert_false(player.add("iron", -HELD), "(AU): a negative add must be refused")
	assert_eq(player.amount_of("iron"), HELD, "(AU): a refused add changes nothing")
	assert_eq(player.content_hash(), before, "§11.1: a refused add is not a state change")


# =============================================================================================
# D. spend — ATOMIC REFUSAL, NEVER NEGATIVE (§3.4 step 2)
# =============================================================================================

## §3.4 step 2 — a shortage is paid in HP ("every unpaid unit loses 10% max HP this turn"), so a
## stockpile is NEVER negative: spending more than is held is refused ATOMICALLY, leaving the
## balance exactly as it was. A partial debit would silently corrupt every later income tick.
func test_spend_refuses_atomically_instead_of_going_negative() -> void:
	var player: PlayerState = PlayerState.new()
	assert_true(player.add("gold", HELD), "sanity: the deposit is accepted")
	assert_false(player.spend("gold", HELD + 1), "§3.4: overspending must be refused")
	assert_eq(player.amount_of("gold"), HELD, "§3.4: a refused spend debits NOTHING")
	assert_false(player.spend("gold", BIG_AMOUNT), "§3.4: overspending must be refused")
	assert_eq(player.amount_of("gold"), HELD, "§3.4: a refused spend debits NOTHING")
	assert_true(player.spend("gold", HELD), "§5.1: spending exactly the balance is allowed")
	assert_eq(player.amount_of("gold"), 0, "§5.1: spending the whole balance leaves 0")
	assert_false(player.spend("gold", 1), "§3.4: an empty stockpile cannot be spent from")
	assert_eq(player.amount_of("gold"), 0, "§3.4: a stockpile never goes negative")


## (AU) — `spend` is total and strictly positive on the same terms as `add`: a non-positive
## amount, an unknown id and the empty id are all refused without touching anything.
func test_spend_refuses_non_positive_amounts_unknown_ids_and_the_empty_id() -> void:
	var player: PlayerState = PlayerState.new()
	assert_true(player.add("stone", HELD), "sanity: the deposit is accepted")
	for amount: int in [0, -1, -HELD]:
		assert_false(player.spend("stone", amount), "(AU): spend(%d) must be refused" % amount)
	assert_false(player.spend(UNKNOWN_ID, 1), "(AU): nothing is held under an unknown id")
	assert_false(player.spend("", 1), "(AU): the empty id is not a resource")
	assert_eq(player.amount_of("stone"), HELD, "(AU): every refusal left the balance alone")
	assert_eq(
		player.resource_ids(),
		["stone"] as Array[String],
		"(AU): a refused spend must not create an entry for the id it was refused on"
	)


## (AU) — ZERO ENTRIES ARE REMOVED. After spending a balance to zero, the id is GONE from
## `resource_ids()`, so "never had it" and "spent it all" are indistinguishable and the content
## hash is a function of the OBSERVABLE stockpile alone.
func test_a_stockpile_spent_to_zero_is_removed_entirely() -> void:
	var player: PlayerState = PlayerState.new()
	assert_true(player.add("magestone", HELD), "sanity: the deposit is accepted")
	assert_true(player.add("mithril", 1), "sanity: the second deposit is accepted")
	assert_true(player.spend("magestone", HELD), "sanity: the whole balance is spendable")
	assert_eq(player.amount_of("magestone"), 0, "§5.1: the balance is 0")
	assert_false(
		player.resource_ids().has("magestone"),
		"(AU): a zero stockpile is REMOVED — resource_ids() lists only what is held"
	)
	assert_eq(
		player.resource_ids(),
		["mithril"] as Array[String],
		"(AU): only the surviving stockpile remains listed"
	)


## §11.1 + (AU) — the observable consequence of the rule above: a player who deposited and spent
## it all hashes EXACTLY like a player who never touched anything. An implementation that kept a
## 0-valued entry (or an insertion-order log) fails here and nowhere else.
func test_spending_everything_hashes_like_a_fresh_player() -> void:
	var spent: PlayerState = PlayerState.new()
	assert_true(spent.add("gold", HELD), "sanity: the deposit is accepted")
	assert_true(spent.add("food", 7), "sanity: the second deposit is accepted")
	assert_true(spent.spend("gold", HELD), "sanity: the whole gold balance is spendable")
	assert_true(spent.spend("food", 7), "sanity: the whole food balance is spendable")
	assert_eq(
		spent.content_hash(),
		PlayerState.new().content_hash(),
		"(AU)/§11.1: \"spent it all\" and \"never had it\" are the same observable state"
	)


# =============================================================================================
# E. can_afford IS EXACTLY THE spend PREDICATE
# =============================================================================================

## (AU) — `can_afford(id, n)` == `(n > 0 and amount_of(id) >= n)`, and it agrees with what
## `spend` actually does on a FRESH copy for every case. Swept over held / unknown / empty ids
## and the amounts 0, -1, held-1, held, held+1 (plus a negative and a 64-bit outlier), so a
## predicate that drifted from the mutator — the classic validate/apply split — cannot hide.
func test_can_afford_is_exactly_the_spend_predicate() -> void:
	var ids: Array[String] = ["gold", "food", UNKNOWN_ID, ""]
	var amounts: Array[int] = [-HELD, -1, 0, 1, HELD - 1, HELD, HELD + 1, BIG_AMOUNT]
	var disagreements: Array[String] = []
	for id: String in ids:
		for amount: int in amounts:
			var probe: PlayerState = _stocked()
			var held: int = probe.amount_of(id)
			var expected: bool = amount > 0 and held >= amount
			var predicted: bool = probe.can_afford(id, amount)
			var performed: bool = probe.spend(id, amount)
			var after: int = probe.amount_of(id)
			if predicted != expected:
				disagreements.append(
					"can_afford(\"%s\", %d) == %s, expected %s" % [id, amount, predicted, expected]
				)
			if performed != expected:
				disagreements.append(
					"spend(\"%s\", %d) == %s, expected %s" % [id, amount, performed, expected]
				)
			var wanted_after: int = held - amount if expected else held
			if after != wanted_after:
				disagreements.append(
					"after spend(\"%s\", %d) the balance is %d, expected %d" % [
						id, amount, after, wanted_after
					]
				)
	assert_eq(
		disagreements.size(),
		0,
		"(AU): can_afford must be exactly the spend predicate; %s" % [
			str(disagreements.slice(0, 6))
		]
	)


## (AU) — `can_afford` is a pure observer: asking never moves the stockpile.
func test_can_afford_never_mutates() -> void:
	var player: PlayerState = _stocked()
	var before: int = player.content_hash()
	for amount: int in [-1, 0, 1, HELD, HELD + 1]:
		var answered: bool = player.can_afford("gold", amount)
		assert_eq(
			answered,
			amount > 0 and amount <= HELD,
			"(AU): can_afford(\"gold\", %d)" % amount
		)
	assert_eq(player.amount_of("gold"), HELD, "(AU): asking must not spend")
	assert_eq(player.content_hash(), before, "§11.1: a query is not a state change")


# =============================================================================================
# F. CANONICAL ORDER (§11.1 "iterate collections in stable ID order")
# =============================================================================================

## §11.1 + (AU) — `resource_ids()` is ASCENDING by String and INDEPENDENT of insertion order. A
## Dictionary's own key order is insertion order, so an implementation that returned `keys()`
## directly passes every other test in this file and fails here.
func test_resource_ids_are_ascending_and_independent_of_insertion_order() -> void:
	var forward: PlayerState = PlayerState.new()
	var backward: PlayerState = PlayerState.new()
	for i: int in range(RESOURCE_IDS.size()):
		assert_true(forward.add(RESOURCE_IDS[i], i + 1), "sanity: forward deposit %d" % i)
	for i: int in range(RESOURCE_IDS.size() - 1, -1, -1):
		assert_true(backward.add(RESOURCE_IDS[i], i + 1), "sanity: backward deposit %d" % i)

	var expected: Array[String] = RESOURCE_IDS.duplicate()
	expected.sort()
	assert_eq(forward.resource_ids(), expected, "§11.1: resource_ids() is ascending by id")
	assert_eq(
		backward.resource_ids(),
		expected,
		"§11.1: resource_ids() must not depend on insertion order"
	)
	assert_eq(
		forward.resource_ids(),
		backward.resource_ids(),
		"§11.1: stable ID order, whichever way the stockpile was filled"
	)


## §11.1 — the canonical order survives churn: an id removed by spending to zero and re-added
## later still sorts into place rather than landing at the end.
func test_canonical_order_survives_removal_and_reinsertion() -> void:
	var player: PlayerState = PlayerState.new()
	assert_true(player.add("food", 1), "sanity")
	assert_true(player.add("gold", 1), "sanity")
	assert_true(player.add("stone", 1), "sanity")
	assert_true(player.spend("food", 1), "sanity: food is spent to zero and removed")
	assert_true(player.add("food", 5), "sanity: food comes back")
	assert_eq(
		player.resource_ids(),
		["food", "gold", "stone"] as Array[String],
		"§11.1: ascending id order, regardless of when an id was (re)created"
	)


## §11.1 — `resource_ids()` is a FRESH array per call. The `is_same()` IDENTITY assertion is the
## load-bearing half: M1-T9 item 6(a) measured that a SELF-CLEARING member cache passes a
## pollution-only freshness check while every caller still receives the same aliased array.
func test_resource_ids_returns_a_fresh_array_per_call() -> void:
	var player: PlayerState = _stocked()
	var first: Array[String] = player.resource_ids()
	var twin: Array[String] = player.resource_ids()
	assert_false(
		is_same(first, twin),
		"§11.1: resource_ids() must return a FRESH array, never a cached/aliased one"
	)
	first.append("tampered")
	first.append("tampered_twice")
	assert_false(
		player.resource_ids().has("tampered"),
		"§11.1: a caller mutating the returned array must not corrupt the stockpile"
	)
	assert_eq(
		twin.size(),
		player.resource_ids().size(),
		"§11.1: an earlier caller's array must survive a later call unchanged"
	)


# =============================================================================================
# G. content_hash (§11.1 "FNV over canonical serialization ... must be reproducible")
# =============================================================================================

## §11.1 — the hash is a function of the OBSERVABLE stockpile, not of how it was built: the same
## balances reached in opposite insertion orders hash identically.
func test_content_hash_is_independent_of_insertion_order() -> void:
	var first: PlayerState = PlayerState.new()
	assert_true(first.add("food", 1), "sanity")
	assert_true(first.add("gold", 2), "sanity")
	var second: PlayerState = PlayerState.new()
	assert_true(second.add("gold", 2), "sanity")
	assert_true(second.add("food", 1), "sanity")
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: a canonical serialization cannot depend on insertion order"
	)


## §11.1 — the hash is stable across calls (no counter, no wall clock, no RNG inside).
func test_content_hash_is_reproducible() -> void:
	var player: PlayerState = _stocked()
	assert_eq(
		player.content_hash(), player.content_hash(), "§11.1: the hash must be reproducible"
	)


## §11.1 — every observable difference moves the hash: a different amount, a different id, and
## the swap of two amounts between two ids (which a per-id-unordered fold would miss).
func test_content_hash_separates_different_stockpiles() -> void:
	var base: PlayerState = PlayerState.new()
	assert_true(base.add("gold", 1), "sanity")
	var bigger: PlayerState = PlayerState.new()
	assert_true(bigger.add("gold", 2), "sanity")
	var other_id: PlayerState = PlayerState.new()
	assert_true(other_id.add("food", 1), "sanity")
	assert_ne(base.content_hash(), bigger.content_hash(), "§11.1: a different amount, a new hash")
	assert_ne(base.content_hash(), other_id.content_hash(), "§11.1: a different id, a new hash")

	var swapped_a: PlayerState = PlayerState.new()
	assert_true(swapped_a.add("food", 1), "sanity")
	assert_true(swapped_a.add("gold", 2), "sanity")
	var swapped_b: PlayerState = PlayerState.new()
	assert_true(swapped_b.add("food", 2), "sanity")
	assert_true(swapped_b.add("gold", 1), "sanity")
	assert_ne(
		swapped_a.content_hash(),
		swapped_b.content_hash(),
		"§11.1: an amount is bound to ITS id — swapping two amounts must change the hash"
	)


## §11.1 "FNV over canonical serialization" — the serialization must be UNAMBIGUOUS, not merely
## ordered. An amount is always exactly eight bytes and an id carries no length prefix, so without
## a separator ending each id/amount pair the stockpile `{"a": 0x7878…78, "b": n}` and the
## stockpile `{"axxxxxxxxb": n}` fold over the IDENTICAL byte stream and collide. The fixture is
## built FROM the amount's own bytes, so it proves the confusion rather than asserting it: a
## separator-less fold passes every other test in this suite and dies only here.
##
## Measured at Verify (M2-T1 probe 12): deleting the separator fold from `player_state.gd` left
## the whole 502-test suite GREEN before this test existed.
func test_content_hash_cannot_be_confused_by_an_id_that_spells_out_a_neighbour() -> void:
	var amount_bytes: PackedByteArray = PackedByteArray()
	for i: int in range(AMOUNT_BYTES):
		amount_bytes.append((RUN_TOGETHER_AMOUNT >> (8 * i)) & 0xff)
	var filler: String = amount_bytes.get_string_from_utf8()
	assert_eq(
		filler.to_utf8_buffer(),
		amount_bytes,
		"fixture: the amount's eight bytes must round-trip as UTF-8 text"
	)
	var merged_id: String = RUN_TOGETHER_FIRST_ID + filler + RUN_TOGETHER_SECOND_ID

	var pair: PlayerState = PlayerState.new()
	assert_true(pair.add(RUN_TOGETHER_FIRST_ID, RUN_TOGETHER_AMOUNT), "sanity: §5.1 has no caps")
	assert_true(pair.add(RUN_TOGETHER_SECOND_ID, HELD), "sanity: the second deposit is accepted")
	var merged: PlayerState = PlayerState.new()
	assert_true(merged.add(merged_id, HELD), "(AU): resource ids are opaque strings")

	assert_eq(
		pair.resource_ids(),
		[RUN_TOGETHER_FIRST_ID, RUN_TOGETHER_SECOND_ID] as Array[String],
		"fixture: the two-entry stockpile is in ascending id order"
	)
	assert_eq(
		merged.resource_ids(), [merged_id] as Array[String], "fixture: the merged id is one entry"
	)
	assert_eq(
		RUN_TOGETHER_FIRST_ID.to_utf8_buffer().size()
		+ AMOUNT_BYTES
		+ RUN_TOGETHER_SECOND_ID.to_utf8_buffer().size()
		+ AMOUNT_BYTES,
		merged_id.to_utf8_buffer().size() + AMOUNT_BYTES,
		"fixture: both stockpiles serialise to the same NUMBER of bytes without a separator"
	)
	assert_ne(
		pair.content_hash(),
		merged.content_hash(),
		"§11.1: the canonical serialization must be unambiguous — an id/amount pair is delimited"
	)


## §5.1 "No storage caps" + §11.1 — two amounts that differ only ABOVE 32 bits must hash
## differently. A 4-byte fold of the amount (the shape `hex_map.gd` uses for its 0..3 elevations)
## collides here and NOWHERE else in this suite.
func test_content_hash_separates_amounts_differing_only_above_thirty_two_bits() -> void:
	var small: PlayerState = PlayerState.new()
	assert_true(small.add("gold", 1), "sanity")
	var large: PlayerState = PlayerState.new()
	assert_true(large.add("gold", 1 + OVER_32), "sanity: §5.1 has no storage caps")
	assert_eq(large.amount_of("gold"), 1 + OVER_32, "§5.1: the amount is held exactly")
	assert_ne(
		small.content_hash(),
		large.content_hash(),
		"§5.1/§11.1: amounts differing only above 2^32 must fold to different hashes"
	)


## §11.1 / M1-T5 (U) — the hash is a 32-bit value, like every other content hash in the project.
func test_content_hash_stays_within_thirty_two_bits() -> void:
	var samples: Array[PlayerState] = [PlayerState.new(), _stocked(), _fully_stocked()]
	for player: PlayerState in samples:
		var observed: int = player.content_hash()
		assert_gte(observed, 0, "§11.1: a content hash is unsigned")
		assert_lte(observed, HASH_MASK, "§11.1: a content hash is 32-bit")


## §11.1 — the hash actually distinguishes the seven §5.1 resources from one another: the same
## amount under each of them yields seven distinct hashes (a fold that ignored the id would
## collapse them).
func test_content_hash_distinguishes_every_resource_id() -> void:
	var seen: Dictionary = {}
	for id: String in RESOURCE_IDS:
		var player: PlayerState = PlayerState.new()
		assert_true(player.add(id, 1), "sanity: %s is storable" % id)
		seen[player.content_hash()] = id
	assert_eq(
		seen.size(),
		RESOURCE_IDS.size(),
		"§11.1: holding 1 of each §5.1 resource must give %d distinct hashes" % RESOURCE_IDS.size()
	)


# =============================================================================================
# H. MECHANICAL SOURCE SCANS ON scripts/sim/player_state.gd (§11.1, §11.2, §11.3, §13.6)
#    Written FRESH for this file — a new file inherits NOTHING from the other scan suites.
# =============================================================================================

## S1 §11.1 "no float accumulation in rules" — §5.1 stockpiles are INTEGERS. Comment stripping is
## LOAD-BEARING: the doc block above cites "§5.1"/"§3.4"/"§11.1", which `\.[0-9]` would hit.
func test_source_contains_no_float_literal_and_no_float_type() -> void:
	var code: String = _code_text(PLAYER_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PLAYER_STATE_PATH)
	var float_literal: RegEx = RegEx.new()
	assert_eq(float_literal.compile("\\.[0-9]"), OK, "sanity: the float-literal pattern compiles")
	var hit: RegExMatch = float_literal.search(code)
	assert_null(
		hit,
		"§5.1/§11.1: stockpiles are integers — %s must contain no float literal (found %s)" % [
			PLAYER_STATE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_false(
		code.contains("float"),
		"§5.1/§11.1: stockpiles are integers — %s must not use the float type" % PLAYER_STATE_PATH
	)
	assert_false(
		code.contains("integer_division"),
		"M0-T4 (d): a stockpile divides nothing — %s must not suppress that warning" % [
			PLAYER_STATE_PATH
		]
	)


## S2 §11.1 "the core must run headless byte-identically" — engine-free source, including the
## M1-T5 item 6 `RandomNumberGenerator` ban (rng.gd is its single home in the project).
func test_source_is_engine_free() -> void:
	var code: String = _code_text(PLAYER_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PLAYER_STATE_PATH)
	for banned: String in ENGINE_BOUND_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1: the sim core must be engine-free — %s contains %s" % [
				PLAYER_STATE_PATH, banned
			]
		)


## S3 (AU) / §13.5 / §13.6 — NO RESOURCE-ID WHITELIST IN ENGINE CODE, on the §4.2 terrain-type
## precedent (M1-T5 (T), M1-T7 (AH)): resource ids are OPAQUE strings, so adding one is a DATA
## edit. Every one of §5.1's seven ids is therefore a FORBIDDEN token in this file — the
## vocabulary is pinned by section B above, by test, and never by an enum or a const in `.gd`.
## Comment stripping is load-bearing: the doc block names all seven.
func test_source_carries_no_resource_id_whitelist() -> void:
	var code: String = _code_text(PLAYER_STATE_PATH).to_lower()
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PLAYER_STATE_PATH)
	for id: String in RESOURCE_IDS:
		assert_false(
			code.contains(id),
			"(AU)/§13.5: resource ids are opaque data — %s must not name \"%s\"" % [
				PLAYER_STATE_PATH, id
			]
		)


## S4 §4.4 line 238 / §13.6 — map sizes are tunable content in data/mapgen/*.json. A stockpile
## container has no business naming one.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(PLAYER_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PLAYER_STATE_PATH)
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
			PLAYER_STATE_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S5 §13.4 — this file loads no document, so it must not grow a loader (the M1-T9 rule); and it
## must not override `Object.hash()` (M1-T5 (U): `native_method_override` is level 2 = an error
## under the live M0-T4 gate), which is why the member is `content_hash`.
func test_source_declares_no_loader_and_never_overrides_object_hash() -> void:
	var code: String = _code_text(PLAYER_STATE_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % PLAYER_STATE_PATH)
	assert_false(
		code.contains("RulesError"),
		"§13.4: %s loads no document and must not carry a loader" % PLAYER_STATE_PATH
	)
	assert_false(
		code.contains("func hash("),
		"(U)/M0-T4: overriding Object.hash() trips native_method_override — %s must not" % [
			PLAYER_STATE_PATH
		]
	)


## S6 §11.3/§13.4 — the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (a `set_amount` that could write a negative
## balance, an income/upkeep hook, a serializer) fails too. Zero public vars: the storage stays
## private so no caller can bypass the canonical order.
func test_public_api_is_exactly_the_six_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(PLAYER_STATE_PATH, public_functions, undocumented)

	var player: PlayerState = PlayerState.new()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, PLAYER_STATE_PATH]
		)
		assert_true(
			player.has_method(required),
			"§11.2: %s must be callable on a PlayerState instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			PLAYER_STATE_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(PLAYER_STATE_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the storage stays private — the public FIELD surface of %s is empty" % [
			PLAYER_STATE_PATH
		]
	)


## S7 §11.1/§11.2 — PlayerState is a pure [RefCounted] living in `scripts/sim/`. Asserted through
## get_class() — `is Node` is a PARSE ERROR here (M0-T2 item 11 / M0-T5 item (a)).
func test_player_state_is_a_pure_refcounted_in_scripts_sim() -> void:
	assert_true(
		FileAccess.file_exists(PLAYER_STATE_PATH),
		"§11.2: PlayerState lives at %s" % PLAYER_STATE_PATH
	)
	assert_eq(
		PlayerState.new().get_class(),
		"RefCounted",
		"§11.1: PlayerState must be a pure RefCounted"
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A player holding exactly HELD gold and nothing else — the fixture the spend/afford sweeps
## reset to on every case.
func _stocked() -> PlayerState:
	var player: PlayerState = PlayerState.new()
	var accepted: bool = player.add("gold", HELD)
	assert_true(accepted, "fixture: the sweep's gold deposit must be accepted")
	return player


## A player holding one of each §5.1 resource, for the range sweeps.
func _fully_stocked() -> PlayerState:
	var player: PlayerState = PlayerState.new()
	for i: int in range(RESOURCE_IDS.size()):
		var accepted: bool = player.add(RESOURCE_IDS[i], (i + 1) * HELD)
		assert_true(accepted, "fixture: %s must be storable" % RESOURCE_IDS[i])
	return player


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
