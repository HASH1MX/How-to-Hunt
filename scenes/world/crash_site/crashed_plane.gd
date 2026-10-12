@tool
class_name CrashedPlane
extends StaticBody3D
## The crashed airplane where players start. Built in code from simple shapes.
## The plane broke in two: the front half (with one wing) and the tail half.
## Around it: a torn-off wing, torn metal, dangling wires, seats, luggage,
## an emergency slide, a lost wheel, scorch marks and a smoking engine.
## Big parts have collision, so players can climb onto the wing and fuselage.

@export var debris_seed: int = 7

const BODY_COLOR := Color(0.88, 0.88, 0.85)
const STRIPE_COLOR := Color(0.75, 0.2, 0.16)
const WINDOW_COLOR := Color(0.14, 0.2, 0.28)
const METAL_COLOR := Color(0.55, 0.57, 0.6)
const DARK_COLOR := Color(0.1, 0.1, 0.1)
const SCORCH_COLOR := Color(0.16, 0.14, 0.13)
const DIRT_COLOR := Color(0.4, 0.29, 0.19)
const SEAT_COLOR := Color(0.2, 0.3, 0.55)
const SLIDE_COLOR := Color(0.95, 0.74, 0.15)
const LUGGAGE_COLORS: Array[Color] = [Color(0.2, 0.35, 0.6), Color(0.6, 0.2, 0.18), Color(0.85, 0.65, 0.2), Color(0.25, 0.25, 0.25)]
const WIRE_COLORS: Array[Color] = [Color(0.8, 0.15, 0.12), Color(0.9, 0.75, 0.15), Color(0.1, 0.1, 0.1), Color(0.2, 0.4, 0.8)]

## Turns a shape standing along Y so it lies along X (the plane's length). Its top ends up at +X.
const ALONG_X := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
const FUSELAGE_RADIUS := 1.5
const FUSELAGE_HEIGHT := 1.5 # Height of the fuselage's centre line above the ground.

var _st: SurfaceTool
var _rng := RandomNumberGenerator.new()
var _engine_xform: Transform3D


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.queue_free()
	_rng.seed = debris_seed
	_st = LowPoly.begin()

	# Front half: tilted a little and dug into the ground.
	_build_front(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.0, -0.25, 0.0)))
	# Tail half: broke off, slid sideways and rolled onto its side a bit.
	_build_tail(Transform3D(Basis(Vector3.UP, 0.45) * Basis(Vector3.RIGHT, -0.3), Vector3(-7.5, -0.15, -3.5)))
	_build_torn_wing(Transform3D(Basis(Vector3.UP, 0.9) * Basis(Vector3.FORWARD, 0.12), Vector3(-1.0, 0.2, -8.5)))
	_build_ground_debris()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = LowPoly.commit(_st)
	add_child(mesh_instance)
	_add_smoke(_engine_xform * Vector3(0.2, 0.4, 0.0))


