@tool
class_name PropLibrary
## Builds the nature models (trees, bushes, rocks, grass, flowers...) in code.
## Every builder takes a seed: the same seed always gives the same model.

const TRUNK_COLOR := Color(0.33, 0.22, 0.16)
const WOOD_COLOR := Color(0.62, 0.47, 0.31)
const PINE_DARK := Color(0.12, 0.27, 0.17)
const PINE_LIGHT := Color(0.24, 0.42, 0.24)
const LEAF_DARK := Color(0.21, 0.36, 0.15)
const LEAF_LIGHT := Color(0.36, 0.53, 0.2)
const BIRCH_BARK := Color(0.86, 0.84, 0.78)
const BIRCH_MARK := Color(0.2, 0.19, 0.18)
const BERRY_COLOR := Color(0.78, 0.12, 0.15)
const BIRCH_LEAF := Color(0.46, 0.58, 0.22)
const BUSH_COLOR := Color(0.2, 0.37, 0.16)
const MOSS_COLOR := Color(0.3, 0.45, 0.16)
const ROCK_COLOR := Color(0.5, 0.5, 0.48)
const GRASS_BASE_COLOR := Color(0.2, 0.36, 0.13)
const GRASS_TIP_COLOR := Color(0.47, 0.64, 0.26)
const FLOWER_COLORS: Array[Color] = [Color(0.95, 0.95, 0.9), Color(0.96, 0.8, 0.2), Color(0.62, 0.42, 0.85), Color(0.92, 0.45, 0.62)]
const MUSHROOM_CAP := Color(0.78, 0.2, 0.15)
const MUSHROOM_STEM := Color(0.9, 0.87, 0.78)


static func pine_tree(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var height := rng.randf_range(8.0, 11.0)

	var trunk := _cylinder(0.16, 0.34, height * 0.6, 7)
	LowPoly.add_shape(st, trunk, Transform3D(Basis(), Vector3(0.0, trunk.height * 0.5, 0.0)), TRUNK_COLOR, 0.04, 0.1, rng)
	_add_roots(st, rng, 0.34, TRUNK_COLOR)
	# A couple of bare branch stubs below the leaves.
	for i in 2:
		var angle := rng.randf() * TAU
		var stub_dir := Vector3(cos(angle), 0.4, sin(angle)).normalized()
		var start := Vector3(0.0, height * rng.randf_range(0.12, 0.2), 0.0)
		LowPoly.add_shape(st, _cylinder(0.02, 0.06, 0.8, 4), _between(start, start + stub_dir * 0.8), TRUNK_COLOR, 0.0, 0.1, rng)

	# Layers of drooping cones, darker at the bottom and lighter at the top (more sun).
	var layers := rng.randi_range(5, 6)
	for i in layers:
		var t := float(i) / (layers - 1)
		var cone := _cylinder(0.0, lerpf(2.7, 0.8, t) * rng.randf_range(0.9, 1.1), lerpf(2.4, 1.6, t), 8)
		cone.cap_top = false
		cone.rings = 2
		var y := height * 0.24 + t * height * 0.62 + cone.height * 0.5
		var wobble := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.08))
		var xform := Transform3D(tilt * Basis(Vector3.UP, rng.randf() * TAU), Vector3(0.0, y, 0.0) + wobble)
		LowPoly.add_shape(st, cone, xform, PINE_DARK.lerp(PINE_LIGHT, t), 0.22, 0.12, rng)
	return LowPoly.commit(st)


