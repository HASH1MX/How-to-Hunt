class_name Jaguar
extends Animal
## The jaguar: the jungle's predator (Island 2). It stalks the jungle and hunts any player
## it spots (crouching halves how far it sees you). It can't outrun a sprint, but it's fast
## and it hits hard. 200 health. Drops its body (Jaguar, $150).

const FUR := Color(0.88, 0.62, 0.22)
const SPOT := Color(0.18, 0.12, 0.08)
const BELLY := Color(0.95, 0.86, 0.68)
const LEG_LENGTH := 0.46

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _walk_phase := 0.0
var _time := 0.0


func _init() -> void:
	display_name = "Jaguar"
	max_health = 200.0
	walk_speed = 1.6
	flee_speed = 7.0
	skittish_distance = 0.0
	flee_time = 3.0
	loot_id = &"jaguar"
	body_size = Vector3(0.5, 0.8, 1.3)
	aggressive = true
	aggro_distance = 16.0
	chase_speed = 7.2
	attack_damage = 20.0
	attack_gap = 1.4
	attack_reach = 2.0
	chase_time = 14.0
	hurt_sound = "growl"
	die_sound = "growl"
	attack_sound = "roar"
	idle_sound = "growl"
	idle_sound_gap = Vector2(14.0, 30.0)


func _build_model(root: Node3D) -> void:
	for z in [-0.42, 0.42]:
		for side in [-1.0, 1.0]:
			var leg := _pivot(root, Vector3(0.13 * side, LEG_LENGTH + 0.1, z))
			var st := _begin()
			_sphere(st, 0.1, Vector3.ZERO, Vector3(0.9, 1.2, 1.2), FUR)
			_limb(st, Vector3(0, -0.05, 0), Vector3(0, -LEG_LENGTH - 0.05, 0), 0.07, 0.05, FUR)
			_sphere(st, 0.06, Vector3(0, -LEG_LENGTH - 0.07, -0.03), Vector3(1.0, 0.7, 1.4), FUR.lightened(0.1)) # Paw.
			_finish(st, leg)
			_legs.append(leg)
	_body = _pivot(root, Vector3(0, LEG_LENGTH + 0.2, 0))
	var st := _begin()
	_sphere(st, 0.24, Vector3.ZERO, Vector3(0.95, 0.9, 2.3), FUR)
	_sphere(st, 0.19, Vector3(0, -0.07, 0), Vector3(0.95, 0.7, 2.2), BELLY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var side := -1.0 if i % 2 == 0 else 1.0
		_sphere(st, 0.035, Vector3(side * rng.randf_range(0.12, 0.2), rng.randf_range(0.04, 0.17), rng.randf_range(-0.45, 0.45)), Vector3(1.2, 1.0, 1.4), SPOT)
	_finish(st, _body)
	_head = _pivot(_body, Vector3(0, 0.12, -0.55))
	st = _begin()
	_sphere(st, 0.16, Vector3.ZERO, Vector3(1.0, 0.9, 1.05), FUR)
	_limb(st, Vector3(0, -0.04, -0.1), Vector3(0, -0.06, -0.19), 0.08, 0.06, BELLY) # Muzzle.
	_sphere(st, 0.025, Vector3(0, -0.03, -0.24), Vector3(1.3, 0.9, 1.0), SPOT) # Nose.
	for side in [-1.0, 1.0]:
		_sphere(st, 0.026, Vector3(0.07 * side, 0.05, -0.13), Vector3.ONE, Color(0.85, 0.75, 0.2)) # Eyes.
		_sphere(st, 0.012, Vector3(0.07 * side, 0.05, -0.155), Vector3(0.5, 1.4, 0.5), Color(0.05, 0.04, 0.03))
		_sphere(st, 0.05, Vector3(0.1 * side, 0.13, 0.0), Vector3(1.0, 1.0, 0.5), FUR) # Ears.
	_finish(st, _head)
	_tail = _pivot(_body, Vector3(0, 0.08, 0.52))
	st = _begin()
	var curve := [Vector3.ZERO, Vector3(0, -0.12, 0.25), Vector3(0, -0.15, 0.5), Vector3(0, -0.02, 0.72)]
	for i in 3:
		_limb(st, curve[i], curve[i + 1], 0.04, 0.035, FUR if i < 2 else SPOT)
	_finish(st, _tail)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	var moving := speed > 0.2
	if moving:
		_walk_phase += delta * (4.5 + speed * 1.3)
	var amount := clampf(speed / 5.0, 0.3, 0.9) if moving else 0.0
	var phases := [0.0, PI, PI * 0.9, 0.1]
	for i in _legs.size():
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, sin(_walk_phase + phases[i]) * amount, 1.0 - exp(-12.0 * delta))
	# Low and stretched when charging.
	_body.position.y = LEG_LENGTH + 0.2 - (0.06 if speed > 5.0 else 0.0) + (absf(sin(_walk_phase)) * 0.03 if moving else 0.0)
	_tail.rotation.x = sin(_time * 2.0) * 0.25
	_tail.rotation.y = sin(_time * 1.3) * 0.3
	_head.rotation.y = sin(_time * 0.5) * 0.3 if not moving else 0.0
