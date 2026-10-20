extends Node
## Sound (autoload "Sfx"). Everything that makes noise goes through here:
##
##   Sfx.play("ui_click")                      a plain sound (menus, your own actions)
##   Sfx.play_at("punch_hit", position)        a sound in the world, louder when close
##   Sfx.get_loop("wind_loop")                 a stream that repeats (ambience)
##
## Sounds are grouped: "step_grass" is five different footstep recordings, and each play
## picks one at random (never the same one twice in a row) with a slight pitch change, so
## nothing sounds like a machine gun. Where each group's files are is listed in GROUPS.
##
## Three volume buses (Effects, Ambience, UI) follow the sliders in Settings > Game.
## Buttons anywhere in the game get click and hover sounds automatically.
## Credits: assets/audio/LICENSES.txt.

const SFX := "res://assets/audio/sfx/"
const SYNTH := "res://assets/audio/synth/"
const POOL_3D := 24
const POOL_2D := 6

## group name -> [folder, file name pattern, how many variants]. "%d" is the variant number.
const GROUPS := {
	"step_grass": [SFX, "step_grass_%d.ogg", 5],
	"step_sand": [SFX, "step_sand_%d.ogg", 5],
	"step_rock": [SFX, "step_rock_%d.ogg", 5],
	"step_wood": [SFX, "step_wood_%d.ogg", 5],
	"punch_hit": [SFX, "punch_hit_%d.ogg", 5],
	"punch_hit_heavy": [SFX, "punch_hit_heavy_%d.ogg", 5],
	"thud_soft": [SFX, "thud_soft_%d.ogg", 5],
	"thud_heavy": [SFX, "thud_heavy_%d.ogg", 5],
	"drop_stone": [SFX, "drop_stone_%d.ogg", 5],
	"drop_wood": [SFX, "drop_wood_%d.ogg", 5],
	"drop_generic": [SFX, "drop_generic_%d.ogg", 5],
	"cloth": [SFX, "cloth_%d.ogg", 4],
	"pickup": [SFX, "pickup_%d.ogg", 2],
	"coins": [SFX, "coins_%d.ogg", 2],
	"slot": [SFX, "slot_%d.ogg", 2],
	"ui_click": [SFX, "ui_click_%d.ogg", 5],
	"ui_hover": [SFX, "ui_hover_%d.ogg", 3],
	"ui_back": [SFX, "ui_back_%d.ogg", 4],
	"ui_confirm": [SFX, "ui_confirm_%d.ogg", 4],
	"ui_error": [SFX, "ui_error_%d.ogg", 2],
	"ui_open": [SFX, "ui_open_%d.ogg", 4],
	"ui_close": [SFX, "ui_close_%d.ogg", 4],
	"bird": [SYNTH, "bird_%d.wav", 6],
	"splash_step": [SYNTH, "splash_step_%d.wav", 3],
	"splash_in": [SYNTH, "splash_in_%d.wav", 2],
	"swim": [SYNTH, "swim_%d.wav", 3],
	"gasp": [SYNTH, "gasp.wav", 1],
	"hurt": [SYNTH, "hurt_%d.wav", 3],
	"whoosh": [SYNTH, "whoosh_%d.wav", 3],
	"rabbit_hurt": [SYNTH, "rabbit_hurt_%d.wav", 2],
	"rabbit_die": [SYNTH, "rabbit_die.wav", 1],
	"chicken_cluck": [SYNTH, "chicken_cluck_%d.wav", 3],
	"chicken_hurt": [SYNTH, "chicken_hurt.wav", 1],
	"chicken_die": [SYNTH, "chicken_die.wav", 1],
	"squirrel_chitter": [SYNTH, "squirrel_chitter_%d.wav", 2],
	"squirrel_hurt": [SYNTH, "squirrel_hurt.wav", 1],
	"deer_hurt": [SYNTH, "deer_hurt.wav", 1],
	"deer_die": [SYNTH, "deer_die.wav", 1],
	"deer_snort": [SYNTH, "deer_snort.wav", 1],
	"blip": [SYNTH, "blip_%d.wav", 6],
	"munch": [SYNTH, "munch_%d.wav", 3],
	"fire_loop": [SYNTH, "fire_loop.wav", 1],
	"gun_pistol": [SYNTH, "gun_pistol_%d.wav", 2],
	"gun_shotgun": [SYNTH, "gun_shotgun.wav", 1],
	"gun_smg": [SYNTH, "gun_smg_%d.wav", 2],
	"gun_rifle": [SYNTH, "gun_rifle_%d.wav", 2],
	"gun_sniper": [SYNTH, "gun_sniper.wav", 1],
	"flare_shot": [SYNTH, "flare_shot.wav", 1],
	"dry_fire": [SYNTH, "dry_fire.wav", 1],
	"reload": [SYNTH, "reload.wav", 1],
	"beep": [SYNTH, "beep.wav", 1],
	"wind_loop": [SYNTH, "wind_loop.wav", 1],
	"waves_loop": [SYNTH, "waves_loop.wav", 1],
}

