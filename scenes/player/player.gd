extends CharacterBody3D
## The player: first-person movement, like How to Fish.
## WASD = move, Shift = sprint, Ctrl = crouch (hold), Mouse = look, Space = jump,
## Left click = punch (click fast to punch fast, or hold),
## E = pick up / talk, 1-4 = inventory slots, Q = drop, J = show/hide the quest tip,
## Esc = pause menu. Keys can be changed in Settings > Controls.
##
## Survival:
##   - Health: at zero the player respawns at the spawn point.
##   - Food: slowly runs down. When empty, the player slowly loses health.
##   - Stamina: used by sprinting and jumping, refills while resting.
##   - Breath: runs down while the head is under water. When empty, the player
##     loses health. In deep water the player sinks; 3 jumps can be used to push
##     back up, and they come back when touching the ground.
##
## The body is on render layer 2, which this player's own camera does not draw,
## so you don't see the inside of your own body. Other players (later, in
## multiplayer) will still see it, and you still see your own shadow.

signal health_changed(current: float, maximum: float)
signal food_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal breath_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died
## Asks the HUD to show a conversation. The HUD calls on_finished when it closes.
signal dialogue_requested(speaker: String, lines: PackedStringArray, on_finished: Callable)

@export_group("Punching")
@export var punch_damage: float = 10.0
## How far a punch reaches, in meters.
@export var punch_reach: float = 2.4
## How hard a punch knocks loose items around.
@export var punch_push: float = 2.5
## Fastest you can punch by clicking (seconds between punches).
@export var click_punch_gap: float = 0.11
## Holding the button punches automatically this often, after holding for a moment.
@export var hold_punch_gap: float = 0.32

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.5
## Body height standing and crouching (meters). The eyes are a little below the top.
@export var stand_height: float = 2.0
@export var crouch_height: float = 1.3
## How much wider the view gets while sprinting, for a feeling of speed.
@export var sprint_fov_boost: float = 8.0
@export var jump_velocity: float = 4.5
## Minimum seconds between jumps, so spamming jump can't chain jumps up slopes.
@export var jump_cooldown: float = 0.4
## Steepest slope (in degrees) the player can walk up. Mountains are climbable below this.
@export var max_climb_angle: float = 60.0
## If the player falls below this height, they are sent back to the spawn point.
@export var fall_limit: float = -20.0

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Fall damage")
## Landing slower than this (meters per second) doesn't hurt. 9 m/s is about a 4 m drop.
@export var safe_fall_speed: float = 9.0
## Damage for each m/s of landing speed above the safe speed.
## With these numbers: 6 m drop = 18, 10 m drop = 50, 15 m drop = 81, about 20 m = deadly.
@export var fall_damage_per_speed: float = 10.0

@export_group("Food")
@export var max_food: float = 100.0
## Minutes for the food bar to go from full to empty.
@export var food_duration_minutes: float = 12.0
@export var starve_damage_per_second: float = 1.5

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var sprint_stamina_per_second: float = 18.0
@export var jump_stamina_cost: float = 8.0
@export var stamina_regen_per_second: float = 25.0
## Seconds after using stamina before it starts refilling.
@export var stamina_regen_delay: float = 1.0
## After running out, sprinting is blocked until stamina is back to this much.
@export var stamina_needed_after_empty: float = 25.0

@export_group("Water")
@export var swim_speed: float = 3.0
## Seconds you can hold your breath with your head under water before taking damage.
@export var breath_time: float = 6.0
@export var drown_damage_per_second: float = 10.0
## How fast breath comes back with the head above water (seconds per second).
@export var breath_refill_rate: float = 2.0
## Gravity in deep water is this fraction of normal, so you sink slowly.
@export var water_gravity_scale: float = 0.3
@export var max_sink_speed: float = 2.5
## Jumps you can make while in deep water before touching the ground again.
@export var water_jumps: int = 3

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var view_model: ViewModel = $Head/Camera3D/ViewModel
@onready var inventory: Inventory = $Inventory
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Body

