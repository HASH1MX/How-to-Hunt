class_name RescueEvent
extends Node3D
## The end of Island 1. Once the flare is seen, a medical helicopter flies in and lands in
## the field by the crash site. Everyone boards it (press E on it). Then a short film plays
## for every player at once: take-off with Captain Gus, Nurse Nina and the pilot, a calm
## flight east over the sea... until the engine catches fire and it spins down into the
## water. Black. "Hours later..." - and everyone wakes up on Island 2's beach.
##
## In multiplayer the host waits until every player has boarded, then starts the film on
## every computer (one RPC), and moves everybody to the next island at the end.

const QUEST := "rescue"
const ARRIVE_TIME := 13.0
const FLIGHT_TIME := 26.0
const NEXT_ISLAND := "jungle"

## Where it lands (set by the Crash Forest before adding this).
var landing_at := Vector3.ZERO
var water_level := -0.6

var heli: Helicopter
var _rotor_sound: AudioStreamPlayer3D
var _phase := "waiting"
var _t := 0.0
var _boarded := {}
var _camera: Camera3D
var _overlay: CutsceneOverlay
var _lines_done := {}
var _spin := 0.0


func _ready() -> void:
	heli = Helicopter.new()
	heli.name = "Helicopter"
	heli.visible = false
	heli.on_board = _on_board
	add_child(heli)
	_rotor_sound = AudioStreamPlayer3D.new()
	_rotor_sound.stream = Sfx.get_loop("rotor_loop")
	_rotor_sound.bus = "Effects"
	_rotor_sound.unit_size = 8.0
	_rotor_sound.max_distance = 220.0
	heli.add_child(_rotor_sound)
	Quests.session_started.connect(_on_session_started)


## When a world loads in the middle of the rescue, the helicopter is already waiting.
func _on_session_started() -> void:
	if Quests.is_active(QUEST) and _phase == "waiting":
		_land_now()


func _process(delta: float) -> void:
	match _phase:
		"waiting":
			if Quests.is_active(QUEST):
				_phase = "arriving"
				_t = 0.0
				heli.visible = true
				heli.rotor_speed = 5.0
				_rotor_sound.play()
				var hud := get_tree().get_first_node_in_group("hud")
				if hud != null:
					hud.show_tip("A helicopter!", "Someone saw the flare! A rescue helicopter is coming in to land by the crash site.", 8.0)
		"arriving":
			_t += delta
			var k := smoothstep(0.0, 1.0, minf(_t / ARRIVE_TIME, 1.0))
			var start := landing_at + Vector3(-220.0, 70.0, 160.0)
			heli.global_position = start.lerp(landing_at, k) + Vector3(0, sin(k * PI) * 10.0, 0)
			heli.rotation = Vector3(0.15 * (1.0 - k), lerp_angle(-2.2, -PI * 0.5, k), 0.0)
			if _t >= ARRIVE_TIME:
				_land_now()
		"flight":
			_update_flight(delta)


func _land_now() -> void:
	_phase = "landed"
	heli.visible = true
	heli.global_position = landing_at
	heli.rotation = Vector3(0, -PI * 0.5, 0)
	heli.rotor_speed = 4.0
	heli.boarding_open = true
	if not _rotor_sound.playing:
		_rotor_sound.play()


# --- Boarding -------------------------------------------------------------------------------

