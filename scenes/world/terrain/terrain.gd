@tool
class_name Terrain
extends StaticBody3D
## Builds a low-poly hilly ground from noise, with collision.
## The same noise_seed always makes the same terrain, so every player
## in multiplayer will get an identical world.

@export var size: float = 200.0
## How many squares along each side. More = smoother hills but slower.
@export var resolution: int = 100
@export var max_height: float = 5.0
@export var noise_seed: int = 1234
## Flat clearing in the middle where the plane crashed and players spawn.
@export var flat_radius: float = 22.0
## Tall hills around the edges that keep players inside the map.
@export var border_height: float = 28.0

@export_group("Colors")
@export var grass_color_a: Color = Color(0.36, 0.52, 0.21)
@export var grass_color_b: Color = Color(0.27, 0.43, 0.17)
@export var hill_color: Color = Color(0.4, 0.47, 0.25)

var _noise := FastNoiseLite.new()
var _color_noise := FastNoiseLite.new()
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D


func _ready() -> void:
	generate()


## Height of the ground at a world X/Z position. Use this to place
## trees, rocks and spawn points on the ground.
func get_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var outside_clearing := smoothstep(flat_radius, flat_radius * 1.8, dist)
	var height := _noise.get_noise_2d(x, z) * max_height * outside_clearing
	# Small bumps everywhere so even the clearing isn't perfectly flat.
	height += _color_noise.get_noise_2d(x * 3.0, z * 3.0) * 0.25
	var edge := maxf(absf(x), absf(z)) / (size * 0.5)
	height += pow(smoothstep(0.7, 1.0, edge), 2.0) * border_height
	return height


func generate() -> void:
	_noise.seed = noise_seed
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	_color_noise.seed = noise_seed + 1
	_color_noise.frequency = 0.05

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


func _point(x: float, z: float) -> Vector3:
	return Vector3(x, get_height(x, z), z)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var center := (a + b + c) / 3.0
	var color := grass_color_a.lerp(grass_color_b, _color_noise.get_noise_2d(center.x, center.z) * 0.5 + 0.5)
	color = color.lerp(hill_color, clampf(center.y / border_height, 0.0, 1.0))
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
