class_name ItemLibrary
## The list of every item in the game. Ask for an item by its id:
##     var stone := ItemLibrary.get_item(&"stone")
## To add a new item, add a line to _build_items().
## Items with a value can be fed to Captain Gus for cash (animal bodies).

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
	# Story items (see QuestLibrary).
	_add(&"first_aid_kit", "First-Aid Kit", Color(0.9, 0.2, 0.2), _first_aid_mesh(), Vector3(0.34, 0.16, 0.26))
	_items[&"first_aid_kit"].glows = true
	_add(&"cloth", "Cloth", Color(0.98, 0.9, 0.6), _cloth_mesh(), Vector3(0.3, 0.1, 0.3))
	_items[&"cloth"].glows = true
	# Weapons. Damage numbers are per hit (shotgun: per pellet). Animals: rabbit 30 hp,
	# chicken/squirrel 20, deer 80 (Island 2 ones are tougher).
	_weapon(&"knife", "Knife", Color(0.82, 0.84, 0.86), WeaponMeshes.knife(), Vector3(0.06, 0.05, 0.35),
			{use = "melee", damage = 25.0, reach = 2.7, fire_gap = 0.35, hold = "knife"})
	_weapon(&"pistol", "Pistol", Color(0.3, 0.32, 0.36), WeaponMeshes.pistol(), Vector3(0.06, 0.16, 0.24),
			{use = "gun", damage = 25.0, reach = 70.0, fire_gap = 0.22, magazine = 8, reload_time = 1.3, ammo = "pistol", spread = 1.0, recoil = 2.2, sound = "gun_pistol", hold = "pistol", price = 150})
	_weapon(&"double_barrel", "Double-Barrel Shotgun", Color(0.48, 0.3, 0.16), WeaponMeshes.double_barrel(), Vector3(0.08, 0.14, 0.95),
			{use = "gun", damage = 11.0, pellets = 8, reach = 32.0, fire_gap = 0.55, magazine = 2, reload_time = 2.2, ammo = "shells", spread = 6.0, recoil = 7.0, sound = "gun_shotgun", hold = "rifle", price = 400})
	_weapon(&"smg", "SMG", Color(0.2, 0.21, 0.24), WeaponMeshes.smg(), Vector3(0.07, 0.28, 0.4),
			{use = "gun", damage = 12.0, reach = 45.0, fire_gap = 0.075, automatic = true, magazine = 30, reload_time = 1.8, ammo = "smg", spread = 3.0, recoil = 0.9, sound = "gun_smg", hold = "pistol", price = 650})
	_weapon(&"assault_rifle", "Assault Rifle", Color(0.62, 0.52, 0.36), WeaponMeshes.assault_rifle(), Vector3(0.08, 0.25, 0.85),
			{use = "gun", damage = 20.0, reach = 95.0, fire_gap = 0.11, automatic = true, magazine = 30, reload_time = 2.0, ammo = "rifle", spread = 1.6, recoil = 1.25, sound = "gun_rifle", hold = "rifle", price = 900})
	_weapon(&"sniper", "Sniper Rifle", Color(0.86, 0.66, 0.2), WeaponMeshes.sniper(), Vector3(0.08, 0.22, 1.25),
			{use = "gun", damage = 130.0, reach = 260.0, fire_gap = 1.2, magazine = 5, reload_time = 2.6, ammo = "sniper", spread = 0.0, zoom_fov = 18.0, recoil = 8.0, sound = "gun_sniper", hold = "rifle", price = 1200})
	_weapon(&"flare_gun", "Flare Gun", Color(0.95, 0.42, 0.1), WeaponMeshes.flare_gun(), Vector3(0.06, 0.16, 0.24),
			{use = "flare", fire_gap = 1.5, recoil = 4.0, sound = "flare_shot", hold = "pistol"})
	_add(&"case_key", "Case Key", Color(0.9, 0.72, 0.28), WeaponMeshes.key(), Vector3(0.08, 0.04, 0.16))
	_items[&"case_key"].max_stack = 1
	_items[&"case_key"].glows = true
	_items[&"flare_gun"].glows = true
	# Parts of the plane's radar, scattered around the island (see QuestLibrary: scrap_hunt).
	_add(&"wire_bundle", "Wire Bundle", Color(0.95, 0.55, 0.15), _wire_mesh(), Vector3(0.3, 0.12, 0.3))
	_add(&"battery", "Battery", Color(0.3, 0.85, 0.4), _battery_mesh(), Vector3(0.22, 0.2, 0.14))
	_add(&"antenna", "Antenna", Color(0.45, 0.7, 1.0), _antenna_mesh(), Vector3(0.12, 0.12, 0.9))
	for id in [&"wire_bundle", &"battery", &"antenna"]:
		_items[id].glows = true
		_items[id].beacon = true
	# Animals: when one is hunted its body becomes this item. Feed it to Captain Gus for cash.
	# The price follows how hard the animal is to catch:
	#   chicken  20 hp, never runs away, slow             -> $6
	#   squirrel 20 hp, runs from 5 m, fast and tiny      -> $14
	#   rabbit   30 hp, runs from 5 m, fast               -> $18
	#   deer     80 hp (8 punches), runs from 10 m, fastest, only a few exist -> $60
	_add(&"chicken", "Chicken", Color(0.64, 0.4, 0.2), _carcass_mesh(&"chicken"), Vector3.ZERO, 6)
	_add(&"squirrel", "Squirrel", Color(0.7, 0.4, 0.18), _carcass_mesh(&"squirrel"), Vector3.ZERO, 14)
	_add(&"rabbit", "Rabbit", Color(0.6, 0.5, 0.4), _carcass_mesh(&"rabbit"), Vector3.ZERO, 18)
	_add(&"deer", "Deer", Color(0.58, 0.4, 0.25), _carcass_mesh(&"deer"), Vector3.ZERO, 60)
	# Island 2 (the jungle), priced the same way:
	#   toucan   15 hp, slow, runs from 4 m                         -> $12
	#   monkey   40 hp, fast, runs from 7 m                         -> $25
	#   boar    120 hp, charges back and bites when hit             -> $45
	#   jaguar  200 hp, hunts you on sight, fast, hits hard        -> $150
	_add(&"toucan", "Toucan", Color(0.98, 0.55, 0.12), _carcass_mesh(&"toucan"), Vector3.ZERO, 12)
	_add(&"monkey", "Monkey", Color(0.42, 0.28, 0.17), _carcass_mesh(&"monkey"), Vector3.ZERO, 25)
	_add(&"boar", "Boar", Color(0.32, 0.25, 0.22), _carcass_mesh(&"boar"), Vector3.ZERO, 45)
	_add(&"jaguar", "Jaguar", Color(0.88, 0.62, 0.22), _carcass_mesh(&"jaguar"), Vector3.ZERO, 150)
	for id in [&"chicken", &"squirrel", &"rabbit", &"deer", &"toucan", &"monkey", &"boar", &"jaguar"]:
		_items[id].icon_from_above = true
	# Captain Gus's cap, washed up on Island 2's beach.
	_add(&"gus_hat", "Captain Gus's Cap", Color(0.95, 0.95, 0.93), _cap_mesh(), Vector3(0.32, 0.14, 0.32))
	_items[&"gus_hat"].glows = true
	_items[&"gus_hat"].max_stack = 1


