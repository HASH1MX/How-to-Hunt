class_name ViewModel
extends Node3D
## The player's own first-person arms and fists, How to Fish style.
## Lives under the camera. Everything is animated in code:
##   - idle breathing, walking/sprinting bob, arm pumping while sprinting
##   - sway: the arms lag a little behind when looking around
##   - jumping lifts the arms, landing dips them
##   - punches: alternating left/right jabs with a small wind-up
## Held items sit in the right fist (held_item_anchor).

## Emitted at the moment a punch reaches full reach, so the player can check what it hit.
signal punch_hit

@export var skin_color := Color(0.87, 0.7, 0.48)
@export var sleeve_color := Color(0.27, 0.33, 0.55)
## Seconds between punches when no gap is given.
@export var punch_cooldown := 0.32

## Rest and full-punch positions for each arm, relative to the camera (-Z is forward).
## The fists are turned so the thumb is on top, like a boxing stance.
const REST_POSITION := [Vector3(-0.26, -0.29, -0.4), Vector3(0.26, -0.29, -0.4)]
const REST_ROTATION := [Vector3(0.3, -0.22, 0.85), Vector3(0.3, 0.22, -0.85)]
const PUNCH_POSITION := [Vector3(-0.12, -0.2, -0.6), Vector3(0.12, -0.2, -0.6)]
const PUNCH_ROTATION := [Vector3(0.12, -0.05, 1.3), Vector3(0.12, 0.05, -1.3)]
## Fists are drawn a bit bigger than life, like How to Fish's chunky hands.
const ARM_SCALE := 1.35
# Punch timing (seconds): pull back, then jab out, then return.
const WIND_UP := 0.05
const JAB := 0.06
const RETURN := 0.17

## Where held items go: inside the right fist.
var held_item_anchor: Node3D
## Set by the player each frame, used for bobbing.
var move_speed := 0.0
var on_floor := true
var sprinting := false

var _arms: Array[Node3D] = []
var _punch_time := [-1.0, -1.0] # -1 = not punching
var _punch_hit_sent := [false, false]
var _next_arm := 1
var _cooldown := 0.0
var _time := 0.0
var _bob_phase := 0.0
var _bob_amount := 0.0
var _sway := Vector2.ZERO
var _dip := 0.0
var _dip_velocity := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	for i in 2:
		var arm := Node3D.new()
		arm.name = "LeftArm" if i == 0 else "RightArm"
		arm.add_child(_build_arm_mesh(-1.0 if i == 0 else 1.0))
		add_child(arm)
		_arms.append(arm)
	held_item_anchor = Node3D.new()
	held_item_anchor.name = "HeldItem"
	# In the middle of the fist, tilted up so long items stick up and forward out of the grip.
	held_item_anchor.position = Vector3(0.0, -0.005, -0.155)
	held_item_anchor.rotation = Vector3(0.9, 0.0, 0.0)
	_arms[1].add_child(held_item_anchor)


## Starts a punch with the next arm, then waits at least gap seconds before the next.
## Returns false while still waiting.
func punch(gap: float = -1.0) -> bool:
	if _cooldown > 0.0:
		return false
	var arm := _next_arm
	_next_arm = 1 - _next_arm
	_punch_time[arm] = 0.0
	_punch_hit_sent[arm] = false
	_cooldown = gap if gap >= 0.0 else punch_cooldown
	return true


## Mouse movement, used for the arms lagging behind when looking around.
func add_sway(mouse_relative: Vector2) -> void:
	_sway += mouse_relative * 0.0012
	_sway = _sway.clamp(Vector2(-0.08, -0.08), Vector2(0.08, 0.08))


## Landing dips the arms down; harder landings dip more.
func on_landed(fall_speed: float) -> void:
	_dip_velocity -= clampf(fall_speed * 0.12, 0.2, 1.2)


