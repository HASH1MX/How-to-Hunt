class_name WeaponMeshes
## Low-poly models of every weapon, in the How to Fish style: chunky shapes with softly
## bevelled edges, solid colours and a few clear details (sights, trigger guards, rails,
## magazines) so each gun reads at a glance. Each points forward along -Z with the grip
## at the origin, so it sits in the hand ready to fire. The barrel sits about 0.055 above
## the grip (where ViewModel.get_muzzle_position puts the muzzle flash).

const DARK := Color(0.15, 0.16, 0.18)
const GUNMETAL := Color(0.27, 0.28, 0.31)
const METAL := Color(0.58, 0.6, 0.63)
const WOOD := Color(0.58, 0.35, 0.17)
const WOOD_DARK := Color(0.42, 0.24, 0.12)
const TAN := Color(0.7, 0.6, 0.42)
const GOLD := Color(0.9, 0.68, 0.24)
const GOLD_DARK := Color(0.68, 0.48, 0.15)
const BLADE := Color(0.82, 0.84, 0.87)
const LENS := Color(0.18, 0.32, 0.45)


static func knife() -> Mesh:
	var st := LowPoly.begin()
	# Handle with a rounded butt and two rivets.
	_cbox(st, Vector3(0.03, 0.04, 0.11), Vector3(0, 0, 0.03), Color(0.24, 0.17, 0.12))
	_cbox(st, Vector3(0.034, 0.044, 0.018), Vector3(0, 0, 0.088), METAL)
	for z in [0.0, 0.05]:
		_cylinder(st, 0.007, 0.007, 0.034, Vector3(0, 0, z), METAL, Basis(Vector3.BACK, PI * 0.5), 6)
	_cbox(st, Vector3(0.026, 0.07, 0.014), Vector3(0, 0.004, -0.03), METAL)  # guard
	# Blade: straight spine, curved edge up to the point, thinner at the cutting edge.
	_prism(st, [Vector2(-0.035, 0.018), Vector2(-0.24, 0.018), Vector2(-0.285, 0.004), Vector2(-0.25, -0.012),
			Vector2(-0.16, -0.02), Vector2(-0.035, -0.02)], 0.009, BLADE)
	_prism(st, [Vector2(-0.04, 0.016), Vector2(-0.22, 0.016), Vector2(-0.22, 0.006), Vector2(-0.04, 0.006)], 0.011, BLADE.darkened(0.12))  # fuller
	return LowPoly.commit(st)


static func pistol() -> Mesh:
	var st := LowPoly.begin()
	_cbox(st, Vector3(0.04, 0.04, 0.2), Vector3(0, 0.062, -0.062), DARK)            # slide
	for i in 4:
		_box(st, Vector3(0.042, 0.028, 0.004), Vector3(0, 0.062, 0.012 + i * 0.008), GUNMETAL)  # grip serrations
	_box(st, Vector3(0.006, 0.014, 0.034), Vector3(0.019, 0.07, -0.04), METAL)     # ejection port
	_cbox(st, Vector3(0.036, 0.026, 0.17), Vector3(0, 0.032, -0.055), GUNMETAL)     # frame
	_cylinder(st, 0.012, 0.012, 0.012, Vector3(0, 0.058, -0.165), METAL, _along_z()) # muzzle
	_cylinder(st, 0.007, 0.007, 0.014, Vector3(0, 0.058, -0.167), Color.BLACK, _along_z())
	# Grip, with brown panels on both sides.
	var grip_tilt := Basis(Vector3.RIGHT, -0.28)
	_cbox(st, Vector3(0.034, 0.11, 0.048), Vector3(0, -0.026, 0.022), DARK, grip_tilt)
	_cbox(st, Vector3(0.039, 0.075, 0.036), Vector3(0, -0.022, 0.022), Color(0.36, 0.24, 0.15), grip_tilt)
	_trigger_guard(st, Vector3(0, 0.0, -0.035), 0.05)
	_box(st, Vector3(0.008, 0.012, 0.01), Vector3(0, 0.088, -0.152), METAL)        # front sight
	for x in [-0.011, 0.011]:
		_box(st, Vector3(0.008, 0.012, 0.01), Vector3(x, 0.088, 0.02), DARK)        # rear sight
	_box(st, Vector3(0.012, 0.02, 0.012), Vector3(0, 0.075, 0.045), GUNMETAL, Basis(Vector3.RIGHT, -0.5))  # hammer
	return LowPoly.commit(st)