## Height of the water surface. Set by the level; -INF means there is no water.
var water_level: float = -INF
var health: float
var food: float
var stamina: float
var breath: float
var water_jumps_left: int
var spawn_position: Vector3
## Water is above the waist: the player sinks and moves slowly.
var is_in_deep_water := false
## The eyes are below the water surface: breath runs down.
var is_head_underwater := false
var _base_fov: float
var _jump_cooldown_left := 0.0
var _stamina_regen_wait := 0.0
## Stamina ran out: sprinting is blocked until it refills a bit.
var is_exhausted := false
## True while talking to someone: no moving, punching or picking things up.
var in_dialogue := false
## True while the pause menu is open: no moving, looking, punching or using things.
var in_menu := false
## Steep surfaces touched last frame, used to stop "climbing" walls by jumping.
var _steep_normals: Array[Vector3] = []
var is_crouching := false
## How long the punch button has been held without letting go.
var _attack_held_time := 0.0
## A click that came a little too early is remembered for this long, so no click is lost.
var _punch_buffer := 0.0


func _ready() -> void:
	spawn_position = global_position
	# Every player needs its own collision shape, because crouching changes its height.
	body_shape.shape = body_shape.shape.duplicate()
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	floor_max_angle = deg_to_rad(max_climb_angle)
	floor_snap_length = 0.4 # Stick to the ground when walking down slopes.
	add_to_group("players")
	inventory.changed.connect(_update_held_item)
	inventory.item_dropped.connect(_on_item_dropped)
	view_model.punch_hit.connect(_on_punch_hit)
	_reset_stats()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Field of view comes from the settings menu.
func _apply_settings() -> void:
	_base_fov = Settings.field_of_view


