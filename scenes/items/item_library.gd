class_name ItemLibrary
## The list of every item in the game. Ask for an item by its id:
##     var stone := ItemLibrary.get_item(&"stone")
## To add a new item, add a line to _build_items().
## Items with a value can be sold to Captain Gus (animal bodies).

static var _items: Dictionary = {}


static func has_item(id: StringName) -> bool:
	if _items.is_empty():
		_build_items()
	return _items.has(id)


static func get_item(id: StringName) -> ItemData:
	if _items.is_empty():
		_build_items()
	if not _items.has(id):
		push_error("Unknown item id: %s" % id)
		return null
	return _items[id]


static func _build_items() -> void:
	_add(&"stone", "Stone", Color(0.6, 0.6, 0.58), _stone_mesh(), Vector3(0.25, 0.18, 0.22))
	_add(&"stick", "Stick", Color(0.55, 0.38, 0.22), _stick_mesh(), Vector3(0.12, 0.12, 0.7))
	# Animals: when one is hunted its body becomes this item. Take it to Captain Gus to sell.
	_add(&"rabbit", "Rabbit", Color(0.6, 0.5, 0.4), _carcass_mesh(&"rabbit"), Vector3(0.3, 0.2, 0.5), 10)
	_add(&"chicken", "Chicken", Color(0.64, 0.4, 0.2), _carcass_mesh(&"chicken"), Vector3(0.4, 0.2, 0.4), 8)
	_add(&"squirrel", "Squirrel", Color(0.7, 0.4, 0.18), _carcass_mesh(&"squirrel"), Vector3(0.3, 0.15, 0.55), 8)
	_add(&"deer", "Deer", Color(0.58, 0.4, 0.25), _carcass_mesh(&"deer"), Vector3(0.7, 0.3, 1.0), 40)


static func _add(id: StringName, display_name: String, icon_color: Color, mesh: Mesh, collision_size: Vector3, value: int = 0) -> void:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.icon_color = icon_color
	item.mesh = mesh
	item.collision_size = collision_size
	item.value = value
	_items[id] = item


# --- Animal bodies ---------------------------------------------------------------
# Each is a small soft model lying on its side, facing -Z (so it points forward when held).