static func flare_gun() -> Mesh:
	var st := LowPoly.begin()
	var orange := Color(0.96, 0.44, 0.1)
	_cylinder(st, 0.03, 0.03, 0.15, Vector3(0, 0.06, -0.085), orange, _along_z(), 12)      # fat barrel
	_cylinder(st, 0.035, 0.035, 0.022, Vector3(0, 0.06, -0.158), orange.darkened(0.15), _along_z(), 12)
	_cylinder(st, 0.021, 0.021, 0.024, Vector3(0, 0.06, -0.16), Color(0.08, 0.06, 0.05), _along_z(), 10)  # the hole
	_cbox(st, Vector3(0.044, 0.056, 0.06), Vector3(0, 0.05, 0.0), orange)               # breech
	_cylinder(st, 0.009, 0.009, 0.05, Vector3(0, 0.03, -0.03), DARK, Basis(Vector3.BACK, PI * 0.5), 8)  # hinge
	_cbox(st, Vector3(0.038, 0.11, 0.05), Vector3(0, -0.03, 0.03), orange.darkened(0.22), Basis(Vector3.RIGHT, -0.3))
	_cbox(st, Vector3(0.042, 0.02, 0.054), Vector3(0, -0.082, 0.048), orange.darkened(0.35), Basis(Vector3.RIGHT, -0.3))
	_trigger_guard(st, Vector3(0, 0.0, -0.025), 0.045)
	_box(st, Vector3(0.012, 0.024, 0.012), Vector3(0, 0.084, 0.02), DARK, Basis(Vector3.RIGHT, -0.5))  # hammer
	return LowPoly.commit(st)


static func double_barrel() -> Mesh:
	var st := LowPoly.begin()
	# Two long barrels with a flat rib on top and a bead sight.
	for x in [-0.019, 0.019]:
		_cylinder(st, 0.018, 0.018, 0.56, Vector3(x, 0.056, -0.37), GUNMETAL, _along_z(), 12)
		_cylinder(st, 0.011, 0.011, 0.01, Vector3(x, 0.056, -0.652), Color.BLACK, _along_z(), 8)
	_box(st, Vector3(0.014, 0.008, 0.56), Vector3(0, 0.077, -0.37), DARK)
	_cylinder(st, 0.005, 0.005, 0.008, Vector3(0, 0.085, -0.64), METAL, Basis(), 6)
	_cbox(st, Vector3(0.05, 0.036, 0.22), Vector3(0, 0.026, -0.21), WOOD)              # fore-end
	_cbox(st, Vector3(0.056, 0.066, 0.12), Vector3(0, 0.043, -0.045), METAL)           # receiver
	_box(st, Vector3(0.058, 0.012, 0.09), Vector3(0, 0.03, -0.045), METAL.darkened(0.15))  # engraving line
	_box(st, Vector3(0.016, 0.012, 0.04), Vector3(0, 0.08, 0.0), DARK)                  # top lever
	for x in [-0.012, 0.012]:
		_box(st, Vector3(0.008, 0.022, 0.012), Vector3(x, 0.08, 0.02), DARK, Basis(Vector3.RIGHT, -0.5))  # hammers
	_trigger_guard(st, Vector3(0, 0.002, -0.02), 0.06)
	_box(st, Vector3(0.006, 0.02, 0.006), Vector3(0, 0.012, -0.002), METAL, Basis(Vector3.RIGHT, 0.3))
	# Stock: a slim wrist that widens into the butt, with a dark pad.
	_cbox(st, Vector3(0.038, 0.05, 0.13), Vector3(0, 0.02, 0.06), WOOD, Basis(Vector3.RIGHT, 0.22))
	_cbox(st, Vector3(0.046, 0.115, 0.2), Vector3(0, -0.02, 0.2), WOOD, Basis(Vector3.RIGHT, 0.14))
	_cbox(st, Vector3(0.05, 0.12, 0.02), Vector3(0, -0.035, 0.302), WOOD_DARK.darkened(0.4), Basis(Vector3.RIGHT, 0.14))
	return LowPoly.commit(st)


