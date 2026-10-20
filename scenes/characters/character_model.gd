@tool
class_name CharacterModel
extends Node3D
## A How to Fish-style character, built in code from simple low-poly shapes
## (flat-shaded facets, like the reference game): a small tall egg-shaped head with big
## googly eyes sitting straight on narrow shoulders, long thin arms with little mitten
## hands, long straight legs and chunky boots. Proportions (of a 2.0 m character):
## legs 48%, torso 30%, head 22%.
## The look is set with the exported outfit options, so the same model is used
## for the pilot, the merchant and (later) players.
##
## The character faces -Z (Godot's "forward"). Body parts are separate nodes so
## they can be animated: breathing, looking at someone, talking and gesturing.

enum Hat { NONE, PILOT_CAP, BEANIE, NURSE_CAP }

## Flat-shaded facets (the How to Fish look). Turn off for smooth, rounded shading.
@export var faceted := true

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
@export var beard := false
## Hair tied up in a bun at the back of the head.
@export var hair_bun := false
## An apron over the shirt, from the chest to the knees (like the cooks in How to Fish).
@export var wear_apron := false
@export var apron_color := Color(0.85, 0.5, 0.16)
@export var hair_color := Color(0.35, 0.24, 0.16)
## A white bandage around the right leg.
@export var bandaged_leg := false

@export_group("Pose")
## Sit down or stand up. Changing it plays a smooth sit/stand animation
## (use set_sitting_instantly for the starting pose).
@export var sitting := false
## A hurt, limping stance: weight on one leg, a slight lean.
@export var injured_stance := false
## A splint (two sticks tied with cloth) on the right shin.
@export var splinted_leg := false:
	set(value):
		splinted_leg = value
		if _splint != null:
			_splint.visible = value
## A wooden crutch under the left arm, planted on the ground.
@export var crutch := false

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
const FOOT_HEIGHT := 0.09
const HIP_HEIGHT := LEG_UPPER + LEG_LOWER + FOOT_HEIGHT
const TORSO_HEIGHT := 0.6
const ARM_LENGTH := 0.62
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
var _sit_amount := 0.0
var _splint: Node3D
var _crutch: MeshInstance3D
## In the right hand (other players' weapons and tools).
var _hand_anchor: Node3D
var _held_item: ItemData
## Body-part colours chosen on the Customize screen (part -> Color, see the Appearance
## autoload). A part not listed uses the outfit colours above.
var part_colors := {}
## Empty spots for accessories (hats, masks, moustaches - later): on top of the head and
## on the face. They turn with the head.
var head_attachment: Node3D
var face_attachment: Node3D
## "" or "pistol"/"rifle": arms held up and forward, aiming.
var aim_pose := ""
var _crouch_amount := 0.0
var _air_amount := 0.0
var _punch_time := -1.0
var _punch_arm := 0
var _chew_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name)
	_build()
	_apply_base_pose()


## Height of the top of the head above the character's feet (or seat base).
func get_head_top() -> float:
	return _head.global_position.y - global_position.y + 0.45


# --- Building -----------------------------------------------------------------

