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
const LEG_LENGTH := 0.72

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
	loot_id = &"deer"
	hurt_sound = "deer_hurt"
	die_sound = "deer_die"
	alert_sound = "deer_snort"
	body_size = Vector3(0.5, 1.3, 1.2)


func _build_model(root: Node3D) -> void:
	# Legs: front pair at -Z, back pair at +Z. Each pivots at the hip, inside the body.
	for z in [-0.36, 0.36]:
		for side in [-1.0, 1.0]:
			var leg := _pivot(root, Vector3(0.14 * side, LEG_LENGTH + 0.12, z))
			var st := _begin()
			_sphere(st, 0.12, Vector3.ZERO, Vector3(0.85, 1.1, 1.2), FUR) # Shoulder / thigh muscle.
			_limb(st, Vector3(0, -0.05, 0), Vector3(0, -0.42, 0), 0.085, 0.045, FUR) # Upper leg.
			_limb(st, Vector3(0, -0.42, 0), Vector3(0, -LEG_LENGTH - 0.05, 0), 0.045, 0.03, FUR.darkened(0.08)) # Lower leg.
			_sphere(st, 0.038, Vector3(0, -LEG_LENGTH - 0.07, -0.005), Vector3(0.9, 0.9, 1.3), DARK) # Hoof.
			_finish(st, leg)
			_legs.append(leg)

	_body = _pivot(root, Vector3(0, LEG_LENGTH + 0.24, 0))
	var st := _begin()
	_sphere(st, 0.34, Vector3(0, 0, 0), Vector3(0.92, 0.9, 1.7), FUR) # Barrel.
	_sphere(st, 0.27, Vector3(0, -0.1, 0), Vector3(0.95, 0.7, 1.8), LIGHT) # Pale belly.
	_sphere(st, 0.26, Vector3(0, 0.04, -0.36), Vector3(1.0, 1.1, 1.0), FUR) # Chest.
	_limb(st, Vector3(0, 0.1, 0.55), Vector3(0, 0.17, 0.66), 0.05, 0.035, LIGHT) # White tail.
	_finish(st, _body)

	# Neck reaching up and forward, with the head on the end. Everything is one
	# connected piece, so grazing bends the neck from the shoulders.
	_neck = _pivot(_body, Vector3(0, 0.16, -0.4))
	st = _begin()
	var tip := Vector3(0, 0.36, -0.34)
	_limb(st, Vector3(0, 0.0, 0.02), tip, 0.15, 0.085, FUR)
	_limb(st, tip + Vector3(0, 0.02, 0.0), tip + Vector3(0, 0.06, -0.12), 0.095, 0.09, FUR) # Back of the head.
	_sphere(st, 0.1, tip + Vector3(0, 0.07, -0.1), Vector3(0.85, 0.9, 1.25), FUR) # Head.
	_limb(st, tip + Vector3(0, 0.05, -0.15), tip + Vector3(0, 0.0, -0.27), 0.065, 0.048, LIGHT) # Snout.
	_sphere(st, 0.03, tip + Vector3(0, 0.0, -0.285), Vector3(1.2, 0.9, 1.0), DARK) # Nose.
	for side in [-1.0, 1.0]:
		_sphere(st, 0.024, tip + Vector3(0.075 * side, 0.1, -0.13), Vector3.ONE, DARK) # Eyes.
		var ear := tip + Vector3(0.09 * side, 0.15, -0.02)
		_limb(st, ear, ear + Vector3(0.07 * side, 0.1, 0.0), 0.035, 0.012, FUR) # Ears.
	if _rng.randf() < 0.5:
		# Antlers: a curved main beam with two tines on each side, all joined.
		for side in [-1.0, 1.0]:
			var base := tip + Vector3(0.05 * side, 0.2, -0.03)
			var mid := base + Vector3(0.07 * side, 0.15, 0.0)
			var top := mid + Vector3(0.05 * side, 0.15, -0.04)
			_limb(st, base, mid, 0.02, 0.016, ANTLER)
			_limb(st, mid, top, 0.016, 0.01, ANTLER)
			_limb(st, mid, mid + Vector3(-0.03 * side, 0.1, -0.1), 0.012, 0.007, ANTLER)
			_limb(st, base + Vector3(0, 0.05, 0), base + Vector3(0.0, 0.17, -0.1), 0.012, 0.007, ANTLER)
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
	_body.position.y = LEG_LENGTH + 0.24 + (absf(sin(_walk_phase)) * 0.04 if moving else 0.0)

	# Graze with the head down while standing; head up while moving or scared.
	_graze_timer -= delta
	if _graze_timer <= 0.0:
		_graze_timer = _rng.randf_range(2.0, 5.0)
		_graze = 0.0 if _graze > 0.5 else 1.0
	var target_graze := _graze if state == State.IDLE else 0.0
	_neck.rotation.x = lerpf(_neck.rotation.x, -target_graze * 1.1, 1.0 - exp(-3.0 * delta))