static func smg() -> Mesh:
	var st := LowPoly.begin()
	_cbox(st, Vector3(0.05, 0.066, 0.25), Vector3(0, 0.052, -0.06), DARK)              # receiver
	_rail(st, Vector3(0, 0.09, -0.07), 0.17)
	_cbox(st, Vector3(0.054, 0.04, 0.09), Vector3(0, 0.03, -0.15), GUNMETAL)           # hand guard
	_cylinder(st, 0.02, 0.02, 0.08, Vector3(0, 0.056, -0.225), GUNMETAL, _along_z(), 10)  # barrel shroud
	_cylinder(st, 0.013, 0.013, 0.05, Vector3(0, 0.056, -0.285), DARK, _along_z(), 10)    # muzzle
	_cylinder(st, 0.007, 0.007, 0.052, Vector3(0, 0.056, -0.287), Color.BLACK, _along_z(), 6)
	_box(st, Vector3(0.012, 0.022, 0.012), Vector3(0, 0.1, -0.2), DARK)                 # front sight
	_cylinder(st, 0.014, 0.014, 0.01, Vector3(0, 0.105, 0.04), DARK, _along_z(), 8)     # rear ring sight
	_box(st, Vector3(0.012, 0.012, 0.03), Vector3(0.03, 0.065, -0.11), METAL)          # cocking handle
	# A curved magazine in front of the grip.
	_curved_mag(st, Vector3(0, 0.015, -0.075), Vector3(0.03, 0.05, 0.042), 3, 0.12, DARK.lightened(0.05))
	_cbox(st, Vector3(0.034, 0.1, 0.045), Vector3(0, -0.026, 0.026), GUNMETAL, Basis(Vector3.RIGHT, -0.25))
	_trigger_guard(st, Vector3(0, 0.004, -0.02), 0.045)
	# Folded wire stock, tucked along the left side.
	_tube(st, Vector3(-0.03, 0.07, 0.06), Vector3(-0.03, 0.07, -0.12), 0.005, 0.005, GUNMETAL)
	_tube(st, Vector3(-0.03, 0.04, 0.06), Vector3(-0.03, 0.04, -0.12), 0.005, 0.005, GUNMETAL)
	_cbox(st, Vector3(0.012, 0.05, 0.016), Vector3(-0.03, 0.055, -0.125), DARK)
	_cbox(st, Vector3(0.04, 0.05, 0.03), Vector3(0, 0.05, 0.075), DARK)                  # end cap
	return LowPoly.commit(st)