var _streams := {}
var _last_variant := {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_2d := 0
var _underwater := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Effects", "Ambience", "UI"]:
		_ensure_bus(bus)
	# Muffles Effects and Ambience (an extra "filter" effect that is normally off) for under water.
	for bus in ["Effects", "Ambience"]:
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 800.0
		var index := AudioServer.get_bus_index(bus)
		AudioServer.add_bus_effect(index, filter)
		AudioServer.set_bus_effect_enabled(index, 0, false)
	for i in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.bus = "Effects"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 5.0
		add_child(player)
		_players_3d.append(player)
	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		_players_2d.append(player)
	Settings.changed.connect(apply_volumes)
	apply_volumes()
	# Every button in the game clicks, without each menu having to ask.
	get_tree().node_added.connect(_on_node_added)


func apply_volumes() -> void:
	_set_bus("Master", Settings.master_volume)
	_set_bus("Effects", Settings.effects_volume)
	_set_bus("UI", Settings.effects_volume)
	_set_bus("Ambience", Settings.ambience_volume)


## Under water everything sounds muffled.
func set_underwater(underwater: bool) -> void:
	if underwater == _underwater:
		return
	_underwater = underwater
	for bus in ["Effects", "Ambience"]:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(bus), 0, underwater)


# --- Playing ------------------------------------------------------------------------------

## Plays a sound that isn't in the world (your own footsteps' hand-ups, menus, the HUD).
func play(group: String, volume_db: float = 0.0, pitch_variation: float = 0.05, bus: String = "Effects") -> void:
	var stream := _pick(group)
	if stream == null:
		return
	var player := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


## Plays a sound at a place in the world. Quieter further away; `max_distance` is where
## it can no longer be heard.
func play_at(group: String, position: Vector3, volume_db: float = 0.0, pitch_variation: float = 0.08, max_distance: float = 35.0) -> void:
	var stream := _pick(group)
	if stream == null:
		return
	var player := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_3D
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


## A sound that repeats forever (wind, waves). A new copy every call.
func get_loop(group: String) -> AudioStream:
	var source := _load_variant(group, 0)
	if source is AudioStreamWAV:
		var looped: AudioStreamWAV = source.duplicate()
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = looped.data.size() / (4 if looped.stereo else 2)
		return looped
	return source


func has_group(group: String) -> bool:
	return GROUPS.has(group)


# --- Internals ---------------------------------------------------------------------------------

func _pick(group: String) -> AudioStream:
	if not GROUPS.has(group):
		push_warning("Unknown sound group: %s" % group)
		return null
	var count: int = GROUPS[group][2]
	var variant := 0
	if count > 1:
		variant = randi() % count
		if variant == _last_variant.get(group, -1):
			variant = (variant + 1 + randi() % (count - 1)) % count
	_last_variant[group] = variant
	return _load_variant(group, variant)


func _load_variant(group: String, variant: int) -> AudioStream:
	var info: Array = GROUPS[group]
	var path: String = info[0] + (info[1] % variant if "%d" in info[1] else info[1])
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _set_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)


func _on_node_added(node: Node) -> void:
	if not node is BaseButton:
		return
	node.mouse_entered.connect(func():
		if not node.disabled:
			play("ui_hover", -14.0, 0.04, "UI"))
	node.pressed.connect(func(): play("ui_click", -6.0, 0.03, "UI"))