func _process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)

	# Walking bob: faster and bigger while sprinting, none while in the air.
	var target_bob := clampf(move_speed / 5.0, 0.0, 1.8) if on_floor else 0.0
	_bob_amount = lerpf(_bob_amount, target_bob, 1.0 - exp(-8.0 * delta))
	_bob_phase += delta * (7.0 + move_speed * 0.9) * minf(_bob_amount, 1.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	# Springy landing dip.
	_dip_velocity += (-_dip * 120.0 - _dip_velocity * 14.0) * delta
	_dip += _dip_velocity * delta

	var breathing := sin(_time * 1.6) * 0.004
	var air_lift := 0.0 if on_floor else 0.025
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var phase := _bob_phase + PI * i
		var bob := Vector3(cos(phase) * 0.012, -absf(sin(phase)) * 0.02, 0.0) * _bob_amount
		var position_now: Vector3 = REST_POSITION[i] + bob + Vector3(0, breathing + air_lift + _dip * 0.1, 0)
		var rotation_now: Vector3 = REST_ROTATION[i]
		# Arms pump forward and back while sprinting.
		if sprinting and on_floor:
			var pump := sin(phase) * 0.12
			position_now.z += pump * 0.4
			rotation_now.x += pump
		# Lag behind the mouse.
		position_now += Vector3(-_sway.x * 0.25, _sway.y * 0.25, 0)
		rotation_now += Vector3(-_sway.y, -_sway.x, 0)

		var punch_amount := _update_punch(i, delta)
		if punch_amount != 0.0:
			position_now = position_now.lerp(PUNCH_POSITION[i], punch_amount) if punch_amount > 0.0 \
					else position_now + Vector3(0.02 * side, -0.02, 0.08) * -punch_amount
			rotation_now = rotation_now.lerp(PUNCH_ROTATION[i], clampf(punch_amount, 0.0, 1.0))
		_arms[i].position = position_now
		_arms[i].rotation = rotation_now
		_arms[i].scale = Vector3.ONE * ARM_SCALE


## Advances one arm's punch and returns how far out it is:
## negative = pulled back (wind-up), 1 = fully extended, 0 = at rest.
func _update_punch(i: int, delta: float) -> float:
	var t: float = _punch_time[i]
	if t < 0.0:
		return 0.0
	t += delta
	_punch_time[i] = t
	if t < WIND_UP:
		return -t / WIND_UP
	if t < WIND_UP + JAB:
		var k := (t - WIND_UP) / JAB
		return lerpf(-1.0, 1.0, 1.0 - pow(1.0 - k, 3.0)) # Fast out, ease at the end.
	if not _punch_hit_sent[i]:
		_punch_hit_sent[i] = true
		punch_hit.emit()
	if t < WIND_UP + JAB + RETURN:
		var k := (t - WIND_UP - JAB) / RETURN
		return 1.0 - k * k * (3.0 - 2.0 * k) # Smooth return.
	_punch_time[i] = -1.0
	return 0.0


## One arm: a sleeve, a lighter cuff and a fist with curled fingers and a thumb.
## Built pointing forward (-Z), back of the hand up, with the fist at the front.
func _build_arm_mesh(side: float) -> MeshInstance3D:
	var st := LowPoly.begin()
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 0.05
	sleeve.bottom_radius = 0.062
	sleeve.height = 0.42
	sleeve.radial_segments = 8
	sleeve.rings = 1
	var along_z := Basis(Vector3.RIGHT, -PI * 0.5) # Cylinder's top now points to -Z.
	LowPoly.add_shape(st, sleeve, Transform3D(along_z, Vector3(0, 0, 0.17)), sleeve_color, 0.004, 0.05, _rng)
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.054
	cuff.bottom_radius = 0.054
	cuff.height = 0.035
	cuff.radial_segments = 8
	cuff.rings = 1
	LowPoly.add_shape(st, cuff, Transform3D(along_z, Vector3(0, 0, -0.04)), sleeve_color.lightened(0.25), 0.0, 0.05, _rng)
	# Wrist, then the back of the hand.
	_box(st, Vector3(0.062, 0.05, 0.05), Vector3(0, 0, -0.07))
	_box(st, Vector3(0.088, 0.05, 0.075), Vector3(0, 0.006, -0.125), Basis(Vector3.RIGHT, 0.12))
	# Four fingers curled into the palm: a knuckle row on top, finger fronts, and tips underneath.
	for k in 4:
		var x := (-0.032 + k * 0.0215) * side
		_box(st, Vector3(0.02, 0.024, 0.026), Vector3(x, 0.012, -0.17))
		_box(st, Vector3(0.02, 0.034, 0.024), Vector3(x, -0.016, -0.181))
		_box(st, Vector3(0.019, 0.02, 0.03), Vector3(x, -0.036, -0.162))
	# Thumb: folded over the front of the index and middle fingers.
	_box(st, Vector3(0.026, 0.026, 0.045), Vector3(-0.045 * side, -0.02, -0.135), Basis(Vector3.UP, 0.5 * side))
	_box(st, Vector3(0.04, 0.022, 0.022), Vector3(-0.024 * side, -0.03, -0.172))
	var instance := MeshInstance3D.new()
	instance.mesh = LowPoly.commit(st)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _box(st: SurfaceTool, size: Vector3, at: Vector3, rot: Basis = Basis()) -> void:
	var box := BoxMesh.new()
	box.size = size
	LowPoly.add_shape(st, box, Transform3D(rot, at), skin_color, 0.003, 0.06, _rng)
