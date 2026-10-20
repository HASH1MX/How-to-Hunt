class_name RemotePlayer
extends Node3D
## Another player's character, shown in your world. It has no controls of its own:
## it just follows the positions the other player sends (see Network), smoothed so the
## motion looks continuous, and plays the walking, crouching and punching animations.
## It is built from the same CharacterModel as the NPCs, with a name above the head.
##
## Later (character customization) the look comes from the player's saved appearance,
## and (accessories) hats etc. attach to the model's head.

const FLAG_CROUCH := 1
const FLAG_SPRINT := 2
const FLAG_ON_FLOOR := 4
const FLAG_SWIM := 8
## Shirt colors given out by player number, so people are easy to tell apart.
const SHIRT_COLORS: Array[Color] = [
	Color(0.27, 0.45, 0.85), Color(0.85, 0.3, 0.3), Color(0.3, 0.7, 0.4), Color(0.92, 0.72, 0.2),
	Color(0.68, 0.38, 0.82), Color(0.25, 0.75, 0.78), Color(0.9, 0.5, 0.2), Color(0.85, 0.45, 0.65),
	Color(0.55, 0.55, 0.6), Color(0.45, 0.3, 0.2),
]

var peer_id := 0
var player_name := "Player"

var model: CharacterModel
var _label: Label3D
var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _pitch := 0.0
var _flags := 0
var _have_state := false
var _speed := 0.0
var _step_distance := 0.0
var _was_airborne := false
var _terrain: Terrain
## So animals (which run on the host) get scared of this player like any other.
var velocity := Vector3.ZERO
var is_crouching := false


func _ready() -> void:
	add_to_group("remote_players")
	model = CharacterModel.new()
	model.shirt_color = SHIRT_COLORS[(peer_id - 1) % SHIRT_COLORS.size()]
	model.pants_color = Color(0.2, 0.22, 0.3)
	model.name = "Model"
	add_child(model)
	model.remote_controlled = true

	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.0045
	_label.modulate = Color(0.98, 0.96, 0.92)
	_label.outline_modulate = Color(0, 0, 0, 0.6)
	_label.position = Vector3(0, 2.3, 0)
	add_child(_label)
	# Nothing to show until the first position arrives.
	visible = false


## Called with each update from the other player.
func push_state(position: Vector3, yaw: float, pitch: float, flags: int) -> void:
	_target_position = position
	_target_yaw = yaw
	_pitch = pitch
	_flags = flags
	if not _have_state:
		_have_state = true
		global_position = position
		rotation.y = yaw
		visible = true


func set_held(item_id: String) -> void:
	if model != null:
		model.set_held_item(ItemLibrary.get_item(StringName(item_id)) if item_id != "" and ItemLibrary.has_item(StringName(item_id)) else null)


## This player fired: flash at their hand, tracers to where the shots went, and the sound.
func show_shot(weapon_id: String, ends: Array) -> void:
	if model == null:
		return
	var muzzle := model.get_hand_position()
	var parent := get_parent()
	WeaponEffects.muzzle_flash(parent, muzzle)
	for to in ends:
		WeaponEffects.tracer(parent, muzzle, to)
	model.play_punch()
	if ItemLibrary.has_item(StringName(weapon_id)):
		Sfx.play_at(ItemLibrary.get_item(StringName(weapon_id)).sound, muzzle, 2.0, 0.05, 150.0)


func punch() -> void:
	if model != null:
		model.play_punch()
		Sfx.play_at("whoosh", global_position + Vector3(0, 1.3, 0), -7.0, 0.1, 25.0)


func _process(delta: float) -> void:
	if not _have_state:
		return
	var before := global_position
	# Teleports (respawning) snap instead of sliding across the map.
	if before.distance_to(_target_position) > 8.0:
		global_position = _target_position
	else:
		global_position = before.lerp(_target_position, 1.0 - exp(-14.0 * delta))
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-14.0 * delta))

	var flat := Vector2(global_position.x - before.x, global_position.z - before.z)
	_speed = lerpf(_speed, flat.length() / maxf(delta, 0.0001), 1.0 - exp(-10.0 * delta))
	model.move_speed = _speed if _speed > 0.15 else 0.0
	velocity = Vector3(flat.x, 0.0, flat.y) / maxf(delta, 0.0001)
	is_crouching = _flags & FLAG_CROUCH != 0
	model.crouching = _flags & FLAG_CROUCH != 0
	model.sprinting = _flags & FLAG_SPRINT != 0
	model.airborne = _flags & FLAG_ON_FLOOR == 0 and _flags & FLAG_SWIM == 0
	model.swimming = _flags & FLAG_SWIM != 0
	model.remote_pitch = _pitch
	_make_sounds(delta)


## Footsteps, jumps and landings of another player, heard from where they are.
func _make_sounds(delta: float) -> void:
	var airborne := model.airborne
	if airborne and not _was_airborne:
		Sfx.play_at("cloth", global_position + Vector3(0, 1.0, 0), -8.0, 0.08, 25.0)
	elif _was_airborne and not airborne:
		Sfx.play_at("thud_soft", global_position, -7.0, 0.08, 30.0)
		_step_distance = 0.0
	_was_airborne = airborne
	if airborne or model.swimming or _speed < 0.6:
		if model.swimming and _speed > 0.8 and fmod(Time.get_ticks_msec() / 1000.0, 0.95) < delta:
			Sfx.play_at("swim", global_position + Vector3(0, 0.8, 0), -7.0, 0.1, 30.0)
		return
	_step_distance += _speed * delta
	if _step_distance < 1.55 + _speed * 0.13:
		return
	_step_distance = 0.0
	if _terrain == null and get_parent() != null:
		_terrain = get_parent().get_node_or_null("Terrain")
	var surface := "grass" if _terrain == null else _terrain.get_surface_at(global_position.x, global_position.z)
	var volume := -9.0 - (7.0 if model.crouching else 0.0)
	Sfx.play_at("step_" + surface, global_position, volume, 0.1, 30.0)
