class_name Animal
extends CharacterBody3D
## The base for every animal: wandering around, running away, health,
## getting hit (white flash, knockback, damage number), dying and dropping loot.
## Each species (Rabbit, Chicken, Squirrel, Deer) extends this, sets its stats in
## _init(), builds its low-poly model in _build_model() and animates it in _animate().
## Stage 1 animals never fight back: when hit, they run away.

signal died(animal: Animal)

## Physics layer 5 is for animals. Players walk through them; punches still hit them.
const ANIMAL_LAYER := 1 << 4

enum State { IDLE, WANDER, FLEE, DEAD }

var display_name := "Animal"
var max_health := 20.0
var walk_speed := 1.2
var flee_speed := 5.0
## Runs away when a player who is moving fast (not sneaking) comes this close. 0 = never.
var skittish_distance := 0.0
## How long it keeps running after being scared or hit.
var flee_time := 4.0
var loot_id: StringName
var loot_count := 1
## Size of the collision box (also what punches hit).
var body_size := Vector3(0.4, 0.4, 0.5)

var health: float
var state := State.IDLE
## Set by the spawner: animals stay on dry land within roam_radius of the middle.
var terrain: Terrain
var roam_radius := 90.0

var model: Node3D
var _state_time := 0.0
var _move_dir := Vector3.FORWARD
var _scare_check := 0.0
var _flash: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	collision_layer = ANIMAL_LAYER
	collision_mask = 1
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.3
	health = max_health
	var shape := BoxShape3D.new()
	shape.size = body_size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = body_size.y * 0.5
	add_child(collider)

	model = Node3D.new()
	add_child(model)
	_build_model(model)
	# A white see-through layer over the whole model, used for the hit flash.
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)
	_set_overlay(model)

	rotation.y = _rng.randf() * TAU
	_start_idle()


# --- For each species to fill in -----------------------------------------------

## Build the animal's look under `root`. Faces -Z.
func _build_model(_root: Node3D) -> void:
	pass


## Animate the model. `speed` is how fast it's moving along the ground.
func _animate(_delta: float, _speed: float) -> void:
	pass


# --- Behaviour --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	_state_time -= delta
	_scare_check -= delta
	if _scare_check <= 0.0:
		_scare_check = 0.25
		_check_for_scary_players()

	var target_speed := 0.0
	match state:
		State.IDLE:
			if _state_time <= 0.0:
				_start_wander()
		State.WANDER:
			target_speed = walk_speed
			if _state_time <= 0.0:
				_start_idle()
			elif not _is_safe_ahead(_move_dir):
				_turn_toward_safety()
		State.FLEE:
			target_speed = flee_speed
			if _state_time <= 0.0:
				_start_idle()
			elif not _is_safe_ahead(_move_dir):
				_turn_toward_safety()

	# Accelerate smoothly instead of instantly (knockback from a punch can play out).
	var wanted := _move_dir * target_speed
	var blend := 1.0 - exp(-(6.0 if is_on_floor() else 1.0) * delta)
	velocity.x = lerpf(velocity.x, wanted.x, blend)
	velocity.z = lerpf(velocity.z, wanted.z, blend)
	move_and_slide()
	if is_on_wall() and state != State.IDLE:
		_move_dir = _move_dir.rotated(Vector3.UP, _rng.randf_range(1.6, 3.0))

	# Turn to face where it's going.
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-8.0 * delta))
	_animate(delta, flat_speed)


func _start_idle() -> void:
	state = State.IDLE
	_state_time = _rng.randf_range(1.5, 4.5)


func _start_wander() -> void:
	state = State.WANDER
	_state_time = _rng.randf_range(2.0, 5.0)
	_move_dir = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
	if not _is_safe_ahead(_move_dir):
		_turn_toward_safety()


## Run away from `from` for a few seconds.
func flee_from(from: Vector3) -> void:
	state = State.FLEE
	_state_time = flee_time
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	_move_dir = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))


## Scared by players who run or sprint nearby. Crouching lets you sneak up.
func _check_for_scary_players() -> void:
	if skittish_distance <= 0.0 or state == State.FLEE:
		return
	for player in get_tree().get_nodes_in_group("players"):
		var distance := global_position.distance_to(player.global_position)
		var moving_fast := Vector2(player.velocity.x, player.velocity.z).length() > 3.0
		if distance < skittish_distance and moving_fast and not player.is_crouching:
			flee_from(player.global_position)
			return


