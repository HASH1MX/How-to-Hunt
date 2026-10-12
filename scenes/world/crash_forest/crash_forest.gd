extends Node3D
## The Crash Forest: the first area of the game.
## Creates the player at the SpawnPoint when the level starts,
## tells it where the sea is, gives it a HUD and shows the first goal.
## The main menu also uses this scene as its background, with spawn_player off.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Off for the main menu background (just the world, no player or HUD).
@export var spawn_player: bool = true

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var water: Water = $Water


func _ready() -> void:
	# Stand NPCs on the ground, wherever the terrain's little bumps are.
	for child in get_children():
		if child is NPC:
			child.position.y = $Terrain.get_height(child.position.x, child.position.z) - 0.03
	if not spawn_player:
		return
	var player := PLAYER_SCENE.instantiate()
	# Set the position before adding, so the player remembers it as its respawn point.
	player.position = spawn_point.position
	player.rotation = spawn_point.rotation
	add_child(player)
	player.water_level = water.get_level()

	var hud := HUD.new()
	hud.player = player
	add_child(hud)
	hud.show_tip("Your Goal",
			"Your plane crashed on this island. Hunt animals, sell their loot to the merchant "
			+ "and earn money to unlock the next forest.\n\nPress [J] to show or hide this tip.", 25.0)