func _build_front(g: Transform3D) -> void:
	var c := FUSELAGE_HEIGHT
	# Fuselage: a long cylinder lying along X. The nose points to +X.
	_part(_cylinder(FUSELAGE_RADIUS, FUSELAGE_RADIUS, 9.0, 10), g * Transform3D(ALONG_X, Vector3(0.0, c, 0.0)), BODY_COLOR, true, 0.03)
	# Nose: a stretched sphere.
	_part(_sphere(FUSELAGE_RADIUS, 10, 6), g * Transform3D(Basis.from_scale(Vector3(1.6, 1.0, 1.0)), Vector3(4.5, c, 0.0)), BODY_COLOR, true, 0.03)
	_part(_box(Vector3(1.0, 0.5, 2.3)), g * Transform3D(Basis(Vector3.BACK, -0.6), Vector3(5.2, 2.45, 0.0)), WINDOW_COLOR)
	_part(_box(Vector3(9.0, 0.3, 3.08)), g * Transform3D(Basis(), Vector3(0.0, 1.25, 0.0)), STRIPE_COLOR)
	for i in 7:
		var x := -3.6 + i * 1.1
		if absf(x - 3.0) < 0.6:
			continue # Leave room for the door.
		for side in [-1.0, 1.0]:
			_part(_box(Vector3(0.45, 0.38, 0.12)), g * Transform3D(Basis(), Vector3(x, 1.95, 1.43 * side)), WINDOW_COLOR)

	# Open emergency door with the yellow slide coming out of it.
	_part(_box(Vector3(0.9, 1.5, 0.14)), g * Transform3D(Basis(), Vector3(3.0, 1.6, 1.42)), DARK_COLOR)
	var slide_top := g * Vector3(3.0, 0.95, 1.55)
	var slide_bottom := Vector3(3.0, 0.08, 4.4)
	_part(_box(Vector3(1.0, slide_top.distance_to(slide_bottom), 0.22)), _between(slide_top, slide_bottom), SLIDE_COLOR, true)
	for side in [-0.5, 0.5]:
		var rail := Vector3(side, 0.15, 0.0)
		_part(_cylinder(0.12, 0.12, slide_top.distance_to(slide_bottom), 6), _between(slide_top + rail, slide_bottom + rail), SLIDE_COLOR * Color(0.9, 0.85, 0.8))

	# The broken end: dark hole, jagged torn metal, wires and a seat hanging out.
	_part(_cylinder(1.42, 1.42, 0.1, 10), g * Transform3D(ALONG_X, Vector3(-4.52, c, 0.0)), DARK_COLOR)
	_add_torn_edge(g, Vector3(-4.5, c, 0.0), -1.0, FUSELAGE_RADIUS)
	for i in 4:
		var angle := _rng.randf_range(-1.2, 1.2)
		var start := g * Vector3(-4.3, c + sin(angle) * 0.9, cos(angle) * 0.9)
		var end := Vector3(_rng.randf_range(-6.4, -5.4), 0.03, _rng.randf_range(-1.5, 1.8))
		_part(_cylinder(0.035, 0.035, start.distance_to(end), 4), _between(start, end), WIRE_COLORS[i % WIRE_COLORS.size()])

	# Small black scorch marks near the broken end and the wing.
	for i in 4:
		_add_scorch_on_fuselage(g, _rng.randf_range(-4.0, 1.5), _rng.randf_range(-0.2, 0.9), _rng.randf_range(0.2, 0.4))

	# Right wing, still attached, bent upward slightly.
	var wing := g * Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0.6, 0.85, 5.4))
	_part(_box(Vector3(2.6, 0.22, 8.0)), wing, BODY_COLOR, true, 0.04)
	_part(_box(Vector3(0.5, 0.23, 8.0)), wing * Transform3D(Basis(), Vector3(1.1, 0.0, 0.0)), STRIPE_COLOR)
	# Flap hanging down at the back of the wing.
	_part(_box(Vector3(0.6, 0.08, 2.5)), wing * Transform3D(Basis(Vector3.BACK, 0.5), Vector3(-1.45, -0.18, 1.8)), METAL_COLOR, false, 0.02)
	# Engine with a bent propeller, blackened from the fire.
	_engine_xform = wing * Transform3D(Basis(), Vector3(0.6, -0.15, -1.2))
	_part(_cylinder(0.45, 0.55, 2.0, 8), _engine_xform * Transform3D(ALONG_X, Vector3.ZERO), METAL_COLOR, true, 0.03)
	_part(_cylinder(0.5, 0.5, 0.9, 8), _engine_xform * Transform3D(ALONG_X, Vector3(-0.3, 0.0, 0.0)), SCORCH_COLOR, false, 0.04)
	_part(_sphere(0.3, 8, 4), _engine_xform * Transform3D(Basis(), Vector3(1.05, 0.0, 0.0)), DARK_COLOR)
	_part(_box(Vector3(0.08, 2.2, 0.25)), _engine_xform * Transform3D(Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, 0.25), Vector3(1.15, 0.0, 0.0)), DARK_COLOR)
	_part(_box(Vector3(0.08, 1.1, 0.25)), _engine_xform * Transform3D(Basis(Vector3.RIGHT, 1.9), Vector3(1.15, 0.3, -0.5)), DARK_COLOR)
	# Stub where the left wing tore off, with torn metal and wires.
	var stub := g * Transform3D(Basis(), Vector3(0.6, 0.85, -2.0))
	_part(_box(Vector3(2.6, 0.22, 1.4)), stub, BODY_COLOR, true)
	for i in 5:
		var x := -1.1 + i * 0.55
		var shard_basis := Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5)) * Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3))
		_part(_box(Vector3(0.4, 0.05, _rng.randf_range(0.4, 0.8))), stub * Transform3D(shard_basis, Vector3(x, 0.0, -0.85)), BODY_COLOR if i % 2 == 0 else METAL_COLOR)
	for i in 2:
		var start := stub * Vector3(_rng.randf_range(-0.6, 0.6), 0.0, -0.7)
		var end := start + Vector3(_rng.randf_range(-0.3, 0.3), -start.y + 0.03, _rng.randf_range(-0.8, -0.3))
		_part(_cylinder(0.03, 0.03, start.distance_to(end), 4), _between(start, end), WIRE_COLORS[i])

	# Dirt piled up in front of the nose from sliding along the ground.
	_part(_sphere(1.0, 7, 4), g * Transform3D(Basis.from_scale(Vector3(1.2, 0.5, 2.8)), Vector3(7.4, 0.0, 0.0)), DIRT_COLOR, true, 0.25)