static func assault_rifle() -> Mesh:
	var st := LowPoly.begin()
	_cbox(st, Vector3(0.05, 0.056, 0.26), Vector3(0, 0.062, -0.08), DARK)             # upper receiver
	_cbox(st, Vector3(0.046, 0.05, 0.18), Vector3(0, 0.02, -0.07), GUNMETAL)           # lower receiver
	_rail(st, Vector3(0, 0.096, -0.15), 0.4)
	_box(st, Vector3(0.006, 0.016, 0.04), Vector3(0.026, 0.068, -0.05), METAL)         # ejection port
	# Tan hand guard with dark vent slots, then the barrel, front sight and muzzle brake.
	_cbox(st, Vector3(0.058, 0.058, 0.25), Vector3(0, 0.058, -0.34), TAN)
	for i in 4:
		for x in [-0.03, 0.03]:
			_box(st, Vector3(0.004, 0.014, 0.03), Vector3(x, 0.058, -0.26 - i * 0.055), DARK)
	_cylinder(st, 0.012, 0.012, 0.16, Vector3(0, 0.058, -0.54), DARK, _along_z(), 10)
	_cbox(st, Vector3(0.022, 0.05, 0.022), Vector3(0, 0.083, -0.5), DARK)
	_cylinder(st, 0.018, 0.018, 0.055, Vector3(0, 0.058, -0.635), DARK, _along_z(), 10)
	_cylinder(st, 0.009, 0.009, 0.057, Vector3(0, 0.058, -0.637), Color.BLACK, _along_z(), 6)
	for z in [-0.625, -0.645]:
		_box(st, Vector3(0.04, 0.005, 0.006), Vector3(0, 0.07, z), Color.BLACK)
	# A small red-dot sight on the rail.
	_cbox(st, Vector3(0.03, 0.016, 0.05), Vector3(0, 0.109, -0.06), GUNMETAL)
	_cylinder(st, 0.021, 0.021, 0.06, Vector3(0, 0.135, -0.06), DARK, _along_z(), 10)
	_cylinder(st, 0.016, 0.016, 0.062, Vector3(0, 0.135, -0.06), LENS, _along_z(), 10)
	_curved_mag(st, Vector3(0, -0.005, -0.12), Vector3(0.028, 0.045, 0.06), 4, 0.14, DARK.lightened(0.04))
	_cbox(st, Vector3(0.035, 0.1, 0.045), Vector3(0, -0.026, 0.03), TAN, Basis(Vector3.RIGHT, -0.32))
	_trigger_guard(st, Vector3(0, -0.006, -0.02), 0.05)
	# Buffer tube and tan stock with a dark butt pad.
	_cylinder(st, 0.017, 0.017, 0.15, Vector3(0, 0.05, 0.12), GUNMETAL, _along_z(), 10)
	_cbox(st, Vector3(0.046, 0.09, 0.14), Vector3(0, 0.03, 0.23), TAN)
	_cbox(st, Vector3(0.048, 0.095, 0.02), Vector3(0, 0.03, 0.305), DARK)
	return LowPoly.commit(st)


## A golden sniper rifle with a big black scope (like the one in How to Fish).
static func sniper() -> Mesh:
	var st := LowPoly.begin()
	# Long golden stock, thumb-hole butt with a cheek rest.
	_cbox(st, Vector3(0.052, 0.058, 0.48), Vector3(0, 0.032, -0.12), GOLD)
	_cbox(st, Vector3(0.046, 0.05, 0.14), Vector3(0, 0.03, 0.17), GOLD)                # wrist
	_cbox(st, Vector3(0.05, 0.1, 0.16), Vector3(0, 0.005, 0.28), GOLD, Basis(Vector3.RIGHT, 0.06))
	_cbox(st, Vector3(0.048, 0.026, 0.13), Vector3(0, 0.068, 0.25), GOLD_DARK)         # cheek rest
	_cbox(st, Vector3(0.052, 0.105, 0.02), Vector3(0, 0.0, 0.365), DARK, Basis(Vector3.RIGHT, 0.06))
	_cbox(st, Vector3(0.035, 0.095, 0.045), Vector3(0, -0.03, 0.03), GOLD, Basis(Vector3.RIGHT, -0.3))  # grip
	_trigger_guard(st, Vector3(0, -0.002, -0.025), 0.05)
	# Receiver, bolt handle and the long barrel with a muzzle brake.
	_cylinder(st, 0.022, 0.022, 0.22, Vector3(0, 0.07, -0.04), GOLD_DARK, _along_z(), 12)
	_tube(st, Vector3(0.02, 0.07, 0.04), Vector3(0.06, 0.055, 0.05), 0.006, 0.006, GOLD_DARK)
	_cylinder(st, 0.012, 0.012, 0.02, Vector3(0.064, 0.054, 0.05), DARK, Basis(), 8)
	_cylinder(st, 0.012, 0.017, 0.56, Vector3(0, 0.062, -0.63), GOLD_DARK, _along_z(), 10)
	_cbox(st, Vector3(0.036, 0.03, 0.07), Vector3(0, 0.062, -0.94), DARK)
	for z in [-0.925, -0.955]:
		_box(st, Vector3(0.04, 0.008, 0.008), Vector3(0, 0.062, z), Color.BLACK)
	_box(st, Vector3(0.03, 0.022, 0.03), Vector3(0, 0.0, -0.06), DARK)                  # magazine
	# Folded bipod under the front.
	for x in [-0.014, 0.014]:
		_tube(st, Vector3(x, 0.01, -0.34), Vector3(x, 0.012, -0.58), 0.006, 0.006, DARK)
	# The scope: rings, tube, big front lens, eyepiece and turrets.
	for z in [-0.15, 0.03]:
		_cbox(st, Vector3(0.03, 0.085, 0.025), Vector3(0, 0.1, z), GOLD_DARK)
	_cylinder(st, 0.021, 0.021, 0.3, Vector3(0, 0.14, -0.06), DARK, _along_z(), 12)
	_cylinder(st, 0.034, 0.022, 0.08, Vector3(0, 0.14, -0.25), DARK, _along_z(), 12)
	_cylinder(st, 0.029, 0.029, 0.006, Vector3(0, 0.14, -0.292), LENS, _along_z(), 12)
	_cylinder(st, 0.022, 0.028, 0.06, Vector3(0, 0.14, 0.115), DARK, _along_z(), 12)
	_cylinder(st, 0.012, 0.012, 0.03, Vector3(0, 0.168, -0.06), GUNMETAL, Basis(), 8)
	_cylinder(st, 0.012, 0.012, 0.03, Vector3(0.028, 0.14, -0.06), GUNMETAL, Basis(Vector3.BACK, PI * 0.5), 8)
	return LowPoly.commit(st)


