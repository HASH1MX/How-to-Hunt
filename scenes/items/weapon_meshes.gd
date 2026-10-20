class_name WeaponMeshes
## Low-poly, flat-shaded models of every weapon, in the How to Fish style (simple chunky
## shapes, solid colours). Each points forward along -Z with the grip at the origin, so it
## sits in the hand ready to fire.

const DARK := Color(0.16, 0.17, 0.19)
const METAL := Color(0.45, 0.47, 0.5)
const WOOD := Color(0.48, 0.3, 0.16)
const GOLD := Color(0.76, 0.56, 0.2)
const BLADE := Color(0.82, 0.84, 0.86)


static func knife() -> Mesh:
	var st := LowPoly.begin()
	_box(st, Vector3(0.035, 0.05, 0.13), Vector3(0, 0, 0.02), DARK)            # handle
	_box(st, Vector3(0.09, 0.025, 0.02), Vector3(0, 0.005, -0.05), METAL)       # guard
	_box(st, Vector3(0.012, 0.04, 0.17), Vector3(0, 0.008, -0.145), BLADE)      # blade
	_box(st, Vector3(0.011, 0.028, 0.06), Vector3(0, 0.0, -0.24), BLADE, Basis(Vector3.RIGHT, 0.45))  # pointed tip
	return LowPoly.commit(st)


static func pistol() -> Mesh:
	var st := LowPoly.begin()
	_box(st, Vector3(0.045, 0.05, 0.22), Vector3(0, 0.06, -0.06), DARK)        # slide
	_box(st, Vector3(0.04, 0.03, 0.2), Vector3(0, 0.025, -0.05), METAL)        # frame
	_box(st, Vector3(0.04, 0.12, 0.055), Vector3(0, -0.035, 0.03), DARK, Basis(Vector3.RIGHT, -0.25))  # grip
	_box(st, Vector3(0.012, 0.02, 0.012), Vector3(0, 0.092, -0.16), METAL)     # front sight
	return LowPoly.commit(st)


static func flare_gun() -> Mesh:
	var st := LowPoly.begin()
	var orange := Color(0.95, 0.42, 0.1)
	_cylinder(st, 0.035, 0.035, 0.2, Vector3(0, 0.055, -0.07), orange, Basis(Vector3.RIGHT, PI * 0.5))  # fat barrel
	_box(st, Vector3(0.04, 0.04, 0.08), Vector3(0, 0.035, 0.03), orange)
	_box(st, Vector3(0.04, 0.12, 0.05), Vector3(0, -0.035, 0.04), orange.darkened(0.2), Basis(Vector3.RIGHT, -0.25))
	_box(st, Vector3(0.015, 0.03, 0.03), Vector3(0, -0.0, 0.0), DARK)          # trigger guard
	return LowPoly.commit(st)


static func double_barrel() -> Mesh:
	var st := LowPoly.begin()
	for x in [-0.022, 0.022]:
		_cylinder(st, 0.02, 0.02, 0.62, Vector3(x, 0.05, -0.36), METAL, Basis(Vector3.RIGHT, PI * 0.5))
	_box(st, Vector3(0.07, 0.05, 0.28), Vector3(0, 0.02, -0.15), WOOD)          # fore-end
	_box(st, Vector3(0.06, 0.07, 0.1), Vector3(0, 0.03, 0.02), METAL)            # action
	_box(st, Vector3(0.05, 0.1, 0.3), Vector3(0, -0.02, 0.2), WOOD, Basis(Vector3.RIGHT, 0.18))  # stock
	return LowPoly.commit(st)


static func smg() -> Mesh:
	var st := LowPoly.begin()
	_box(st, Vector3(0.06, 0.08, 0.3), Vector3(0, 0.05, -0.08), DARK)           # body
	_cylinder(st, 0.014, 0.014, 0.1, Vector3(0, 0.06, -0.28), METAL, Basis(Vector3.RIGHT, PI * 0.5))
	_box(st, Vector3(0.04, 0.2, 0.05), Vector3(0, -0.07, -0.05), DARK.lightened(0.08))  # magazine in the grip
	_box(st, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.03, 0.04), DARK, Basis(Vector3.RIGHT, -0.15))
	_box(st, Vector3(0.012, 0.025, 0.012), Vector3(0, 0.1, -0.2), METAL)
	return LowPoly.commit(st)


