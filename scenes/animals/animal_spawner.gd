class_name AnimalSpawner
extends Node3D
## Keeps the island populated: spawns animals on dry land when the level starts,
## and sends a new one somewhere else (away from players) a while after one dies.
## The first island has mostly small, easy animals and only a few deer.

## How many of each animal live on the island at once.
@export var rabbits := 30
@export var chickens := 22
@export var squirrels := 18
@export var deer := 9
## Seconds before a hunted animal is replaced.
@export var respawn_delay := 60.0
## Animals live between these distances from the middle of the island
## (inside the mountains, but not right on top of the crash site).
@export var min_distance := 16.0
@export var max_distance := 131.0
## New animals never appear closer than this to a player.
@export var min_distance_from_players := 25.0

var terrain: Terrain
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var counts := {Rabbit: rabbits, Chicken: chickens, Squirrel: squirrels, Deer: deer}
	for species in counts:
		for i in counts[species]:
			_spawn(species)


func _spawn(species: GDScript) -> void:
	# Deer keep to the outer forest; small animals can be anywhere.
	var near := min_distance * (2.5 if species == Deer else 1.0)
	var spot := _find_spot(near, max_distance)
	if spot == Vector3.INF:
		return
	var animal: Animal = species.new()
	animal.terrain = terrain
	animal.roam_radius = max_distance
	add_child(animal)
	animal.global_position = spot + Vector3(0.0, 0.3, 0.0)
	animal.died.connect(_on_animal_died.bind(species))


func _on_animal_died(_animal: Animal, species: GDScript) -> void:
	get_tree().create_timer(respawn_delay).timeout.connect(_spawn.bind(species))


## A random spot on dry land, between the two distances, away from players.
func _find_spot(near: float, far: float) -> Vector3:
	for attempt in 40:
		var angle := _rng.randf() * TAU
		var distance := sqrt(_rng.randf_range(near * near, far * far)) # Even spread, not bunched in the middle.
		var x := cos(angle) * distance
		var z := sin(angle) * distance
		var height := terrain.get_height(x, z)
		if height < terrain.water_level + 1.0:
			continue
		var spot := Vector3(x, height, z)
		var too_close := false
		for player in get_tree().get_nodes_in_group("players"):
			if player.global_position.distance_to(spot) < min_distance_from_players:
				too_close = true
		if not too_close:
			return spot
	return Vector3.INF
