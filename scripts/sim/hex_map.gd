## HexMap — GDD §4.1 (Hex Grid Specification, binding: "Elevation: integer 0-3 per hex",
## "Map sizes (hex radius): Small 24 ... Medium 32 ... Large 40"), §11.1 (GameState's
## "map (hex array: type, elevation, features, light, stress, knowledge per player)";
## sim core is engine-free and deterministic), §11.2 (`scripts/sim/`), §11.3, §13.2, §13.6.
##
## The per-hex terrain container `Los` deliberately did NOT invent (M1-T3 resolution (H)):
## `Los` consumes two [Callable]s, so this class is free to pick its own shape and callers bind
## closures over it — `scripts/core/los.gd` never changes.
##
## SLICE 1 STORES ELEVATION ONLY. Terrain type (§4.2), features, veins, light, stress and
## per-player knowledge belong to later tasks/milestones (§13.4: invent nothing ahead of its
## milestone). This class grows field by field, exactly as GameState will.
##
## §13.4 resolution (O) — STORAGE, CANONICAL ORDER AND OUT-OF-BOUNDS TOTALITY:
##   - Storage is ONE [PackedInt32Array] over the axial bounding square, index
##     `(r + radius) * (2 * radius + 1) + (q + radius)`. No [Dictionary] anywhere, so
##     Dictionary key order can never leak into behaviour (§11.1 "iterate collections in stable
##     ID order").
##   - Membership is `HexMath.distance(Vector2i.ZERO, hex) <= radius` — never a second bounds
##     formula.
##   - CANONICAL ITERATION ORDER (pinned by test; the M1-T5 golden will hash it):
##     `r` ascending from `-radius` to `+radius`, and within each `r`, `q` ascending.
##     [method hexes] builds a FRESH `Array[Vector2i]` every call (M1-T2 trap 1).
##   - A fresh map starts at §4.1's elevation floor, 0, on every in-bounds hex.
##   - Every accessor is TOTAL (the spirit of M1-T1 resolution (B) and M1-T3 resolution (L)):
##     a bad argument must never tear down a headless run. Off-disc, [method get_elevation]
##     returns the sentinel -1, [method index_of] returns -1 and [method set_elevation] is a
##     silent no-op. A negative radius is the empty map.
class_name HexMap
extends RefCounted

## §4.1 — the map's hex radius (Small 24 / Medium 32 / Large 40 come from
## `data/mapgen/*.json`, never from this file).
var radius: int = 0

## Backing storage over the axial bounding square (resolution (O)). Never exposed directly —
## always go through [method get_elevation]/[method set_elevation].
var _elevations: PackedInt32Array = PackedInt32Array()

## §4.2 terrain-type ids over the SAME index scheme (M1-T5). One PackedStringArray, never a
## Dictionary. The default and out-of-bounds value is the empty id "".
var _terrain_types: PackedStringArray = PackedStringArray()

## Side length of the axial bounding square, `2 * radius + 1`; 0 when `radius` is negative.
var _side: int = 0

## FNV-1a 32-bit constants for [method content_hash] (resolution (U)). Algorithm constants, not
## GDD game content, so they stay as code literals rather than moving to data/*.json.
const FNV_OFFSET_BASIS: int = 2166136261
const FNV_PRIME: int = 16777619
const FNV_MASK: int = 0xffffffff
const FNV_SEPARATOR: int = 0x1f


func _init(map_radius: int) -> void:
	radius = map_radius
	_elevations = PackedInt32Array()
	_terrain_types = PackedStringArray()
	if radius < 0:
		_side = 0
		return
	_side = 2 * radius + 1
	_elevations.resize(_side * _side)
	_terrain_types.resize(_side * _side)


## §4.1 — number of in-bounds hexes, i.e. `3 * radius * (radius + 1) + 1` for a non-negative
## radius and 0 for a negative one.
func hex_count() -> int:
	if radius < 0:
		return 0
	return 3 * radius * (radius + 1) + 1


