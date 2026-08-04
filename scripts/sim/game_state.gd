## GameState — GDD §11.1 ("single serializable object — map ... players (stockpiles, techs,
## meters) ... and **one** **RandomNumberGenerator** **seeded at match start** (the only RNG in
## the program; every roll goes through state.rng)"), §3.3 (fixed order by player index),
## §11.2, §11.3.
##
## §13.4 resolution (AU) (M1-T9 ended the lettering at (AT)):
##   - `_init(p_seed_value, p_map, p_player_count)`. The seed parameter is deliberately NOT named
##     `seed`: GDScript's global `seed()` makes that shadowed_global_identifier, level 2 = a hard
##     error under the live static-typing gate (the same trap M1-T5 (R) hit for [Rng]).
##   - The seed value is kept PRIVATE and folded into [method content_hash], because §11.1's
##     replay contract is over (seed, command_log).
##   - `state.rng` is the ONE [Rng]. Its stream position ([method Rng.rolls_drawn]) is part of
##     the content hash: two states that have rolled a different number of times are not the
##     same replayable state.
##   - Players are folded BY INDEX (§3.3 "fixed order by player index"), never as a set.
##   - Totality: `player(i)` answers null outside 0..n-1, a non-positive player count is the
##     empty roster, and a null map constructs cleanly.
##
## AMENDED BY M2-T2, resolution (AV) ((AU) is cross-referenced by four files — do NOT renumber
## it). §3.3's turn position now lives here, and the fold grew to cover it:
##   - Private `_turn` / `_current_player_index`, public `turn()` / `current_player_index()` and
##     ONE mutator `set_turn_position(p_turn, p_player_index)`, documented as "§11.1 — intended
##     to be written only from a Command's apply()" (GDScript has no package-private;
##     `HexMap.set_elevation` is the precedent).
##   - A fresh state starts at turn 1, current_player_index 0, independently of the roster size —
##     an empty roster still reads turn 1 / index 0.
##   - The mutator is TOTAL: a SILENT NO-OP if `p_turn < 1` or `p_player_index` is outside
##     0..player_count()-1, and both counters are written together or neither is.
##   - THE ROTATION ITSELF IS NOT HERE: it is a §3.3 rule and lives in EndTurnCommand. GameState
##     only stores the position.
##   - THE FOLD ORDER GAINS THE TURN POSITION, immediately after `rng.rolls_drawn()` and BEFORE
##     the map-presence flag: private seed -> rng.rolls_drawn() -> turn -> current_player_index
##     -> map-presence flag (0/1) -> map.content_hash() when present -> player_count() -> per
##     index ascending, the index then that player's hash. No existing step is renamed or
##     reordered. NO GOLDEN IS RECORDED for GameState in this slice — the replay contract lands
##     as a property test in tests/sim/test_turn_replay.gd instead.
##
## EXTENDED BY M2-T4, resolution (AX) ((AU)/(AV) are cross-referenced by four and five files
## respectively — do NOT renumber either). §11.1 line 704 lists units as a TOP-LEVEL GameState
## collection ("map ..., players (stockpiles, techs, meters), units, buildings, nodes, turn
## counters ..."), NOT a PlayerState field, so the roster lands here and a unit carries its owner
## as an integer player index. `tests/unit/test_player_state.gd` stays untouched and green —
## PlayerState's public surface does not move:
##   - THE UNIT ROSTER is a pure CONTAINER (no Command, no Event, no data key, no rule): private
##     `_units` (keyed by int id, touched only by lookup/assign/erase) and `_next_unit_id`; six
##     public functions `spawn_unit`, `unit`, `unit_ids`, `units_of`, `units_at`, `remove_unit`.
##   - IDS START AT 1 AND ARE NEVER REUSED. 0 means "no unit" — an algorithmic constant (the (AJ)
##     precedent), not a §12.1 key. A reused id would silently rebind dangling references and
##     break §11.1's replay contract.
##   - Every list accessor sorts a FRESH copy of the keys and returns a FRESH Array each call
##     (§11.1 line 707 "iterate collections in stable ID order").
##   - `spawn_unit` is TOTAL and every refusal is ATOMIC: an owner outside 0..player_count()-1, an
##     EMPTY `type_id` or a non-positive `max_hp` answers null, leaves content_hash() unchanged
##     AND BURNS NO ID.
##   - PLACEMENT IS NOT VALIDATED HERE: `spawn_unit` accepts ANY Vector2i and never consults
##     `map`. Legality (cave hex, in bounds, §5.2 housing free) is a Command rule for a later
##     slice, and §6.4's stacking legality is M4 — the container stacks freely.
##   - NEUTRAL OWNERSHIP IS DELIBERATELY NOT MODELLED (§8.1 creeps, §3.2's "their units become
##     neutral hostiles"): every owner index outside the roster is refused, and M5 must add an
##     explicit sentinel rather than silently inventing -1.
##   - THE FOLD IS EXTENDED BY APPENDING ONLY — no existing step is renamed or reordered
##     ((AV) is the precedent for how to amend it): ... player_count() -> per player index
##     ascending -> `_next_unit_id` -> the unit count -> per unit id ascending: the id, then that
##     unit's content_hash(). `_next_unit_id` folds FIRST of the three because it is what makes
##     "spawned 3 then removed all 3" differ from "never spawned", which §11.1's replay contract
##     requires. The unit-count step is knowingly an EQUIVALENT MUTANT given the per-id fold — it
##     is kept for symmetry with the player fold, exactly as (AU) recorded for `player_count()`.
##   - MUTATORS ARE COMMAND-ONLY BY DOCUMENTATION (`set_turn_position`/`HexMap.set_elevation` are
##     the precedents; GDScript has no package-private), and because NO rule runs in this slice
##     §13.6's "events emitted for every state change" clause is VACUOUS here.
##
## DELIBERATELY NOT IN M2-T2/M2-T4 (§13.4 — invent nothing ahead of its milestone): §3.4's
## per-player start-of-turn steps and World-phase steps, §3.2/§12.1's victory turn limit, §12.7's
## trait set (worker-ness is a TRAIT, i.e. DATA), dig progress, yields, vein nodes, Extractors,
## income/upkeep, §5.2's housing cap (`housing.hq` is already shipped in `data/ruleset.json` and
## stays UNUSED), Mining Zones and §3.1's starting kit.
class_name GameState
extends RefCounted

