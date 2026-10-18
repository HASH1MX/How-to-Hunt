class_name Squirrel
extends Animal
## A squirrel: small and quick, with a big bushy tail.
## Runs away if you run close to it. Sometimes sits up to look around.
## 20 health = 2 punches. Drops a Squirrel Tail.

const FUR := Color(0.7, 0.4, 0.18)
const BELLY := Color(0.93, 0.82, 0.66)

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _hop_phase := 0.0
var _time := 0.0
var _sit := 0.0


func _init() -> void:
	display_name = "Squirrel"
	max_health = 20.0
	walk_speed = 1.8
	flee_speed = 5.2
	skittish_distance = 5.0
	flee_time = 3.0
	loot_id = &"squirrel_tail"
	hurt_sound = "squirrel_hurt"
	die_sound = "squirrel_hurt"
	alert_sound = "squirrel_chitter"
	idle_sound = "squirrel_chitter"
	idle_sound_gap = Vector2(15.0, 35.0)
	body_size = Vector3(0.22, 0.26, 0.32)


func _build_model(root: Node3D) -> void:
	var dark := FUR.darkened(0.12)
	_body = _pivot(root, Vector3(0, 0, 0))
	var st := _begin()
	_sphere(st, 0.09, Vector3(0, 0.1, 0.02), Vector3(1.0, 1.0, 1.4), FUR) # Body.
	_sphere(st, 0.06, Vector3(0, 0.085, -0.04), Vector3(1.0, 1.0, 1.2), BELLY) # Belly.
	_sphere(st, 0.075, Vector3(0, 0.13, -0.07), Vector3.ONE, FUR) # Chest, blends into the neck.
	for side in [-1.0, 1.0]:
		_sphere(st, 0.06, Vector3(0.06 * side, 0.07, 0.07), Vector3(0.75, 1.0, 1.3), FUR) # Haunch.
		_box(st, Vector3(0.04, 0.03, 0.1), Vector3(0.055 * side, 0.015, 0.05), dark) # Back foot.
		_limb(st, Vector3(0.04 * side, 0.1, -0.07), Vector3(0.035 * side, 0.02, -0.095), 0.022, 0.016, FUR) # Front leg.
		_box(st, Vector3(0.03, 0.02, 0.04), Vector3(0.035 * side, 0.012, -0.105), dark) # Front paw.
	_finish(st, _body)

	_head = _pivot(_body, Vector3(0, 0.16, -0.09))
	st = _begin()
	_sphere(st, 0.065, Vector3(0, 0, -0.02), Vector3(0.95, 0.95, 1.15), FUR)
	_sphere(st, 0.035, Vector3(0, -0.02, -0.075), Vector3(1.0, 0.8, 1.0), BELLY) # Muzzle.
	for side in [-1.0, 1.0]:
		_sphere(st, 0.022, Vector3(0.04 * side, 0.07, 0.0), Vector3(0.6, 1.4, 0.7), dark) # Ears.
		_sphere(st, 0.015, Vector3(0.04 * side, 0.02, -0.055), Vector3.ONE, Color(0.05, 0.05, 0.05))
	_sphere(st, 0.011, Vector3(0, -0.012, -0.105), Vector3.ONE, Color(0.25, 0.15, 0.12))
	_finish(st, _head)

	# Bushy tail: one connected S-curve rising up behind the back, fatter towards the tip.
	_tail = _pivot(_body, Vector3(0, 0.08, 0.1))
	st = _begin()
	var curve := [Vector3(0, 0.0, 0.0), Vector3(0, 0.06, 0.1), Vector3(0, 0.17, 0.14), Vector3(0, 0.27, 0.1), Vector3(0, 0.33, 0.0)]
	var radii := [0.035, 0.065, 0.09, 0.1, 0.08]
	for i in 4:
		_limb(st, curve[i], curve[i + 1], radii[i], radii[i + 1], FUR.lightened(0.04 * i))
	_finish(st, _tail)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	if speed > 0.3:
		_hop_phase += delta * (9.0 + speed * 1.5)
		_body.position.y = absf(sin(_hop_phase)) * 0.07
		_body.rotation.x = cos(_hop_phase) * 0.2
		_sit = maxf(_sit - delta * 4.0, 0.0)
	else:
		_body.position.y = lerpf(_body.position.y, 0.05 * _sit, 1.0 - exp(-12.0 * delta))
		# Sit up on the back legs now and then.
		var wants_sit := sin(_time * 0.5) > 0.3
		_sit = move_toward(_sit, 1.0 if wants_sit else 0.0, delta * 3.0)
		_body.rotation.x = lerpf(_body.rotation.x, 0.9 * _sit, 1.0 - exp(-10.0 * delta))
	_head.rotation.y = sin(_time * 1.3) * 0.5 * _sit
	_tail.rotation.x = sin(_time * 3.0) * 0.12 - 0.1 + _body.rotation.x * -0.4