## §4.1 — true when `hex` lies within `radius` of the origin under cube distance.
func is_in_bounds(hex: Vector2i) -> bool:
	if radius < 0:
		return false
	return HexMath.distance(Vector2i.ZERO, hex) <= radius


## §4.1 — stable dense storage index of `hex`, or -1 when it is out of bounds.
func index_of(hex: Vector2i) -> int:
	if not is_in_bounds(hex):
		return -1
	return (hex.y + radius) * _side + (hex.x + radius)


## §4.1 — every in-bounds hex in canonical order (`r` ascending, then `q` ascending), as a
## FRESH array per call.
func hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius < 0:
		return out
	for r: int in range(-radius, radius + 1):
		for q: int in range(-radius, radius + 1):
			var hex: Vector2i = Vector2i(q, r)
			if HexMath.distance(Vector2i.ZERO, hex) <= radius:
				out.append(hex)
	return out


## §4.1 — elevation (integer 0-3) at `hex`; -1 when `hex` is out of bounds.
func get_elevation(hex: Vector2i) -> int:
	var index: int = index_of(hex)
	if index == -1:
		return -1
	return _elevations[index]


## §4.1 — writes the elevation at `hex`; a silent no-op when `hex` is out of bounds.
func set_elevation(hex: Vector2i, value: int) -> void:
	var index: int = index_of(hex)
	if index == -1:
		return
	_elevations[index] = value


## §4.2 — terrain-type id at `hex` ("" when unset or out of bounds).
func get_terrain_type(hex: Vector2i) -> String:
	var index: int = index_of(hex)
	if index == -1:
		return ""
	return _terrain_types[index]


## §4.2 — writes the terrain-type id at `hex`; a silent no-op when `hex` is out of bounds.
func set_terrain_type(hex: Vector2i, value: String) -> void:
	var index: int = index_of(hex)
	if index == -1:
		return
	_terrain_types[index] = value


## §11.1 — reproducible FNV-1a 32-bit content hash over this map in canonical order (resolution
## (U)): the radius, then every hex's coordinates, elevation and terrain-type id, in [method hexes]
## order. This is the value the M1 golden records (§14 M1: "Golden mapgen test (seed => terrain
## hash)").
func content_hash() -> int:
	var hash_value: int = FNV_OFFSET_BASIS
	hash_value = _fold_int(hash_value, radius)
	for hex: Vector2i in hexes():
		hash_value = _fold_int(hash_value, hex.x)
		hash_value = _fold_int(hash_value, hex.y)
		hash_value = _fold_int(hash_value, get_elevation(hex))
		hash_value = _fold_bytes(hash_value, get_terrain_type(hex).to_utf8_buffer())
		hash_value = _fold_byte(hash_value, FNV_SEPARATOR)
	return hash_value


## Folds `value`'s 4 little-endian bytes (masked to 32 bits first) into `hash_value` via FNV-1a,
## masking after every multiply so the result never escapes 32 bits (resolution (U)).
func _fold_int(hash_value: int, value: int) -> int:
	var masked: int = value & FNV_MASK
	var result: int = hash_value
	var byte_width: int = 8
	for byte_index: int in range(4):
		var shift: int = byte_width * byte_index
		result = _fold_byte(result, (masked >> shift) & 0xff)
	return result


## Folds every byte of `data` into `hash_value` via FNV-1a, in order.
func _fold_bytes(hash_value: int, data: PackedByteArray) -> int:
	var result: int = hash_value
	for byte: int in data:
		result = _fold_byte(result, byte)
	return result


## One FNV-1a step: xor the byte in, multiply by the prime, mask to 32 bits.
func _fold_byte(hash_value: int, byte: int) -> int:
	var result: int = (hash_value ^ byte) & FNV_MASK
	result = (result * FNV_PRIME) & FNV_MASK
	return result
