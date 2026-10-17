@tool
class_name CharacterModel
extends Node3D
## A How to Fish-style character, built in code from simple low-poly shapes:
## tall and lanky, a bean-shaped bald head with big googly eyes, long thin
## arms with mitten hands, long legs and boots.
## The look is set with the exported outfit options, so the same model is used
## for the pilot, the merchant and (later) players.
##
## The character faces -Z (Godot's "forward"). Body parts are separate nodes so
## they can be animated: breathing, looking at someone, talking and gesturing.

enum Hat { NONE, PILOT_CAP, BEANIE }

@export_group("Outfit")
@export var skin_color := Color(0.87, 0.7, 0.48)
@export var shirt_color := Color(0.27, 0.33, 0.55)
@export var short_sleeves := false
@export var pants_color := Color(0.2, 0.22, 0.28)
## Overalls cover the body and legs on top of the shirt (like How to Fish's orange ones).
@export var wear_overalls := false
@export var overalls_color := Color(0.96, 0.52, 0.12)
@export var shoe_color := Color(0.1, 0.1, 0.11)
@export var hat := Hat.NONE
@export var hat_color := Color(0.95, 0.95, 0.93)
@export var tie := false
@export var tie_color := Color(0.12, 0.14, 0.22)
@export var mustache := false
@export var hair_color := Color(0.35, 0.24, 0.16)
## A white bandage around the right leg.
@export var bandaged_leg := false

@export_group("Pose")
@export var sitting := false:
	set(value):
		sitting = value
		if is_node_ready():
			_apply_base_pose()

## Where the character looks (world position). Leave empty to look around idly.
var look_target: Variant = null
## True while talking: nods the head and waves a hand.
var talking := false

## For a character that is another player in multiplayer: it is posed from what the
## network says (below) instead of idling, and looks up and down with remote_pitch.
var remote_controlled := false
var remote_pitch := 0.0
## Horizontal speed in m/s. Above zero the character walks (legs and arms swing).
var move_speed := 0.0
var crouching := false
var sprinting := false
var airborne := false
var swimming := false

const LEG_UPPER := 0.45
const LEG_LOWER := 0.42
const FOOT_HEIGHT := 0.1
const HIP_HEIGHT := LEG_UPPER + LEG_LOWER + FOOT_HEIGHT
const TORSO_HEIGHT := 0.56
const ARM_LENGTH := 0.6
const SEAT_HEIGHT := 0.5
const PUNCH_DURATION := 0.28

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _shoulders: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _time := 0.0
var _talk_amount := 0.0
var _walk_phase := 0.0
var _swing := 0.0
var _crouch_amount := 0.0
var _air_amount := 0.0
var _punch_time := -1.0
var _punch_arm := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name)
	_build()
	_apply_base_pose()


## Height of the top of the head above the character's feet (or seat base).
func get_head_top() -> float:
	return _head.global_position.y - global_position.y + 0.3


# --- Building -----------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		child.queue_free()

	_hips = Node3D.new()
	add_child(_hips)

	# Torso: a slightly tapered cylinder, with optional overalls, tie and belt.
	_torso = Node3D.new()
	_hips.add_child(_torso)
	var body := _begin()
	_add(body, _cylinder(0.17, 0.2, TORSO_HEIGHT, 20), Vector3(0, TORSO_HEIGHT * 0.5, 0), shirt_color)
	if wear_overalls:
		# Overalls bib over the lower torso, with two straps over the shoulders.
		_add(body, _cylinder(0.185, 0.205, TORSO_HEIGHT * 0.62, 20), Vector3(0, TORSO_HEIGHT * 0.31, 0), overalls_color)
		_add(body, _box(Vector3(0.2, 0.2, 0.06)), Vector3(0, TORSO_HEIGHT * 0.66, -0.16), overalls_color)
		for x in [-0.09, 0.09]:
			_add(body, _box(Vector3(0.04, 0.24, 0.36)), Vector3(x, TORSO_HEIGHT * 0.84, 0.0), overalls_color)
	else:
		# Belt.
		_add(body, _cylinder(0.205, 0.205, 0.06, 20), Vector3(0, 0.05, 0), Color(0.12, 0.1, 0.09))
	if tie:
		_add(body, _box(Vector3(0.06, 0.32, 0.02)), Vector3(0, TORSO_HEIGHT * 0.66, -0.178), tie_color, Basis(Vector3.RIGHT, 0.06))
		_add(body, _box(Vector3(0.07, 0.05, 0.03)), Vector3(0, TORSO_HEIGHT * 0.92, -0.168), tie_color)
		# Epaulettes with gold stripes, for a pilot.
		for x in [-0.15, 0.15]:
			_add(body, _box(Vector3(0.1, 0.03, 0.14)), Vector3(x, TORSO_HEIGHT - 0.01, 0), tie_color)
			_add(body, _box(Vector3(0.1, 0.031, 0.025)), Vector3(x, TORSO_HEIGHT - 0.01, -0.03), Color(0.95, 0.75, 0.25))
	_torso.add_child(_mesh(body))

	_build_head()
	_build_arms()
	_build_legs()