static func assault_rifle() -> Mesh:
	var st := LowPoly.begin()
	var tan := Color(0.62, 0.52, 0.36)
	_box(st, Vector3(0.06, 0.09, 0.42), Vector3(0, 0.05, -0.12), DARK)          # receiver
	_cylinder(st, 0.016, 0.016, 0.3, Vector3(0, 0.06, -0.48), METAL, Basis(Vector3.RIGHT, PI * 0.5))
	_box(st, Vector3(0.065, 0.06, 0.2), Vector3(0, 0.04, -0.3), tan)             # handguard
	_box(st, Vector3(0.04, 0.16, 0.06), Vector3(0, -0.08, -0.12), DARK, Basis(Vector3.RIGHT, 0.2))  # curved magazine
	_box(st, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.03, 0.04), DARK, Basis(Vector3.RIGHT, -0.2))   # grip
	_box(st, Vector3(0.05, 0.08, 0.24), Vector3(0, 0.03, 0.22), tan)             # stock
	_box(st, Vector3(0.03, 0.04, 0.12), Vector3(0, 0.115, -0.08), DARK)          # carry sight
	return LowPoly.commit(st)


## A golden sniper rifle with a big black scope (like the one in How to Fish).
static func sniper() -> Mesh:
	var st := LowPoly.begin()
	_box(st, Vector3(0.06, 0.08, 0.5), Vector3(0, 0.04, -0.12), GOLD)           # body
	_cylinder(st, 0.018, 0.02, 0.55, Vector3(0, 0.055, -0.62), GOLD.darkened(0.1), Basis(Vector3.RIGHT, PI * 0.5))
	_box(st, Vector3(0.04, 0.14, 0.06), Vector3(0, -0.06, -0.06), GOLD.darkened(0.15))  # magazine
	_box(st, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.03, 0.08), GOLD, Basis(Vector3.RIGHT, -0.2))
	_box(st, Vector3(0.055, 0.1, 0.28), Vector3(0, 0.02, 0.28), GOLD)            # stock
	_cylinder(st, 0.035, 0.03, 0.34, Vector3(0, 0.15, -0.12), DARK, Basis(Vector3.RIGHT, PI * 0.5))  # scope
	_cylinder(st, 0.045, 0.045, 0.05, Vector3(0, 0.15, -0.3), DARK, Basis(Vector3.RIGHT, PI * 0.5))
	for z in [-0.18, -0.04]:
		_box(st, Vector3(0.03, 0.05, 0.02), Vector3(0, 0.1, z), GOLD.darkened(0.2))
	return LowPoly.commit(st)


static func key() -> Mesh:
	var st := LowPoly.begin()
	var brass := Color(0.9, 0.72, 0.28)
	_cylinder(st, 0.035, 0.035, 0.012, Vector3(0, 0.01, 0.05), brass)          # bow (the ring)
	_box(st, Vector3(0.016, 0.012, 0.12), Vector3(0, 0.01, -0.03), brass)       # shaft
	_box(st, Vector3(0.016, 0.012, 0.03), Vector3(0.016, 0.01, -0.08), brass)   # teeth
	_box(st, Vector3(0.016, 0.012, 0.02), Vector3(0.014, 0.01, -0.05), brass)
	return LowPoly.commit(st)


# --- Helpers ---------------------------------------------------------------------------------

static func _box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, rot: Basis = Basis()) -> void:
	var box := BoxMesh.new()
	box.size = size
	LowPoly.add_shape(st, box, Transform3D(rot, at), color, 0.0, 0.05)


static func _cylinder(st: SurfaceTool, top: float, bottom: float, height: float, at: Vector3, color: Color, rot: Basis = Basis()) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = height
	tube.radial_segments = 8
	tube.rings = 1
	LowPoly.add_shape(st, tube, Transform3D(rot, at), color, 0.0, 0.05)
