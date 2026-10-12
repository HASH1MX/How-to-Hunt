@tool
class_name Terrain
extends StaticBody3D
## Builds a low-poly island from noise, with collision:
##   middle   - forest with gentle hills and a flat clearing (crash site)
##   ring     - climbable mountains around the forest
##   outside  - a beach that slopes down under the sea
## The same noise_seed always makes the same island, so every player
## in multiplayer will get an identical world.

@export var size: float = 320.0
## How many squares along each side. More = smoother hills but slower.
@export var resolution: int = 160
@export var noise_seed: int = 1234
## Height of the sea surface. The Water node uses this too.
@export var water_level: float = -0.6

@export_group("Forest")
@export var max_height: float = 5.0
## Flat clearing in the middle where the plane crashed and players spawn.
@export var flat_radius: float = 22.0

@export_group("Mountains")
## Distance from the middle to the top of the mountain ring.
@export var mountain_radius: float = 96.0
## How wide the mountains are. Wider = gentler slopes, easier to climb.
@export var mountain_width: float = 36.0
@export var mountain_height: float = 20.0

@export_group("Coast")
## Distance from the middle where the beach meets the sea.
@export var coast_radius: float = 134.0
@export var sea_depth: float = 8.0

@export_group("Colors")
@export var grass_color_a: Color = Color(0.36, 0.52, 0.21)
@export var grass_color_b: Color = Color(0.27, 0.43, 0.17)
@export var rock_color: Color = Color(0.48, 0.47, 0.44)
@export var sand_color: Color = Color(0.86, 0.78, 0.56)
@export var wet_sand_color: Color = Color(0.62, 0.55, 0.4)

var _noise := FastNoiseLite.new()
var _color_noise := FastNoiseLite.new()
var _shape_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _sea_floor: CollisionShape3D


func _ready() -> void:
	generate()


## Height of the ground at a world X/Z position. Use this to place
## trees, rocks and spawn points on the ground.
func get_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	# Noise makes the mountain ring and coastline wobbly instead of perfect circles.
	var wobbly_dist := dist + _shape_noise.get_noise_2d(x, z) * 14.0

	# Forest hills, flat in the clearing. Hills only go up (0 to max_height),
	# so the forest never dips below sea level and fills with water.
	var outside_clearing := smoothstep(flat_radius, flat_radius * 1.8, dist)
	var height := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * max_height * outside_clearing

	# Mountain ring: a smooth bump, made rugged by extra noise.
	var t := (wobbly_dist - mountain_radius) / mountain_width
	if absf(t) < 1.0:
		var bump := pow(1.0 - t * t, 2.0)
		var ruggedness := 0.85 + 0.3 * (_ridge_noise.get_noise_2d(x, z) * 0.5 + 0.5)
		# Fade out the forest hills on the mountain so the two slopes don't add up
		# into a wall too steep to climb.
		height *= 1.0 - bump * 0.8
		height += bump * mountain_height * ruggedness

	# Past the coast the ground slopes down under the sea.
	height -= smoothstep(coast_radius - 6.0, coast_radius + 22.0, wobbly_dist) * (sea_depth + max_height)

	# Small bumps everywhere so even the clearing isn't perfectly flat.
	height += _color_noise.get_noise_2d(x * 3.0, z * 3.0) * 0.25
	return height


## Roughly how far from the middle there is dry land.
func get_land_radius() -> float:
	return coast_radius


func generate() -> void:
	_noise.seed = noise_seed
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	_color_noise.seed = noise_seed + 1
	_color_noise.frequency = 0.05
	_shape_noise.seed = noise_seed + 2
	_shape_noise.frequency = 0.01
	_ridge_noise.seed = noise_seed + 3
	_ridge_noise.frequency = 0.03
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # Flat shading gives the faceted low-poly look.

	var step := size / resolution
	var half := size * 0.5
	for zi in resolution:
		for xi in resolution:
			var x0 := -half + xi * step
			var z0 := -half + zi * step
			var p00 := _point(x0, z0)
			var p10 := _point(x0 + step, z0)
			var p01 := _point(x0, z0 + step)
			var p11 := _point(x0 + step, z0 + step)
			_add_triangle(st, p00, p10, p01)
			_add_triangle(st, p10, p11, p01)

	st.generate_normals()
	var mesh := st.commit()

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true # Colors above are picked as normal screen colors.
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.surface_set_material(0, material)

	# The nodes are created in code (no owner), so they are never saved
	# into the scene file. The terrain is rebuilt every time it loads.
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
		_collision_shape = CollisionShape3D.new()
		add_child(_collision_shape)
	_mesh_instance.mesh = mesh
	_collision_shape.shape = mesh.create_trimesh_shape()

	# An endless flat sea floor under the whole ocean, so nothing can sink
	# forever past the edge of the terrain.
	if _sea_floor == null:
		_sea_floor = CollisionShape3D.new()
		_sea_floor.shape = WorldBoundaryShape3D.new()
		add_child(_sea_floor)
	_sea_floor.position.y = -(sea_depth + max_height) - 1.0


func _point(x: float, z: float) -> Vector3:
	return Vector3(x, get_height(x, z), z)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var center := (a + b + c) / 3.0
	var normal := (b - a).cross(c - a).normalized()
	var steepness := 1.0 - absf(normal.y) # 0 = flat, 1 = vertical wall

	var color := grass_color_a.lerp(grass_color_b, _color_noise.get_noise_2d(center.x, center.z) * 0.5 + 0.5)
	if center.y < water_level + 0.9 and Vector2(center.x, center.z).length() > mountain_radius:
		# Beach: dry sand above the water, darker wet sand below it.
		color = sand_color if center.y > water_level else wet_sand_color
	elif steepness > 0.28 or center.y > mountain_height * 0.75:
		# Steep slopes and high peaks are bare rock.
		color = rock_color.lerp(rock_color * 0.85, _color_noise.get_noise_2d(center.x * 2.0, center.z * 2.0) * 0.5 + 0.5)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
