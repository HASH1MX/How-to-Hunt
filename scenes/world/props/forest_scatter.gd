@tool
class_name ForestScatter
extends Node3D
## Places trees, bushes, rocks, logs, flowers, mushrooms and grass across the terrain.
## Uses a fixed seed, so every player gets exactly the same forest.
## Models are drawn with MultiMesh (one draw for many copies) to keep the game fast,
## and small things are split into chunks that hide when far away.

@export var terrain: Terrain
@export var scatter_seed: int = 42
## Keep this area around the middle free of trees (the crash site).
@export var clearing_radius: float = 24.0
## No grass or small props within no_grass_radius of this node (e.g. the crashed plane).
@export var no_grass_center: Node3D
@export var no_grass_radius: float = 11.0

@export_group("Amounts")
@export var pine_count: int = 1300
@export var leafy_count: int = 350
@export var birch_count: int = 200
@export var bush_count: int = 800
@export var rock_count: int = 350
@export var log_count: int = 90
@export var stump_count: int = 100
@export var flower_count: int = 1750
@export var mushroom_count: int = 500
@export var pebble_count: int = 1000
@export var grass_count: int = 100000

const MODEL_VARIANTS := 4
## Where Gus's campfire is (no grass or small props around it); keep in step with CrashForest.CAMPFIRE_AT.
const CAMPFIRE_SPOT := Vector2(-6.4, -0.3)
const CHUNK_SIZE := 25.0
const GRASS_VIEW_DISTANCE := 70.0
const SMALL_PROP_VIEW_DISTANCE := 50.0

var _patch_noise := FastNoiseLite.new()
var _trunk_shape := CylinderShape3D.new()


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
	_patch_noise.seed = scatter_seed
	_patch_noise.frequency = 0.04
	_trunk_shape.radius = 0.35
	_trunk_shape.height = 4.0

	# Each line: name, model builder, seed, how many, and settings (see _scatter).
	_scatter("Pines", PropLibrary.pine_tree, 100, pine_count, rng,
			{min_dist = clearing_radius, max_edge = 0.95, scale = Vector2(0.8, 1.25), collision = "trunk", tint = 0.1, sink = 0.3})
	_scatter("LeafyTrees", PropLibrary.leafy_tree, 200, leafy_count, rng,
			{min_dist = clearing_radius, max_edge = 0.68, scale = Vector2(0.8, 1.2), collision = "trunk", tint = 0.12, sink = 0.3})
	_scatter("Birches", PropLibrary.birch_tree, 250, birch_count, rng,
			{min_dist = clearing_radius, max_edge = 0.68, scale = Vector2(0.8, 1.15), collision = "trunk", tint = 0.08, sink = 0.3})
	_scatter("Rocks", PropLibrary.rock, 300, rock_count, rng,
			{min_dist = clearing_radius * 0.6, max_edge = 1.0, scale = Vector2(0.5, 1.8), collision = "convex", keep_off_crash_site = true})
	_scatter("Logs", PropLibrary.fallen_log, 350, log_count, rng,
			{min_dist = clearing_radius * 0.8, max_edge = 0.85, collision = "convex", keep_off_crash_site = true, sink = 0.05})
	_scatter("Stumps", PropLibrary.stump, 380, stump_count, rng,
			{min_dist = clearing_radius * 0.7, max_edge = 0.85, scale = Vector2(0.8, 1.3), collision = "convex", keep_off_crash_site = true})
	_scatter("Bushes", PropLibrary.bush, 420, bush_count, rng,
			{min_dist = clearing_radius * 0.5, max_edge = 0.9, scale = Vector2(0.7, 1.4), tint = 0.12, keep_off_crash_site = true, view_distance = GRASS_VIEW_DISTANCE})
	_scatter("Flowers", PropLibrary.flowers, 460, flower_count, rng,
			{max_edge = 0.85, keep_off_crash_site = true, patchy = true, shadow = false, view_distance = SMALL_PROP_VIEW_DISTANCE})
	_scatter("Mushrooms", PropLibrary.mushrooms, 500, mushroom_count, rng,
			{min_dist = clearing_radius * 0.7, max_edge = 0.85, scale = Vector2(0.8, 1.6), keep_off_crash_site = true, shadow = false, view_distance = SMALL_PROP_VIEW_DISTANCE})
	_scatter("Pebbles", PropLibrary.pebbles, 540, pebble_count, rng,
			{max_edge = 0.9, keep_off_crash_site = true, shadow = false, view_distance = SMALL_PROP_VIEW_DISTANCE})
	_scatter("Grass", PropLibrary.grass_clump, 400, grass_count, rng,
			{max_edge = 0.95, scale = Vector2(0.7, 1.4), tint = 0.15, keep_off_crash_site = true, patchy = true, shadow = false, view_distance = GRASS_VIEW_DISTANCE, sink = 0.05})


