extends Node3D
## The Crash Forest: the first area of the game. Easy, peaceful animals live here.
## Creates the player at the SpawnPoint when the level starts,
## tells it where the sea is, gives it a HUD and shows the first goal.
## The main menu also uses this scene as its background, with spawn_player off.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Off for the main menu background (just the world, no player or HUD).
@export var spawn_player: bool = true

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var water: Water = $Water

var _started := false


func _ready() -> void:
	# Let the graphics settings control this level's sky effects, shadows and grass distance.
	Settings.register_world($WorldEnvironment.environment, $Sun)
	# Wind, waves and birds (also behind the main menu).
	var ambience := AmbienceController.new()
	ambience.name = "Ambience"
	ambience.terrain = $Terrain
	add_child(ambience)
	# Stand NPCs on the ground, wherever the terrain's little bumps are.
	for child in get_children():
		if child is NPC:
			child.position.y = $Terrain.get_height(child.position.x, child.position.z) - 0.03
	if spawn_player:
		start_game()


## Sticks lie around under the trees (and more fall out when you punch a tree).
const STICK_COUNT := 45
## Where the radar parts are: [angle in degrees, distance from the middle]. Wires east,
## battery up the western mountains, antenna north-west (see GusStory).
const SCRAP_SPOTS := {
	&"wire_bundle": [35.0, 75.0],
	&"battery": [150.0, 120.0],
	&"antenna": [250.0, 100.0],
}
## Where the campfire is built, next to Gus.
const CAMPFIRE_AT := Vector2(-6.4, -0.3)
## The plane's radar (pulled out next to the seats) and the emergency case (by the cockpit).
const RADAR_AT := Vector3(-0.4, 0.0, -3.4)
const CASE_AT := Vector3(6.6, 0.0, -9.6)


func _scatter_sticks(world_sync: WorldSync) -> void:
	if Network.is_online() and not Network.is_host():
		return # The host's items are sent to us.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var stick := ItemLibrary.get_item(&"stick")
	var terrain: Terrain = $Terrain
	var placed := 0
	var tries := 0
	while placed < STICK_COUNT and tries < 600:
		tries += 1
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf_range(22.0 * 22.0, 135.0 * 135.0))
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		var height := terrain.get_height(x, z)
		if height < terrain.water_level + 1.5 or dist > terrain.mountain_radius * 0.92:
			continue
		var item := WorldSync.spawn_item(self, stick, Vector3(x, height + 0.4, z), Vector3.ZERO)
		if item != null:
			item.rotation.y = rng.randf() * TAU
		placed += 1


## Loose items aren't saved, so if the case was opened but the flare not fired yet, a flare
## gun waits in the case again.
func _replace_flare_gun(case: Node3D) -> void:
	if Network.is_online() and not Network.is_host():
		return
	if Quests.is_active("signal_for_help") and Quests.get_progress("signal_for_help", 0) > 0 and Quests.get_progress("signal_for_help", 1) == 0:
		WorldSync.spawn_item(self, ItemLibrary.get_item(&"flare_gun"), case.global_position + Vector3(0, 0.5, 0), Vector3.ZERO)


## The three radar parts, each with a beam of light, unless they were already handed over.
func _place_scrap() -> void:
	if Network.is_online() and not Network.is_host():
		return
	if Quests.is_done("scrap_hunt"):
		return
	var terrain: Terrain = $Terrain
	var objective_index := {&"wire_bundle": 0, &"battery": 1, &"antenna": 2}
	for id in SCRAP_SPOTS:
		if Quests.get_progress("scrap_hunt", objective_index[id]) > 0:
			continue
		var angle := deg_to_rad(SCRAP_SPOTS[id][0])
		var dist: float = SCRAP_SPOTS[id][1]
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		WorldSync.spawn_item(self, ItemLibrary.get_item(id), Vector3(x, terrain.get_height(x, z) + 0.5, z), Vector3.ZERO)