func _build() -> void:
	_rng.seed = hash(name) # The same small random details on every rebuild.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_shoulders.clear()
	_legs.clear()
	_knees.clear()

	_hips = Node3D.new()
	add_child(_hips)

	# Torso: a flat-ish tapered body (wider than deep), with optional overalls, apron, tie.
	_torso = Node3D.new()
	_hips.add_child(_torso)
	var body := _begin()
	var flat := Basis.from_scale(Vector3(1.0, 1.0, 0.68))
	_add(body, _cylinder(0.16, 0.18, TORSO_HEIGHT, 10), Vector3(0, TORSO_HEIGHT * 0.5, 0), _part("torso", shirt_color), flat)
	if wear_overalls:
		# Overalls bib over the lower torso, with two straps over the shoulders.
		_add(body, _cylinder(0.172, 0.185, TORSO_HEIGHT * 0.68, 10), Vector3(0, TORSO_HEIGHT * 0.34, 0), overalls_color, flat)
		_add(body, _box(Vector3(0.2, 0.3, 0.04)), Vector3(0, TORSO_HEIGHT * 0.66, -0.108), overalls_color)
		for x in [-0.085, 0.085]:
			_add(body, _box(Vector3(0.04, 0.24, 0.25)), Vector3(x, TORSO_HEIGHT * 0.85, -0.006), overalls_color)
	elif wear_apron:
		# A flat apron hanging from a neck strap down to the knees.
		_add(body, _box(Vector3(0.25, 0.64, 0.03)), Vector3(0, TORSO_HEIGHT * 0.42, -0.128), apron_color)
		_add(body, _box(Vector3(0.28, 0.035, 0.26)), Vector3(0, TORSO_HEIGHT * 0.92, -0.01), apron_color.darkened(0.15))
	else:
		# Belt.
		_add(body, _cylinder(0.185, 0.185, 0.05, 10), Vector3(0, 0.04, 0), Color(0.12, 0.1, 0.09), flat)
	if tie:
		_add(body, _box(Vector3(0.055, 0.3, 0.02)), Vector3(0, TORSO_HEIGHT * 0.66, -0.125), tie_color, Basis(Vector3.RIGHT, 0.06))
		_add(body, _box(Vector3(0.065, 0.05, 0.03)), Vector3(0, TORSO_HEIGHT * 0.92, -0.118), tie_color)
		# Epaulettes with gold stripes, for a pilot.
		for x in [-0.15, 0.15]:
			_add(body, _box(Vector3(0.1, 0.03, 0.12)), Vector3(x, TORSO_HEIGHT - 0.01, 0), tie_color)
			_add(body, _box(Vector3(0.1, 0.031, 0.025)), Vector3(x, TORSO_HEIGHT - 0.01, -0.03), Color(0.95, 0.75, 0.25))
	_torso.add_child(_mesh(body))

	_build_head()
	_build_arms()
	_build_legs()
	_build_crutch()


## A small tall egg-shaped head sitting right on the shoulders, with big googly eyes.
func _build_head() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0, TORSO_HEIGHT - 0.03, 0)
	_torso.add_child(_head)
	var st := _begin()
	# The head: an egg, a little taller at the back and tilted forward.
	var head_shape := CapsuleMesh.new()
	head_shape.radius = 0.118
	head_shape.height = 0.44
	head_shape.radial_segments = 12
	head_shape.rings = 5
	_add(st, head_shape, Vector3(0, 0.21, 0.012), _part("head", skin_color), Basis(Vector3.RIGHT, -0.1))
	# Big googly eyes bulging out of the front: white balls, small pupils looking a bit apart.
	for side in [-1.0, 1.0]:
		var eye := Vector3(0.05 * side, 0.285, -0.1)
		_add(st, _sphere(0.062, 10, 6), eye, Color(0.98, 0.98, 0.97))
		var pupil_dir := Vector3(0.14 * side, 0.04, -1.0).normalized()
		_add(st, _sphere(0.028, 8, 4), eye + pupil_dir * 0.052, Color(0.07, 0.08, 0.1), Basis.from_scale(Vector3(1, 1, 0.6)))
	if mustache:
		_add(st, _box(Vector3(0.12, 0.03, 0.04)), Vector3(0, 0.155, -0.118), hair_color, Basis(Vector3.RIGHT, -0.12))
	if beard:
		_add(st, _sphere(0.1, 10, 6), Vector3(0, 0.1, -0.06), hair_color, Basis.from_scale(Vector3(1.0, 1.05, 0.95)))
	match hat:
		Hat.PILOT_CAP:
			var cap := Vector3(0, 0.41, 0.02)
			var tilt := Basis(Vector3.RIGHT, 0.1)
			_add(st, _cylinder(0.15, 0.135, 0.09, 12), cap, hat_color, tilt)
			_add(st, _cylinder(0.14, 0.14, 0.03, 12), cap + Vector3(0, -0.05, 0), Color(0.12, 0.13, 0.18), tilt)
			# Black visor sticking out at the front, and a gold badge.
			_add(st, _box(Vector3(0.18, 0.018, 0.1)), cap + Vector3(0, -0.06, -0.15), Color(0.08, 0.08, 0.09), Basis(Vector3.RIGHT, 0.25))
			_add(st, _box(Vector3(0.06, 0.045, 0.018)), cap + Vector3(0, -0.004, -0.15), Color(0.95, 0.76, 0.25), tilt)
		Hat.BEANIE:
			_add(st, _sphere(0.14, 10, 6), Vector3(0, 0.37, 0.015), hat_color, Basis.from_scale(Vector3(1.0, 0.75, 1.0)))
		Hat.NURSE_CAP:
			_add(st, _box(Vector3(0.2, 0.07, 0.11)), Vector3(0, 0.43, -0.02), Color(0.98, 0.98, 0.97), Basis(Vector3.RIGHT, -0.25))
			_add(st, _box(Vector3(0.05, 0.016, 0.014)), Vector3(0, 0.44, -0.08), Color(0.85, 0.15, 0.15), Basis(Vector3.RIGHT, -0.25))
			_add(st, _box(Vector3(0.016, 0.05, 0.014)), Vector3(0, 0.44, -0.08), Color(0.85, 0.15, 0.15), Basis(Vector3.RIGHT, -0.25))
	if hair_bun:
		_add(st, _sphere(0.11, 10, 6), Vector3(0, 0.3, 0.05), hair_color, Basis.from_scale(Vector3(1.05, 1.1, 1.0)))
		_add(st, _sphere(0.065, 8, 5), Vector3(0, 0.35, 0.14), hair_color)
	_head.add_child(_mesh(st))
	head_attachment = Node3D.new()
	head_attachment.name = "HeadTop"
	head_attachment.position = Vector3(0, 0.43, 0.01)
	_head.add_child(head_attachment)
	face_attachment = Node3D.new()
	face_attachment.name = "Face"
	face_attachment.position = Vector3(0, 0.2, -0.12)
	_head.add_child(face_attachment)