## §11.1 — the shared hex map for this match; may be null (a mapless state still hashes, per
## resolution (AU)). GameState holds the caller's object directly — it is never copied.
var map: HexMap = null

## §11.1 — the single seeded RNG for the whole match ("the only RNG in the program; every roll
## goes through state.rng").
var rng: Rng = null

## Kept private and folded into [method content_hash] rather than exposed directly: §11.1's
## replay contract is over (seed, command_log), not over a public seed accessor.
var _seed_value: int = 0

## §3.3 — the roster, built once in `_init` and indexed by player index thereafter, so a mutation
## through [method player] is visible on every later call rather than a fresh copy each time.
var _players: Array[PlayerState] = []

## §3.3 — the current turn number. A fresh state starts at turn 1.
var _turn: int = 1

## §3.3 — the index of the player whose turn it is. A fresh state starts at index 0.
var _current_player_index: int = 0

## (AX) — the unit roster, keyed by int id; touched ONLY by lookup/assign/erase and NEVER
## iterated for output — every list accessor ([method unit_ids]/[method units_of]/
## [method units_at]) sorts a FRESH copy of the keys instead (the `PlayerState._amounts`
## precedent; §11.1 line 707 "iterate collections in stable ID order").
var _units: Dictionary = {}

## (AX) — the id minted for the NEXT spawned unit. Starts at 1 ("0 means no unit") and advances
## ONLY on a successful [method spawn_unit]; a removed id is NEVER reused, so a dangling
## reference can never be silently rebound. Part of the replayable state (§11.1 line 708) —
## folded into [method content_hash] so "spawned then removed every unit" cannot hash the same as
## "never spawned".
var _next_unit_id: int = 1


