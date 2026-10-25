@tool
class_name Terrain
extends StaticBody3D
## Builds a low-poly island from noise, with collision:
##   middle   - forest with gentle hills and a flat clearing (crash site)
##   ring     - climbable mountains around the forest
##   outside  - a beach that slopes down under the sea
## The same noise_seed always makes the same island, so every player
## in multiplayer will get an identical world.

@export var size: float = 540.0
## How many squares along each side. More = smoother hills but slower.
@export var resolution: int = 240
@export var noise_seed: int = 1234
## Height of the sea surface. The Water node uses this too.
@export var water_level: float = -0.6

@export_group("Forest")
@export var max_height: float = 5.0
## Flat clearing in the middle where the plane crashed and players spawn.
@export var flat_radius: float = 26.0

@export_group("Mountains")
## Distance from the middle to the top of the mountain ring.
@export var mountain_radius: float = 154.0
## How wide the mountains are. Wider = gentler slopes, easier to climb.
@export var mountain_width: float = 56.0
@export var mountain_height: float = 26.0

@export_group("Coast")
## Distance from the middle where the beach meets the sea.
@export var coast_radius: float = 214.0
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
## Ground steeper than this (height change per metre) is bare rock; a little less steep
## is mossy rock. Grass, flowers and trees only grow below GRASS_SLOPE.
const ROCK_SLOPE := 0.95
const GRASS_SLOPE := 0.75
## Heights of every grid corner, exactly as the ground mesh is built (see get_height).
var _grid := PackedFloat32Array()
var _rock := PackedFloat32Array()
var _corners := 0
var _step := 1.0
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _sea_floor: CollisionShape3D


func _ready() -> void:
	generate()


## Height of the ground at a world X/Z position, exactly on the faceted ground you see and
## walk on (the same triangles as the mesh). Use this to place trees, rocks and spawn
## points, so nothing floats above or sinks into a slope.
func get_height(x: float, z: float) -> float:
	if _grid.is_empty():
		return _shape_height(x, z)
	var half := size * 0.5
	var gx := (x + half) / _step
	var gz := (z + half) / _step
	var xi := floori(gx)
	var zi := floori(gz)
	if xi < 0 or zi < 0 or xi >= resolution or zi >= resolution:
		return _shape_height(x, z)
	var fx := gx - xi
	var fz := gz - zi
	var h00 := _grid[zi * _corners + xi]
	var h10 := _grid[zi * _corners + xi + 1]
	var h01 := _grid[(zi + 1) * _corners + xi]
	var h11 := _grid[(zi + 1) * _corners + xi + 1]
	# Each square is two triangles: (00, 10, 01) and (10, 11, 01).
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


## How "rocky" the ground is here: 0 = grass, 1 = bare rock (steep slopes and peaks).
## Worked out once per grid corner when the island is built, from the slope over a few
## metres, so single triangles don't flip between grass and rock.
func get_rockiness(x: float, z: float) -> float:
	if _rock.is_empty():
		return 0.0
	var half := size * 0.5
	var gx := clampf((x + half) / _step, 0.0, resolution - 0.001)
	var gz := clampf((z + half) / _step, 0.0, resolution - 0.001)
	var xi := floori(gx)
	var zi := floori(gz)
	var fx := gx - xi
	var fz := gz - zi
	var top := lerpf(_rock[zi * _corners + xi], _rock[zi * _corners + xi + 1], fx)
	var bottom := lerpf(_rock[(zi + 1) * _corners + xi], _rock[(zi + 1) * _corners + xi + 1], fx)
	return lerpf(top, bottom, fz)


func _corner_rockiness(xi: int, zi: int) -> float:
	var left := _grid[zi * _corners + maxi(xi - 1, 0)]
	var right := _grid[zi * _corners + mini(xi + 1, _corners - 1)]
	var up := _grid[maxi(zi - 1, 0) * _corners + xi]
	var down := _grid[mini(zi + 1, _corners - 1) * _corners + xi]
	var slope := Vector2(right - left, down - up).length() / (2.0 * _step)
	var by_slope := smoothstep(GRASS_SLOPE, ROCK_SLOPE, slope)
	var by_height := smoothstep(mountain_height * 0.68, mountain_height * 0.8, _grid[zi * _corners + xi])
	return maxf(by_slope, by_height)


## The smooth shape of the island before it is cut into triangles.
func _shape_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	# Noise makes the mountain ring and coastline wobbly instead of perfect circles.
	var wobbly_dist := dist + _shape_noise.get_noise_2d(x, z) * 22.0

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


## What the ground is made of at a world position: "grass", "sand" or "rock".
## Used to pick footstep sounds.
## Also used to keep grass and trees off bare rock and sand (see ForestScatter).
func get_surface_at(x: float, z: float) -> String:
	if _is_beach(get_height(x, z), x, z):
		return "sand"
	return "rock" if get_rockiness(x, z) > 0.5 else "grass"


func _is_beach(height: float, x: float, z: float) -> bool:
	return height < water_level + 0.9 and Vector2(x, z).length() > mountain_radius


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
	# Work out each grid corner's height once (every corner is shared by 4 squares).
	var corners := resolution + 1
	var points := PackedVector3Array()
	points.resize(corners * corners)
	_grid = PackedFloat32Array()
	for zi in corners:
		for xi in corners:
			var x := -half + xi * step
			var z := -half + zi * step
			points[zi * corners + xi] = Vector3(x, _shape_height(x, z), z)
	_grid.resize(corners * corners)
	for i in points.size():
		_grid[i] = points[i].y
	_corners = corners
	_step = step
	_rock = PackedFloat32Array()
	_rock.resize(corners * corners)
	for zi in corners:
		for xi in corners:
			_rock[zi * corners + xi] = _corner_rockiness(xi, zi)
	for zi in resolution:
		for xi in resolution:
			var p00 := points[zi * corners + xi]
			var p10 := points[zi * corners + xi + 1]
			var p01 := points[(zi + 1) * corners + xi]
			var p11 := points[(zi + 1) * corners + xi + 1]
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
	if _is_beach(center.y, center.x, center.z):
		# Beach: dry sand above the water, darker wet sand below it.
		color = sand_color if center.y > water_level else wet_sand_color
	else:
		# Steep slopes and high peaks are rock, with a mossy mix where grass meets rock.
		# Worked out from the smoothed slope, so the edge is a soft band, not a checkerboard.
		var rock := rock_color.lerp(rock_color * 0.85, _color_noise.get_noise_2d(center.x * 2.0, center.z * 2.0) * 0.5 + 0.5)
		var rockiness := get_rockiness(center.x, center.z)
		if steepness > 0.45:
			rockiness = 1.0 # Cliffs are always bare.
		color = color.lerp(rock, rockiness)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