static func leafy_tree(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var height := rng.randf_range(4.5, 6.5)

	var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.12))
	var top := lean * Vector3(0.0, height, 0.0)
	LowPoly.add_shape(st, _cylinder(0.14, 0.32, height, 7), _between(Vector3.ZERO, top), TRUNK_COLOR, 0.06, 0.1, rng)
	_add_roots(st, rng, 0.32, TRUNK_COLOR)

	# Branches reach out from the upper trunk, each ending in a leaf blob.
	var blob_centers: Array[Vector3] = [top + Vector3(0.0, 0.8, 0.0)]
	for i in rng.randi_range(3, 4):
		var angle := (TAU / 4.0) * i + rng.randf_range(-0.5, 0.5)
		var start := top * rng.randf_range(0.6, 0.85)
		var tip := start + Vector3(cos(angle) * 1.6, rng.randf_range(0.8, 1.5), sin(angle) * 1.6)
		LowPoly.add_shape(st, _cylinder(0.05, 0.11, start.distance_to(tip), 5), _between(start, tip), TRUNK_COLOR, 0.03, 0.1, rng)
		blob_centers.append(tip)

	for center in blob_centers:
		var radius := rng.randf_range(1.3, 1.9)
		var blob := _sphere(radius, 7, 4)
		var squash := Basis.from_scale(Vector3(1.0, 0.8, 1.0)).rotated(Vector3.UP, rng.randf() * TAU)
		# Higher blobs catch more sun, so they are lighter.
		var light := clampf((center.y - height * 0.7) / (height * 0.5), 0.0, 1.0)
		LowPoly.add_shape(st, blob, Transform3D(squash, center), LEAF_DARK.lerp(LEAF_LIGHT, light), 0.35, 0.12, rng)
	return LowPoly.commit(st)


static func birch_tree(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var height := rng.randf_range(6.0, 8.0)
	var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.02, 0.1))
	var top := lean * Vector3(0.0, height, 0.0)
	# White bark with dark marks painted onto some of its facets.
	# Many short rings make each facet wide and flat, so the marks run sideways like real birch.
	var trunk := _cylinder(0.12, 0.22, height, 6)
	trunk.rings = int(height / 0.14)
	LowPoly.add_shape(st, trunk, _between(Vector3.ZERO, top), BIRCH_BARK, 0.0, 0.05, rng, BIRCH_MARK, 0.13)
	# Tall narrow crown made of small blobs.
	for i in rng.randi_range(5, 7):
		var y := height * rng.randf_range(0.55, 1.05)
		var center := lean * Vector3(rng.randf_range(-0.7, 0.7), y, rng.randf_range(-0.7, 0.7))
		var blob := _sphere(rng.randf_range(0.8, 1.2), 6, 4)
		LowPoly.add_shape(st, blob, Transform3D(Basis.from_scale(Vector3(1.0, 1.2, 1.0)), center), BIRCH_LEAF, 0.25, 0.14, rng)
	return LowPoly.commit(st)


static func bush(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	# Many small leaf clumps around a bigger middle one, so it reads as a bush, not a ball.
	var clumps: Array[Vector4] = [] # xyz = centre, w = radius
	var count := rng.randi_range(6, 9)
	for i in count:
		var radius := rng.randf_range(0.5, 0.6) if i == 0 else rng.randf_range(0.28, 0.45)
		var angle := TAU * i / count + rng.randf_range(-0.3, 0.3)
		var dist := 0.0 if i == 0 else rng.randf_range(0.3, 0.55)
		var center := Vector3(cos(angle) * dist, radius * 0.8 + (0.25 if i == 0 else rng.randf_range(0.0, 0.2)), sin(angle) * dist)
		clumps.append(Vector4(center.x, center.y, center.z, radius))
		# Higher clumps get more sun, so they're lighter.
		var color := BUSH_COLOR.lerp(LEAF_LIGHT, clampf(center.y - 0.3, 0.0, 0.6))
		LowPoly.add_shape(st, _sphere(radius, 6, 4), Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 1.0)), center), color, 0.08, 0.12, rng)
	# Half of the bushes have small clusters of red berries sitting on the leaves.
	if model_seed % 2 == 0:
		for cluster in 4:
			var clump: Vector4 = clumps[rng.randi() % clumps.size()]
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1)).normalized()
			var surface := Vector3(clump.x, clump.y, clump.z) + Vector3(dir.x, dir.y * 0.85, dir.z) * clump.w
			for b in rng.randi_range(2, 3):
				var offset := Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05))
				LowPoly.add_shape(st, _sphere(0.045, 5, 3), Transform3D(Basis(), surface + offset), BERRY_COLOR, 0.0, 0.1, rng)
	return LowPoly.commit(st)