static func _add(id: StringName, display_name: String, icon_color: Color, mesh: Mesh, collision_size: Vector3, value: int = 0) -> void:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.icon_color = icon_color
	item.mesh = mesh
	# Vector3.ZERO = use the model's own size.
	item.collision_size = collision_size if collision_size != Vector3.ZERO else mesh.get_aabb().size
	item.value = value
	_items[id] = item


## Adds a weapon (one per slot) with its stats (see ItemData's "Using it" group).
static func _weapon(id: StringName, display_name: String, icon_color: Color, mesh: Mesh, collision_size: Vector3, stats: Dictionary) -> void:
	_add(id, display_name, icon_color, mesh, collision_size)
	var item: ItemData = _items[id]
	item.max_stack = 1
	for key in stats:
		item.set(key, stats[key])


## All weapons, for the shop and the HUD.
static func weapons() -> Array[ItemData]:
	if _items.is_empty():
		_build_items()
	var list: Array[ItemData] = []
	for item: ItemData in _items.values():
		if item.use == "gun" or item.use == "melee":
			list.append(item)
	return list


# --- Story items ------------------------------------------------------------------

## A red box with a white cross and a little handle.
static func _first_aid_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var st := LowPoly.begin()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.14, 0.2)
	LowPoly.add_shape(st, box, Transform3D(Basis(), Vector3(0, 0.07, 0)), Color(0.95, 0.95, 0.92), 0.0, 0.04, rng)
	var white := Color(0.85, 0.12, 0.12) # The cross is red on the white box.
	var bar_a := BoxMesh.new()
	bar_a.size = Vector3(0.1, 0.012, 0.03)
	var bar_b := BoxMesh.new()
	bar_b.size = Vector3(0.03, 0.012, 0.1)
	LowPoly.add_shape(st, bar_a, Transform3D(Basis(), Vector3(0, 0.146, 0)), white, 0.0, 0.0, rng)
	LowPoly.add_shape(st, bar_b, Transform3D(Basis(), Vector3(0, 0.146, 0)), white, 0.0, 0.0, rng)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.1, 0.03, 0.025)
	LowPoly.add_shape(st, handle, Transform3D(Basis(), Vector3(0, 0.15, 0.11)), Color(0.85, 0.12, 0.12), 0.0, 0.0, rng)
	return LowPoly.commit(st)