## Long thin arms (sleeves) ending in small mitten hands.
func _build_arms() -> void:
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.205 * side, TORSO_HEIGHT - 0.06, 0)
		_torso.add_child(shoulder)
		var st := _begin()
		var sleeve_color := _part("right_arm" if side > 0 else "left_arm", shirt_color)
		var hand_color := _part("right_hand" if side > 0 else "left_hand", skin_color)
		# A small rounded shoulder so the arm joins the body.
		_add(st, _sphere(0.055, 8, 5), Vector3(0, -0.01, 0), sleeve_color)
		if short_sleeves:
			_add(st, _cylinder(0.046, 0.05, 0.2, 8), Vector3(0, -0.1, 0), sleeve_color)
			_add(st, _cylinder(0.036, 0.04, ARM_LENGTH - 0.18, 8), Vector3(0, -0.18 - (ARM_LENGTH - 0.18) * 0.5, 0), hand_color)
		else:
			_add(st, _cylinder(0.04, 0.046, ARM_LENGTH, 8), Vector3(0, -ARM_LENGTH * 0.5, 0), sleeve_color)
		_add_mitten(st, Vector3(0, -ARM_LENGTH - 0.045, 0), side, hand_color)
		shoulder.add_child(_mesh(st))
		if side > 0:
			_hand_anchor = Node3D.new()
			_hand_anchor.position = Vector3(0, -ARM_LENGTH - 0.06, -0.01)
			shoulder.add_child(_hand_anchor)
		_shoulders.append(shoulder)


## A small mitten hand: a flat palm, a block of fingers and a thumb.
func _add_mitten(st: SurfaceTool, at: Vector3, side: float, color: Color) -> void:
	_add(st, _sphere(0.05, 7, 5), at, color, Basis.from_scale(Vector3(0.85, 1.25, 0.65)))
	_add(st, _sphere(0.04, 6, 4), at + Vector3(0, -0.05, -0.006), color, Basis.from_scale(Vector3(0.9, 1.25, 0.7)))
	_add(st, _sphere(0.022, 6, 4), at + Vector3(-0.042 * side, 0.0, -0.016), color, Basis(Vector3.BACK, 0.5 * side) * Basis.from_scale(Vector3(0.8, 1.6, 0.9)))


## Long straight legs ending in chunky dark boots.
func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.085 * side, 0, 0)
		_hips.add_child(hip)
		var leg_color := _part("right_leg" if side > 0 else "left_leg", overalls_color if wear_overalls else pants_color)
		var foot_color := _part("right_foot" if side > 0 else "left_foot", shoe_color)
		var thigh := _begin()
		_add(thigh, _cylinder(0.058, 0.066, LEG_UPPER, 8), Vector3(0, -LEG_UPPER * 0.5, 0), leg_color)
		hip.add_child(_mesh(thigh))
		var knee := Node3D.new()
		knee.position = Vector3(0, -LEG_UPPER, 0)
		hip.add_child(knee)
		var shin := _begin()
		_add(shin, _cylinder(0.054, 0.058, LEG_LOWER, 8), Vector3(0, -LEG_LOWER * 0.5, 0), leg_color)
		if bandaged_leg and side > 0:
			_add(shin, _cylinder(0.066, 0.066, 0.16, 8), Vector3(0, -LEG_LOWER * 0.45, 0), Color(0.95, 0.94, 0.9))
		# Chunky rounded boot, pointing forward.
		_add(shin, _sphere(0.5, 10, 6), Vector3(0, -LEG_LOWER - FOOT_HEIGHT * 0.5 + 0.012, -0.05), foot_color, Basis.from_scale(Vector3(0.14, 0.13, 0.28)))
		_add(shin, _sphere(0.07, 8, 5), Vector3(0, -LEG_LOWER + 0.0, 0.0), foot_color)
		knee.add_child(_mesh(shin))
		if side > 0:
			_splint = _build_splint()
			knee.add_child(_splint)
		_legs.append(hip)
		_knees.append(knee)


