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
	# Stand NPCs on the ground, wherever the terrain's little bumps are.
	for child in get_children():
		if child is NPC:
			child.position.y = $Terrain.get_height(child.position.x, child.position.z) - 0.03
	if spawn_player:
		start_game()


## Puts the player, HUD and pause menu into the world. The main menu calls this
## when Play is pressed, so the world it already built is reused (no second load).
func start_game() -> void:
	if _started:
		return
	_started = true
	# Animals: rabbits, chickens, squirrels and a few deer. In a multiplayer game only
	# the host has them for now (sharing animals between players comes in a later stage).
	if not Network.is_online() or Network.is_host():
		var animals := AnimalSpawner.new()
		animals.name = "Animals"
		animals.terrain = $Terrain
		add_child(animals)
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
	hud.show_tip("Your Goal",
			"Your plane crashed on this island. Hunt animals, sell their loot to the merchant "
			+ "and earn money to unlock the next forest.\n\nPress [%s] to show or hide this tip." % Settings.get_binding_text("toggle_tip"), 25.0)
