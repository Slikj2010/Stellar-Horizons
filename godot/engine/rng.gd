## Seeded random numbers (Park-Miller "minimal standard"), identical to the generator in tools/parity_dump.js,
## so a seeded game plays out the same in Godot and in the web version.
class_name SHRng
extends RefCounted

var seed_value: int

func _init(s: int = 1) -> void:
	seed_value = posmod(s, 2147483647)
	if seed_value == 0: seed_value = 1

func next() -> float:
	seed_value = (seed_value * 48271) % 2147483647
	return float(seed_value) / 2147483647.0

## a Callable for SHRules.rnd; it keeps this generator alive
func as_callable() -> Callable:
	var me := self
	return func() -> float: return me.next()