static func fallen_log(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var length := rng.randf_range(3.5, 6.0)
	var radius := rng.randf_range(0.28, 0.4)
	var a := Vector3(-length * 0.5, radius * 0.8, 0.0)
	var b := Vector3(length * 0.5, radius * 0.8, 0.0)
	LowPoly.add_shape(st, _cylinder(radius, radius * 1.1, length, 8), _between(a, b), TRUNK_COLOR, 0.05, 0.1, rng)
	# Light cut-wood rings at both ends.
	LowPoly.add_shape(st, _cylinder(radius * 0.9, radius * 0.9, 0.05, 8), _between(b, b + Vector3(0.04, 0, 0)), WOOD_COLOR)
	LowPoly.add_shape(st, _cylinder(radius * 0.95, radius * 0.95, 0.05, 8), _between(a - Vector3(0.04, 0, 0), a), WOOD_COLOR)
	# Moss on top.
	for i in 3:
		var pos := Vector3(rng.randf_range(-length * 0.35, length * 0.35), radius * 1.7, 0.0)
		LowPoly.add_shape(st, _sphere(0.4, 6, 3), Transform3D(Basis.from_scale(Vector3(1.4, 0.35, 0.8)), pos), MOSS_COLOR, 0.08, 0.1, rng)
	return LowPoly.commit(st)


static func stump(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var height := rng.randf_range(0.4, 0.8)
	LowPoly.add_shape(st, _cylinder(0.38, 0.45, height, 8), Transform3D(Basis(), Vector3(0.0, height * 0.5, 0.0)), TRUNK_COLOR, 0.04, 0.1, rng)
	LowPoly.add_shape(st, _cylinder(0.34, 0.34, 0.04, 8), Transform3D(Basis(), Vector3(0.0, height + 0.01, 0.0)), WOOD_COLOR, 0.02, 0.05, rng)
	_add_roots(st, rng, 0.45, TRUNK_COLOR)
	return LowPoly.commit(st)


static func rock(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var scale := Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.5, 0.8), rng.randf_range(0.8, 1.2))
	LowPoly.add_shape(st, _sphere(1.0, 7, 4), Transform3D(Basis.from_scale(scale), Vector3(0.0, scale.y * 0.4, 0.0)), ROCK_COLOR, 0.35, 0.1, rng)
	# Moss on the top of some rocks.
	if rng.randf() < 0.6:
		LowPoly.add_shape(st, _sphere(0.7, 6, 3), Transform3D(Basis.from_scale(Vector3(scale.x, 0.25, scale.z)), Vector3(0.1, scale.y * 1.05, 0.0)), MOSS_COLOR, 0.15, 0.1, rng)
	return LowPoly.commit(st)


## A few small stones lying together (decoration only).
static func pebbles(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	for i in rng.randi_range(3, 6):
		var size := rng.randf_range(0.08, 0.22)
		var pos := Vector3(rng.randf_range(-0.6, 0.6), size * 0.3, rng.randf_range(-0.6, 0.6))
		LowPoly.add_shape(st, _sphere(size, 5, 3), Transform3D(Basis.from_scale(Vector3(1.0, 0.6, 1.0)), pos), ROCK_COLOR, 0.0, 0.15, rng)
	return LowPoly.commit(st)


## A small patch of flowers in one color.
static func flowers(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var color: Color = FLOWER_COLORS[model_seed % FLOWER_COLORS.size()]
	for i in rng.randi_range(5, 9):
		var base := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var head := base + Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(0.3, 0.55), rng.randf_range(-0.08, 0.08))
		LowPoly.add_shape(st, _cylinder(0.012, 0.015, base.distance_to(head), 3), _between(base, head), GRASS_BASE_COLOR)
		LowPoly.add_shape(st, _sphere(0.07, 5, 2), Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 1.0)), head), color, 0.0, 0.08, rng)
		LowPoly.add_shape(st, _sphere(0.025, 4, 2), Transform3D(Basis(), head + Vector3(0, 0.03, 0)), Color(0.95, 0.8, 0.2))
	return LowPoly.commit(st)


