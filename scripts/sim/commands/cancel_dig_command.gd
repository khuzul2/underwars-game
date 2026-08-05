## CancelDigCommand — the THIRD of §11.1 line 705's fourteen printed commands, and a PURE CONSUMER
## of what M2-T5 landed (`DigSite.remove_digger`, `GameState.remove_dig_site`,
## `GameState.dig_site_of_digger`). GDD §11.1 (Layered Design, binding), §4.2 (Hex Types — the dig
## table the cancelled order was sized from), §4.1 (hex geometry — irrelevant here; cancel is
## unit-targeted, not hex-targeted), §3.4 (step 4's tick is SLICE 4, pinned negatively), §1.1
## (Design Pillars — pillar 1 decides progress is LOST, not refunded), §5.3 (Mining Zones — why an
## orphan site would be a deadlock).
##
## §4.2 PRINTS NOTHING ABOUT CANCEL SEMANTICS, so four rules are §13.4 judgment calls, logged by
## Land as (AZ):
##   (AZ)(i)   CANCEL IS UNIT-TARGETED, NOT HEX-TARGETED. `_init(player_index, unit_id)` — no hex
##             parameter and no `DigRules` parameter: `dig_site_of_digger(unit_id)` is total and
##             unambiguous (a unit digs at most one site), and this is the exact inverse of
##             `DigHexCommand`, which assigns exactly one unit.
##   (AZ)(ii)  THE LAST DIGGER LEAVING REMOVES THE SITE, AND ITS PROGRESS IS LOST. An ownerless
##             site that kept its progress would be permanently un-startable by anyone else
##             (`DigHexCommand` rejects `site_not_yours` on an owner mismatch), and §5.3's Mining
##             Zones re-issue "ordinary Dig commands each turn", so an orphan site is a DEADLOCK.
##             §1.1 pillar 1 ("Exploration IS excavation") wants a dig to be a commitment, not a
##             free undo.
##   (AZ)(iii) A NON-LAST CANCEL LEAVES `remaining_turns` UNCHANGED and the site alive.
##   (AZ)(iv)  `no_map` IS DELIBERATELY NOT A CODE HERE: a cancel reads no terrain, so `validate`
##             must not consult `state.map` at all.
##   (AZ)(v)   THE REJECTION VOCABULARY IS SIX OPAQUE `StringName`s, each authored at its OWN call
##             site (no enum, no const list, no whitelist), in this fixed precedence: `null_state`
##             -> `no_players` -> `not_current_player` -> `no_such_unit` -> `not_your_unit` ->
##             `not_digging`.
##
## An IMMUTABLE value object: `(player_index, unit_id)` set in `_init`; neither `validate` nor
## `apply` ever mutates `self` (§11.1 replays the same log more than once).
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time. Class kind is asserted via get_class() ONLY.
class_name CancelDigCommand
extends Command

## (AZ)(i) — the issuing player. Read-only: see [method player_index].
var _player_index: int = 0

## (AZ)(i) — the unit whose dig job is being cancelled. Read-only: see [method unit_id].
var _unit_id: int = 0


func _init(p_player_index: int, p_unit_id: int) -> void:
	_player_index = p_player_index
	_unit_id = p_unit_id


## §11.1 — the player who issued this order. Never changes.
func player_index() -> int:
	return _player_index


## §11.1 — the unit this order unassigns. Never changes.
func unit_id() -> int:
	return _unit_id


## §11.1 line 705 — one of the fourteen printed §11.1 command names.
func command_name() -> StringName:
	return &"cancel_dig"


## §11.1/§3.4 step 9/(AZ)(v) — the six-code rejection vocabulary, in precedence order. Null means
## legal. A PURE PREDICATE: never mutates `state`, whatever the answer. (AZ)(iv): this command
## reads no terrain, so `state.map` is never consulted and `no_map` is deliberately not a code.
func validate(state: GameState) -> CommandError:
	if state == null:
		return CommandError.new(&"null_state", "CancelDigCommand requires a GameState")
	if state.player_count() == 0:
		return CommandError.new(&"no_players", "CancelDigCommand requires at least one player")
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
	if state.dig_site_of_digger(_unit_id) == null:
		return CommandError.new(&"not_digging", "unit %d is not assigned to a dig site" % _unit_id)
	return null


## §4.2/(AZ)(ii)/(AZ)(iii) — unassigns the issuer's unit from its dig site and emits exactly one
## [DigCancelledEvent]. When the departing digger was the LAST one, the site is removed from the
## registry and its progress is lost (AZ)(ii); otherwise the site survives with its remaining
## worker-turns untouched (AZ)(iii). §13.6: a unit assigned to no site changes nothing, so nothing
## is emitted.
func apply(state: GameState) -> Array[Event]:
	var out: Array[Event] = []
	var site: DigSite = state.dig_site_of_digger(_unit_id)
	if site == null:
		return out
	var target: Vector2i = site.hex()
	var remaining: int = site.remaining_turns()
	site.remove_digger(_unit_id)
	var site_removed: bool = site.digger_ids().is_empty()
	if site_removed:
		state.remove_dig_site(target)
	out.append(DigCancelledEvent.new(_player_index, _unit_id, target, remaining, site_removed))
	return out
