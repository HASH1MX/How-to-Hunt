@tool
class_name LowPoly
## Helpers that turn simple shapes (boxes, spheres, cones) into faceted,
## slightly wobbly low-poly meshes with solid colors, like How to Fish.

static var _jitter_noise: FastNoiseLite
static var _solid_material: StandardMaterial3D
static var _double_sided_material: StandardMaterial3D


## Starts a new mesh. Add shapes to it, then call commit().
static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # Flat shading: every triangle gets its own facet.
	return st


## Adds a shape as flat-shaded triangles.
## jitter = how much the corners wobble (0 = perfectly clean shape).
## color_variation = how much each facet's brightness randomly differs.
static func add_shape(st: SurfaceTool, shape: PrimitiveMesh, xform: Transform3D, color: Color,
		jitter: float = 0.0, color_variation: float = 0.06, rng: RandomNumberGenerator = null) -> void:
	var arrays := shape.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var noise := _get_noise()
	for i in range(0, indices.size(), 3):
		var shade := 1.0
		if rng != null:
			shade += rng.randf_range(-color_variation, color_variation)
		st.set_color(Color(color.r * shade, color.g * shade, color.b * shade))
		for k in 3:
			var v := verts[indices[i + k]]
			if jitter > 0.0:
				# Based on the corner's position, so shared corners move together (no holes).
				var p := v * 2.7
				v += Vector3(
					noise.get_noise_3dv(p),
					noise.get_noise_3dv(p + Vector3(31.0, 0.0, 0.0)),
					noise.get_noise_3dv(p + Vector3(0.0, 0.0, 57.0))) * jitter
			st.add_vertex(xform * v)


## Finishes the mesh and gives it the shared low-poly material.
static func commit(st: SurfaceTool, double_sided: bool = false) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, get_material(double_sided))
	return mesh


static func get_material(double_sided: bool = false) -> StandardMaterial3D:
	if _solid_material == null:
		_solid_material = _make_material()
		_double_sided_material = _make_material()
		_double_sided_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _double_sided_material if double_sided else _solid_material


static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


static func _get_noise() -> FastNoiseLite:
	if _jitter_noise == null:
		_jitter_noise = FastNoiseLite.new()
		_jitter_noise.seed = 7
		_jitter_noise.frequency = 0.6
	return _jitter_noise