## Two sticks along the shin, tied on with three bands of cloth.
func _build_splint() -> Node3D:
	var st := _begin()
	var wood := Color(0.55, 0.38, 0.22)
	for z in [-0.07, 0.07]:
		_tube(st, Vector3(0, -0.05, z), Vector3(0, -0.38, z), 0.02, 0.02, wood)
	for y in [-0.1, -0.21, -0.32]:
		_add(st, _cylinder(0.072, 0.072, 0.035, 10), Vector3(0, y, 0), Color(0.98, 0.9, 0.6))
	var holder := Node3D.new()
	holder.add_child(_mesh(st))
	holder.visible = splinted_leg
	return holder


## A wooden crutch with a cross piece, standing next to the left arm.
func _build_crutch() -> void:
	var st := _begin()
	var wood := Color(0.55, 0.38, 0.22)
	_tube(st, Vector3(-0.27, 1.42, -0.03), Vector3(-0.42, 0.02, -0.14), 0.022, 0.026, wood)
	_tube(st, Vector3(-0.2, 1.43, -0.03), Vector3(-0.36, 1.43, -0.03), 0.02, 0.02, wood)
	_crutch = _mesh(st)
	_crutch.visible = false
	add_child(_crutch)


## A rounded tube from `a` to `b`, built from the usual cylinder shape.
func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, color: Color) -> void:
	var along := b - a
	var tube := _cylinder(rb, ra, along.length(), 8)
	_add(st, tube, (a + b) * 0.5, color, Basis(Quaternion(Vector3.UP, along.normalized())))


# --- Posing and animation -------------------------------------------------------

## Rebuilds the character with these body-part colours (part -> Color). Each part is
## coloured on its own: a blue head, red body, green legs and yellow hands all work.
func apply_part_colors(colors: Dictionary) -> void:
	part_colors = colors.duplicate()
	if _hips == null:
		return
	var was_sitting := _sit_amount
	_build()
	_sit_amount = was_sitting
	_apply_base_pose()
	if _held_item != null:
		set_held_item(_held_item)


func _part(part: String, fallback: Color) -> Color:
	return part_colors.get(part, fallback)


## Puts an item in the right hand (null = empty). Guns are held up, aiming forward.
func set_held_item(item: ItemData) -> void:
	_held_item = item
	if _hand_anchor == null:
		return
	for child in _hand_anchor.get_children():
		child.queue_free()
	aim_pose = item.hold if item != null else ""
	if item == null:
		return
	var model := MeshInstance3D.new()
	model.mesh = item.mesh
	# Item meshes point along -Z; the arm points along -Y.
	model.rotation.x = -PI * 0.5
	_hand_anchor.add_child(model)


## Where the right hand is (world position), e.g. for a muzzle flash.
func get_hand_position() -> Vector3:
	return _hand_anchor.global_position if _hand_anchor != null else global_position + Vector3(0, 1.3, 0)


## Sets sitting with no animation (the starting pose when the world loads).
func set_sitting_instantly(value: bool) -> void:
	sitting = value
	_sit_amount = 1.0 if value else 0.0
	if _hips != null:
		_apply_base_pose()


## 1 = fully seated, 0 = fully standing (in between while sitting down or getting up).
func get_sit_amount() -> float:
	return _sit_amount


## Chews happily for a moment (after being fed).
func play_chew(seconds: float = 1.4) -> void:
	_chew_time = seconds


## Swings an arm forward in a punch. Alternates between the left and right arm.
func play_punch() -> void:
	_punch_time = 0.0
	_punch_arm = 1 - _punch_arm


func _apply_base_pose() -> void:
	if _hips == null:
		return
	_sit_amount = 1.0 if sitting else _sit_amount
	if _sit_amount >= 1.0:
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
	_torso.rotation.x = 0.02 + breath * 0.01
	if _crutch != null:
		_crutch.visible = crutch and _sit_amount < 0.45
	_chew_time = maxf(_chew_time - delta, 0.0)
	if _punch_time >= 0.0:
		_punch_time += delta
		if _punch_time > PUNCH_DURATION:
			_punch_time = -1.0

	_animate_locomotion(delta)
	_animate_head(delta)
	_animate_arms()