static func mushrooms(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	for i in rng.randi_range(2, 4):
		var base := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var height := rng.randf_range(0.12, 0.28)
		var cap_radius := height * rng.randf_range(0.6, 0.9)
		LowPoly.add_shape(st, _cylinder(0.025, 0.035, height, 5), Transform3D(Basis(), base + Vector3(0, height * 0.5, 0)), MUSHROOM_STEM)
		var cap := _sphere(cap_radius, 7, 4)
		cap.is_hemisphere = true
		LowPoly.add_shape(st, cap, Transform3D(Basis.from_scale(Vector3(1, 0.7, 1)), base + Vector3(0, height, 0)), MUSHROOM_CAP, 0.0, 0.06, rng)
		for d in 3:
			var angle := rng.randf() * TAU
			var dot_pos := base + Vector3(cos(angle) * cap_radius * 0.5, height + cap_radius * 0.55, sin(angle) * cap_radius * 0.5)
			LowPoly.add_shape(st, _sphere(0.015, 4, 2), Transform3D(Basis(), dot_pos), MUSHROOM_STEM)
	return LowPoly.commit(st)


## An airplane seat pulled out of the wreck: blue cushion and backrest on metal legs.
## Faces -Z (the backrest is at +Z), so a character facing -Z can sit on it.
static func airplane_seat(model_seed: int) -> ArrayMesh:
	var rng := _rng(model_seed)
	var st := LowPoly.begin()
	var blue := Color(0.2, 0.3, 0.55)
	var metal := Color(0.55, 0.57, 0.6)
	LowPoly.add_shape(st, _box(Vector3(0.6, 0.14, 0.55)), Transform3D(Basis(), Vector3(0, 0.42, 0)), blue, 0.015, 0.06, rng)
	LowPoly.add_shape(st, _box(Vector3(0.6, 0.8, 0.13)), Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.86, 0.25)), blue, 0.015, 0.06, rng)
	LowPoly.add_shape(st, _box(Vector3(0.44, 0.17, 0.14)), Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 1.22, 0.3)), Color(0.92, 0.92, 0.9), 0.01, 0.04, rng)
	for x in [-0.25, 0.25]:
		LowPoly.add_shape(st, _box(Vector3(0.05, 0.38, 0.46)), Transform3D(Basis(), Vector3(x, 0.19, 0)), metal, 0.0, 0.05, rng)
		# Armrests.
		LowPoly.add_shape(st, _box(Vector3(0.06, 0.05, 0.42)), Transform3D(Basis(), Vector3(x * 1.2, 0.62, 0.02)), metal, 0.0, 0.05, rng)
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


## Short root wedges spreading out from the base of a trunk.
static func _add_roots(st: SurfaceTool, rng: RandomNumberGenerator, trunk_radius: float, color: Color) -> void:
	for i in rng.randi_range(3, 4):
		var angle := (TAU / 4.0) * i + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var start := dir * trunk_radius * 0.5 + Vector3(0.0, 0.35, 0.0)
		var end := dir * (trunk_radius + rng.randf_range(0.35, 0.6)) + Vector3(0.0, -0.05, 0.0)
		# Thick where it joins the trunk, thin at the tip.
		LowPoly.add_shape(st, _cylinder(trunk_radius * 0.45, 0.04, start.distance_to(end), 4), _between(end, start), color, 0.02, 0.1, rng)


## A transform that stands a Y-axis shape (like a cylinder) between points a and b.
static func _between(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


static func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _rng(model_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = model_seed
	return rng