## Places `count` copies of a model made by `builder`. Settings (all optional):
##   min_dist             - stay at least this far from the map centre
##   max_edge             - how close to the map edge (1.0 = right up to it)
##   scale                - random size range, Vector2(min, max)
##   collision            - "none", "trunk" (tree trunk cylinder) or "convex" (matches the model)
##   tint                 - random color variation between copies (0 = all identical)
##   keep_off_crash_site  - skip the area around no_grass_center
##   patchy               - only place inside natural patches (like grass meadows)
##   shadow               - whether copies cast shadows
##   view_distance        - hide copies further away than this (0 = always visible)
##   sink                 - push down into the ground a little so nothing floats on slopes
func _scatter(group: String, builder: Callable, seed_base: int, count: int, rng: RandomNumberGenerator, settings: Dictionary) -> void:
	var min_dist: float = settings.get("min_dist", 0.0)
	var max_edge: float = settings.get("max_edge", 0.9)
	var scale_range: Vector2 = settings.get("scale", Vector2.ONE)
	var collision: String = settings.get("collision", "none")
	var tint: float = settings.get("tint", 0.06)
	var keep_off: bool = settings.get("keep_off_crash_site", false)
	var patchy: bool = settings.get("patchy", false)
	var shadow: bool = settings.get("shadow", true)
	var view_distance: float = settings.get("view_distance", 0.0)
	var sink: float = settings.get("sink", 0.0)

	var meshes: Array[Mesh] = []
	var shapes: Array[Shape3D] = []
	for v in MODEL_VARIANTS:
		var mesh: Mesh = builder.call(seed_base + v)
		meshes.append(mesh)
		shapes.append(mesh.create_convex_shape() if collision == "convex" else null)

	var body: StaticBody3D = null
	if collision != "none":
		body = StaticBody3D.new()
		body.name = group + "Colliders"
		if collision == "trunk":
			body.add_to_group("trees") # Punching a tree can shake a stick loose (see WorldSync.shake_tree).
		add_child(body)

	# batches[Vector3i(variant, chunk_x, chunk_z)] = [transforms, colors]
	var batches := {}
	for i in count:
		var spot := _random_spot(rng, min_dist, max_edge)
		if spot == Vector3.INF:
			continue
		if keep_off and _is_cleared(spot.x, spot.z):
			continue
		if patchy and _patch_noise.get_noise_2d(spot.x, spot.z) < -0.15:
			continue
		var size := rng.randf_range(scale_range.x, scale_range.y)
		var rot := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
		var xform := Transform3D(rot, spot - Vector3(0.0, sink * size, 0.0))
		var variant := rng.randi() % MODEL_VARIANTS
		# Slightly darker / more yellow / more blue copies so they don't all look the same.
		var shade := 1.0 - rng.randf() * tint
		var color := Color(shade * (1.0 - rng.randf() * tint * 0.5), shade, shade * (1.0 - rng.randf() * tint * 0.5))

		var chunk := Vector2i.ZERO
		if view_distance > 0.0:
			chunk = Vector2i(floori(spot.x / CHUNK_SIZE), floori(spot.z / CHUNK_SIZE))
		var key := Vector3i(variant, chunk.x, chunk.y)
		if not batches.has(key):
			batches[key] = [[], []]
		batches[key][0].append(xform)
		batches[key][1].append(color)

		if collision == "trunk":
			var collider := CollisionShape3D.new()
			collider.shape = _trunk_shape
			collider.position = spot + Vector3(0.0, 2.0, 0.0)
			body.add_child(collider)
		elif collision == "convex":
			var collider := CollisionShape3D.new()
			collider.shape = shapes[variant]
			collider.transform = xform
			body.add_child(collider)

	for key in batches:
		var instance := _add_multimesh("%s_%d_%d_%d" % [group, key.x, key.y, key.z], meshes[key.x], batches[key][0], batches[key][1], shadow)
		if view_distance > 0.0:
			# The "Grass & detail distance" setting scales this (see Settings).
			instance.add_to_group("detail_props")
			instance.set_meta("base_view_distance", view_distance)
			instance.visibility_range_end = view_distance
			instance.visibility_range_end_margin = 10.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array, colors: Array, casts_shadow: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## A random point on dry land, at least min_dist from the centre.
## max_edge: how far out to go, 1.0 = all the way to the beach.
## Never returns a spot on the beach or under water.
func _random_spot(rng: RandomNumberGenerator, min_dist: float, max_edge: float) -> Vector3:
	var max_dist := terrain.get_land_radius() * max_edge
	for attempt in 30:
		var x := rng.randf_range(-max_dist, max_dist)
		var z := rng.randf_range(-max_dist, max_dist)
		var dist := Vector2(x, z).length()
		if dist < min_dist or dist > max_dist:
			continue
		var height := terrain.get_height(x, z)
		# Nothing on the beach or under water.
		var beach_height := 1.0 if dist > terrain.mountain_radius else 0.3
		if height < terrain.water_level + beach_height:
			continue
		return Vector3(x, height, z)
	return Vector3.INF


## True if this spot is inside the area kept clear around the crash site.
func _is_cleared(x: float, z: float) -> bool:
	# Gus's campfire needs a bare patch around it too.
	if Vector2(x - CAMPFIRE_SPOT.x, z - CAMPFIRE_SPOT.y).length() < 3.4:
		return true
	if no_grass_center == null:
		return false
	var c := no_grass_center.position
	return Vector2(x - c.x, z - c.z).length() < no_grass_radius
