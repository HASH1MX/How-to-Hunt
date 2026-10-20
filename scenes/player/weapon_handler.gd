class_name WeaponHandler
extends Node
## Everything about using what you hold: swinging the knife, firing guns (ammo, reloading,
## recoil, aiming, the sniper scope) and the flare gun. Added under the player.
##
## Ammo: each gun keeps the rounds in its magazine; spare rounds are kept per ammo type
## ("pistol", "shells", "smg", "rifle", "sniper") and bought from the trader. Both are saved.
## In multiplayer the shots are shown to the other players (Network.send_shot) and the host
## checks the damage against the weapon (WorldSync).

signal ammo_changed

## Height above sea level a flare has to be fired from for rescuers to see it.
const FLARE_HEIGHT := 14.0
## Field of view while aiming a gun without a scope, as a fraction of the normal one.
const AIM_ZOOM := 0.82

var player: CharacterBody3D
## weapon id -> rounds in its magazine (a gun not listed has a full magazine).
var mags := {}
## ammo type -> spare rounds.
var reserve := {}
var aiming := false
var reloading := false

var _cooldown := 0.0
var _reload_left := 0.0
var _reload_item: ItemData


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if reloading:
		if _held() != _reload_item:
			_stop_reload()
			return
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


## The gun (or other usable item) in the player's hands, or null.
func _held() -> ItemData:
	var item: ItemData = player.inventory.get_active_item()
	return item if item != null and item.use != "" else null


## Called every frame while holding a usable item instead of punching.
func handle(item: ItemData, clicked: bool, held: bool) -> void:
	match item.use:
		"melee":
			if (clicked or held) and _cooldown <= 0.0:
				_cooldown = item.fire_gap
				player.view_model.punch_with(1, item.fire_gap)
		"gun":
			if reloading:
				return
			if (clicked or (held and item.automatic)) and _cooldown <= 0.0:
				_fire(item)
		"flare":
			if clicked and _cooldown <= 0.0:
				_fire_flare(item)


# --- Guns ------------------------------------------------------------------------------------

func get_mag(item: ItemData) -> int:
	return int(mags.get(String(item.id), item.magazine))


func get_reserve(ammo_type: String) -> int:
	return int(reserve.get(ammo_type, 0))


func add_ammo(ammo_type: String, amount: int) -> void:
	reserve[ammo_type] = get_reserve(ammo_type) + amount
	ammo_changed.emit()


func _fire(item: ItemData) -> void:
	var mag := get_mag(item)
	if item.magazine > 0 and mag <= 0:
		Sfx.play("dry_fire", -6.0, 0.05)
		_cooldown = 0.3
		start_reload()
		return
	_cooldown = item.fire_gap
	if item.magazine > 0:
		mags[String(item.id)] = mag - 1
		ammo_changed.emit()

	var camera: Camera3D = player.camera
	var from := camera.global_position
	var basis := camera.global_transform.basis
	var spread := item.spread * (0.4 if aiming else 1.0)
	var space := player.get_world_3d().direct_space_state
	var world: Node = player.get_parent()
	# Add up the damage per target first, so a shotgun blast is one hit with the total.
	var hits := {}
	var ends: Array[Vector3] = []
	for pellet in item.pellets:
		var direction := -basis.z
		if spread > 0.0:
			direction = direction.rotated(basis.x, deg_to_rad(randf_range(-spread, spread)))
			direction = direction.rotated(basis.y, deg_to_rad(randf_range(-spread, spread))).normalized()
		var to := from + direction * item.reach
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			to = hit.position
			var target: Object = hit.collider
			if target.has_method("take_hit"):
				if not hits.has(target):
					hits[target] = [0.0, hit.position]
				hits[target][0] += item.damage
			else:
				WeaponEffects.impact(world, hit.position, hit.normal)
				if target is RigidBody3D and not (target is WorldItem and target.puppet):
					target.apply_impulse(direction * 1.5, hit.position - target.global_position)
		ends.append(to)
	for target in hits:
		if is_instance_valid(target):
			player.punch_connected.emit(true, hits[target][1])
			target.take_hit(hits[target][0], player, hits[target][1], String(item.id))

	var muzzle: Vector3 = player.view_model.get_muzzle_position()
	WeaponEffects.muzzle_flash(world, muzzle)
	for to in ends:
		WeaponEffects.tracer(world, muzzle, to)
	Sfx.play(item.sound, 0.0, 0.05)
	player.view_model.kick(item.recoil)
	player.head.rotation.x = clampf(player.head.rotation.x + deg_to_rad(item.recoil * (0.5 if aiming else 0.9)), deg_to_rad(-89.0), deg_to_rad(89.0))
	Network.send_shot(String(item.id), muzzle, ends)
	if item.magazine > 0 and get_mag(item) <= 0:
		start_reload()