## A neatly folded cloth: three soft layers with blue stripes, so it reads as fabric.
static func _cloth_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var st := LowPoly.begin()
	var cream := Color(0.98, 0.92, 0.66) # Pale, easy to see in the grass.
	var blue := Color(0.32, 0.5, 0.82)
	var layer := BoxMesh.new()
	for i in 3:
		layer.size = Vector3(0.3 - i * 0.012, 0.03, 0.22 - i * 0.01)
		var turn := Basis(Vector3.UP, rng.randf_range(-0.08, 0.08))
		LowPoly.add_shape(st, layer, Transform3D(turn, Vector3(rng.randf_range(-0.008, 0.008), 0.016 + i * 0.03, 0)), cream.darkened(0.04 * (2 - i)), 0.006, 0.05, rng)
	# Rounded folded edge along the front.
	var fold := CylinderMesh.new()
	fold.top_radius = 0.045
	fold.bottom_radius = 0.045
	fold.height = 0.29
	fold.radial_segments = 8
	fold.rings = 1
	LowPoly.add_shape(st, fold, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.047, -0.105)), cream, 0.0, 0.04, rng)
	# Two blue stripes across the top.
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.028, 0.004, 0.2)
	for x in [-0.07, 0.07]:
		LowPoly.add_shape(st, stripe, Transform3D(Basis(), Vector3(x, 0.093, 0.0)), blue, 0.0, 0.0, rng)
	var band := CylinderMesh.new()
	band.top_radius = 0.047
	band.bottom_radius = 0.047
	band.height = 0.028
	band.radial_segments = 8
	band.rings = 1
	for x in [-0.07, 0.07]:
		LowPoly.add_shape(st, band, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.047, -0.105)), blue, 0.0, 0.0, rng)
	return LowPoly.commit(st)

