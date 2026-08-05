## DigHexCommand — the SECOND of §11.1 line 705's fourteen printed commands, the first consumer of
## [DigRules] AND of the §11.1 unit roster. GDD §11.1 (Layered Design, binding), §4.2 (Hex Types —
## the dig-time table, reached only through [DigRules]), §7.1 (the Artificial-Granite owner
## variant), §4.1 (hex geometry — adjacency), §3.4 (step 4's tick is a LATER slice, pinned
## negatively).
##
## (AY) THE DIG ORDER.
##   - An IMMUTABLE value object: `(player_index, unit_id, hex, dig_rules)` set in `_init`; neither
##     `validate` nor `apply` ever mutates `self` (§11.1 replays the same log more than once).
##   - `DigRules` is INJECTED already-loaded (the M1-T3 injected-dependency precedent). `GameState`
##     holds no `RulesLoader` and does not gain one here.
##   - THE §7.1 OWNERSHIP SEAM: [method _digs_own_terrain] is the ONE place that decides whether the
##     issuer is digging their own Artificial Granite. Today it answers false unconditionally: no
##     hex anywhere carries a builder index, and §7.1's Raise Granite — the ONLY producer of
##     Artificial Granite — is M3/M4.
##   - ONE OWNER PER DIG SITE and ONE JOB PER UNIT: a site belongs to the player who ordered it, and
##     a unit digs at most one site at a time.
##   - REJECTION VOCABULARY AND PRECEDENCE, opaque StringNames authored at their own call sites (no
##     enum, no const list): `null_state`, `no_map`, `no_players`, `not_current_player`,
##     `no_such_unit`, `not_your_unit`, `unit_not_adjacent`, `not_diggable`, `site_not_yours`,
##     `already_digging`, `dig_site_full`, in that order.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time. Class kind is asserted via get_class() ONLY.
class_name DigHexCommand
extends Command

## §4.1 line 172 "Distance = cube distance" — the fixed adjacency distance §4.2 line 197 requires
## ("multiple workers on adjacent hexes"). A NAMED private const (the (AJ) precedent): this is
## §4.1's fixed geometry, never a §12.1 tunable.
const _ADJACENT_DISTANCE: int = 1

## (AY) — the ordering player. Read-only: see [method player_index].
var _player_index: int = 0

## (AY) — the unit assigned by this order. Read-only: see [method unit_id].
var _unit_id: int = 0

## §4.1/(AY) — the target hex. Read-only: see [method hex].
var _hex: Vector2i = Vector2i.ZERO

## §4.2/(AY) — the injected, already-loaded dig table this order reads through.
var _dig_rules: DigRules = null


func _init(p_player_index: int, p_unit_id: int, p_hex: Vector2i, p_dig_rules: DigRules) -> void:
	_player_index = p_player_index
	_unit_id = p_unit_id
	_hex = p_hex
	_dig_rules = p_dig_rules


## §11.1/(AY) — the player who issued this order. Never changes.
func player_index() -> int:
	return _player_index


## §11.1/(AY) — the unit this order assigns. Never changes.
func unit_id() -> int:
	return _unit_id


## §4.1/(AY) — the target hex. Never changes.
func hex() -> Vector2i:
	return _hex


## §11.1 line 705 — one of the fourteen printed §11.1 command names.
func command_name() -> StringName:
	return &"dig_hex"


## §11.1/§4.2/§4.1/§3.4 step 9 — the eleven-code rejection vocabulary, in precedence order. Null
## means legal. A PURE PREDICATE: never mutates `state`, whatever the answer.
func validate(state: GameState) -> CommandError:
	if state == null:
		return CommandError.new(&"null_state", "DigHexCommand requires a GameState")
	if state.map == null:
		return CommandError.new(&"no_map", "DigHexCommand requires a map")
	if state.player_count() == 0:
		return CommandError.new(&"no_players", "DigHexCommand requires at least one player")
	if _player_index != state.current_player_index():
		return CommandError.new(
			&"not_current_player",
			"player %d may not act during player %d's turn" % [
				_player_index, state.current_player_index()
			]
		)
	var digger: UnitState = state.unit(_unit_id)
	if digger == null:
		return CommandError.new(&"no_such_unit", "unit %d does not exist" % _unit_id)
	if digger.owner_index() != _player_index:
		return CommandError.new(
			&"not_your_unit",
			"unit %d belongs to player %d, not %d" % [_unit_id, digger.owner_index(), _player_index]
		)
	if HexMath.distance(digger.hex(), _hex) != _ADJACENT_DISTANCE:
		return CommandError.new(
			&"unit_not_adjacent", "unit %d is not adjacent to %s" % [_unit_id, str(_hex)]
		)
	var terrain_id: String = state.map.get_terrain_type(_hex)
	if not _dig_rules.is_diggable(terrain_id):
		return CommandError.new(&"not_diggable", "%s cannot be dug" % str(_hex))
	var existing: DigSite = state.dig_site(_hex)
	if existing != null and existing.owner_index() != _player_index:
		return CommandError.new(
			&"site_not_yours", "the dig site at %s belongs to another player" % str(_hex)
		)
	if state.dig_site_of_digger(_unit_id) != null:
		return CommandError.new(
			&"already_digging", "unit %d is already assigned to a dig site" % _unit_id
		)
	if existing != null and existing.digger_ids().size() >= _dig_rules.max_diggers_per_hex():
		return CommandError.new(
			&"dig_site_full", "the dig site at %s already has the maximum diggers" % str(_hex)
		)
	return null


## §4.2/§4.2 line 197/§7.1 — creates a site (reading its total worker-turns from [DigRules] through
## the ONE ownership seam) or joins the existing one, assigns the unit, and emits exactly ONE
## [DigStartedEvent] — for the creation AND for a second digger joining alike (§13.6: a join is a
## state change too). Called with an UNCONFIGURED [DigRules] (unreachable through [method execute]),
## the site cannot be sized: nothing is created and the returned array is empty.
func apply(state: GameState) -> Array[Event]:
	var out: Array[Event] = []
	var terrain_id: String = state.map.get_terrain_type(_hex)
	var total: int = _dig_rules.dig_turns_for(terrain_id, _digs_own_terrain(state, _hex, _player_index))
	var site: DigSite = state.dig_site(_hex)
	var site_created: bool = false
	if site == null:
		site = state.add_dig_site(_hex, _player_index, total)
		if site == null:
			return out
		site_created = true
	site.add_digger(_unit_id)
	out.append(DigStartedEvent.new(_player_index, _unit_id, _hex, site.remaining_turns(), site_created))
	return out


## §7.1 line 367 — THE OWNERSHIP SEAM: "Enemies dig it in 3 turns; Dwarves clear their own in 1."
## No hex anywhere carries a builder index, and §7.1's Raise Granite (the ONLY producer of
## Artificial Granite) is M3/M4, so no player in this slice can be the builder of what they are
## digging. This is the ONE place that determination is made; a later slice teaches it to consult
## the hex's builder instead of answering unconditionally.
func _digs_own_terrain(_state: GameState, _target: Vector2i, _issuer: int) -> bool:
	return false
