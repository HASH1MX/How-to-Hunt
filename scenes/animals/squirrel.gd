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
	flee_speed = 6.0
	skittish_distance = 5.0
	flee_time = 3.0
	loot_id = &"squirrel_tail"
	body_size = Vector3(0.22, 0.26, 0.32)


func _build_model(root: Node3D) -> void:
	_body = _pivot(root, Vector3(0, 0, 0))
	var st := _begin()
	_sphere(st, 0.09, Vector3(0, 0.1, 0.02), Vector3(1.0, 1.0, 1.4), FUR)
	_sphere(st, 0.06, Vector3(0, 0.08, -0.04), Vector3(1.0, 1.0, 1.2), BELLY)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(0.04, 0.03, 0.09), Vector3(0.05 * side, 0.015, 0.06), FUR.darkened(0.1))
		_box(st, Vector3(0.025, 0.06, 0.025), Vector3(0.035 * side, 0.03, -0.07), FUR)
	_finish(st, _body)

	_head = _pivot(_body, Vector3(0, 0.16, -0.09))
	st = _begin()
	_sphere(st, 0.065, Vector3(0, 0, -0.02), Vector3(0.95, 0.95, 1.15), FUR)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(0.022, 0.045, 0.012), Vector3(0.035 * side, 0.065, 0.01), FUR.darkened(0.1))
		_sphere(st, 0.013, Vector3(0.038 * side, 0.02, -0.06), Vector3.ONE, Color(0.05, 0.05, 0.05), 6, 3)
	_sphere(st, 0.01, Vector3(0, -0.005, -0.095), Vector3.ONE, Color(0.25, 0.15, 0.12), 6, 3)
	_finish(st, _head)

	# Bushy tail curling up over the back.
	_tail = _pivot(_body, Vector3(0, 0.1, 0.13))
	st = _begin()
	for i in 5:
		var t := i / 4.0
		var at := Vector3(0, sin(t * 2.4) * 0.2, cos(t * 2.4) * 0.07 + t * 0.02)
		_sphere(st, lerpf(0.045, 0.07, t), at, Vector3.ONE, FUR.lightened(0.05 * i), 7, 4)
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