## A coil of orange wire with loose ends.
static func _wire_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var st := LowPoly.begin()
	var coil := TorusMesh.new()
	coil.inner_radius = 0.07
	coil.outer_radius = 0.14
	coil.rings = 10
	coil.ring_segments = 6
	for i in 3:
		LowPoly.add_shape(st, coil, Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3(0, 0.04 + i * 0.045, 0)), Color(0.95, 0.5, 0.12).lightened(0.06 * i), 0.0, 0.06, rng)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.012
	tail.bottom_radius = 0.012
	tail.height = 0.22
	tail.radial_segments = 5
	tail.rings = 1
	LowPoly.add_shape(st, tail, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.2, 0.05, 0.06)), Color(0.95, 0.5, 0.12), 0.0, 0.0, rng)
	LowPoly.add_shape(st, tail, Transform3D(Basis(Vector3.BACK, PI * 0.5).rotated(Vector3.UP, 0.7), Vector3(-0.16, 0.12, 0.15)), Color(0.2, 0.6, 0.9), 0.0, 0.0, rng)
	return LowPoly.commit(st)


## A boxy battery with two terminals on top.
static func _battery_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	var st := LowPoly.begin()
	var body := BoxMesh.new()
	body.size = Vector3(0.2, 0.16, 0.12)
	LowPoly.add_shape(st, body, Transform3D(Basis(), Vector3(0, 0.08, 0)), Color(0.18, 0.2, 0.24), 0.0, 0.05, rng)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.202, 0.05, 0.122)
	LowPoly.add_shape(st, stripe, Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.95, 0.8, 0.15), 0.0, 0.0, rng)
	var terminal := CylinderMesh.new()
	terminal.top_radius = 0.02
	terminal.bottom_radius = 0.02
	terminal.height = 0.04
	terminal.radial_segments = 6
	terminal.rings = 1
	LowPoly.add_shape(st, terminal, Transform3D(Basis(), Vector3(-0.06, 0.18, 0)), Color(0.8, 0.8, 0.82), 0.0, 0.0, rng)
	LowPoly.add_shape(st, terminal, Transform3D(Basis(), Vector3(0.06, 0.18, 0)), Color(0.85, 0.2, 0.2), 0.0, 0.0, rng)
	return LowPoly.commit(st)


## A long metal rod with three cross pieces, lying along Z.
static func _antenna_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var st := LowPoly.begin()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.012
	rod.bottom_radius = 0.016
	rod.height = 0.9
	rod.radial_segments = 6
	rod.rings = 1
	var metal := Color(0.75, 0.77, 0.8)
	LowPoly.add_shape(st, rod, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.03, 0)), metal, 0.0, 0.06, rng)
	var bar := BoxMesh.new()
	for i in 3:
		bar.size = Vector3(0.26 - i * 0.06, 0.012, 0.012)
		LowPoly.add_shape(st, bar, Transform3D(Basis(), Vector3(0, 0.03, -0.25 + i * 0.16)), metal, 0.0, 0.04, rng)
	var base := BoxMesh.new()
	base.size = Vector3(0.1, 0.05, 0.1)
	LowPoly.add_shape(st, base, Transform3D(Basis(), Vector3(0, 0.03, 0.4)), Color(0.2, 0.22, 0.26), 0.0, 0.04, rng)
	return LowPoly.commit(st)


# --- Animal bodies ---------------------------------------------------------------
# A hunted animal becomes an item that looks exactly like the animal you hunted:
# its own model (the same one that walks around), lying on its side. Big animals are
# shrunk a little so they can be carried. Faces -Z (points forward when held).

## How much each animal is shrunk when it becomes an item.
const CARRY_SCALE := {&"deer": 0.62, &"boar": 0.62, &"jaguar": 0.55, &"monkey": 0.85}


static func _carcass_mesh(kind: StringName) -> Mesh:
	var species: GDScript
	match kind:
		&"rabbit": species = Rabbit
		&"chicken": species = Chicken
		&"squirrel": species = Squirrel
		&"deer": species = Deer
		&"toucan": species = Toucan
		&"monkey": species = Monkey
		&"boar": species = Boar
		&"jaguar": species = Jaguar
	# Build the animal's model without putting the animal in the world.
	var animal: Animal = species.new()
	animal._rng.seed = 7 # Always the same colours for the item.
	var root := Node3D.new()
	animal._build_model(root)
	# Lying on its side, legs pointing out sideways.
	var scale: float = CARRY_SCALE.get(kind, 1.0)
	var lying := Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_merge_meshes(st, root, lying)
	root.free()
	animal.free()
	var merged := st.commit()
	# Centre it, so it matches the pick-up box (which is centred) and lies on the grass.
	var shift := -merged.get_aabb().get_center()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(merged, 0, Transform3D(Basis(), shift))
	return LowPoly.commit_smooth(st)