func _build_head() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0, TORSO_HEIGHT - 0.02, 0)
	_head.scale = Vector3.ONE * 1.1 # How to Fish heads are big.
	_torso.add_child(_head)
	var st := _begin()
	# Bean-shaped head, a bit taller at the back, tilted forward.
	var head_shape := CapsuleMesh.new()
	head_shape.radius = 0.17
	head_shape.height = 0.54
	head_shape.radial_segments = 28
	head_shape.rings = 10
	_add(st, head_shape, Vector3(0, 0.24, 0.02), skin_color, Basis(Vector3.RIGHT, -0.12), 0.012)
	# Big googly eyes: white balls bulging out, small black pupils looking slightly apart.
	for side in [-1.0, 1.0]:
		var eye := Vector3(0.068 * side, 0.33, -0.135)
		_add(st, _sphere(0.062, 20, 12), eye, Color(0.98, 0.98, 0.97))
		var pupil_dir := Vector3(0.12 * side, 0.05, -1.0).normalized()
		_add(st, _sphere(0.026, 14, 8), eye + pupil_dir * 0.048, Color(0.05, 0.05, 0.05), Basis.from_scale(Vector3(1, 1, 0.6)))
	# Small open "o" mouth.
	_add(st, _sphere(0.03, 14, 8), Vector3(0, 0.16, -0.165), Color(0.25, 0.1, 0.08), Basis.from_scale(Vector3(1.0, 0.75, 0.45)))
	if mustache:
		_add(st, _box(Vector3(0.13, 0.035, 0.04)), Vector3(0, 0.205, -0.17), hair_color, Basis(Vector3.RIGHT, -0.15), 0.008)
	match hat:
		Hat.PILOT_CAP:
			var cap := Vector3(0, 0.49, 0.03)
			var tilt := Basis(Vector3.RIGHT, 0.1)
			_add(st, _cylinder(0.2, 0.175, 0.11, 24), cap, hat_color, tilt)
			_add(st, _cylinder(0.18, 0.18, 0.035, 24), cap + Vector3(0, -0.06, 0), Color(0.12, 0.13, 0.18), tilt)
			# Black visor sticking out at the front, and a gold badge.
			_add(st, _box(Vector3(0.22, 0.02, 0.12)), cap + Vector3(0, -0.07, -0.2), Color(0.08, 0.08, 0.09), Basis(Vector3.RIGHT, 0.25))
			_add(st, _box(Vector3(0.07, 0.05, 0.02)), cap + Vector3(0, -0.005, -0.198), Color(0.95, 0.76, 0.25), tilt)
		Hat.BEANIE:
			_add(st, _sphere(0.18, 20, 10), Vector3(0, 0.44, 0.02), hat_color, Basis.from_scale(Vector3(1.0, 0.75, 1.0)))
	_head.add_child(_mesh(st))


func _build_arms() -> void:
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.235 * side, TORSO_HEIGHT - 0.06, 0)
		_torso.add_child(shoulder)
		var st := _begin()
		var sleeve_color := shirt_color
		# Rounded shoulder so the arm doesn't look stuck on like a stick.
		_add(st, _sphere(0.072, 16, 8), Vector3(0, -0.01, 0), sleeve_color)
		if short_sleeves:
			_add(st, _cylinder(0.062, 0.068, 0.2, 14), Vector3(0, -0.1, 0), sleeve_color)
			_add(st, _cylinder(0.045, 0.05, ARM_LENGTH - 0.18, 14), Vector3(0, -0.18 - (ARM_LENGTH - 0.18) * 0.5, 0), skin_color)
		else:
			_add(st, _cylinder(0.05, 0.058, ARM_LENGTH, 14), Vector3(0, -ARM_LENGTH * 0.5, 0), sleeve_color)
		_add_mitten(st, Vector3(0, -ARM_LENGTH - 0.06, 0), side)
		shoulder.add_child(_mesh(st))
		_shoulders.append(shoulder)


