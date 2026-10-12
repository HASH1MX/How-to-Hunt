class_name ItemLibrary
## The list of every item in the game. Ask for an item by its id:
##     var stone := ItemLibrary.get_item(&"stone")
## To add a new item, add a line to _build_items().
## (Stone and stick are placeholder items for testing the inventory.)

static var _items: Dictionary = {}


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


static func _add(id: StringName, display_name: String, icon_color: Color, mesh: Mesh, collision_size: Vector3) -> void:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.icon_color = icon_color
	item.mesh = mesh
	item.collision_size = collision_size
	_items[id] = item


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
