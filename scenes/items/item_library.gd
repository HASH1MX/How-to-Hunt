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
	# Animal loot (sold to the merchant later).
	_add(&"rabbit_pelt", "Rabbit Pelt", Color(0.62, 0.52, 0.42),
			_pelt_mesh(Vector3(0.32, 0.05, 0.4), Color(0.62, 0.52, 0.42), Color(0.82, 0.76, 0.68), 33), Vector3(0.3, 0.08, 0.38), 8)
	_add(&"feathers", "Feathers", Color(0.96, 0.95, 0.9), _feathers_mesh(), Vector3(0.25, 0.08, 0.25), 5)
	_add(&"squirrel_tail", "Squirrel Tail", Color(0.78, 0.45, 0.2), _tail_mesh(), Vector3(0.2, 0.2, 0.3), 6)
	_add(&"deer_hide", "Deer Hide", Color(0.58, 0.4, 0.25),
			_pelt_mesh(Vector3(0.65, 0.07, 0.8), Color(0.58, 0.4, 0.25), Color(0.9, 0.85, 0.75), 34), Vector3(0.6, 0.1, 0.75), 30)


static func _add(id: StringName, display_name: String, icon_color: Color, mesh: Mesh, collision_size: Vector3, value: int = 0) -> void:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.icon_color = icon_color
	item.mesh = mesh
	item.collision_size = collision_size
	item.value = value
	_items[id] = item


# --- Animal loot ---------------------------------------------------------------

## A soft, flat, slightly wobbly pelt.
static func _pelt_mesh(size: Vector3, color: Color, spot_color: Color, model_seed: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = model_seed
	var st := LowPoly.begin()
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 8
	shape.rings = 3
	LowPoly.add_shape(st, shape, Transform3D(Basis.from_scale(size), Vector3.ZERO), color, size.x * 0.12, 0.1, rng)
	for i in 3:
		var spot := Vector3(rng.randf_range(-0.25, 0.25) * size.x, size.y * 0.42, rng.randf_range(-0.25, 0.25) * size.z)
		LowPoly.add_shape(st, shape, Transform3D(Basis.from_scale(Vector3(size.x * 0.25, size.y * 0.2, size.z * 0.22)), spot), spot_color, 0.0, 0.05, rng)
	return LowPoly.commit(st)


## A small bundle of feathers.
static func _feathers_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var st := LowPoly.begin()
	var feather := SphereMesh.new()
	feather.radius = 0.5
	feather.height = 1.0
	feather.radial_segments = 6
	feather.rings = 3
	for i in 4:
		var angle := -0.6 + i * 0.4
		var rot := Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(0.05, 0.015, 0.22))
		LowPoly.add_shape(st, feather, Transform3D(rot, Vector3(0, i * 0.012, 0)), Color(0.96, 0.95, 0.9), 0.0, 0.06, rng)
	return LowPoly.commit(st)


## A fluffy orange squirrel tail.
static func _tail_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	var st := LowPoly.begin()
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 7
	puff.rings = 4
	for i in 4:
		var t := i / 3.0
		var at := Vector3(0, sin(t * 2.2) * 0.06, -0.1 + t * 0.2)
		LowPoly.add_shape(st, puff, Transform3D(Basis.from_scale(Vector3.ONE * lerpf(0.09, 0.12, t)), at), Color(0.78, 0.45, 0.2), 0.008, 0.1, rng)
	return LowPoly.commit(st)


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