func _build_tail(g: Transform3D) -> void:
	var c := FUSELAGE_HEIGHT
	# Tail section of the fuselage gets thinner toward the back (-X).
	_part(_cylinder(FUSELAGE_RADIUS, 0.6, 6.0, 10), g * Transform3D(ALONG_X, Vector3(-3.0, c, 0.0)), BODY_COLOR, true, 0.03)
	_part(_box(Vector3(6.0, 0.25, 2.6)), g * Transform3D(Basis(Vector3.BACK, -0.1), Vector3(-2.6, 1.15, 0.0)), STRIPE_COLOR)
	_part(_cylinder(1.42, 1.42, 0.1, 10), g * Transform3D(ALONG_X, Vector3(0.02, c, 0.0)), DARK_COLOR)
	_add_torn_edge(g, Vector3(0.0, c, 0.0), 1.0, FUSELAGE_RADIUS)
	_part(_box(Vector3(2.0, 2.4, 0.18)), g * Transform3D(Basis(Vector3.BACK, 0.4), Vector3(-5.2, 3.1, 0.0)), STRIPE_COLOR, true, 0.03)
	_part(_box(Vector3(1.3, 0.14, 4.4)), g * Transform3D(Basis(), Vector3(-5.4, 1.85, 0.0)), BODY_COLOR, true, 0.03)
	# A seat that fell out of the tail.
	_add_seat(g * Transform3D(Basis(Vector3.UP, 0.4), Vector3(1.3, 0.35, 0.8)))
	_part(_sphere(1.0, 7, 4), g * Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 2.2)), Vector3(1.0, 0.0, 0.0)), DIRT_COLOR, true, 0.25)


func _build_torn_wing(g: Transform3D) -> void:
	_part(_box(Vector3(2.4, 0.2, 5.5)), g, BODY_COLOR, true, 0.04)
	_part(_box(Vector3(0.5, 0.21, 5.5)), g * Transform3D(Basis(), Vector3(1.0, 0.0, 0.0)), STRIPE_COLOR)
	# Jagged torn end where it ripped off the plane.
	for i in 5:
		var x := -1.0 + i * 0.5
		var shard_basis := Basis(Vector3.RIGHT, _rng.randf_range(-0.6, 0.6)) * Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4))
		_part(_box(Vector3(0.35, 0.05, _rng.randf_range(0.4, 0.9))), g * Transform3D(shard_basis, Vector3(x, 0.0, 2.9)), METAL_COLOR if i % 2 == 0 else BODY_COLOR)


