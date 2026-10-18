class_name AmbienceController
extends Node
## The sound of the island itself: wind that gets stronger up on the mountains, waves
## that fade in as you walk towards the beach, and birds that call from the trees now and
## then. It follows whatever the camera is (the main menu's orbiting camera too).

var terrain: Terrain

var _wind: AudioStreamPlayer
var _waves: AudioStreamPlayer
var _bird_timer := 2.0


func _ready() -> void:
	_wind = _loop("wind_loop", -32.0)
	_waves = _loop("waves_loop", -46.0)


func _loop(group: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = Sfx.get_loop(group)
	player.bus = "Ambience"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or terrain == null:
		return
	var at := camera.global_position
	var distance := Vector2(at.x, at.z).length()
	var ground := terrain.get_height(at.x, at.z)

	# Waves: faint from the edge of the mountains, clear on the beach.
	var shore := smoothstep(terrain.mountain_radius * 0.8, terrain.coast_radius - 4.0, distance)
	var waves_db := lerpf(-48.0, -16.0, shore)
	# Wind: soft in the forest, stronger higher up.
	var height := clampf(ground / terrain.mountain_height, 0.0, 1.0)
	var wind_db := lerpf(-34.0, -22.0, height)
	var blend := 1.0 - exp(-2.0 * delta)
	_waves.volume_db = lerpf(_waves.volume_db, waves_db, blend)
	_wind.volume_db = lerpf(_wind.volume_db, wind_db, blend)

	# Birds: only in the forest, not up high or on the beach.
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(4.0, 11.0)
		if distance < terrain.mountain_radius and height < 0.5:
			var angle := randf() * TAU
			var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(8.0, 30.0) + Vector3(0, randf_range(4.0, 10.0), 0)
			Sfx.play_at("bird", spot, randf_range(-12.0, -5.0), 0.18, 70.0)