static func key() -> Mesh:
	var st := LowPoly.begin()
	var brass := Color(0.9, 0.72, 0.28)
	_cylinder(st, 0.035, 0.035, 0.012, Vector3(0, 0.01, 0.05), brass)          # bow (the ring)
	_box(st, Vector3(0.016, 0.012, 0.12), Vector3(0, 0.01, -0.03), brass)       # shaft
	_box(st, Vector3(0.016, 0.012, 0.03), Vector3(0.016, 0.01, -0.08), brass)   # teeth
	_box(st, Vector3(0.016, 0.012, 0.02), Vector3(0.014, 0.01, -0.05), brass)
	return LowPoly.commit(st)


# --- Parts used by several guns ---------------------------------------------------------------

## A loop under the gun around the trigger, and the trigger itself.
static func _trigger_guard(st: SurfaceTool, at: Vector3, length: float) -> void:
	_box(st, Vector3(0.01, 0.007, length), at + Vector3(0, -0.012, 0), DARK)
	_box(st, Vector3(0.01, 0.022, 0.007), at + Vector3(0, -0.002, -length * 0.5), DARK)
	_box(st, Vector3(0.006, 0.02, 0.007), at + Vector3(0, 0.0, 0.004), METAL, Basis(Vector3.RIGHT, 0.3))


## A flat rail with ridges along the top (for sights).
static func _rail(st: SurfaceTool, at: Vector3, length: float) -> void:
	_box(st, Vector3(0.024, 0.01, length), at, GUNMETAL)
	var count := int(length / 0.022)
	for i in count:
		_box(st, Vector3(0.028, 0.006, 0.008), at + Vector3(0, 0.006, -length * 0.5 + 0.011 + i * 0.022), DARK)


## A banana magazine: `segments` blocks going down and curving forward.
static func _curved_mag(st: SurfaceTool, top: Vector3, block: Vector3, segments: int, bend: float, color: Color) -> void:
	var at := top
	var angle := 0.0
	for i in segments:
		var rot := Basis(Vector3.RIGHT, angle)
		_cbox(st, block, at + rot * Vector3(0, -block.y * 0.5, 0), color, rot)
		at += rot * Vector3(0, -block.y * 0.92, 0)
		angle += bend


# --- Shapes ------------------------------------------------------------------------------------

static func _along_z() -> Basis:
	return Basis(Vector3.RIGHT, PI * 0.5)


static func _box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, rot: Basis = Basis()) -> void:
	var box := BoxMesh.new()
	box.size = size
	LowPoly.add_shape(st, box, Transform3D(rot, at), color, 0.0, 0.05)


