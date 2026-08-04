## Fnv — GDD §11.1 ("GameState.hash() (FNV over canonical serialization) must be reproducible"),
## §11.2 (`scripts/core/` is where the pure, unit-tested algorithm helpers live), §11.3.
##
## The shared FNV-1a 32-bit fold helper for §11.1's content-hash contract: an all-static
## namespace, never instantiated with state. Parameters match the published FNV-1a 32-bit
## constants, and also `scripts/sim/hex_map.gd`'s already-landed private constants (M1-T5 (U)) —
## one algorithm for the whole project, resolution (AU).
##
## DELIBERATE DUPLICATION, RECORDED NOT FIXED (decisions.md (AU)): `scripts/sim/hex_map.gd` keeps
## its own PRIVATE `_fold_int`/`_fold_bytes`/`_fold_byte`, which fold an int as 4 little-endian
## bytes (its 0..3 elevations never need more) while [method fold_int64] here folds 8 (§5.1 "No
## storage caps" needs the full 64-bit range). This task does not retrofit `Fnv` into `HexMap` —
## the M1-T5 golden (`tests/golden/mapgen_concentric_bowl_small_seed1337.json`, content_hash
## `0xcad24923`) must stay byte-identical and untouched. A later opportunistic task may collapse
## the duplication with that golden as its proof.
class_name Fnv
extends RefCounted

## The FNV-1a 32-bit offset basis (published constant).
const OFFSET_BASIS: int = 2166136261

## The FNV-1a 32-bit prime (published constant).
const PRIME: int = 16777619

## Every fold step is masked to this after each multiply, keeping the accumulator a genuine
## 32-bit unsigned value rather than relying on int64 overflow.
const MASK: int = 0xffffffff

## Bytes per [method fold_int64] call (little-endian).
const _INT64_BYTE_COUNT: int = 8

## Bits per byte, used to compute each shift in [method fold_int64] without a literal shift table.
const _BITS_PER_BYTE: int = 8


## §11.1 — one FNV-1a step: xor `byte_value` into `hash_value`, multiply by [constant PRIME], mask
## to 32 bits. The building block every other fold in this file composes.
static func fold_byte(hash_value: int, byte_value: int) -> int:
	var result: int = (hash_value ^ byte_value) & MASK
	result = (result * PRIME) & MASK
	return result


## §11.1 — folds `value` as EIGHT little-endian bytes (masking to 64 bits first so a negative
## int64 folds the same way every time). §5.1's "No storage caps" stockpiles are honest 64-bit
## integers, so two amounts differing only above 2^32 must fold to different hashes — a 4-byte
## fold (the shape `hex_map.gd` uses for its 0..3 elevations) cannot make that distinction.
static func fold_int64(hash_value: int, value: int) -> int:
	var result: int = hash_value
	for byte_index: int in range(_INT64_BYTE_COUNT):
		var shift: int = _BITS_PER_BYTE * byte_index
		result = fold_byte(result, (value >> shift) & 0xff)
	return result


## §11.1 — folds every byte of `data` into `hash_value`, left to right, via [method fold_byte]. An
## empty buffer is the identity: folding nothing leaves the accumulator unchanged.
static func fold_bytes(hash_value: int, data: PackedByteArray) -> int:
	var result: int = hash_value
	for byte_value: int in data:
		result = fold_byte(result, byte_value)
	return result


## §11.1 — folds `text`'s UTF-8 bytes into `hash_value`; exactly [method fold_bytes] over
## `text.to_utf8_buffer()`, so string and byte-buffer folds always agree.
static func fold_string(hash_value: int, text: String) -> int:
	return fold_bytes(hash_value, text.to_utf8_buffer())