## §11.1/§3.3 — builds a state for `p_player_count` players (a non-positive count clamps to the
## empty roster) on `p_map` (held, not copied), with `p_seed_value` seeding the ONE [Rng] for the
## whole match.
func _init(p_seed_value: int, p_map: HexMap, p_player_count: int) -> void:
	_seed_value = p_seed_value
	map = p_map
	rng = Rng.new(p_seed_value)
	_players = []
	var roster_size: int = p_player_count if p_player_count > 0 else 0
	for _index: int in range(roster_size):
		_players.append(PlayerState.new())


## §3.3 — the roster size (0 for a non-positive requested count).
func player_count() -> int:
	return _players.size()


## §3.3 — the SAME [PlayerState] for `index` every time it is asked for (0 <= index <
## player_count()), so a mutation through it persists across calls; null outside that range.
func player(index: int) -> PlayerState:
	if index < 0 or index >= _players.size():
		return null
	return _players[index]


## §3.3 — the current turn number ("Sequential player turns (IGOUGO, Civ-style), fixed order by
## player index, then a World phase").
func turn() -> int:
	return _turn


## §3.3 — the index of the player whose turn it currently is.
func current_player_index() -> int:
	return _current_player_index


## §11.1 — writes the turn position. Intended to be written only from a Command's apply()
## (GDScript has no package-private; HexMap.set_elevation is the precedent). TOTAL: a SILENT
## NO-OP if `p_turn < 1` or `p_player_index` is outside 0..player_count()-1 — both counters are
## written together or neither is, so a buggy caller can never park the state in an unreachable
## position.
func set_turn_position(p_turn: int, p_player_index: int) -> void:
	if p_turn < 1:
		return
	if p_player_index < 0 or p_player_index >= player_count():
		return
	_turn = p_turn
	_current_player_index = p_player_index


## §11.1 line 704/707 — spawns a unit for `owner_index` of the opaque §12.2 `type_id`, placed at
## `hex`, with `max_hp` as BOTH its current and maximum health. TOTAL and every refusal is
## ATOMIC — [method content_hash] is byte-identical before/after AND no id is burned:
## `owner_index` outside `0..player_count()-1`, an empty `type_id`, or a non-positive `max_hp`
## all answer null. PLACEMENT IS NOT VALIDATED: any Vector2i is accepted and `map` is never
## consulted — legality (cave hex, in bounds, §5.2 housing) is a Command rule for a later slice,
## and §6.4's stacking legality is M4, so the roster stacks freely. Intended to be called only
## from a Command's apply() (the [method set_turn_position]/`HexMap.set_elevation` precedent;
## GDScript has no package-private).
func spawn_unit(owner_index: int, type_id: String, hex: Vector2i, max_hp: int) -> UnitState:
	if owner_index < 0 or owner_index >= player_count():
		return null
	if type_id.is_empty():
		return null
	if max_hp <= 0:
		return null
	var minted: UnitState = UnitState.new(_next_unit_id, owner_index, type_id, hex, max_hp)
	_units[_next_unit_id] = minted
	_next_unit_id += 1
	return minted


## §11.1 — the SAME [UnitState] for `unit_id` every call, so a mutation through it is visible on
## every later call (the [method player] precedent). Null for 0 ("no unit"), a negative id, or
## any id that was never minted or has since been removed.
func unit(unit_id: int) -> UnitState:
	if not _units.has(unit_id):
		return null
	var found: UnitState = _units[unit_id]
	return found