static func _carcass_mesh(kind: StringName) -> Mesh:
	var st := LowPoly.begin()
	var eye := Color(0.1, 0.09, 0.09)
	match kind:
		&"rabbit":
			var fur := Color(0.6, 0.5, 0.4)
			LowPoly.add_blob(st, Vector3(0, 0.1, 0), Vector3(0.1, 0.09, 0.2), fur)
			LowPoly.add_blob(st, Vector3(0, 0.1, -0.22), Vector3(0.07, 0.07, 0.09), fur)
			LowPoly.add_blob(st, Vector3(0, 0.06, -0.3), Vector3(0.025, 0.02, 0.02), Color(0.93, 0.66, 0.66))
			LowPoly.add_blob(st, Vector3(0, 0.1, 0.2), Vector3(0.045, 0.045, 0.045), Color(0.96, 0.95, 0.93))
			for side in [-1.0, 1.0]:
				LowPoly.add_tube(st, Vector3(0.03 * side, 0.15, -0.2), Vector3(0.05 * side, 0.12, -0.02), 0.022, 0.016, fur.darkened(0.08))
				LowPoly.add_tube(st, Vector3(0.07 * side, 0.08, 0.12), Vector3(0.18 * side, 0.06, 0.16), 0.04, 0.025, fur)
				LowPoly.add_tube(st, Vector3(0.06 * side, 0.08, -0.12), Vector3(0.15 * side, 0.06, -0.17), 0.028, 0.02, fur)
				LowPoly.add_blob(st, Vector3(0.05 * side, 0.115, -0.26), Vector3(0.012, 0.012, 0.012), eye)
		&"chicken":
			var feathers := Color(0.64, 0.4, 0.2)
			LowPoly.add_blob(st, Vector3(0, 0.1, 0), Vector3(0.1, 0.09, 0.14), feathers)
			LowPoly.add_blob(st, Vector3(0, 0.1, -0.1), Vector3(0.085, 0.08, 0.08), feathers.lightened(0.05))
			LowPoly.add_tube(st, Vector3(0, 0.1, -0.12), Vector3(0, 0.09, -0.2), 0.045, 0.035, feathers)
			LowPoly.add_blob(st, Vector3(0, 0.09, -0.22), Vector3(0.04, 0.045, 0.045), feathers)
			LowPoly.add_blob(st, Vector3(0, 0.14, -0.22), Vector3(0.012, 0.025, 0.03), Color(0.85, 0.15, 0.12))
			LowPoly.add_tube(st, Vector3(0, 0.085, -0.255), Vector3(0, 0.08, -0.29), 0.014, 0.004, Color(0.95, 0.62, 0.15))
			for i in 3:
				var angle := (i - 1) * 0.5
				LowPoly.add_tube(st, Vector3(0, 0.12, 0.12), Vector3(sin(angle) * 0.1, 0.17, 0.25), 0.04, 0.02, feathers.darkened(0.06 + 0.03 * i))
			for side in [-1.0, 1.0]:
				LowPoly.add_blob(st, Vector3(0.095 * side, 0.115, 0.0), Vector3(0.03, 0.07, 0.1), feathers.darkened(0.08))
				LowPoly.add_tube(st, Vector3(0.04 * side, 0.07, 0.04), Vector3(0.2 * side, 0.07, 0.06), 0.014, 0.009, Color(0.95, 0.62, 0.15))
				LowPoly.add_blob(st, Vector3(0.04 * side, 0.115, -0.21), Vector3(0.009, 0.009, 0.009), eye)
		&"squirrel":
			var fur := Color(0.7, 0.4, 0.18)
			LowPoly.add_blob(st, Vector3(0, 0.065, 0), Vector3(0.065, 0.06, 0.12), fur)
			LowPoly.add_blob(st, Vector3(0, 0.065, -0.14), Vector3(0.05, 0.05, 0.06), fur)
			LowPoly.add_blob(st, Vector3(0, 0.04, -0.19), Vector3(0.018, 0.016, 0.016), Color(0.25, 0.15, 0.12))
			LowPoly.add_tube(st, Vector3(0, 0.06, 0.1), Vector3(0.05, 0.07, 0.22), 0.03, 0.05, fur.lightened(0.04))
			LowPoly.add_tube(st, Vector3(0.05, 0.07, 0.22), Vector3(0.14, 0.07, 0.3), 0.05, 0.06, fur.lightened(0.08))
			for side in [-1.0, 1.0]:
				LowPoly.add_blob(st, Vector3(0.035 * side, 0.105, -0.17), Vector3(0.012, 0.025, 0.012), fur.darkened(0.12))
				LowPoly.add_tube(st, Vector3(0.05 * side, 0.05, 0.06), Vector3(0.12 * side, 0.04, 0.08), 0.03, 0.018, fur)
				LowPoly.add_tube(st, Vector3(0.04 * side, 0.05, -0.07), Vector3(0.1 * side, 0.04, -0.1), 0.02, 0.014, fur)
				LowPoly.add_blob(st, Vector3(0.03 * side, 0.08, -0.17), Vector3(0.009, 0.009, 0.009), eye)
		&"deer":
			var fur := Color(0.58, 0.4, 0.25)
			var light := Color(0.9, 0.84, 0.72)
			var k := 0.7 # Shrunk a little so it is carryable.
			LowPoly.add_blob(st, Vector3(0, 0.2, 0) * k, Vector3(0.2, 0.18, 0.45) * k, fur)
			LowPoly.add_blob(st, Vector3(0, 0.14, 0) * k, Vector3(0.17, 0.12, 0.4) * k, light)
			LowPoly.add_tube(st, Vector3(0, 0.2, -0.3) * k, Vector3(0, 0.15, -0.55) * k, 0.12 * k, 0.07 * k, fur)
			LowPoly.add_blob(st, Vector3(0, 0.14, -0.62) * k, Vector3(0.085, 0.08, 0.13) * k, fur)
			LowPoly.add_tube(st, Vector3(0, 0.12, -0.7) * k, Vector3(0, 0.1, -0.8) * k, 0.055 * k, 0.04 * k, light)
			LowPoly.add_blob(st, Vector3(0, 0.1, -0.82) * k, Vector3(0.028, 0.025, 0.025) * k, Color(0.15, 0.12, 0.1))
			LowPoly.add_tube(st, Vector3(0, 0.2, 0.42) * k, Vector3(0, 0.26, 0.54) * k, 0.04 * k, 0.03 * k, light)
			for side in [-1.0, 1.0]:
				LowPoly.add_tube(st, Vector3(0.07 * side, 0.2, -0.63) * k, Vector3(0.14 * side, 0.26, -0.6) * k, 0.03 * k, 0.012 * k, fur)
				LowPoly.add_blob(st, Vector3(0.07 * side, 0.17, -0.66) * k, Vector3(0.02, 0.02, 0.02) * k, eye)
				for z in [-0.28, 0.3]:
					LowPoly.add_tube(st, Vector3(0.15 * side, 0.2, z) * k, Vector3(0.38 * side, 0.18, z * 1.05) * k, 0.07 * k, 0.04 * k, fur)
					LowPoly.add_tube(st, Vector3(0.38 * side, 0.18, z * 1.05) * k, Vector3(0.5 * side, 0.14, z * 1.1) * k, 0.04 * k, 0.028 * k, fur.darkened(0.08))
					LowPoly.add_blob(st, Vector3(0.52 * side, 0.14, z * 1.1) * k, Vector3(0.03, 0.03, 0.045) * k, Color(0.15, 0.12, 0.1))
	return LowPoly.commit_smooth(st)


static func _stone_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := LowPoly.begin()
	var shape := SphereMesh.new()
	shape.radius = 0.13
	shape.height = 0.26
	shape.radial_segments = 6
	shape.rings = 4
	LowPoly.add_shape(st, shape, Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 0.85)), Vector3.ZERO), PropLibrary.ROCK_COLOR, 0.03, 0.12, rng)
	return LowPoly.commit(st)


static func _stick_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var st := LowPoly.begin()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.025
	shape.bottom_radius = 0.035
	shape.height = 0.7
	shape.radial_segments = 5
	shape.rings = 1
	# Lie along Z so it points forward when held.
	LowPoly.add_shape(st, shape, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), PropLibrary.TRUNK_COLOR, 0.0, 0.1, rng)
	var twig := CylinderMesh.new()
	twig.top_radius = 0.008
	twig.bottom_radius = 0.015
	twig.height = 0.18
	twig.radial_segments = 4
	twig.rings = 1
	LowPoly.add_shape(st, twig, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.6), Vector3(0.04, 0.0, 0.1)), PropLibrary.TRUNK_COLOR, 0.0, 0.1, rng)
	return LowPoly.commit(st)
