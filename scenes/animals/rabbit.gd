class_name Rabbit
extends Animal
## A rabbit: the most common animal on the first island.
## Hops around, and runs away if you run or sprint close to it (crouch to sneak up).
## 30 health = 3 punches. Drops a Rabbit Pelt.

const FUR_COLORS: Array[Color] = [Color(0.6, 0.5, 0.4), Color(0.74, 0.68, 0.6), Color(0.46, 0.39, 0.33)]
const PINK := Color(0.93, 0.66, 0.66)

var _body: Node3D
var _head: Node3D
var _ears: Array[Node3D] = []
var _hop_phase := 0.0
var _time := 0.0


func _init() -> void:
	display_name = "Rabbit"
	max_health = 30.0
	walk_speed = 1.6
	flee_speed = 6.5
	skittish_distance = 5.0
	flee_time = 3.5
	loot_id = &"rabbit_pelt"
	body_size = Vector3(0.32, 0.34, 0.48)


func _build_model(root: Node3D) -> void:
	var fur: Color = FUR_COLORS[_rng.randi() % FUR_COLORS.size()]
	_body = _pivot(root, Vector3.ZERO)
	var st := _begin()
	_sphere(st, 0.17, Vector3(0, 0.17, 0.04), Vector3(1.0, 0.92, 1.3), fur)
	_sphere(st, 0.12, Vector3(0, 0.11, -0.02), Vector3(1.0, 0.8, 1.2), fur.lightened(0.25)) # Lighter belly.
	_sphere(st, 0.065, Vector3(0, 0.22, 0.24), Vector3.ONE, Color(0.96, 0.95, 0.93)) # Fluffy tail.
	for side in [-1.0, 1.0]:
		_box(st, Vector3(0.065, 0.045, 0.17), Vector3(0.09 * side, 0.025, 0.1), fur.darkened(0.12)) # Back feet.
		_box(st, Vector3(0.045, 0.1, 0.045), Vector3(0.06 * side, 0.05, -0.12), fur) # Front paws.
	_finish(st, _body)

	_head = _pivot(_body, Vector3(0, 0.27, -0.15))
	st = _begin()
	_sphere(st, 0.1, Vector3(0, 0, -0.03), Vector3(0.95, 0.95, 1.12), fur)
	for side in [-1.0, 1.0]:
		_sphere(st, 0.02, Vector3(0.06 * side, 0.03, -0.09), Vector3.ONE, Color(0.06, 0.05, 0.05), 6, 3)
	_sphere(st, 0.017, Vector3(0, -0.005, -0.145), Vector3.ONE, PINK, 6, 3)
	_finish(st, _head)
	for side in [-1.0, 1.0]:
		var ear := _pivot(_head, Vector3(0.04 * side, 0.07, 0.02))
		ear.rotation.z = -0.15 * side
		st = _begin()
		_box(st, Vector3(0.05, 0.17, 0.022), Vector3(0, 0.085, 0), fur)
		_box(st, Vector3(0.028, 0.13, 0.006), Vector3(0, 0.085, -0.013), PINK)
		_finish(st, ear)
		_ears.append(ear)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	if speed > 0.3:
		# Hop: up and down with the body tipping forward and back.
		_hop_phase += delta * (6.0 + speed * 1.4)
		var hop := absf(sin(_hop_phase))
		_body.position.y = hop * clampf(speed / 3.0, 0.4, 1.0) * 0.14
		_body.rotation.x = cos(_hop_phase) * 0.18
	else:
		_body.position.y = lerpf(_body.position.y, 0.0, 1.0 - exp(-12.0 * delta))
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, 1.0 - exp(-12.0 * delta))
	# Nose twitching and looking around while sitting still.
	_head.rotation.x = sin(_time * 13.0) * 0.025 + sin(_time * 0.7) * 0.08
	_head.rotation.y = sin(_time * 0.45) * 0.4 * (1.0 if speed < 0.3 else 0.0)
	# Ears flop back while hopping.
	for i in _ears.size():
		_ears[i].rotation.x = -0.25 - _body.position.y * 3.0 + sin(_time * 2.0 + i) * 0.05
