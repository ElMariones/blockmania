class_name BMRngStream
extends RefCounted
## Named, seeded random stream. Separate streams (shapes, shop, boss) keep UI activity or
## shop browsing from changing shape draws. Godot's RandomNumberGenerator is PCG32 and
## deterministic for a given seed/state across platforms.

var name: String
var _rng := RandomNumberGenerator.new()


func _init(run_seed: int = 0, stream_name: String = "") -> void:
	name = stream_name
	_rng.seed = ("%d/%s" % [run_seed, stream_name]).hash()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Picks an index from integer weights. Returns -1 for an empty or all-zero list.
func weighted_index(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return -1
	var roll := _rng.randi_range(0, total - 1)
	for i in weights.size():
		roll -= int(weights[i])
		if roll < 0:
			return i
	return weights.size() - 1


## 64-bit seed/state are stored as strings so JSON saves keep full precision.
func get_state() -> Dictionary:
	return {"name": name, "seed": str(_rng.seed), "state": str(_rng.state)}


func set_state(d: Dictionary) -> void:
	name = d.get("name", name)
	_rng.seed = String(d.seed).to_int()
	_rng.state = String(d.state).to_int()


func clone() -> BMRngStream:
	var c := BMRngStream.new()
	c.set_state(get_state())
	return c
