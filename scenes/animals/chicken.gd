class_name Chicken
extends Animal
## A chicken: slow and not shy at all, the easiest animal to hunt.
## Pecks at the ground, and flaps its wings while running away after being hit.
## 20 health = 2 punches. Drops Feathers.

const FEATHER_COLORS: Array[Color] = [Color(0.96, 0.95, 0.9), Color(0.64, 0.4, 0.2), Color(0.86, 0.72, 0.5)]
const RED := Color(0.85, 0.15, 0.12)
const ORANGE := Color(0.95, 0.62, 0.15)

var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _walk_phase := 0.0
var _time := 0.0
var _peck_timer := 2.0
var _peck := 0.0


func _init() -> void:
	display_name = "Chicken"
	max_health = 20.0
	walk_speed = 1.0
	flee_speed = 4.2
	skittish_distance = 0.0
	flee_time = 3.0
	loot_id = &"feathers"
	body_size = Vector3(0.3, 0.42, 0.36)


func _build_model(root: Node3D) -> void:
	var feathers: Color = FEATHER_COLORS[_rng.randi() % FEATHER_COLORS.size()]
	for side in [-1.0, 1.0]:
		var leg := _pivot(root, Vector3(0.055 * side, 0.17, 0.01))
		var st := _begin()
		_cylinder(st, 0.012, 0.012, 0.16, Vector3(0, -0.08, 0), ORANGE)
		_box(st, Vector3(0.06, 0.012, 0.07), Vector3(0, -0.165, -0.015), ORANGE)
		_finish(st, leg)
		_legs.append(leg)

	_body = _pivot(root, Vector3(0, 0.16, 0))
	var st := _begin()
	_sphere(st, 0.15, Vector3(0, 0.12, 0.02), Vector3(0.88, 0.85, 1.12), feathers)
	# Tail feathers sticking up at the back.
	_box(st, Vector3(0.11, 0.15, 0.05), Vector3(0, 0.22, 0.15), feathers.darkened(0.08), Basis(Vector3.RIGHT, 0.5))
	_finish(st, _body)
	for side in [-1.0, 1.0]:
		var wing := _pivot(_body, Vector3(0.12 * side, 0.15, 0.02))
		st = _begin()
		_sphere(st, 0.1, Vector3(0.015 * side, -0.02, 0.02), Vector3(0.35, 0.75, 1.15), feathers.darkened(0.06), 6, 3)
		_finish(st, wing)
		_wings.append(wing)

	_head = _pivot(_body, Vector3(0, 0.24, -0.1))
	st = _begin()
	_sphere(st, 0.07, Vector3(0, 0.04, -0.01), Vector3(0.9, 1.0, 1.0), feathers)
	for i in 3:
		_box(st, Vector3(0.018, 0.045, 0.03), Vector3(0, 0.115, -0.04 + i * 0.03), RED)
	var beak := Basis(Vector3.RIGHT, -PI * 0.5) # Cone pointing forward.
	_cylinder(st, 0.0, 0.025, 0.06, Vector3(0, 0.035, -0.09), ORANGE, beak)
	_sphere(st, 0.018, Vector3(0, 0.0, -0.07), Vector3(0.8, 1.3, 0.6), RED, 6, 3)
	for side in [-1.0, 1.0]:
		_sphere(st, 0.013, Vector3(0.045 * side, 0.06, -0.045), Vector3.ONE, Color(0.05, 0.05, 0.05), 6, 3)
	_finish(st, _head)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	var walking := speed > 0.2
	if walking:
		_walk_phase += delta * (8.0 + speed * 3.0)
	for i in _legs.size():
		var swing := sin(_walk_phase + PI * i) * 0.7 if walking else 0.0
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, swing, 1.0 - exp(-15.0 * delta))
	_body.position.y = 0.16 + (absf(sin(_walk_phase)) * 0.02 if walking else 0.0)

	# Pecking at the ground every few seconds while standing still.
	_peck_timer -= delta
	if not walking and _peck_timer <= 0.0:
		_peck = 1.0
		_peck_timer = _rng.randf_range(1.5, 3.5)
	_peck = maxf(_peck - delta * 2.5, 0.0)
	var peck_angle := sin(_peck * PI) * 1.0
	# The head bobs back and forth while walking, like real chickens.
	_head.position.z = -0.1 + (sin(_walk_phase * 2.0) * 0.025 if walking else 0.0)
	_head.rotation.x = -peck_angle

	# Wings flap while running away, otherwise tucked in.
	var flapping := state == State.FLEE
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var target := (0.4 + sin(_time * 28.0) * 0.6) * side if flapping else 0.0
		_wings[i].rotation.z = lerpf(_wings[i].rotation.z, -target, 1.0 - exp(-20.0 * delta))
