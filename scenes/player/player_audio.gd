class_name PlayerAudio
extends Node
## All the sounds your own character makes: footsteps (grass, sand, rock, shallow water),
## jumping and landing, swimming, splashing in, coming up for air, being hurt, punching
## and dropping things. Added under the local player when the game starts.
## It only listens to the player (signals and state), so the player's own code stays simple.

var player: CharacterBody3D
## The ground, used to tell grass from sand and rock.
var terrain: Terrain

var _step_distance := 0.0
var _swim_timer := 0.0
var _was_deep := false
var _was_underwater := false
var _was_crouching := false
var _hurt_cooldown := 0.0
var _foot := 0


func _ready() -> void:
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.damaged.connect(_on_damaged)
	player.punch_connected.connect(_on_punch_connected)
	player.view_model.punch_started.connect(func(): Sfx.play("whoosh", -7.0, 0.1))
	player.inventory.item_dropped.connect(_on_item_dropped)
	player.inventory.item_picked_up.connect(func(_item): Sfx.play("pickup", -4.0, 0.06))


func _physics_process(delta: float) -> void:
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	var flat_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var deep: bool = player.is_in_deep_water
	var feet := player.global_position

	Sfx.set_underwater(player.is_head_underwater)
	# Splash when going into deep water; a gasp for air when coming back up after a while.
	if deep and not _was_deep:
		Sfx.play_at("splash_in", feet, -2.0, 0.08, 40.0)
	if _was_underwater and not player.is_head_underwater and player.breath < player.breath_time * 0.75:
		Sfx.play("gasp", -4.0, 0.05)
	_was_deep = deep
	_was_underwater = player.is_head_underwater

	if player.is_crouching and not _was_crouching:
		Sfx.play("cloth", -16.0, 0.08)
	_was_crouching = player.is_crouching

	if deep:
		# Swimming: a soft stroke every second or so while moving.
		if flat_speed > 0.8:
			_swim_timer -= delta
			if _swim_timer <= 0.0:
				_swim_timer = 0.95
				Sfx.play_at("swim", feet + Vector3(0, 0.8, 0), -7.0, 0.1, 30.0)
		return
	if not player.is_on_floor() or flat_speed < 0.6:
		return
	# Footsteps: one every stride (longer strides when running).
	_step_distance += flat_speed * delta
	if _step_distance >= 1.55 + flat_speed * 0.13:
		_step_distance = 0.0
		_step(flat_speed)


func _step(speed: float) -> void:
	var feet := player.global_position
	var volume := -9.0 + clampf((speed - 5.0) * 0.6, -2.0, 3.0)
	if player.is_crouching:
		volume -= 7.0
	_foot = 1 - _foot
	var in_water := terrain != null and terrain.get_height(feet.x, feet.z) < terrain.water_level + 0.15
	if in_water:
		Sfx.play_at("splash_step", feet, volume + 2.0, 0.12, 30.0)
		return
	var surface := "grass" if terrain == null else terrain.get_surface_at(feet.x, feet.z)
	Sfx.play_at("step_" + surface, feet, volume, 0.1, 30.0)


func _on_jumped() -> void:
	var feet := player.global_position
	Sfx.play_at("cloth", feet + Vector3(0, 1.0, 0), -8.0, 0.08, 25.0)
	Sfx.play_at("thud_soft", feet, -16.0, 0.12, 25.0)


func _on_landed(speed: float) -> void:
	if player.is_in_deep_water:
		Sfx.play_at("splash_in", player.global_position, -3.0, 0.1, 40.0)
		return
	var feet := player.global_position
	if speed > 9.0:
		Sfx.play_at("thud_heavy", feet, -2.0, 0.08, 40.0)
	elif speed > 5.0:
		Sfx.play_at("thud_soft", feet, -5.0, 0.08, 35.0)
	elif speed > 2.5:
		Sfx.play_at("thud_soft", feet, -12.0, 0.1, 30.0)
	_step_distance = 0.0


func _on_damaged(amount: float) -> void:
	# Hits and falls make a sound; slow starvation and drowning (tiny amounts) don't.
	if amount >= 3.0 and _hurt_cooldown <= 0.0:
		_hurt_cooldown = 0.5
		Sfx.play("hurt", -3.0, 0.06)


func _on_punch_connected(hit_creature: bool, at: Vector3) -> void:
	Sfx.play_at("punch_hit" if hit_creature else "thud_soft", at, -2.0 if hit_creature else -9.0, 0.08, 30.0)


func _on_item_dropped(item: ItemData) -> void:
	var group := "drop_generic"
	match String(item.id):
		"stone": group = "drop_stone"
		"stick": group = "drop_wood"
	Sfx.play_at(group, player.global_position + Vector3(0, 1.0, 0) + -player.global_transform.basis.z, -9.0, 0.1, 25.0)