func _unhandled_input(event: InputEvent) -> void:
	if in_menu:
		return # The pause menu is open.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left/right turns the whole player, up/down tilts only the head.
		var turn := Settings.get_mouse_turn_speed()
		var vertical := -1.0 if Settings.invert_mouse_y else 1.0
		rotate_y(-event.relative.x * turn)
		head.rotate_x(-event.relative.y * turn * vertical)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		view_model.add_sway(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled() # This click only captures the mouse, it doesn't punch.
	elif in_dialogue:
		return # The dialogue box handles E while talking.
	elif event.is_action_pressed("interact"):
		var target := get_interact_target()
		if target != null:
			target.interact(self)
	elif event.is_action_pressed("drop"):
		inventory.drop_active_item()
	else:
		for i in Inventory.SLOT_COUNT:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				inventory.press_slot(i)


func _physics_process(delta: float) -> void:
	is_in_deep_water = global_position.y + 1.0 < water_level
	is_head_underwater = camera.global_position.y < water_level

	var input_dir := Vector2.ZERO
	var can_act := not in_dialogue and not in_menu
	if can_act:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var mouse_ready := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	update_attack(delta, can_act and mouse_ready and Input.is_action_just_pressed("attack"),
			can_act and mouse_ready and Input.is_action_pressed("attack"))
	_update_crouch(delta, can_act and Input.is_action_pressed("crouch"))

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var wants_sprint := Input.is_action_pressed("sprint") and input_dir.y < -0.1
	var sprinting := wants_sprint and not is_in_deep_water and not is_exhausted and stamina > 0.0 and not is_crouching

	_apply_gravity(delta)
	_handle_jump(delta)

	var speed := walk_speed
	if is_in_deep_water:
		speed = swim_speed
	elif is_crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	var target_fov := _base_fov + (sprint_fov_boost if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 8.0 * delta)

	var was_on_floor := is_on_floor()
	var landing_speed := -velocity.y
	_move_without_wall_climbing()
	if not was_on_floor and is_on_floor():
		_on_landed(landing_speed)
	view_model.move_speed = Vector2(velocity.x, velocity.z).length()
	view_model.on_floor = is_on_floor() or is_in_deep_water
	view_model.sprinting = sprinting and direction != Vector3.ZERO
	_update_stamina(delta, sprinting and direction != Vector3.ZERO)
	_update_breath(delta)
	_update_food(delta)

	if global_position.y < fall_limit:
		respawn()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		water_jumps_left = water_jumps
		return
	if is_in_deep_water:
		# Sink slowly, and water slows down fast movement up or down.
		velocity += get_gravity() * water_gravity_scale * delta
		velocity.y = maxf(velocity.y, -max_sink_speed)
	else:
		velocity += get_gravity() * delta


func _handle_jump(delta: float) -> void:
	_jump_cooldown_left = maxf(_jump_cooldown_left - delta, 0.0)
	if in_dialogue or in_menu or is_crouching or not Input.is_action_just_pressed("jump") or _jump_cooldown_left > 0.0:
		return
	if is_on_floor():
		if stamina < jump_stamina_cost:
			return
		_use_stamina(jump_stamina_cost)
	elif is_in_deep_water and water_jumps_left > 0:
		water_jumps_left -= 1
	else:
		return
	velocity.y = jump_velocity
	_jump_cooldown_left = jump_cooldown


## Moves the player, but stops jumps from "sliding" up surfaces too steep to walk on.
## Without this, jumping into a steep slope could push the player up along it.
func _move_without_wall_climbing() -> void:
	if not is_on_floor():
		for normal in _steep_normals:
			var away := Vector3(normal.x, 0.0, normal.z).normalized()
			var into_wall := velocity.dot(-away)
			if into_wall > 0.0:
				velocity += away * into_wall
	var vertical_before := velocity.y
	move_and_slide()
	_steep_normals.clear()
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.angle_to(up_direction) > floor_max_angle:
			_steep_normals.append(normal)
	if not is_on_floor() and velocity.y > vertical_before:
		velocity.y = vertical_before


## Punching: every click punches (up to one every click_punch_gap seconds, and a
## click that comes slightly too early is saved and used right after). Holding the
## button for a moment starts punching automatically at a slower pace.
func update_attack(delta: float, clicked: bool, held: bool) -> void:
	_punch_buffer = maxf(_punch_buffer - delta, 0.0)
	_attack_held_time = _attack_held_time + delta if held else 0.0
	if clicked:
		_punch_buffer = 0.2
	if _punch_buffer > 0.0:
		if view_model.punch(click_punch_gap):
			_punch_buffer = 0.0
	elif _attack_held_time > hold_punch_gap:
		view_model.punch(hold_punch_gap)


## Holding crouch makes the body shorter, lowers the view and slows you down.
## You can only stand up again if there's room above your head.
func _update_crouch(delta: float, wants_crouch: bool) -> void:
	if wants_crouch and not is_in_deep_water:
		is_crouching = true
	elif is_crouching and _has_room_to_stand():
		is_crouching = false
	var target_height := crouch_height if is_crouching else stand_height
	var capsule := body_shape.shape as CapsuleShape3D
	if not is_equal_approx(capsule.height, target_height):
		# Shrink straight away, grow back smoothly.
		capsule.height = target_height if is_crouching else move_toward(capsule.height, target_height, 4.0 * delta)
		body_shape.position.y = capsule.height * 0.5
		body_mesh.scale.y = capsule.height / stand_height
		body_mesh.position.y = capsule.height * 0.5
	# The eyes glide down and up instead of snapping.
	var eye_height := target_height - 0.35
	head.position.y = lerpf(head.position.y, eye_height, 1.0 - exp(-14.0 * delta))


func _has_room_to_stand() -> bool:
	var capsule := body_shape.shape as CapsuleShape3D
	return not test_move(global_transform, Vector3(0.0, stand_height - capsule.height, 0.0))


## Hurts the player when landing too fast. Water breaks the fall.
func _on_landed(speed: float) -> void:
	view_model.on_landed(speed)
	if is_in_deep_water or speed <= safe_fall_speed:
		return
	take_damage((speed - safe_fall_speed) * fall_damage_per_speed)


func _use_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_regen_wait = stamina_regen_delay
	if stamina <= 0.0:
		is_exhausted = true


func _update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		_use_stamina(sprint_stamina_per_second * delta)
	elif _stamina_regen_wait > 0.0:
		_stamina_regen_wait -= delta
	else:
		stamina = minf(stamina + stamina_regen_per_second * delta, max_stamina)
	if is_exhausted and stamina >= stamina_needed_after_empty:
		is_exhausted = false
	stamina_changed.emit(stamina, max_stamina)


func _update_breath(delta: float) -> void:
	if is_head_underwater:
		breath = maxf(breath - delta, 0.0)
		if breath <= 0.0:
			take_damage(drown_damage_per_second * delta)
	else:
		breath = minf(breath + breath_refill_rate * delta, breath_time)
	breath_changed.emit(breath, breath_time)


func _update_food(delta: float) -> void:
	food = maxf(food - max_food / (food_duration_minutes * 60.0) * delta, 0.0)
	food_changed.emit(food, max_food)
	if food <= 0.0:
		take_damage(starve_damage_per_second * delta)


## Restores food. Will be used by food items later.
func eat(amount: float) -> void:
	food = minf(food + amount, max_food)
	food_changed.emit(food, max_food)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	if health <= 0.0:
		died.emit()
		respawn()


## Puts the player back at the spawn point with everything refilled.
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_reset_stats()


func _reset_stats() -> void:
	health = max_health
	food = max_food
	stamina = max_stamina
	breath = breath_time
	water_jumps_left = water_jumps
	is_exhausted = false
	health_changed.emit(health, max_health)
	food_changed.emit(food, max_food)
	stamina_changed.emit(stamina, max_stamina)
	breath_changed.emit(breath, breath_time)


## What the player is looking at that can be used with E (an item, a person...), or null.
## Anything with interact(player) and get_interact_text() methods works.
func get_interact_target() -> Node:
	if in_dialogue or not interact_ray.is_colliding():
		return null
	var target := interact_ray.get_collider()
	return target if target != null and target.has_method("interact") else null


## Opens a conversation in the HUD. Called by NPCs.
func start_dialogue(speaker: String, lines: PackedStringArray, on_finished: Callable) -> void:
	in_dialogue = true
	dialogue_requested.emit(speaker, lines, func():
		in_dialogue = false
		on_finished.call())


## Called by the arms at the moment a punch reaches out: hit whatever is in front.
func _on_punch_hit() -> void:
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * punch_reach)
	query.exclude = [get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target: Object = hit.collider
	if target.has_method("take_hit"):
		# Animals (later) will have take_hit and lose health.
		target.take_hit(punch_damage, self, hit.position)
	elif target is RigidBody3D:
		# Knock loose items around.
		target.apply_impulse(forward * punch_push, hit.position - target.global_position)


## Shows the active item in the right hand.
func _update_held_item() -> void:
	var anchor := view_model.held_item_anchor
	for child in anchor.get_children():
		child.queue_free()
	var item := inventory.get_active_item()
	if item == null:
		return
	var model := MeshInstance3D.new()
	model.mesh = item.mesh
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Long items (like a stick) stick out forward from the fist.
	model.position.z = -item.mesh.get_aabb().size.z * 0.3
	anchor.add_child(model)


## Throws the dropped item a little in front of the player, from chest height
## (not from where the camera looks, which could be inside the ground).
func _on_item_dropped(item: ItemData) -> void:
	var dropped := WorldItem.new()
	dropped.item = item
	get_parent().add_child(dropped)
	var forward := -global_transform.basis.z
	dropped.global_position = global_position + Vector3(0.0, 1.2, 0.0) + forward * 0.6
	dropped.linear_velocity = forward * 2.0 + Vector3(0.0, 1.0, 0.0) + Vector3(velocity.x, 0.0, velocity.z) * 0.5
