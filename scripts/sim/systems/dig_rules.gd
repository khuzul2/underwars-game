## Answers GDD §4.2's whole Solid-hex dig paragraph from loaded §12.1 data: dig time per terrain
## type (with the Artificial-Granite owner variant, §7.1), dig yield per terrain type (including
## the four vein lumps), the vein-node resource id left behind (§5.2 is the later consumer), the
## max simultaneous diggers per hex, and §4.2 line 197's "Dig 2x halves remaining time (round up)".
##
## Pure sim core (§11.1): no Node, no SceneTree, no engine singleton, no randi(), integer math
## only, every returned Array fresh and in ascending order. It CONSUMES an already-loaded
## [RulesLoader]; it never loads a document itself, so it carries no `errors` and no [RulesError].
## A null or failed loader leaves it UNCONFIGURED and every accessor answers its zero/empty value
## (the (AL) CameraRig precedent).
##
## §4.2's terrain ids and §12.1's dig keys are two DIFFERENT vocabularies. The binding between them
## lives in `data/ruleset.json`'s `dig.profiles` group, which is what keeps terrain ids out of
## engine code (the (T)/(AH)/(AU)(iv) no-whitelist rule): this file never names a terrain id or a
## resource id — it only names the §12.1 schema paths and profile leaf names it reads through.
class_name DigRules
extends RefCounted

## §4.2 line 197 — "Dig 2x halves remaining time (round up)". The divisor is a mathematical
## constant of the RULE, not a tunable, so it is a NAMED private const (the M1-T8 (AJ)
## named-mathematical-const precedent), never a §12.1 key.
const _HALVE_DIVISOR: int = 2

var _rules: RulesLoader = null


## §12.1 — holds an already-loaded ruleset. `p_rules` may be null (unconfigured).
func _init(p_rules: RulesLoader) -> void:
	_rules = p_rules


## §4.2 — true for exactly the nine printed Solid rows: a terrain id is diggable when
## `dig.profiles.<id>.turns_key` resolves to a non-empty §12.1 key.
func is_diggable(p_terrain_id: String) -> bool:
	return not _profile_key(p_terrain_id, "turns_key").is_empty()


## §4.2 — dig time in worker-turns for `p_terrain_id`. `p_by_owner` selects the §7.1 owner
## variant (Artificial Granite only); every other row ignores the flag entirely.
func dig_turns_for(p_terrain_id: String, p_by_owner: bool) -> int:
	if _rules == null:
		return 0
	var turns_key: String = _profile_key(p_terrain_id, "turns_key")
	if turns_key.is_empty():
		return 0
	if p_by_owner:
		var owner_turns_key: String = _profile_key(p_terrain_id, "owner_turns_key")
		if not owner_turns_key.is_empty():
			return _rules.get_int("dig_turns.%s" % owner_turns_key)
	return _rules.get_int("dig_turns.%s" % turns_key)


## §4.2 — the §5.1 resource ids `p_terrain_id` yields on dig, ascending, fresh per call. Every
## printed row yields exactly one resource: either its `yield_key` (dig_yields) or its `vein_key`
## (the lump left by a vein row, §5.2).
func yield_resource_ids(p_terrain_id: String) -> Array[String]:
	var out: Array[String] = []
	if _rules == null:
		return out
	var yield_key: String = _profile_key(p_terrain_id, "yield_key")
	if not yield_key.is_empty():
		out.append_array(_rules.get_keys("dig_yields.%s" % yield_key))
	var vein_key: String = _profile_key(p_terrain_id, "vein_key")
	if not vein_key.is_empty():
		out.append(vein_key)
	out.sort()
	return out


## §4.2 — the amount of `p_resource_id` yielded by digging `p_terrain_id`; 0 for any resource the
## row does not produce. A vein row's amount is its lump (§12.1 `vein_nodes.<vein_key>.lump`).
func yield_amount(p_terrain_id: String, p_resource_id: String) -> int:
	if _rules == null:
		return 0
	var yield_key: String = _profile_key(p_terrain_id, "yield_key")
	if not yield_key.is_empty():
		var dotted: String = "dig_yields.%s.%s" % [yield_key, p_resource_id]
		if _rules.has(dotted):
			return _rules.get_int(dotted)
	var vein_key: String = _profile_key(p_terrain_id, "vein_key")
	if not vein_key.is_empty() and vein_key == p_resource_id:
		return _rules.get_int("vein_nodes.%s.lump" % vein_key)
	return 0


## §5.2 — the vein-node resource id `p_terrain_id` leaves behind, "" when the row leaves none.
## Vein-node STATE (stock/rate) and Extractors are a LATER M2 slice; this answers the resource
## only.
func vein_resource_id(p_terrain_id: String) -> String:
	return _profile_key(p_terrain_id, "vein_key")


## §4.2 line 197 — "max 2 simultaneous diggers per hex", read from `dig.max_diggers_per_hex`.
func max_diggers_per_hex() -> int:
	if _rules == null:
		return 0
	return _rules.get_int("dig.max_diggers_per_hex")


## §11.1/§4.2 line 197 — "Dig 2x halves remaining time (round up)" = ceil(n/2), computed as
## `(n + 1) / _HALVE_DIVISOR` on non-negative ints (integer division truncates the +1 back down
## exactly on the halves, matching round-half-up at this final step). Totality: a non-positive
## remaining time answers 0 rather than a negative or a crash.
func halve_remaining_turns(p_remaining: int) -> int:
	if p_remaining <= 0:
		return 0
	@warning_ignore("integer_division")
	return (p_remaining + 1) / _HALVE_DIVISOR


## §12.1 — the string leaf `dig.profiles.<p_terrain_id>.<p_leaf>`, or "" when unconfigured, the
## terrain id is empty, or the id/leaf does not resolve (an unknown terrain id is simply not in
## the map — §13.4 totality).
func _profile_key(p_terrain_id: String, p_leaf: String) -> String:
	if _rules == null or p_terrain_id.is_empty():
		return ""
	return _rules.get_string("dig.profiles.%s.%s" % [p_terrain_id, p_leaf])
