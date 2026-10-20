class_name Monkey
extends Animal
## A monkey (Island 2): quick and nervous, it scampers away on all fours when you run near
## it and sits up chattering when left alone. 40 health. Drops its body (Monkey, $25).

const FUR := Color(0.42, 0.28, 0.17)
const FACE := Color(0.86, 0.72, 0.56)

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _phase := 0.0
var _time := 0.0
var _sit := 0.0


func _init() -> void:
	display_name = "Monkey"
	max_health = 40.0
	walk_speed = 2.0
	flee_speed = 6.0
	skittish_distance = 7.0
	flee_time = 3.0
	loot_id = &"monkey"
	body_size = Vector3(0.35, 0.5, 0.5)
	hurt_sound = "squirrel_hurt"
	die_sound = "squirrel_hurt"
	alert_sound = "squirrel_chitter"
	idle_sound = "squirrel_chitter"
	idle_sound_gap = Vector2(8.0, 20.0)


func _build_model(root: Node3D) -> void:
	_body = _pivot(root, Vector3(0, 0.25, 0))
	var st := _begin()
	_sphere(st, 0.15, Vector3(0, 0.05, 0), Vector3(0.9, 1.1, 1.2), FUR)
	_sphere(st, 0.1, Vector3(0, 0.0, -0.06), Vector3(0.9, 1.1, 0.9), FACE.darkened(0.15)) # Belly.
	_finish(st, _body)
	for side in [-1.0, 1.0]:
		var arm := _pivot(_body, Vector3(0.12 * side, 0.12, -0.08))
		st = _begin()
		_limb(st, Vector3.ZERO, Vector3(0.02 * side, -0.32, -0.02), 0.035, 0.03, FUR)
		_sphere(st, 0.035, Vector3(0.02 * side, -0.34, -0.03), Vector3.ONE, FACE)
		_finish(st, arm)
		_arms.append(arm)
		var leg := _pivot(_body, Vector3(0.08 * side, -0.08, 0.06))
		st = _begin()
		_limb(st, Vector3.ZERO, Vector3(0, -0.17, 0.02), 0.045, 0.035, FUR)
		_sphere(st, 0.04, Vector3(0, -0.19, -0.02), Vector3(1.0, 0.7, 1.3), FACE)
		_finish(st, leg)
		_legs.append(leg)
	_head = _pivot(_body, Vector3(0, 0.25, -0.05))
	st = _begin()
	_sphere(st, 0.11, Vector3.ZERO, Vector3.ONE, FUR)
	_sphere(st, 0.075, Vector3(0, -0.02, -0.07), Vector3(1.0, 0.95, 0.6), FACE)
	for side in [-1.0, 1.0]:
		_sphere(st, 0.018, Vector3(0.035 * side, 0.01, -0.115), Vector3.ONE, Color(0.06, 0.05, 0.04))
		_sphere(st, 0.04, Vector3(0.11 * side, 0.01, 0.0), Vector3(0.5, 1.0, 0.9), FACE) # Ears.
	_finish(st, _head)
	_tail = _pivot(_body, Vector3(0, -0.05, 0.15))
	st = _begin()
	var curve := [Vector3.ZERO, Vector3(0, -0.05, 0.2), Vector3(0, 0.12, 0.33), Vector3(0, 0.3, 0.28), Vector3(0, 0.36, 0.16)]
	for i in 4:
		_limb(st, curve[i], curve[i + 1], 0.025, 0.022, FUR)
	_finish(st, _tail)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	var moving := speed > 0.3
	if moving:
		# Running on all fours: leaning forward, arms and legs bounding.
		_phase += delta * (8.0 + speed * 1.5)
		_sit = move_toward(_sit, 0.0, delta * 4.0)
	else:
		_sit = move_toward(_sit, 1.0, delta * 2.0)
	var lean := lerpf(1.1, 0.0, _sit)
	_body.rotation.x = lerpf(_body.rotation.x, -lean, 1.0 - exp(-10.0 * delta))
	_body.position.y = 0.25 + (absf(sin(_phase)) * 0.06 if moving else 0.0)
	for i in 2:
		_arms[i].rotation.x = (sin(_phase + PI * i) * 0.8 if moving else 0.0) + lean * 0.6
		_legs[i].rotation.x = (sin(_phase + PI * i + PI) * 0.7 if moving else 0.0)
	_head.rotation.x = lean * 0.7
	_head.rotation.y = sin(_time * 1.7) * 0.5 * _sit
	_tail.rotation.x = sin(_time * 2.5) * 0.2