## Adds every mesh under `node` (all the animal's body parts) into one mesh.
static func _merge_meshes(st: SurfaceTool, node: Node, parent_transform: Transform3D) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_transform: Transform3D = parent_transform * (child as Node3D).transform
		if child is MeshInstance3D and child.mesh != null:
			st.append_from(child.mesh, 0, child_transform)
		_merge_meshes(st, child, child_transform)

## Captain Gus's white cap with its black band, visor and gold badge.
static func _cap_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var st := LowPoly.begin()
	var top := CylinderMesh.new()
	top.top_radius = 0.15
	top.bottom_radius = 0.135
	top.height = 0.09
	top.radial_segments = 12
	top.rings = 1
	LowPoly.add_shape(st, top, Transform3D(Basis(), Vector3(0, 0.08, 0)), Color(0.95, 0.95, 0.93), 0.0, 0.04, rng)
	var band := CylinderMesh.new()
	band.top_radius = 0.14
	band.bottom_radius = 0.14
	band.height = 0.035
	band.radial_segments = 12
	band.rings = 1
	LowPoly.add_shape(st, band, Transform3D(Basis(), Vector3(0, 0.03, 0)), Color(0.12, 0.13, 0.18), 0.0, 0.02, rng)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.18, 0.018, 0.1)
	LowPoly.add_shape(st, visor, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.02, -0.15)), Color(0.08, 0.08, 0.09), 0.0, 0.0, rng)
	var badge := BoxMesh.new()
	badge.size = Vector3(0.06, 0.045, 0.018)
	LowPoly.add_shape(st, badge, Transform3D(Basis(), Vector3(0, 0.075, -0.145)), Color(0.95, 0.76, 0.25), 0.0, 0.0, rng)
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


## A sturdy branch: bark, a lighter cut end, a knot and two side twigs. Lies along Z.
static func _stick_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var st := LowPoly.begin()
	var bark := PropLibrary.TRUNK_COLOR
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	var shape := CylinderMesh.new()
	shape.top_radius = 0.032
	shape.bottom_radius = 0.042
	shape.height = 0.7
	shape.radial_segments = 7
	shape.rings = 3
	LowPoly.add_shape(st, shape, Transform3D(along_z, Vector3.ZERO), bark, 0.006, 0.12, rng)
	# Light wood where it snapped off, at the back end.
	var cut := CylinderMesh.new()
	cut.top_radius = 0.038
	cut.bottom_radius = 0.038
	cut.height = 0.012
	cut.radial_segments = 7
	cut.rings = 1
	LowPoly.add_shape(st, cut, Transform3D(along_z, Vector3(0, 0, 0.352)), PropLibrary.WOOD_COLOR, 0.0, 0.05, rng)
	# A knot in the bark.
	var knot := SphereMesh.new()
	knot.radius = 0.022
	knot.height = 0.044
	knot.radial_segments = 6
	knot.rings = 3
	LowPoly.add_shape(st, knot, Transform3D(Basis(), Vector3(0.03, 0.012, 0.08)), bark.darkened(0.2), 0.0, 0.05, rng)
	# Two twigs branching off toward the front.
	var twig := CylinderMesh.new()
	twig.top_radius = 0.007
	twig.bottom_radius = 0.016
	twig.height = 0.18
	twig.radial_segments = 5
	twig.rings = 1
	for side in [-1.0, 1.0]:
		var base := Vector3(0.025 * side, 0.0, -0.06 if side > 0 else 0.15)
		var turn := Basis(Vector3.UP, 0.7 * side) * along_z
		LowPoly.add_shape(st, twig, Transform3D(turn, base + turn * Vector3(0, 0.09, 0)), bark, 0.0, 0.1, rng)
	return LowPoly.commit(st)