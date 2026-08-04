## PlayerState — GDD §5.1 ("No storage caps. Stockpiles are per-player integers"), §3.4 step 2
## (upkeep deficit is paid in HP, never in negative stock), §11.1, §11.2, §11.3.
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §5.1 (line 288): "No storage caps. Stockpiles are per-player integers; income/expense
##                     preview shown in HUD."
##   §3.4 step 2 (line 146): "Upkeep: pay per unit. Deficit: every unpaid unit loses 10% max HP
##                     this turn" — a shortage is paid in HP, so a stockpile NEVER goes negative
##                     and a debit must refuse ATOMICALLY instead.
##
## RESOURCE IDS ARE OPAQUE STRINGS — there is NO whitelist in engine code, on the §4.2
## terrain-type precedent (decisions.md M1-T5 (T) / M1-T7 (AH)). §5.1's resource vocabulary is
## pinned by test, never by an enum or a `const` in this file.
##
## §13.4 resolution (AU) (M1-T9 ended the lettering at (AT)):
##   - A stockpile is an honest 64-bit integer (§5.1 "No storage caps"), never a 32-bit slot.
##   - `add`/`spend` are TOTAL (the M1-T1 (B) / M1-T3 (L) spirit): a non-positive amount or an
##     empty id is refused (false) and touches nothing.
##   - `spend` refuses ATOMICALLY rather than going negative.
##   - Spending a balance to exactly zero REMOVES the entry: "never had it" and "spent it all"
##     are indistinguishable, so `content_hash` is a function of the OBSERVABLE stockpile only.
##   - `can_afford` is exactly the `spend` predicate.
##   - Canonical order is ASCENDING id (String order), independent of insertion order;
##     `resource_ids()` is a fresh array every call.
##
## DELIBERATELY NOT IN M2-T1 (§13.4 — invent nothing ahead of its milestone): §3.1's starting kit
## needs its own §12.1 ruleset key and a later task, so every player starts EMPTY here; techs,
## meters, units, buildings, housing and upkeep all belong to later slices.
class_name PlayerState
extends RefCounted

## FNV-1a separator byte between one resource id/amount pair and the next in [method
## content_hash] — keeps "a" then "bc" from folding the same as "ab" then "c".
const _SEPARATOR: int = 0x1f

## Backing stockpile store, keyed by opaque resource id; touched only via key lookup, assignment
## and erase. Canonical ordering (§11.1 "iterate collections in stable ID order") always comes
## from sorting a FRESH copy of the keys — never from iterating this Dictionary directly.
var _amounts: Dictionary = {}


## §5.1 — the amount held of `resource_id`; 0 for an id never deposited (ids are opaque, so an
## unrecognised one answers 0 rather than failing).
func amount_of(resource_id: String) -> int:
	if not _amounts.has(resource_id):
		return 0
	var held: int = _amounts[resource_id]
	return held


## §5.1/§11.1 — deposits `amount` of `resource_id`. TOTAL: a non-positive `amount` or an empty
## `resource_id` is refused (returns false) without creating or changing any entry.
func add(resource_id: String, amount: int) -> bool:
	if resource_id.is_empty() or amount <= 0:
		return false
	var existing: int = amount_of(resource_id)
	_amounts[resource_id] = existing + amount
	return true


## §3.4 step 2 — spends `amount` of `resource_id`. Refuses ATOMICALLY (returns false, changes
## nothing) when `amount` is non-positive, `resource_id` is empty, or the held balance is short —
## a shortage is paid in HP elsewhere, never by a negative stockpile. Spending the WHOLE balance
## REMOVES the entry (§11.1: "never had it" and "spent it all" must hash identically).
func spend(resource_id: String, amount: int) -> bool:
	if resource_id.is_empty() or amount <= 0:
		return false
	var held: int = amount_of(resource_id)
	if amount > held:
		return false
	var remaining: int = held - amount
	if remaining == 0:
		_amounts.erase(resource_id)
	else:
		_amounts[resource_id] = remaining
	return true


## §3.4 step 2 — exactly the [method spend] predicate, so validation and mutation can never
## drift: true iff `amount` is strictly positive and does not exceed the held balance.
func can_afford(resource_id: String, amount: int) -> bool:
	return amount > 0 and amount_of(resource_id) >= amount


## §11.1 — every resource id currently held (strictly positive amounts only), ascending by
## String and independent of insertion order. A FRESH array every call.
func resource_ids() -> Array[String]:
	var ids: Array[String] = []
	var keys: Array = _amounts.keys()
	for key: Variant in keys:
		var id: String = key as String
		ids.append(id)
	ids.sort()
	return ids


## §11.1 — an FNV-1a 32-bit content hash over the canonical (ascending-id) serialization: for
## each held id in order, its UTF-8 bytes, the amount as eight little-endian bytes ([Fnv]'s
## 64-bit fold, the §5.1 "No storage caps" pin), then a separator byte.
func content_hash() -> int:
	var hash_value: int = Fnv.OFFSET_BASIS
	for id: String in resource_ids():
		hash_value = Fnv.fold_string(hash_value, id)
		hash_value = Fnv.fold_int64(hash_value, amount_of(id))
		hash_value = Fnv.fold_byte(hash_value, _SEPARATOR)
	return hash_value