func _build_ground_debris() -> void:
	# Metal scraps around the crash site (no collision, so they never trap players).
	for i in 22:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(3.0, 13.0)
		var pos := Vector3(cos(angle) * dist - 2.0, 0.05, sin(angle) * dist - 1.0)
		var rot := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		var size := Vector3(_rng.randf_range(0.3, 1.2), 0.06, _rng.randf_range(0.3, 0.9))
		_part(_box(size), Transform3D(rot, pos), METAL_COLOR if _rng.randf() < 0.5 else BODY_COLOR, false, 0.05)
	# Luggage spilled out of the broken tail.
	for i in 7:
		var pos := Vector3(_rng.randf_range(-6.5, -2.0), 0.25, _rng.randf_range(-6.0, -1.0))
		var rot := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.2, 0.2))
		var color: Color = LUGGAGE_COLORS[_rng.randi() % LUGGAGE_COLORS.size()]
		_part(_box(Vector3(0.75, 0.5, 0.3)), Transform3D(rot, pos), color, true, 0.02)
		_part(_box(Vector3(0.25, 0.08, 0.06)), Transform3D(rot, pos + rot * Vector3(0.0, 0.29, 0.0)), DARK_COLOR)
	# Seats thrown out of the plane, one knocked over.
	_add_seat(Transform3D(Basis(Vector3.UP, 2.4), Vector3(-5.5, -0.05, 2.6)))
	_add_seat(Transform3D(Basis(Vector3.UP, 2.9), Vector3(-6.2, -0.05, 3.3)))
	_add_seat(Transform3D(Basis(Vector3.UP, 0.8) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-3.4, 0.25, 4.0)))
	# A landing gear wheel that broke off.
	var wheel := Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(6.2, 0.4, -3.6))
	_part(_cylinder(0.45, 0.45, 0.32, 10), wheel, Color(0.12, 0.12, 0.12), true, 0.02)
	_part(_cylinder(0.2, 0.2, 0.34, 8), wheel, METAL_COLOR)
	_part(_box(Vector3(0.12, 1.3, 0.12)), Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, 1.3), Vector3(6.9, 0.12, -4.6)), METAL_COLOR)
	# Door panel and a propeller blade lying in the grass.
	_part(_box(Vector3(0.85, 0.1, 1.45)), Transform3D(Basis(Vector3.UP, 0.3), Vector3(5.2, 0.05, 3.2)), BODY_COLOR, false, 0.02)
	_part(_box(Vector3(0.08, 1.0, 0.25)), Transform3D(Basis(Vector3.UP, 1.1) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(3.5, 0.05, 8.6)), DARK_COLOR)
	# Burned ground under the engine and where the plane broke apart.
	for pos in [Vector3(1.6, 0.0, 4.0), Vector3(-5.0, 0.0, 0.5), Vector3(-2.0, 0.0, -2.5)]:
		var size := Vector3(_rng.randf_range(1.6, 2.4), 0.12, _rng.randf_range(1.2, 1.8))
		_part(_sphere(1.0, 7, 3), Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(size), pos), SCORCH_COLOR, false, 0.2)


