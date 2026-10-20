class_name IslandWorld
extends Node3D
## What every island level has in common. An island scene (Crash Forest, the Jungle...)
## extends this and fills in its own story things in the hooks below.
##
## start_game() puts the local player, HUD and pause menu into the world, shares the world
## in multiplayer (WorldSync), spawns animals (host only), starts the quests, and calls
## the island's hooks. The main menu shows Crash Forest as its background with
## spawn_player off, and calls start_game() when Play is pressed.
##
## Travelling to another island (the helicopter crash) swaps the whole world scene for the
## next one: IslandWorld.travel_to() (every player does it at the same time in multiplayer).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## Every island, by id. The world file remembers which one the players are on.
const ISLAND_SCENES := {
	"crash_forest": "res://scenes/world/crash_forest/crash_forest.tscn",
	"jungle": "res://scenes/world/jungle/jungle.tscn",
}
const FIRST_ISLAND := "crash_forest"

## Off for the main menu background (just the world, no player or HUD).
@export var spawn_player: bool = true
## This island's id (a key of ISLAND_SCENES).
@export var island_id := FIRST_ISLAND

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var water: Water = $Water
@onready var terrain: Terrain = $Terrain

var player: Node
var hud: HUD
var world_sync: WorldSync
var _started := false


func _ready() -> void:
	add_to_group("island_world")
	# Let the graphics settings control this level's sky effects, shadows and grass distance.
	Settings.register_world($WorldEnvironment.environment, $Sun)
	# Wind, waves and birds (also behind the main menu).
	var ambience := AmbienceController.new()
	ambience.name = "Ambience"
	ambience.terrain = terrain
	add_child(ambience)
	# Stand NPCs on the ground, wherever the terrain's little bumps are.
	for child in get_children():
		if child is NPC:
			child.position.y = terrain.get_height(child.position.x, child.position.z) - 0.03
	_island_ready()
	if spawn_player:
		start_game()


## Puts the player, HUD and pause menu into the world.
func start_game() -> void:
	if _started:
		return
	_started = true
	if Network.is_online():
		world_sync = WorldSync.new()
		world_sync.name = "WorldSync"
		world_sync.world = self
		world_sync.terrain = terrain
		add_child(world_sync)
		var test_items := get_node_or_null("TestItems")
		if test_items != null:
			if Network.is_host():
				for item in test_items.get_children():
					world_sync.register_existing_item(item)
			else:
				test_items.queue_free() # The host sends every item, including these.
	if not Network.is_online() or Network.is_host():
		var animals := _make_animal_spawner()
		animals.name = "Animals"
		animals.terrain = terrain
		animals.sync = world_sync
		add_child(animals)
	_place_story_props()
	# The story's quests (a joined player gets them from the host).
	WorldSync.reset_shaken()
	Quests.begin_session()
	_place_story_items()
	_spawn_local_player()
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
	_game_started()


func _spawn_local_player() -> void:
	player = PLAYER_SCENE.instantiate()
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
	player.island_id = island_id
	# Bring back this player's saved progress (a joined player's comes from the host).
	var is_guest := Network.is_online() and not Network.is_host()
	player.load_save_data(Network.my_saved_data if is_guest else SaveManager.get_player_data(SaveManager.HOST_KEY))
	SaveManager.begin_session(player)
	var player_audio := PlayerAudio.new()
	player_audio.name = "PlayerAudio"
	player_audio.player = player
	player_audio.terrain = terrain
	player.add_child(player_audio)
	hud = HUD.new()
	hud.player = player
	add_child(hud)


# --- Hooks for each island ------------------------------------------------------------------

## Called in _ready (also behind the main menu).
func _island_ready() -> void:
	pass


## The animals that live here (only the host / a solo player has a spawner).
func _make_animal_spawner() -> AnimalSpawner:
	return AnimalSpawner.new()


## Props that follow the story (campfire, radar...), before the quests load.
func _place_story_props() -> void:
	pass


## Story items and the like, after the quests have loaded.
func _place_story_items() -> void:
	pass


## The local player, HUD and pause menu exist.
func _game_started() -> void:
	pass


# --- Travelling between islands ---------------------------------------------------------------

## Swaps the current island for another one (and drops this computer's player there).
## In multiplayer the host calls Network.travel_to(), which does this on every computer.
static func travel_to(tree: SceneTree, new_island: String) -> void:
	var current := tree.get_first_node_in_group("island_world") as IslandWorld
	if current == null or not ISLAND_SCENES.has(new_island):
		return
	var parent := current.get_parent()
	SaveManager.end_session()
	if not (Network.is_online() and not Network.is_host()) and SaveManager.has_world():
		SaveManager.data["world"]["island"] = new_island
		SaveManager.save_world_file()
	Network.forget_world()
	current.name = "OldWorld"
	current.queue_free()
	var next: IslandWorld = load(ISLAND_SCENES[new_island]).instantiate()
	next.spawn_player = true
	next.name = "World"
	parent.add_child(next)


## The island the current save (or the host) is on.
static func current_island() -> String:
	if Network.is_online() and not Network.is_host():
		return Network.host_island
	return str(SaveManager.data.get("world", {}).get("island", FIRST_ISLAND))
