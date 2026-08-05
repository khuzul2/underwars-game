## DigSite — the §4.2 DIG-SITE PROGRESS RECORD. GDD §4.2 (Hex Types — dig time is total
## worker-turns; "max 2 simultaneous diggers per hex" is a RULE, not enforced here), §7.1 (the
## Artificial-Granite owner variant, which is why `total_turns` is a per-order value rather than a
## per-terrain one), §11.1 (pure sim core, stable ID order, reproducible FNV content hash), §3.4
## (step 4's dig tick/completion is a LATER slice — reaching 0 remaining does not complete or empty
## this record).
##
## (AY) — a pure RECORD, the [UnitState] shape: no rule, no Command, no Event, no [DigRules].
##   - IDENTITY IS READ-ONLY: `hex`, `owner_index` and `total_turns` have no setters (the (AX)
##     immutable-identity rule). ONE OWNER PER SITE.
##   - `remaining_turns` starts at `total_turns` and is written only by `set_remaining_turns`,
##     which is TOTAL and CLAMPS into `[0, total_turns]` (the `UnitState.set_hp` precedent).
##     Reaching 0 does NOT complete or empty the site — that is a RULE (§3.4 step 4), a later
##     slice.
##   - Diggers are a set of unit ids: `digger_ids()` is FRESH and ASCENDING every call, `add_digger`
##     refuses a duplicate and any id <= 0 (roster ids start at 1, 0 means "no unit"), `remove_digger`
##     answers true exactly once. THE CAP IS NOT HERE — §4.2 line 197's "max 2 simultaneous diggers"
##     is a RULE and lives in `DigHexCommand`; the record itself accepts any number of diggers.
##   - THE content_hash FOLD ORDER: hex.x -> hex.y -> owner_index -> total_turns -> remaining_turns
##     -> the digger COUNT -> the digger ids ASCENDING. Count-prefixed, so it is injective without a
##     separator byte (contrast `UnitState._SEPARATOR`, which exists only because `type_id` is a
##     variable-length string).
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time. Class kind is asserted via get_class() ONLY.
class_name DigSite
extends RefCounted

## §4.1/(AY) — the hex this site is on. Identity: read-only.
var _hex: Vector2i = Vector2i.ZERO

## (AY) — the player who ordered this dig. Identity: read-only.
var _owner_index: int = 0

## §4.2 — the total worker-turns this dig costs, supplied by the caller (the Command reads it from
## `DigRules` over §12.1 data). Identity: read-only.
var _total_turns: int = 0

## §4.2 — worker-turns still to dig. Starts at `_total_turns`; written only by
## [method set_remaining_turns].
var _remaining_turns: int = 0

## (AY) — the set of unit ids assigned to this site, unsorted internally; [method digger_ids]
## always hands back a fresh, ascending copy.
var _diggers: Array[int] = []


## §4.2/(AY) — builds a site on `p_hex` for `p_owner_index`, costing `p_total_turns` worker-turns.
## A fresh site starts with all of its worker-turns remaining and no digger assigned.
func _init(p_hex: Vector2i, p_owner_index: int, p_total_turns: int) -> void:
	_hex = p_hex
	_owner_index = p_owner_index
	_total_turns = p_total_turns
	_remaining_turns = p_total_turns


## §4.2 — the hex this site is on. Never changes.
func hex() -> Vector2i:
	return _hex


## §4.2/(AY) — the player who ordered this dig. Never changes.
func owner_index() -> int:
	return _owner_index


## §4.2 — the total worker-turns this dig costs. Never changes.
func total_turns() -> int:
	return _total_turns


## §4.2 — worker-turns still to dig.
func remaining_turns() -> int:
	return _remaining_turns


## §4.2 — writes the remaining worker-turns. TOTAL and CLAMPS into `[0, total_turns]` (the
## `UnitState.set_hp` precedent): an overshoot saturates at `total_turns`, a negative value floors
## at 0. §3.4 step 4 — reaching 0 does NOT complete or empty the site; that is a later RULE.
## Intended to be written only from a Command's apply() (GDScript has no package-private).
func set_remaining_turns(p_remaining: int) -> void:
	_remaining_turns = clampi(p_remaining, 0, maxi(_total_turns, 0))


## §11.1 line 707 — every assigned unit id, ASCENDING, as a FRESH Array every call.
func digger_ids() -> Array[int]:
	var out: Array[int] = _diggers.duplicate()
	out.sort()
	return out


## §4.2 line 197 — assigns `p_unit_id` to this site. Refuses a duplicate assignment and any id <= 0
## (roster ids start at 1; 0 means "no unit"). THE CAP IS NOT HERE — the record accepts any number
## of diggers; §4.2 line 197's "max 2 simultaneous diggers" is a RULE enforced by `DigHexCommand`.
func add_digger(p_unit_id: int) -> bool:
	if p_unit_id <= 0:
		return false
	if _diggers.has(p_unit_id):
		return false
	_diggers.append(p_unit_id)
	return true


## §4.2/(AY) — unassigns `p_unit_id`. TOTAL: true exactly once for an assigned id, false on a
## second call and for a unit that never dug here.
func remove_digger(p_unit_id: int) -> bool:
	var index: int = _diggers.find(p_unit_id)
	if index == -1:
		return false
	_diggers.remove_at(index)
	return true


## §11.1 line 707 — an FNV-1a 32-bit content hash over this record, in the DOCUMENTED order: hex.x,
## hex.y, owner_index, total_turns, remaining_turns, the digger COUNT, then each digger id
## ascending. Count-prefixed, so the fold is injective without needing a separator byte.
func content_hash() -> int:
	var hash_value: int = Fnv.OFFSET_BASIS
	hash_value = Fnv.fold_int64(hash_value, _hex.x)
	hash_value = Fnv.fold_int64(hash_value, _hex.y)
	hash_value = Fnv.fold_int64(hash_value, _owner_index)
	hash_value = Fnv.fold_int64(hash_value, _total_turns)
	hash_value = Fnv.fold_int64(hash_value, _remaining_turns)
	var ids: Array[int] = digger_ids()
	hash_value = Fnv.fold_int64(hash_value, ids.size())
	for id: int in ids:
		hash_value = Fnv.fold_int64(hash_value, id)
	return hash_value