## Jagged pieces of torn metal around a broken end of the fuselage.
## `direction` is -1 or +1: which way along X the open end faces.
func _add_torn_edge(g: Transform3D, center: Vector3, direction: float, radius: float) -> void:
	var along := Vector3(direction, 0.0, 0.0)
	var count := 14
	for i in count:
		var angle := TAU * i / count + _rng.randf_range(-0.1, 0.1)
		var outward := Vector3(0.0, sin(angle), cos(angle))
		var side := along.cross(outward)
		var length := _rng.randf_range(0.3, 0.9)
		# Lay the shard flat on the fuselage skin, then bend it outward.
		var shard_basis := Basis(along, outward, side).rotated(side, _rng.randf_range(0.1, 0.7))
		var pos := center + outward * radius * 0.98 + shard_basis.x * length * 0.45
		var color := BODY_COLOR if i % 3 != 0 else METAL_COLOR
		_part(_box(Vector3(length, 0.05, _rng.randf_range(0.35, 0.6))), g * Transform3D(shard_basis, pos), color)


func _add_scorch_on_fuselage(g: Transform3D, x: float, angle: float, size: float) -> void:
	var outward := Vector3(0.0, sin(angle), cos(angle))
	var along := Vector3.RIGHT
	var up := outward.cross(along)
	var scorch_basis := Basis(along, up, outward) * Basis.from_scale(Vector3(size * 1.4, size, 0.06))
	var pos := Vector3(x, FUSELAGE_HEIGHT, 0.0) + outward * FUSELAGE_RADIUS * 0.97
	_part(_sphere(1.0, 7, 3), g * Transform3D(scorch_basis, pos), SCORCH_COLOR, false, 0.15)


## An airplane seat: blue cushion and backrest on metal legs.
func _add_seat(xform: Transform3D) -> void:
	_part(_box(Vector3(0.55, 0.14, 0.5)), xform * Transform3D(Basis(), Vector3(0.0, 0.42, 0.0)), SEAT_COLOR, false, 0.02)
	_part(_box(Vector3(0.55, 0.75, 0.12)), xform * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0.0, 0.82, -0.22)), SEAT_COLOR, false, 0.02)
	_part(_box(Vector3(0.42, 0.16, 0.13)), xform * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0.0, 1.15, -0.27)), Color(0.9, 0.9, 0.88))
	for side in [-0.22, 0.22]:
		_part(_box(Vector3(0.05, 0.36, 0.42)), xform * Transform3D(Basis(), Vector3(side, 0.18, 0.0)), METAL_COLOR)


## Grey smoke puffs rising from the burnt engine.
func _add_smoke(at: Vector3) -> void:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 10.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.2
	process.gravity = Vector3(0.25, 0.15, 0.1) # A light breeze pushes the smoke sideways.
	process.angle_max = 180.0
	process.scale_min = 0.5
	process.scale_max = 0.9
	var grow := Curve.new()
	grow.max_value = 3.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 3.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(0.08, 0.08, 0.08, 0.0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	fade.add_point(0.15, Color(0.1, 0.1, 0.1, 0.55))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture

	var puff_tool := LowPoly.begin()
	LowPoly.add_shape(puff_tool, _sphere(0.5, 6, 4), Transform3D(), Color.WHITE, 0.1)
	var puff := LowPoly.commit(puff_tool)
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.roughness = 1.0
	puff.surface_set_material(0, smoke_material)

	var particles := GPUParticles3D.new()
	particles.name = "EngineSmoke"
	particles.amount = 24
	particles.lifetime = 7.0
	particles.preprocess = 7.0 # Start already smoking instead of from nothing.
	particles.position = at
	particles.process_material = process
	particles.draw_pass_1 = puff
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 16, 12))
	add_child(particles)


## Adds one shape to the plane's mesh, and optionally a matching solid collider.
func _part(shape: PrimitiveMesh, xform: Transform3D, color: Color, solid: bool = false, jitter: float = 0.0) -> void:
	LowPoly.add_shape(_st, shape, xform, color, jitter, 0.04, _rng)
	if solid:
		# Collider made from the shape's own corners, so it matches the visible shape.
		var points := PackedVector3Array()
		for v in shape.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
			points.append(xform * v)
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		var collider := CollisionShape3D.new()
		collider.shape = convex
		add_child(collider)


## A transform that stands a Y-axis shape (box or cylinder) between points a and b.
func _between(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh
