## Rng — GDD §11.1 (GameState carries "**one** **RandomNumberGenerator** **seeded at match
## start** (the only RNG in the program; every roll goes through state.rng)"; "no randi()";
## "integers + fixed percent math"), §11.2 (`scripts/core/` lists `Rng` among the pure,
## unit-tested core classes), §11.3, §13.2 tier 1, §13.6.
##
## THIS FILE IS THE SINGLE HOME OF THE ENGINE [RandomNumberGenerator] in the whole project.
## Every other sim file is scanned for the token and must not contain it (see
## `tests/unit/test_map_generator.gd`'s ENGINE_BOUND_TOKENS, amended by M1-T5). When `GameState`
## lands, `state.rng` is an instance of THIS class.
##
## Rolls are integer-only: `randi_range(1, 100)` walks the engine's integer PCG path, so no float
## ever enters a rule (§11.1 forbids float accumulation, and M1's first golden hashes the result).
## `randf()`/`randf_range()`/`randomize()` are forbidden here and scanned for.
class_name Rng
extends RefCounted

## The single sanctioned engine RandomNumberGenerator (resolution (R)). Never exposed directly —
## always go through [method roll_percent].
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Number of percent rolls drawn from this stream since construction.
var _rolls: int = 0


func _init(seed_value: int) -> void:
	_rng.seed = seed_value
	_rolls = 0


## §11.1 — one seeded percent roll: an integer in 1..100 inclusive, drawn from the single
## seeded stream and counted by [method rolls_drawn].
func roll_percent() -> int:
	_rolls += 1
	return _rng.randi_range(1, 100)


## §11.1 — how many rolls this stream has drawn, so a caller can prove the roll sequence is a
## function of the iteration order alone.
func rolls_drawn() -> int:
	return _rolls
