class_name Boar
extends Animal
## A wild boar (Island 2): stocky, bristly and grumpy. It leaves you alone, but hit it and
## it charges back at you with its tusks until it's badly hurt.
## 120 health. Drops its body (Boar, $45).

const FUR := Color(0.32, 0.25, 0.22)
const BRISTLE := Color(0.2, 0.16, 0.14)
const SNOUT := Color(0.62, 0.45, 0.42)
const TUSK := Color(0.95, 0.92, 0.82)
const LEG_LENGTH := 0.34

var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _walk_phase := 0.0
var _time := 0.0


func _init() -> void:
	display_name = "Boar"
	max_health = 120.0
	walk_speed = 1.3
	flee_speed = 5.5
	skittish_distance = 6.0
	flee_time = 3.0
	loot_id = &"boar"
	body_size = Vector3(0.55, 0.7, 1.0)
	retaliates = true
	chase_speed = 6.2
	attack_damage = 18.0
	attack_gap = 1.3
	attack_reach = 1.7
	chase_time = 8.0
	hurt_sound = "deer_hurt"
	die_sound = "deer_die"
	alert_sound = "deer_snort"
	attack_sound = "deer_snort"


func _build_model(root: Node3D) -> void:
	for z in [-0.3, 0.3]:
		for side in [-1.0, 1.0]:
			var leg := _pivot(root, Vector3(0.15 * side, LEG_LENGTH + 0.08, z))
			var st := _begin()
			_limb(st, Vector3.ZERO, Vector3(0, -LEG_LENGTH - 0.04, 0), 0.07, 0.05, FUR)
			_sphere(st, 0.05, Vector3(0, -LEG_LENGTH - 0.06, -0.01), Vector3(1.0, 0.8, 1.2), BRISTLE)
			_finish(st, leg)
			_legs.append(leg)
	_body = _pivot(root, Vector3(0, LEG_LENGTH + 0.22, 0))
	var st := _begin()
	_sphere(st, 0.3, Vector3.ZERO, Vector3(0.95, 0.95, 1.7), FUR)
	_sphere(st, 0.27, Vector3(0, 0.06, -0.25), Vector3(1.05, 1.05, 1.0), FUR) # Big shoulders.
	for i in 5:
		_sphere(st, 0.07, Vector3(0, 0.27 - i * 0.012, -0.3 + i * 0.14), Vector3(0.5, 1.2, 1.4), BRISTLE) # Bristly ridge.
	_limb(st, Vector3(0, 0.08, 0.48), Vector3(0, -0.05, 0.6), 0.025, 0.015, BRISTLE) # Tail.
	_finish(st, _body)
	_head = _pivot(_body, Vector3(0, 0.02, -0.5))
	st = _begin()
	_sphere(st, 0.2, Vector3(0, 0, -0.06), Vector3(0.9, 0.85, 1.15), FUR)
	_limb(st, Vector3(0, -0.04, -0.2), Vector3(0, -0.08, -0.34), 0.1, 0.08, FUR) # Snout.
	_sphere(st, 0.08, Vector3(0, -0.08, -0.38), Vector3(1.0, 0.85, 0.5), SNOUT)
	for side in [-1.0, 1.0]:
		_limb(st, Vector3(0.07 * side, -0.12, -0.3), Vector3(0.1 * side, -0.02, -0.38), 0.018, 0.008, TUSK) # Tusks.
		_sphere(st, 0.02, Vector3(0.1 * side, 0.08, -0.2), Vector3.ONE, Color(0.05, 0.04, 0.04))
		_limb(st, Vector3(0.11 * side, 0.15, -0.02), Vector3(0.17 * side, 0.26, 0.02), 0.04, 0.015, FUR) # Ears.
	_finish(st, _head)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	var moving := speed > 0.2
	if moving:
		_walk_phase += delta * (6.0 + speed * 1.6)
	var amount := clampf(speed / 4.0, 0.3, 0.8) if moving else 0.0
	var phases := [0.0, PI, PI, 0.0]
	for i in _legs.size():
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, sin(_walk_phase + phases[i]) * amount, 1.0 - exp(-12.0 * delta))
	_body.position.y = LEG_LENGTH + 0.22 + (absf(sin(_walk_phase)) * 0.04 if moving else 0.0)
	# Snuffling at the ground while standing.
	_head.rotation.x = (sin(_time * 1.3) * 0.15 - 0.15) if not moving else -0.1
