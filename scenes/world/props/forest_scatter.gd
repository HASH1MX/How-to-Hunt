@tool
class_name ForestScatter
extends Node3D
## Places trees, rocks and grass across the terrain.
## Uses a fixed seed, so every player gets exactly the same forest.
## Models are drawn with MultiMesh (one draw for many copies) to keep the game fast.

@export var terrain: Terrain
@export var scatter_seed: int = 42
@export var pine_count: int = 320
@export var leafy_count: int = 110
@export var rock_count: int = 50
@export var grass_count: int = 30000
## Keep this area around the middle free of trees (the crash site).
@export var clearing_radius: float = 24.0
## Grass further away than this is hidden, to save performance.
@export var grass_view_distance: float = 70.0

const MODEL_VARIANTS := 3
const GRASS_CHUNK_SIZE := 25.0


func _ready() -> void:
	if terrain == null:
		push_warning("ForestScatter needs its 'terrain' set in the Inspector.")
		return
	generate()


func generate() -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	var tree_colliders := StaticBody3D.new()
	tree_colliders.name = "TreeColliders"
	add_child(tree_colliders)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 4.0

	_scatter_trees("Pines", PropLibrary.pine_tree, 100, pine_count, 0.97, rng, tree_colliders, trunk_shape)
	_scatter_trees("LeafyTrees", PropLibrary.leafy_tree, 200, leafy_count, 0.8, rng, tree_colliders, trunk_shape)
	_scatter_rocks(rng)
	_scatter_grass(rng)


func _scatter_trees(group_name: String, builder: Callable, seed_base: int, count: int,
		max_edge: float, rng: RandomNumberGenerator, colliders: StaticBody3D, trunk_shape: Shape3D) -> void:
	var transforms_per_variant: Array[Array] = []
	for v in MODEL_VARIANTS:
		transforms_per_variant.append([])

	for i in count:
		var spot := _random_spot(rng, clearing_radius, max_edge)
		if spot == Vector3.INF:
			continue
		var tree_scale := rng.randf_range(0.8, 1.25)
		var rot := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_scale)
		# Sink slightly so trees on slopes don't float.
		var xform := Transform3D(rot, spot - Vector3(0.0, 0.3, 0.0))
		transforms_per_variant[rng.randi() % MODEL_VARIANTS].append(xform)

		var collider := CollisionShape3D.new()
		collider.shape = trunk_shape
		collider.position = spot + Vector3(0.0, 2.0, 0.0)
		colliders.add_child(collider)

	for v in MODEL_VARIANTS:
		_add_multimesh("%s%d" % [group_name, v], builder.call(seed_base + v), transforms_per_variant[v], true)


func _scatter_rocks(rng: RandomNumberGenerator) -> void:
	var meshes: Array[ArrayMesh] = []
	var shapes: Array[Shape3D] = []
	var transforms_per_variant: Array[Array] = []
	for v in MODEL_VARIANTS:
		var mesh := PropLibrary.rock(300 + v)
		meshes.append(mesh)
		shapes.append(mesh.create_convex_shape())
		transforms_per_variant.append([])

	var rock_bodies := StaticBody3D.new()
	rock_bodies.name = "RockColliders"
	add_child(rock_bodies)

	for i in rock_count:
		var spot := _random_spot(rng, clearing_radius * 0.6, 0.9)
		if spot == Vector3.INF:
			continue
		var v := rng.randi() % MODEL_VARIANTS
		var xform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 1.8)), spot)
		transforms_per_variant[v].append(xform)
		var collider := CollisionShape3D.new()
		collider.shape = shapes[v]
		collider.transform = xform
		rock_bodies.add_child(collider)

	for v in MODEL_VARIANTS:
		_add_multimesh("Rocks%d" % v, meshes[v], transforms_per_variant[v], true)


func _scatter_grass(rng: RandomNumberGenerator) -> void:
	var patch_noise := FastNoiseLite.new()
	patch_noise.seed = scatter_seed
	patch_noise.frequency = 0.04
	var clump_meshes: Array[ArrayMesh] = []
	for v in MODEL_VARIANTS:
		clump_meshes.append(PropLibrary.grass_clump(400 + v))

	# Grass is split into square chunks so far-away chunks can be hidden.
	var chunks := {}
	var half := terrain.size * 0.5 * 0.95
	for i in grass_count:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if patch_noise.get_noise_2d(x, z) < -0.15:
			continue # Leave some open ground between grass patches.
		var key := Vector2i(floori(x / GRASS_CHUNK_SIZE), floori(z / GRASS_CHUNK_SIZE))
		if not chunks.has(key):
			chunks[key] = []
		var rot := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4))
		chunks[key].append(Transform3D(rot, Vector3(x, terrain.get_height(x, z) - 0.05, z)))

	var variant := 0
	for key in chunks:
		var instance := _add_multimesh("Grass_%d_%d" % [key.x, key.y], clump_meshes[variant % MODEL_VARIANTS], chunks[key], false)
		instance.visibility_range_end = grass_view_distance
		instance.visibility_range_end_margin = 10.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		variant += 1


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array, casts_shadow: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## A random point on the ground outside min_dist from the centre.
## max_edge: 1.0 = right up to the map edge.
func _random_spot(rng: RandomNumberGenerator, min_dist: float, max_edge: float) -> Vector3:
	var half := terrain.size * 0.5 * max_edge
	for attempt in 30:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() >= min_dist:
			return Vector3(x, terrain.get_height(x, z), z)
	return Vector3.INF