## A soft round mitten hand: a plump palm, rounded fingers and a thumb.
func _add_mitten(st: SurfaceTool, at: Vector3, side: float) -> void:
	_add(st, _sphere(0.062, 16, 10), at, skin_color, Basis.from_scale(Vector3(0.85, 1.15, 0.8)))
	_add(st, _sphere(0.05, 14, 8), at + Vector3(0, -0.06, -0.008), skin_color, Basis.from_scale(Vector3(0.9, 1.2, 0.8)) )
	_add(st, _sphere(0.026, 12, 8), at + Vector3(-0.05 * side, -0.01, -0.025), skin_color, Basis(Vector3.BACK, 0.5 * side) * Basis.from_scale(Vector3(0.8, 1.5, 0.9)))


func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, 0, 0)
		_hips.add_child(hip)
		var leg_color := overalls_color if wear_overalls else pants_color
		var thigh := _begin()
		_add(thigh, _cylinder(0.075, 0.085, LEG_UPPER, 16), Vector3(0, -LEG_UPPER * 0.5, 0), leg_color)
		hip.add_child(_mesh(thigh))
		var knee := Node3D.new()
		knee.position = Vector3(0, -LEG_UPPER, 0)
		hip.add_child(knee)
		var shin := _begin()
		_add(shin, _cylinder(0.07, 0.075, LEG_LOWER, 16), Vector3(0, -LEG_LOWER * 0.5, 0), leg_color)
		if bandaged_leg and side > 0:
			_add(shin, _cylinder(0.082, 0.082, 0.16, 16), Vector3(0, -LEG_LOWER * 0.45, 0), Color(0.95, 0.94, 0.9), Basis(), 0.006)
		# Boot, sticking forward.
		_add(shin, _sphere(0.5, 18, 10), Vector3(0, -LEG_LOWER - FOOT_HEIGHT * 0.5 + 0.015, -0.05), shoe_color, Basis.from_scale(Vector3(0.17, 0.15, 0.3)))
		_add(shin, _sphere(0.085, 16, 8), Vector3(0, -LEG_LOWER + 0.0, 0.0), shoe_color)
		knee.add_child(_mesh(shin))
		_legs.append(hip)
		_knees.append(knee)


# --- Posing and animation -------------------------------------------------------

## Swings an arm forward in a punch. Alternates between the left and right arm.
func play_punch() -> void:
	_punch_time = 0.0
	_punch_arm = 1 - _punch_arm


func _apply_base_pose() -> void:
	if _hips == null:
		return
	if sitting:
		_hips.position = Vector3(0, SEAT_HEIGHT, 0.05)
		for i in 2:
			_legs[i].rotation = Vector3(PI * 0.5, 0, 0.06 * (1 if i == 1 else -1))
			_knees[i].rotation = Vector3(-PI * 0.5 + 0.12, 0, 0)
	else:
		_hips.position = Vector3(0, HIP_HEIGHT, 0)
		for i in 2:
			_legs[i].rotation = Vector3.ZERO
			_knees[i].rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if _torso == null:
		return
	_time += delta
	_talk_amount = move_toward(_talk_amount, 1.0 if talking else 0.0, delta * 4.0)

	# Breathing: the chest rises and falls slowly.
	var breath := sin(_time * 1.8)
	_torso.scale = Vector3(1.0 + breath * 0.008, 1.0 + breath * 0.012, 1.0 + breath * 0.008)
	_torso.rotation.x = (0.08 if sitting else 0.02) + breath * 0.01
	if _punch_time >= 0.0:
		_punch_time += delta
		if _punch_time > PUNCH_DURATION:
			_punch_time = -1.0

	_animate_locomotion(delta)
	_animate_head(delta)
	_animate_arms()