## §11.1 line 707 "iterate collections in stable ID order" — every minted, not-yet-removed unit
## id, ASCENDING, as a FRESH Array every call (never a cached reference — the M1-T9 lesson).
func unit_ids() -> Array[int]:
	var ids: Array[int] = []
	for key: Variant in _units.keys():
		var id: int = key as int
		ids.append(id)
	ids.sort()
	return ids


## §11.1 line 707 — every id owned by `owner_index`, ascending, as a FRESH Array every call; an
## owner index outside the roster answers an empty array, never null. A LINEAR SCAN over
## [method unit_ids] — no reverse index is built (a second source of truth is a determinism
## hazard at this size).
func units_of(owner_index: int) -> Array[int]:
	var ids: Array[int] = []
	for id: int in unit_ids():
		var found: UnitState = unit(id)
		if found != null and found.owner_index() == owner_index:
			ids.append(id)
	return ids


## §11.1 line 707/§4.1 — every id standing on `hex`, ascending, as a FRESH Array every call; a
## hex holding nothing answers an empty array, never null. Stacking is unlimited at this layer —
## §6.4's stacking legality is an M4 rule, not a container concern. A LINEAR SCAN over
## [method unit_ids].
func units_at(hex: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for id: int in unit_ids():
		var found: UnitState = unit(id)
		if found != null and found.hex() == hex:
			ids.append(id)
	return ids


## §11.1 — removes `unit_id` from the roster. TOTAL: true exactly once for a minted id, false on
## a second call and for any id that was never minted. Intended to be called only from a
## Command's apply().
func remove_unit(unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	_units.erase(unit_id)
	return true


## §11.1 — an FNV-1a 32-bit content hash over this state's replayable surface, in this fixed
## order (documented here because a future golden will record it): the private seed, then the
## RNG's stream position (§11.1 "replaying (seed, command_log) must reproduce the hash" — a
## different number of rolls drawn is a different replayable state), then the turn and then the
## current_player_index (§3.3 "fixed order by player index" — whose turn it is is part of the
## replayable state), then a map-presence flag followed by the map's own hash when present (so
## "no map" can never collide with a real map whose hash happens to be 0), then the player count,
## then for each player index in ascending order the index itself followed by that player's hash
## (players are folded BY INDEX, never as an unordered set). EXTENDED BY (AX) — APPENDED after
## the player fold, no existing step renamed or reordered: `_next_unit_id` (so a roster that was
## populated then fully emptied does not hash like one that was never touched — §11.1 line 708's
## replay contract), then the unit count, then for each unit id in ascending order the id itself
## followed by that unit's own [method UnitState.content_hash] (units are folded BY ID, never as
## an unordered set).
func content_hash() -> int:
	var hash_value: int = Fnv.OFFSET_BASIS
	hash_value = Fnv.fold_int64(hash_value, _seed_value)
	hash_value = Fnv.fold_int64(hash_value, rng.rolls_drawn())
	hash_value = Fnv.fold_int64(hash_value, _turn)
	hash_value = Fnv.fold_int64(hash_value, _current_player_index)
	if map == null:
		hash_value = Fnv.fold_byte(hash_value, 0)
	else:
		hash_value = Fnv.fold_byte(hash_value, 1)
		hash_value = Fnv.fold_int64(hash_value, map.content_hash())
	hash_value = Fnv.fold_int64(hash_value, player_count())
	for index: int in range(_players.size()):
		hash_value = Fnv.fold_int64(hash_value, index)
		hash_value = Fnv.fold_int64(hash_value, _players[index].content_hash())
	hash_value = Fnv.fold_int64(hash_value, _next_unit_id)
	var minted_ids: Array[int] = unit_ids()
	hash_value = Fnv.fold_int64(hash_value, minted_ids.size())
	for id: int in minted_ids:
		hash_value = Fnv.fold_int64(hash_value, id)
		hash_value = Fnv.fold_int64(hash_value, unit(id).content_hash())
	return hash_value