## Dry land, not too far out, a little ahead in this direction?
func _is_safe_ahead(direction: Vector3) -> bool:
	if terrain == null:
		return true
	var ahead := global_position + direction * 1.5
	if Vector2(ahead.x, ahead.z).length() > roam_radius:
		return false
	return terrain.get_height(ahead.x, ahead.z) > terrain.water_level + 0.6


func _turn_toward_safety() -> void:
	var inward := -global_position
	inward.y = 0.0
	_move_dir = inward.normalized().rotated(Vector3.UP, _rng.randf_range(-1.0, 1.0))


# --- Getting hit and dying ------------------------------------------------------------

## Called by punches (and later, weapons).
func take_hit(amount: float, from: Node, at: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	DamageNumber.spawn(self, at, amount)
	_flash.albedo_color.a = 0.75
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.2)
	if from is Node3D:
		var push := global_position - (from as Node3D).global_position
		push.y = 0.0
		velocity += push.normalized() * 3.0 + Vector3(0.0, 2.5, 0.0)
		flee_from((from as Node3D).global_position)
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0 # Can't be hit any more.
	died.emit(self)
	for i in loot_count:
		var drop := WorldItem.new()
		drop.item = ItemLibrary.get_item(loot_id)
		get_parent().add_child(drop)
		drop.global_position = global_position + Vector3(0.0, body_size.y + 0.2, 0.0)
		drop.linear_velocity = Vector3(_rng.randf_range(-1.0, 1.0), 3.0, _rng.randf_range(-1.0, 1.0))
	# Fall over onto its side, wait a moment, then shrink away.
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(model, "position:y", body_size.x * 0.4, 0.35)
	tween.tween_interval(1.5)
	tween.tween_property(model, "scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(queue_free)


func _set_overlay(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			child.material_overlay = _flash
		_set_overlay(child)


# --- Model building helpers for species ----------------------------------------------

## An empty joint to attach parts to (for animating legs, head, ears...).
func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Finishes a mesh and attaches it to `parent`.
func _finish(st: SurfaceTool, parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit_smooth(st)
	parent.add_child(mesh)


## A smooth rounded ball (stretched into an egg shape with `stretch`).
func _sphere(st: SurfaceTool, radius: float, at: Vector3, stretch: Vector3, color: Color, segments: int = 14, rings: int = 8) -> void:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = maxi(segments, 14)
	shape.rings = maxi(rings, 8)
	LowPoly.add_smooth_shape(st, shape, Transform3D(Basis.from_scale(stretch), at), color, 0.03, _rng)


## Despite the name, this makes a soft rounded blob that fills the given box size
## (legs, ears, paws and beaks look rounded instead of blocky).
func _box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, rot: Basis = Basis()) -> void:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 12
	shape.rings = 7
	var blob := Basis.from_scale(size * 1.12)
	LowPoly.add_smooth_shape(st, shape, Transform3D(rot * blob, at), color, 0.03, _rng)


## A rounded tube from point `a` to point `b` (radius `ra` at a, `rb` at b), with ball
## ends so joints always connect: legs, necks, tails and arms.
func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, color: Color) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return
	var shape := CylinderMesh.new()
	shape.top_radius = rb
	shape.bottom_radius = ra
	shape.height = length
	shape.radial_segments = 14
	shape.rings = 1
	shape.cap_top = false
	shape.cap_bottom = false
	var basis := Basis(Quaternion(Vector3.UP, along / length))
	LowPoly.add_smooth_shape(st, shape, Transform3D(basis, (a + b) * 0.5), color, 0.03, _rng)
	_sphere(st, ra, a, Vector3.ONE, color)
	_sphere(st, rb, b, Vector3.ONE, color)


## A cylinder standing along Y, centred on `at`.
func _cylinder(st: SurfaceTool, top: float, bottom: float, height: float, at: Vector3, color: Color, rot: Basis = Basis()) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 12
	shape.rings = 1
	LowPoly.add_smooth_shape(st, shape, Transform3D(rot, at), color, 0.03, _rng)
