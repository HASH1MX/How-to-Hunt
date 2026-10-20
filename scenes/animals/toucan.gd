class_name Toucan
extends Animal
## A toucan (Island 2): a round black bird with a huge orange beak, hopping around the
## jungle floor. Easy to catch. 15 health. Drops its body (Toucan, $12).

const FEATHERS := Color(0.08, 0.08, 0.1)
const CHEST := Color(0.98, 0.92, 0.55)
const BEAK := Color(0.98, 0.55, 0.12)

var _body: Node3D
var _head: Node3D
var _hop := 0.0
var _time := 0.0


func _init() -> void:
	display_name = "Toucan"
	max_health = 15.0
	walk_speed = 1.2
	flee_speed = 4.5
	skittish_distance = 4.0
	flee_time = 2.5
	loot_id = &"toucan"
	body_size = Vector3(0.28, 0.38, 0.32)
	hurt_sound = "chicken_hurt"
	die_sound = "chicken_die"
	idle_sound = "bird"
	idle_sound_gap = Vector2(6.0, 15.0)


func _build_model(root: Node3D) -> void:
	_body = _pivot(root, Vector3(0, 0.08, 0))
	var st := _begin()
	_sphere(st, 0.13, Vector3(0, 0.12, 0.02), Vector3(0.95, 1.05, 1.15), FEATHERS)
	_sphere(st, 0.08, Vector3(0, 0.14, -0.08), Vector3(0.9, 1.1, 0.6), CHEST)
	_limb(st, Vector3(0, 0.08, 0.12), Vector3(0, 0.0, 0.26), 0.05, 0.025, FEATHERS) # Tail.
	for side in [-1.0, 1.0]:
		_limb(st, Vector3(0.05 * side, 0.02, 0.0), Vector3(0.05 * side, -0.08, 0.0), 0.012, 0.012, Color(0.35, 0.45, 0.85)) # Legs.
		_sphere(st, 0.09, Vector3(0.1 * side, 0.12, 0.04), Vector3(0.3, 0.8, 1.2), FEATHERS.lightened(0.05)) # Wings.
	_finish(st, _body)
	_head = _pivot(_body, Vector3(0, 0.25, -0.05))
	st = _begin()
	_sphere(st, 0.075, Vector3.ZERO, Vector3.ONE, FEATHERS)
	_sphere(st, 0.045, Vector3(0, -0.01, -0.05), Vector3(1.1, 1.0, 0.5), CHEST)
	_limb(st, Vector3(0, 0.0, -0.05), Vector3(0, -0.03, -0.2), 0.04, 0.012, BEAK) # The big beak.
	_sphere(st, 0.012, Vector3(0, 0.02, -0.12), Vector3(1.0, 0.6, 2.0), Color(0.15, 0.1, 0.1))
	for side in [-1.0, 1.0]:
		_sphere(st, 0.02, Vector3(0.05 * side, 0.02, -0.03), Vector3.ONE, Color(0.4, 0.75, 0.95))
		_sphere(st, 0.01, Vector3(0.062 * side, 0.02, -0.035), Vector3.ONE, Color(0.02, 0.02, 0.02))
	_finish(st, _head)


func _animate(delta: float, speed: float) -> void:
	_time += delta
	if speed > 0.3:
		_hop += delta * (9.0 + speed * 2.0)
		_body.position.y = 0.08 + absf(sin(_hop)) * 0.1
	else:
		_body.position.y = lerpf(_body.position.y, 0.08, 1.0 - exp(-10.0 * delta))
	_head.rotation.y = sin(_time * 1.1) * 0.6
	_head.rotation.x = sin(_time * 2.3) * 0.1
