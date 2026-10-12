@tool
class_name PropLibrary
## Builds the nature models (trees, rocks, grass) in code.
## The same seed always gives the same model.

const TRUNK_COLOR := Color(0.33, 0.22, 0.16)
const PINE_COLOR := Color(0.17, 0.33, 0.2)
const LEAF_COLOR := Color(0.27, 0.44, 0.18)
const ROCK_COLOR := Color(0.5, 0.5, 0.48)
const GRASS_BASE_COLOR := Color(0.2, 0.36, 0.13)
const GRASS_TIP_COLOR := Color(0.47, 0.64, 0.26)


static func pine_tree(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var height := rng.randf_range(8.0, 11.0)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.32
	trunk.height = height * 0.55
	trunk.radial_segments = 6
	trunk.rings = 1
	LowPoly.add_shape(st, trunk, Transform3D(Basis(), Vector3(0.0, trunk.height * 0.5, 0.0)), TRUNK_COLOR, 0.04, 0.08, rng)

	var layers := 4
	for i in layers:
		var t := float(i) / layers
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = lerpf(2.6, 1.0, t) * rng.randf_range(0.9, 1.1)
		cone.height = height * 0.32
		cone.radial_segments = 7
		cone.rings = 1
		cone.cap_top = false
		var y := height * 0.22 + t * height * 0.55 + cone.height * 0.5
		var xform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0.0, y, 0.0))
		LowPoly.add_shape(st, cone, xform, PINE_COLOR, 0.2, 0.12, rng)
	return LowPoly.commit(st)


static func leafy_tree(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var height := rng.randf_range(5.0, 7.0)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.3
	trunk.height = height
	trunk.radial_segments = 6
	trunk.rings = 2
	var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.12))
	LowPoly.add_shape(st, trunk, Transform3D(lean, lean * Vector3(0.0, height * 0.5, 0.0)), TRUNK_COLOR, 0.08, 0.08, rng)

	var top := lean * Vector3(0.0, height, 0.0)
	for i in rng.randi_range(3, 5):
		var blob := SphereMesh.new()
		blob.radius = rng.randf_range(1.4, 2.2)
		blob.height = blob.radius * 2.0
		blob.radial_segments = 7
		blob.rings = 4
		var offset := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.6, 1.2), rng.randf_range(-1.4, 1.4))
		var squash := Basis.from_scale(Vector3(1.0, 0.8, 1.0)).rotated(Vector3.UP, rng.randf() * TAU)
		LowPoly.add_shape(st, blob, Transform3D(squash, top + offset), LEAF_COLOR, 0.35, 0.12, rng)
	return LowPoly.commit(st)


static func rock(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var shape := SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 6
	shape.rings = 4
	var scale := Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.5, 0.8), rng.randf_range(0.8, 1.2))
	LowPoly.add_shape(st, shape, Transform3D(Basis.from_scale(scale), Vector3(0.0, scale.y * 0.4, 0.0)), ROCK_COLOR, 0.35, 0.1, rng)
	return LowPoly.commit(st)


## A clump of tall grass blades. Built by hand: each blade is one thin triangle.
static func grass_clump(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rng.randi_range(6, 9):
		var base := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var angle := rng.randf() * TAU
		var side := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.07, 0.11)
		var height := rng.randf_range(0.45, 0.9)
		var bend := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var tip := base + bend + Vector3(0.0, height, 0.0)
		# Each blade is added twice (front and back) with normals pointing up,
		# so both sides are lit like the ground instead of one side going black.
		for points in [[base - side, base + side], [base + side, base - side]]:
			st.set_normal(Vector3.UP)
			st.set_color(GRASS_BASE_COLOR)
			st.add_vertex(points[0])
			st.add_vertex(points[1])
			st.set_color(GRASS_TIP_COLOR)
			st.add_vertex(tip)
	var mesh := st.commit()
	mesh.surface_set_material(0, LowPoly.get_material())
	return mesh


static func _rng(model_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = model_seed
	return rng