## A box with its edges and corners cut off (bevelled), so it looks softer and less blocky.
static func _cbox(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, rot: Basis = Basis(), bevel: float = -1.0) -> void:
	var h := size * 0.5
	var c := bevel if bevel >= 0.0 else minf(minf(size.x, size.y), size.z) * 0.2
	var xform := Transform3D(rot, at)
	# p(axis, sx, sy, sz): the corner point of the face on `axis` for the corner with these signs.
	var p := func(axis: int, sx: float, sy: float, sz: float) -> Vector3:
		var v := Vector3(sx * (h.x - c), sy * (h.y - c), sz * (h.z - c))
		v[axis] = [sx, sy, sz][axis] * h[axis]
		return v
	var tri := func(a: Vector3, b: Vector3, d: Vector3) -> void:
		_face(st, xform * a, xform * b, xform * d, rot * (a + b + d))
	var quad := func(a: Vector3, b: Vector3, d: Vector3, e: Vector3) -> void:
		tri.call(a, b, d)
		tri.call(a, d, e)
	st.set_color(color)
	for s in [-1.0, 1.0]:
		# The six flat faces.
		quad.call(p.call(0, s, -1, -1), p.call(0, s, 1, -1), p.call(0, s, 1, 1), p.call(0, s, -1, 1))
		quad.call(p.call(1, -1, s, -1), p.call(1, 1, s, -1), p.call(1, 1, s, 1), p.call(1, -1, s, 1))
		quad.call(p.call(2, -1, -1, s), p.call(2, 1, -1, s), p.call(2, 1, 1, s), p.call(2, -1, 1, s))
	st.set_color(color.darkened(0.06))
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			# The twelve bevelled edges.
			quad.call(p.call(0, a, b, -1), p.call(0, a, b, 1), p.call(1, a, b, 1), p.call(1, a, b, -1))
			quad.call(p.call(0, a, -1, b), p.call(0, a, 1, b), p.call(2, a, 1, b), p.call(2, a, -1, b))
			quad.call(p.call(1, -1, a, b), p.call(1, 1, a, b), p.call(2, 1, a, b), p.call(2, -1, a, b))
			# The eight cut corners.
			for d in [-1.0, 1.0]:
				tri.call(p.call(0, a, b, d), p.call(1, a, b, d), p.call(2, a, b, d))


## A thin rod from a to b.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, color: Color) -> void:
	var along := b - a
	var up := along.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	_cylinder(st, rb, ra, along.length(), (a + b) * 0.5, color, basis, 6)


static func _cylinder(st: SurfaceTool, top: float, bottom: float, height: float, at: Vector3, color: Color, rot: Basis = Basis(), segments: int = 8) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = height
	tube.radial_segments = segments
	tube.rings = 1
	LowPoly.add_shape(st, tube, Transform3D(rot, at), color, 0.0, 0.05)


## A flat shape (outline in the Z/Y side view) given a thickness along X, e.g. a blade.
static func _prism(st: SurfaceTool, outline: Array, thickness: float, color: Color) -> void:
	var points := PackedVector2Array(outline)
	var caps := Geometry2D.triangulate_polygon(points)
	var x := thickness * 0.5
	var middle := Vector2.ZERO
	for q in points:
		middle += q / points.size()
	st.set_color(color)
	for side in [-1.0, 1.0]:
		for i in range(0, caps.size(), 3):
			var q := [points[caps[i]], points[caps[i + 1]], points[caps[i + 2]]]
			_face(st, Vector3(side * x, q[0].y, q[0].x), Vector3(side * x, q[1].y, q[1].x), Vector3(side * x, q[2].y, q[2].x), Vector3(side, 0, 0))
	st.set_color(color.darkened(0.1))
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var mid := (a + b) * 0.5 - middle
		var out := Vector3(0, mid.y, mid.x)
		var quad := [Vector3(x, a.y, a.x), Vector3(-x, a.y, a.x), Vector3(-x, b.y, b.x), Vector3(x, b.y, b.x)]
		_face(st, quad[0], quad[1], quad[2], out)
		_face(st, quad[0], quad[2], quad[3], out)


## One triangle, turned so its front faces `outward` (Godot draws clockwise triangles).
static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
