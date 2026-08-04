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
## DELIBERATELY NOT IN M2-T2 (§13.4 — invent nothing ahead of its milestone): every other §11.1
## command, workers, dig progress, yields, vein nodes, Extractors, income/upkeep, housing,
## Mining Zones and §3.1's starting kit.
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


## §11.1 — an FNV-1a 32-bit content hash over this state's replayable surface, in this fixed
## order (documented here because a future golden will record it): the private seed, then the
## RNG's stream position (§11.1 "replaying (seed, command_log) must reproduce the hash" — a
## different number of rolls drawn is a different replayable state), then the turn and then the
## current_player_index (§3.3 "fixed order by player index" — whose turn it is is part of the
## replayable state), then a map-presence flag followed by the map's own hash when present (so
## "no map" can never collide with a real map whose hash happens to be 0), then the player count,
## then for each player index in ascending order the index itself followed by that player's hash
## (players are folded BY INDEX, never as an unordered set).
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
	return hash_value
