extends Node3D
## The Crash Forest: the first area of the game.
## Creates the player at the SpawnPoint when the level starts.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	# Set the position before adding, so the player remembers it as its respawn point.
	player.position = spawn_point.position
	player.rotation = spawn_point.rotation
	add_child(player)