func start_reload() -> void:
	var item := _held()
	if item == null or item.use != "gun" or reloading or item.magazine <= 0:
		return
	if get_mag(item) >= item.magazine or get_reserve(item.ammo) <= 0:
		return
	reloading = true
	_reload_item = item
	_reload_left = item.reload_time
	player.view_model.reloading = true
	Sfx.play("reload", -4.0, 0.05)
	ammo_changed.emit()


func _finish_reload() -> void:
	var item := _reload_item
	var needed := item.magazine - get_mag(item)
	var taken := mini(needed, get_reserve(item.ammo))
	mags[String(item.id)] = get_mag(item) + taken
	reserve[item.ammo] = get_reserve(item.ammo) - taken
	_stop_reload()


func _stop_reload() -> void:
	reloading = false
	_reload_item = null
	player.view_model.reloading = false
	ammo_changed.emit()


## Right mouse button: aim down the sights (or through the scope).
func set_aiming(want: bool) -> void:
	var item := _held()
	var can_aim := item != null and item.use == "gun" and not reloading
	aiming = want and can_aim
	player.view_model.aiming = aiming


## True while looking through a sniper scope (the HUD draws the scope and the arms hide).
func is_scoped() -> bool:
	var item := _held()
	return aiming and item != null and item.zoom_fov > 0.0


## The field of view to use right now.
func get_fov(normal_fov: float) -> float:
	var item := _held()
	if not aiming or item == null:
		return normal_fov
	return item.zoom_fov if item.zoom_fov > 0.0 else normal_fov * AIM_ZOOM


## "8 / 24" for the HUD, "Reloading..." while reloading, or "" if not holding a gun.
func ammo_text() -> String:
	var item := _held()
	if item == null or item.use != "gun":
		return ""
	if reloading:
		return "Reloading..."
	return "%d / %d" % [get_mag(item), get_reserve(item.ammo)]


# --- Flare gun ------------------------------------------------------------------------------------

func _fire_flare(item: ItemData) -> void:
	_cooldown = item.fire_gap
	var camera: Camera3D = player.camera
	var direction := -camera.global_transform.basis.z
	var from := camera.global_position + direction * 0.6
	FlareShot.fire(player.get_parent(), from, direction)
	Sfx.play(item.sound, 0.0, 0.05)
	player.view_model.kick(item.recoil)
	Network.send_flare(from, direction)
	if Quests.is_active("signal_for_help"):
		if player.global_position.y >= FLARE_HEIGHT:
			Quests.report("flag", "flare_fired")
		else:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null:
				hud.show_tip("Too low!", "Nobody will see a flare from down here. Climb one of the mountains around the island and fire it from up high.", 8.0)


# --- Saving ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {mags = mags.duplicate(), reserve = reserve.duplicate()}


func from_dict(saved: Dictionary) -> void:
	mags = {}
	reserve = {}
	for key in saved.get("mags", {}):
		mags[String(key)] = int(saved.mags[key])
	for key in saved.get("reserve", {}):
		reserve[String(key)] = int(saved.reserve[key])
	ammo_changed.emit()