func _on_board(player: Node) -> void:
	if _phase != "landed":
		return
	heli.boarding_open = false
	player.in_cutscene = true
	player.in_menu = true
	player.visible = false
	Sfx.play("cloth", -4.0, 0.05)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_tip("On board", "Waiting for everyone to climb in...", 0.0)
	if Network.is_online() and not Network.is_host():
		_request_board.rpc_id(1)
	else:
		_host_boarded(Network.get_my_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_board() -> void:
	if multiplayer.is_server():
		_host_boarded(multiplayer.get_remote_sender_id())


func _host_boarded(peer: int) -> void:
	_boarded[peer] = true
	for id in Network.players:
		if not _boarded.has(id):
			return
	if Network.is_online():
		_begin_flight.rpc()
	else:
		_begin_flight()


# --- The film -------------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _begin_flight() -> void:
	_phase = "flight"
	_t = 0.0
	heli.boarding_open = false
	heli.visible = true
	heli.global_position = landing_at
	heli.rotation = Vector3(0, -PI * 0.5, 0)
	heli.show_passenger(true)
	if not _rotor_sound.playing:
		_rotor_sound.play()
	# Gus has climbed aboard; the local player sits in the back too.
	for npc in get_tree().get_nodes_in_group("story_gus"):
		npc.visible = false
	var player := get_tree().get_first_node_in_group("players")
	if player != null:
		player.in_cutscene = true
		player.in_menu = true
		player.visible = false
		player.set_physics_process(false)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.visible = false
	_camera = Camera3D.new()
	_camera.fov = 60.0
	get_parent().add_child(_camera)
	# Start watching from the edge of the field (above the ground, wherever that is).
	var spot := landing_at + Vector3(-15.0, 0.0, 7.0)
	var island := get_tree().get_first_node_in_group("island_world") as IslandWorld
	spot.y = (island.terrain.get_height(spot.x, spot.z) if island != null else landing_at.y) + 2.2
	_camera.global_position = spot
	_camera.make_current()
	_overlay = CutsceneOverlay.new()
	get_parent().add_child(_overlay)


const LINES := [
	[1.0, "Pilot", "Hold on to something! Next stop: a hospital bed and a hot meal."],
	[5.0, "Captain Gus", "We did it, kid! I'll never complain about plane food again."],
	[8.5, "Nurse Nina", "Captain, please sit still. You'll pull your splint loose."],
	[11.2, "Pilot", "Uh... is that smoke?"],
	[13.0, "Captain Gus", "Oh no. No no no. Not AGAIN!"],
	[15.0, "Pilot", "Mayday, mayday! We're going down!"],
]


func _update_flight(delta: float) -> void:
	_t += delta
	var east := Vector3(1, 0, 0)
	var cruise := 30.0
	var position := landing_at
	if _t < 4.0:
		position += Vector3(0, smoothstep(0.0, 4.0, _t) * cruise, 0)
		heli.rotation.x = -0.12 * smoothstep(1.0, 4.0, _t)
		heli.rotor_speed = 6.0
	elif _t < 12.0:
		position += Vector3(0, cruise, 0) + east * (_t - 4.0) * 28.0
	else:
		var fall := smoothstep(12.0, 19.5, _t)
		position += east * (8.0 * 28.0 + (_t - 12.0) * 18.0)
		position.y = lerpf(landing_at.y + cruise, water_level + 0.5, fall * fall)
		_spin = minf(_spin + delta * 2.6, 9.0)
		heli.rotation.y += _spin * delta
		heli.rotation.z = sin(_t * 3.0) * 0.25 * fall
	if _t < 19.5:
		heli.global_position = position
	for line in LINES:
		if _t >= line[0] and not _lines_done.has(line[0]):
			_lines_done[line[0]] = true
			_overlay.say(line[1], line[2], 2.6)
	if _t >= 11.2 and not heli.smoking:
		heli.smoking = true
		Sfx.play_at("engine_fail", heli.global_position, 4.0, 0.0, 400.0)
	# Camera: watching from the field, then chasing alongside, then watching it go down.
	if _t < 4.0:
		_camera.look_at(heli.global_position + Vector3(0, 1.5, 0))
	elif _t < 15.0:
		var chase := heli.global_position + Vector3(-14.0, 5.0, 10.0)
		_camera.global_position = _camera.global_position.lerp(chase, 1.0 - exp(-3.0 * delta))
		_camera.look_at(heli.global_position + Vector3(0, 1.5, 0))
	else:
		_camera.look_at(heli.global_position + Vector3(0, 1.5, 0))
	if _t >= 19.5 and not _lines_done.has("splash"):
		_lines_done["splash"] = true
		heli.visible = false
		_rotor_sound.stop()
		Sfx.play("big_splash", 4.0, 0.0)
		_overlay.fade_to(1.0, 0.8)
	if _t >= 21.0 and not _lines_done.has("dots"):
		_lines_done["dots"] = true
		_overlay.show_title("...", 1.2)
	if _t >= 23.0 and not _lines_done.has("later"):
		_lines_done["later"] = true
		_overlay.show_title("Hours later...", 1.6)
	if _t >= FLIGHT_TIME and not _lines_done.has("end"):
		_lines_done["end"] = true
		# The host moves everyone to the next island (a joined player just waits for it).
		if not (Network.is_online() and not Network.is_host()):
			Quests.report("flag", "boarded")
			Network.travel_to(NEXT_ISLAND)
