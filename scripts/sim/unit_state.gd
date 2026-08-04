## UnitState — GDD §11.1 ("GameState: single serializable object - map ..., players
## (stockpiles, techs, meters), units, buildings, nodes, turn counters, and one
## RandomNumberGenerator seeded at match start" — line 704; "iterate collections in stable ID
## order ... GameState.hash() (FNV over canonical serialization) must be reproducible" — line
## 707), §12.2 (unit definition — an instance references its definition by the opaque `id`
## string, and "hp" is a DATA value), §12.7 line 1015 ("worker | dig_mult | Can Dig/Build;
## dig-speed multiplier" — worker-ness is a TRAIT, not a class), §11.2 (`scripts/sim/`), §11.3.
##
## §13.4 resolution (AX) (M2-T3 ended the lettering at (AW); the full resolution is recorded in
## `docs/decisions.md`):
##   - Units are a TOP-LEVEL GameState collection (§11.1 line 704), never a PlayerState field, so
##     a unit carries its OWNER as an integer player index rather than being reached through a
##     player's stockpile.
##   - `type_id` is an OPAQUE String — the definition's `id` — and `max_hp` is CALLER-SUPPLIED:
##     `data/units/*.json` is an M6 deliverable, so this record holds no stat table and no
##     unit-type whitelist. §12.7's `worker` trait is DATA, never a class, so there is
##     deliberately no `is_worker()`/`has_trait()`.
##   - IDENTITY IS READ-ONLY: `unit_id`, `owner_index` and `type_id` have no setters — a unit that
##     could change owner or definition mid-match would break §11.1's replay contract in a way no
##     hash comparison could ever show.
##   - `set_hex`/`set_hp` are intended to be written only from a Command's apply() (the
##     `GameState.set_turn_position`/`HexMap.set_elevation` precedent; GDScript has no
##     package-private).
##   - `set_hp` is TOTAL and CLAMPS into [0, max_hp] rather than refusing: an overheal saturates
##     at max_hp, an overkill floors at 0, and 0 hp does NOT remove the unit — whether 0 hp kills
##     is a RULE (§3.4 step 2's bleed, §6 combat) for a later slice, never a record concern.
##   - THE DOCUMENTED content_hash FOLD ORDER — fixed-width fields first, the variable-length
##     `type_id` LAST, followed by the private `_SEPARATOR` byte, so the record is obviously
##     injective without needing a confusable-pair fixture: unit_id -> owner_index -> hex.x ->
##     hex.y -> hp -> max_hp -> type_id's UTF-8 bytes -> `_SEPARATOR`.
##
## DELIBERATELY NOT BUILT HERE (§13.4 — invent nothing ahead of its milestone): §12.7's trait set,
## §3.1's starting kit, §5.2's housing cap, movement/combat rules, damage/heal, and any
## data-loaded stat block. This is a pure RECORD; `scripts/sim/game_state.gd`'s unit roster is the
## container that mints, stores and removes it.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): `x is Node` against a RefCounted-typed variable is a
## statically impossible cast rejected at PARSE time, which silently un-collects the whole file.
## Class kind is asserted via get_class() ONLY (see `tests/unit/test_unit_state.gd`).
class_name UnitState
extends RefCounted

## FNV-1a separator byte appended after the variable-length `type_id` in [method content_hash] —
## the `PlayerState._SEPARATOR` precedent (resolution (AU)). PRIVATE, so the public surface stays
## at zero consts; its numbers are otherwise all caller-supplied.
const _SEPARATOR: int = 0x1f

## §11.1 — the unit's stable id, minted once by the roster and never reused. Read-only: see
## [method unit_id].
var _unit_id: int = 0

## §11.1 line 704 — the owning player's index. Read-only: see [method owner_index].
var _owner_index: int = 0

## §12.2 — the opaque definition id (e.g. "dwarf_crossbow"). Read-only: see [method type_id].
var _type_id: String = ""

## §4.1 — the unit's axial (q, r) position.
var _hex: Vector2i = Vector2i.ZERO

## §12.2/§3.4 step 2 — current health, clamped into [0, _max_hp] by [method set_hp].
var _hp: int = 0

## §12.2 — the health ceiling this unit was constructed with. Never changes after [method _init].
var _max_hp: int = 0


## §11.1/§12.2 — builds a unit for `p_owner_index`, of the opaque definition `p_type_id`, at
## `p_hex`, with `p_max_hp` as BOTH its maximum AND its starting current health (§12.2: "a fresh
## unit starts at full health").
func _init(
	p_unit_id: int,
	p_owner_index: int,
	p_type_id: String,
	p_hex: Vector2i,
	p_max_hp: int
) -> void:
	_unit_id = p_unit_id
	_owner_index = p_owner_index
	_type_id = p_type_id
	_hex = p_hex
	_max_hp = p_max_hp
	_hp = p_max_hp


## §11.1 — the unit's stable id, as minted by the roster. Never changes.
func unit_id() -> int:
	return _unit_id


## §11.1 line 704 — the owning player's index. Never changes: identity is immutable.
func owner_index() -> int:
	return _owner_index


## §12.2 — the opaque definition id this unit was constructed with. Never changes.
func type_id() -> String:
	return _type_id


## §11.1/§4.1 — the unit's current axial (q, r) position.
func hex() -> Vector2i:
	return _hex


## §11.1 — writes the unit's position. Intended to be written only from a Command's apply() (the
## `GameState.set_turn_position`/`HexMap.set_elevation` precedent; GDScript has no
## package-private). Touches nothing else on the record.
func set_hex(p_hex: Vector2i) -> void:
	_hex = p_hex


## §12.2 — current health.
func hp() -> int:
	return _hp


## §12.2 — the health ceiling; the value §3.4 step 2's "10% max HP" upkeep bleed reads. Set once
## at construction and never changes afterward.
func max_hp() -> int:
	return _max_hp


## §12.2/§3.4 step 2 — writes current health. TOTAL: CLAMPS into [0, max_hp] rather than
## refusing — an overheal saturates at max_hp and an overkill floors at 0. 0 is a legal,
## representable hp and does NOT remove the unit (that is a later RULE, not this record's
## concern). Intended to be written only from a Command's apply().
func set_hp(p_hp: int) -> void:
	_hp = clampi(p_hp, 0, _max_hp)


## §11.1 line 707 — an FNV-1a 32-bit content hash over this unit's record, in the DOCUMENTED
## order (fixed-width fields first, the variable-length `type_id` last, terminated by the private
## separator, so the record is obviously injective): unit_id, owner_index, hex.x, hex.y, hp,
## max_hp, then type_id's UTF-8 bytes, then the separator byte.
func content_hash() -> int:
	var hash_value: int = Fnv.OFFSET_BASIS
	hash_value = Fnv.fold_int64(hash_value, _unit_id)
	hash_value = Fnv.fold_int64(hash_value, _owner_index)
	hash_value = Fnv.fold_int64(hash_value, _hex.x)
	hash_value = Fnv.fold_int64(hash_value, _hex.y)
	hash_value = Fnv.fold_int64(hash_value, _hp)
	hash_value = Fnv.fold_int64(hash_value, _max_hp)
	hash_value = Fnv.fold_string(hash_value, _type_id)
	hash_value = Fnv.fold_byte(hash_value, _SEPARATOR)
	return hash_value