## Walking, crouching and jumping poses (not used while sitting).
func _animate_locomotion(delta: float) -> void:
	if sitting:
		return
	var blend := 1.0 - exp(-10.0 * delta)
	_crouch_amount = lerpf(_crouch_amount, 1.0 if crouching else 0.0, blend)
	_air_amount = lerpf(_air_amount, 1.0 if airborne else 0.0, blend)
	var intensity := clampf(move_speed / 4.5, 0.0, 1.5)
	if crouching:
		intensity *= 0.8
	if swimming:
		intensity = 0.6
		move_speed = maxf(move_speed, 1.5)
	_swing = lerpf(_swing, 0.0 if airborne else intensity, blend)
	_walk_phase += delta * clampf(move_speed, 0.0, 9.0) * 1.7
	var thigh_amp := 0.7 * minf(_swing, 1.3)
	var bob := absf(cos(_walk_phase)) * 0.035 * minf(_swing, 1.0)
	for i in 2:
		var angle := _walk_phase + PI * i
		var thigh := sin(angle) * thigh_amp
		var knee := -maxf(0.0, cos(angle)) * 0.9 * minf(_swing, 1.2)
		# Crouching: knees bent, hips low. Jumping: one leg forward, one back, knees tucked.
		thigh += 0.7 * _crouch_amount + (0.55 if i == 0 else -0.35) * _air_amount
		knee += -1.3 * _crouch_amount - 0.5 * _air_amount
		_legs[i].rotation = Vector3(thigh, 0, 0.0)
		_knees[i].rotation = Vector3(knee, 0, 0)
	_hips.position = Vector3(0, lerpf(HIP_HEIGHT, 0.8, _crouch_amount) + bob, 0)
	var lean := -0.28 * _crouch_amount - (0.12 if sprinting else 0.0) * minf(_swing, 1.0)
	_torso.rotation.x += lean


func _animate_head(delta: float) -> void:
	var target_yaw := sin(_time * 0.4) * 0.35 # Idle: slowly look around.
	var target_pitch := sin(_time * 0.27) * 0.06
	if remote_controlled:
		target_yaw = 0.0
		target_pitch = remote_pitch
	if look_target != null and not remote_controlled:
		var local: Vector3 = _torso.global_transform.affine_inverse() * (look_target as Vector3)
		var from_head := local - _head.position - Vector3(0, 0.3, 0)
		target_yaw = clampf(atan2(-from_head.x, -from_head.z), -1.2, 1.2)
		target_pitch = clampf(atan2(from_head.y, Vector2(from_head.x, from_head.z).length()), -0.5, 0.5)
	# Nod while talking.
	target_pitch += sin(_time * 9.0) * 0.07 * _talk_amount
	var blend := 1.0 - exp(-5.0 * delta)
	_head.rotation.y = lerp_angle(_head.rotation.y, target_yaw, blend)
	_head.rotation.x = lerpf(_head.rotation.x, target_pitch, blend)


func _animate_arms() -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := _shoulders[i]
		if sitting:
			# Hands resting on the knees.
			shoulder.rotation = Vector3(0.75, 0, -0.12 * side)
		else:
			shoulder.rotation = Vector3(sin(_time * 1.8 + i) * 0.02, 0, 0.07 * side)
			# Arms swing opposite to the legs while walking, and go up when jumping.
			shoulder.rotation.x += sin(_walk_phase + PI * (1 - i)) * 0.75 * minf(_swing, 1.3)
			shoulder.rotation.x += 0.9 * _air_amount + 0.35 * _crouch_amount
			shoulder.rotation.z += 0.5 * side * _air_amount
		if _punch_time >= 0.0 and i == _punch_arm:
			shoulder.rotation.x += 1.6 * sin(_punch_time / PUNCH_DURATION * PI)
	# Talking: the right arm comes up and waves around while explaining.
	var wave := _talk_amount * (1.0 + sin(_time * 3.5) * 0.25)
	_shoulders[1].rotation.x += wave * 0.9
	_shoulders[1].rotation.z += wave * (0.25 + sin(_time * 5.0) * 0.12)


# --- Small helpers --------------------------------------------------------------

func _add(st: SurfaceTool, shape: PrimitiveMesh, at: Vector3, color: Color, rot: Basis = Basis(), jitter: float = 0.0) -> void:
	LowPoly.add_smooth_shape(st, shape, Transform3D(rot, at), color, 0.02, _rng)


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _mesh(st: SurfaceTool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = LowPoly.commit_smooth(st)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh
