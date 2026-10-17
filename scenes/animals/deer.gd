class_name Deer
extends Animal
## A deer: the only big animal on the first island, and there are only a few.
## Very shy and fast: it runs away from you from far off unless you sneak (crouch).
## Grazes with its head down. Some have antlers.
## 80 health = 8 punches. Drops a Deer Hide.

const FUR := Color(0.58, 0.4, 0.25)
const LIGHT := Color(0.9, 0.84, 0.72)
const DARK := Color(0.15, 0.12, 0.1)
const ANTLER := Color(0.85, 0.78, 0.62)
const LEG_LENGTH := 0.62

var _body: Node3D
var _neck: Node3D
var _legs: Array[Node3D] = []
var _walk_phase := 0.0
var _time := 0.0
var _graze := 0.0
var _graze_timer := 3.0


func _init() -> void:
	display_name = "Deer"
	max_health = 80.0
	walk_speed = 1.4
	flee_speed = 7.0
	skittish_distance = 10.0
	flee_time = 3.5
	loot_id = &"deer_hide"
	body_size = Vector3(0.5, 1.3, 1.2)


func _build_model(root: Node3D) -> void:
	# Legs: front pair at -Z, back pair at +Z.
	for z in [-0.36, 0.36]:
		for side in [-1.0, 1.0]:
			var leg := _pivot(root, Vector3(0.15 * side, LEG_LENGTH + 0.1, z))
			var st := _begin()
			_cylinder(st, 0.06, 0.035, LEG_LENGTH, Vector3(0, -LEG_LENGTH * 0.5, 0), FUR)
			_box(st, Vector3(0.06, 0.07, 0.07), Vector3(0, -LEG_LENGTH - 0.02, -0.01), DARK)
			_finish(st, leg)
			_legs.append(leg)

	_body = _pivot(root, Vector3(0, LEG_LENGTH + 0.22, 0))
	var st := _begin()
	_sphere(st, 0.34, Vector3(0, 0, 0), Vector3(0.95, 0.92, 1.75), FUR, 9, 5)
	_sphere(st, 0.26, Vector3(0, -0.11, 0), Vector3(0.95, 0.7, 1.85), LIGHT, 8, 4) # Pale belly.
	_box(st, Vector3(0.1, 0.16, 0.06), Vector3(0, 0.08, 0.56), LIGHT, Basis(Vector3.RIGHT, 0.6)) # White tail.
	_finish(st, _body)

	# Neck reaching up and forward, with the head on the end.
	_neck = _pivot(_body, Vector3(0, 0.12, -0.42))
	st = _begin()
	_cylinder(st, 0.1, 0.15, 0.42, Vector3(0, 0.14, -0.15), FUR, Basis(Vector3.RIGHT, -0.8))
	_sphere(st, 0.12, Vector3(0, 0.34, -0.34), Vector3(0.85, 0.9, 1.3), FUR) # Head.
	_sphere(st, 0.08, Vector3(0, 0.29, -0.48), Vector3(0.75, 0.75, 1.1), LIGHT) # Snout.
	_sphere(st, 0.025, Vector3(0, 0.3, -0.56), Vector3.ONE, DARK, 6, 3) # Nose.
	for side in [-1.0, 1.0]:
		_sphere(st, 0.022, Vector3(0.08 * side, 0.38, -0.41), Vector3.ONE, DARK, 6, 3) # Eyes.
		_box(st, Vector3(0.05, 0.12, 0.025), Vector3(0.11 * side, 0.46, -0.27), FUR, Basis(Vector3.BACK, -0.7 * side)) # Ears.
	if _rng.randf() < 0.5:
		# Antlers: a main branch with two tines on each side.
		for side in [-1.0, 1.0]:
			var base := Vector3(0.05 * side, 0.46, -0.32)
			_cylinder(st, 0.012, 0.02, 0.28, base + Vector3(0.05 * side, 0.13, 0.02), ANTLER, Basis(Vector3.BACK, -0.35 * side))
			_cylinder(st, 0.008, 0.013, 0.13, base + Vector3(0.06 * side, 0.2, -0.05), ANTLER, Basis(Vector3.RIGHT, -0.6))
			_cylinder(st, 0.007, 0.012, 0.11, base + Vector3(0.11 * side, 0.29, 0.0), ANTLER, Basis(Vector3.BACK, -0.9 * side))
	_finish(st, _neck)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	var moving := speed > 0.2
	if moving:
		_walk_phase += delta * (4.5 + speed * 1.3)
	# Diagonal legs move together (front-left with back-right), like a real trot.
	var amount := clampf(speed / 4.0, 0.3, 0.75) if moving else 0.0
	var phases := [0.0, PI, PI, 0.0]
	for i in _legs.size():
		var swing := sin(_walk_phase + phases[i]) * amount
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, swing, 1.0 - exp(-12.0 * delta))
	_body.position.y = LEG_LENGTH + 0.22 + (absf(sin(_walk_phase)) * 0.04 if moving else 0.0)

	# Graze with the head down while standing; head up while moving or scared.
	_graze_timer -= delta
	if _graze_timer <= 0.0:
		_graze_timer = _rng.randf_range(2.0, 5.0)
		_graze = 0.0 if _graze > 0.5 else 1.0
	var target_graze := _graze if state == State.IDLE else 0.0
	_neck.rotation.x = lerpf(_neck.rotation.x, -target_graze * 1.1, 1.0 - exp(-3.0 * delta))