## Walking, crouching and jumping poses (not used while sitting).
func _animate_locomotion(delta: float) -> void:
	_sit_amount = move_toward(_sit_amount, 1.0 if sitting else 0.0, delta / 1.1)
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
	# Hurt stance when standing still: weight on the good leg, splinted leg out in front, leaning.
	if injured_stance and _swing < 0.2:
		var shift := sin(_time * 0.6) * 0.02
		_legs[1].rotation.x += 0.1
		_legs[0].rotation.x -= 0.08
		_knees[0].rotation.x -= 0.12
		_torso.rotation.z = 0.05 + shift
		_torso.rotation.x += 0.05
	else:
		_torso.rotation.z = 0.0
	# Sitting down / getting up: blend from the standing pose to the seated one.
	var seat := smoothstep(0.0, 1.0, _sit_amount)
	if seat > 0.0:
		for i in 2:
			_legs[i].rotation = _legs[i].rotation.lerp(Vector3(PI * 0.5, 0, 0.06 * (1 if i == 1 else -1)), seat)
			_knees[i].rotation = _knees[i].rotation.lerp(Vector3(-PI * 0.5 + 0.12, 0, 0), seat)
		_hips.position = _hips.position.lerp(Vector3(0, SEAT_HEIGHT, 0.05), seat)
		# Lean forward while pushing up or lowering down.
		_torso.rotation.x += 0.06 * seat + sin(seat * PI) * 0.4


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
	# Nod while talking, bob while chewing.
	target_pitch += sin(_time * 9.0) * 0.07 * _talk_amount
	target_pitch += sin(_time * 17.0) * 0.1 * clampf(_chew_time * 2.0, 0.0, 1.0)
	var blend := 1.0 - exp(-5.0 * delta)
	_head.rotation.y = lerp_angle(_head.rotation.y, target_yaw, blend)
	_head.rotation.x = lerpf(_head.rotation.x, target_pitch, blend)


func _animate_arms() -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := _shoulders[i]
		shoulder.rotation = Vector3(sin(_time * 1.8 + i) * 0.02, 0, 0.07 * side)
		# Arms swing opposite to the legs while walking, and go up when jumping.
		shoulder.rotation.x += sin(_walk_phase + PI * (1 - i)) * 0.75 * minf(_swing, 1.3)
		shoulder.rotation.x += 0.9 * _air_amount + 0.35 * _crouch_amount
		shoulder.rotation.z += 0.5 * side * _air_amount
		# Sitting: hands rest on the knees (blended, so sitting down and getting up are smooth).
		var seat := smoothstep(0.0, 1.0, _sit_amount)
		shoulder.rotation = shoulder.rotation.lerp(Vector3(0.75, 0, -0.12 * side), seat)
		if _punch_time >= 0.0 and i == _punch_arm:
			shoulder.rotation.x += 1.6 * sin(_punch_time / PUNCH_DURATION * PI)
	# Aiming a gun: arms up and forward, following where the player looks.
	if aim_pose != "":
		var up := clampf(remote_pitch, -0.8, 0.8)
		_shoulders[1].rotation = Vector3(PI * 0.5 + up, 0.0, 0.12)
		if aim_pose == "rifle":
			_shoulders[0].rotation = Vector3(PI * 0.5 + up - 0.1, 0.0, -0.5)
		if _punch_time >= 0.0:
			_shoulders[1].rotation.x += 0.12
	# Talking: the right arm comes up and waves around while explaining.
	var wave := _talk_amount * (1.0 + sin(_time * 3.5) * 0.25)
	_shoulders[1].rotation.x += wave * 0.9
	_shoulders[1].rotation.z += wave * (0.25 + sin(_time * 5.0) * 0.12)


# --- Small helpers --------------------------------------------------------------

func _add(st: SurfaceTool, shape: PrimitiveMesh, at: Vector3, color: Color, rot: Basis = Basis()) -> void:
	if faceted:
		LowPoly.add_shape(st, shape, Transform3D(rot, at), color, 0.0, 0.05, _rng)
	else:
		LowPoly.add_smooth_shape(st, shape, Transform3D(rot, at), color, 0.02, _rng)


func _begin() -> SurfaceTool:
	if faceted:
		return LowPoly.begin()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _mesh(st: SurfaceTool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = LowPoly.commit(st) if faceted else LowPoly.commit_smooth(st)
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