## The first-aid kit and cloth Gus asks for lie near the wreck until they've been handed over.
func _place_quest_items(world_sync: WorldSync) -> void:
	var items := get_node_or_null("QuestItems")
	if items == null:
		return
	if Network.is_online() and not Network.is_host():
		items.queue_free() # The host sends every item.
		return
	for child in items.get_children():
		var done := Quests.get_progress("patch_me_up", 0 if child.item_id == &"first_aid_kit" else 2) > 0 or Quests.is_done("patch_me_up")
		if done:
			child.queue_free()
		elif world_sync != null:
			world_sync.register_existing_item(child)


## Puts the player, HUD and pause menu into the world. The main menu calls this
## when Play is pressed, so the world it already built is reused (no second load).
func start_game() -> void:
	if _started:
		return
	_started = true
	# Animals: rabbits, chickens, squirrels and a few deer. In a multiplayer game only
	# the host has them for now (sharing animals between players comes in a later stage).
	var world_sync: WorldSync = null
	if Network.is_online():
		world_sync = WorldSync.new()
		world_sync.name = "WorldSync"
		world_sync.world = self
		world_sync.terrain = $Terrain
		add_child(world_sync)
		if Network.is_host():
			for item in $TestItems.get_children():
				world_sync.register_existing_item(item)
		else:
			$TestItems.queue_free() # The host sends every item, including these.
	if not Network.is_online() or Network.is_host():
		var animals := AnimalSpawner.new()
		animals.name = "Animals"
		animals.terrain = $Terrain
		animals.sync = world_sync
		add_child(animals)
	# Gus's campfire (lit by the quest "Light a Fire").
	var campfire := Campfire.new()
	campfire.name = "Campfire"
	add_child(campfire)
	campfire.position = Vector3(CAMPFIRE_AT.x, $Terrain.get_height(CAMPFIRE_AT.x, CAMPFIRE_AT.y), CAMPFIRE_AT.y)
	var radar := RadarConsole.new()
	radar.name = "Radar"
	add_child(radar)
	radar.position = Vector3(RADAR_AT.x, $Terrain.get_height(RADAR_AT.x, RADAR_AT.z) - 0.05, RADAR_AT.z)
	radar.rotation.y = 0.6
	var case := FlareCase.new()
	case.name = "EmergencyCase"
	add_child(case)
	case.position = Vector3(CASE_AT.x, $Terrain.get_height(CASE_AT.x, CASE_AT.z) - 0.04, CASE_AT.z)
	case.rotation = Vector3(0.0, 1.2, 0.08)
	# The story's quests (a joined player gets them from the host).
	WorldSync.reset_shaken()
	Quests.begin_session()
	_place_quest_items(world_sync)
	_scatter_sticks(world_sync)
	_place_scrap()
	_replace_flare_gun(case)
	var player := PLAYER_SCENE.instantiate()
	player.name = "LocalPlayer"
	# Set the position before adding, so the player remembers it as its respawn point.
	player.position = spawn_point.position
	if Network.is_online():
		# Don't all appear in exactly the same spot.
		var angle := randf() * TAU
		player.position += Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.5, 3.5)
	player.rotation = spawn_point.rotation
	add_child(player)
	player.water_level = water.get_level()
	# Bring back this player's saved progress (a joined player's comes from the host).
	var is_guest := Network.is_online() and not Network.is_host()
	player.load_save_data(Network.my_saved_data if is_guest else SaveManager.get_player_data(SaveManager.HOST_KEY))
	SaveManager.begin_session(player)
	var player_audio := PlayerAudio.new()
	player_audio.name = "PlayerAudio"
	player_audio.player = player
	player_audio.terrain = $Terrain
	player.add_child(player_audio)

	var hud := HUD.new()
	hud.player = player
	add_child(hud)
	if Network.is_online():
		var sync := PlayerNetSync.new()
		sync.name = "NetSync"
		sync.player = player
		player.add_child(sync)
		add_child(NetNotice.new())
		Network.world_ready(self)
	var pause_menu := PauseMenu.new()
	pause_menu.player = player
	add_child(pause_menu)
