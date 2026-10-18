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
## alt_color / alt_chance = paint some facets in a second color (like marks on birch bark).
static func add_shape(st: SurfaceTool, shape: PrimitiveMesh, xform: Transform3D, color: Color,
		jitter: float = 0.0, color_variation: float = 0.06, rng: RandomNumberGenerator = null,
		alt_color: Color = Color.BLACK, alt_chance: float = 0.0) -> void:
	var arrays := shape.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var noise := _get_noise()
	var use_alt := false
	for i in range(0, indices.size(), 3):
		var shade := 1.0
		if rng != null:
			shade += rng.randf_range(-color_variation, color_variation)
			# Triangles come in pairs (squares), so decide once per pair.
			if alt_chance > 0.0 and i % 6 == 0:
				use_alt = rng.randf() < alt_chance
		var face_color := alt_color if use_alt else color
		st.set_color(Color(face_color.r * shade, face_color.g * shade, face_color.b * shade))
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


## Adds a shape with soft, rounded shading (characters and animals): uses the shape's
## own smooth normals, so spheres and capsules look round instead of faceted
## while boxes keep their crisp edges. No wobble. Finish with commit_smooth().
static func add_smooth_shape(st: SurfaceTool, shape: PrimitiveMesh, xform: Transform3D, color: Color,
		shade_variation: float = 0.0, rng: RandomNumberGenerator = null) -> void:
	var arrays := shape.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var normal_basis := xform.basis.inverse().transposed()
	var shade := 1.0
	if rng != null and shade_variation > 0.0:
		shade += rng.randf_range(-shade_variation, shade_variation)
	st.set_color(Color(color.r * shade, color.g * shade, color.b * shade))
	for i in indices.size():
		var index := indices[i]
		st.set_normal((normal_basis * normals[index]).normalized())
		st.add_vertex(xform * verts[index])


## A smooth rounded tube from point `a` to point `b` (radius `ra` at a, `rb` at b) with
## ball ends, so limbs, necks and tails join up. For characters, animals and carcasses.
static func add_tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, color: Color) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return
	var tube := CylinderMesh.new()
	tube.top_radius = rb
	tube.bottom_radius = ra
	tube.height = length
	tube.radial_segments = 12
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	add_smooth_shape(st, tube, Transform3D(Basis(Quaternion(Vector3.UP, along / length)), (a + b) * 0.5), color)
	for end in [[a, ra], [b, rb]]:
		var ball := SphereMesh.new()
		ball.radius = end[1]
		ball.height = end[1] * 2.0
		ball.radial_segments = 12
		ball.rings = 7
		add_smooth_shape(st, ball, Transform3D(Basis(), end[0]), color)


## A smooth rounded blob: an egg shape of the given radii (x, y, z) centred on `at`.
static func add_blob(st: SurfaceTool, at: Vector3, radii: Vector3, color: Color) -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 8
	add_smooth_shape(st, ball, Transform3D(Basis.from_scale(radii), at), color)


## Finishes a mesh made with add_smooth_shape().
static func commit_smooth(st: SurfaceTool, double_sided: bool = false) -> ArrayMesh:
	var mesh := st.commit()
	mesh.surface_set_material(0, get_material(double_sided))
	return mesh


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
