extends IslandWorld
## Island 2: the Jungle. The rescue helicopter crashed into the sea nearby; the players wake
## up on the beach with Nurse Nina, the only other survivor. Palm jungle full of tougher
## animals: toucans, monkeys, boars that bite back, and a jaguar that hunts you.
## Tomas's trading post on the beach sells guns and ammo and buys animal bodies (crate).
## Story: see NinaStory and QuestLibrary (washed_ashore -> gus_memorial -> jungle_trade ->
## apex_predator).

## Which way along the coast the beach camp is (degrees around the island).
const CAMP_ANGLE := 90.0

var _beach := Vector3.ZERO
var _along := Vector3.RIGHT
var _inland := Vector3.FORWARD


func _island_ready() -> void:
	_find_beach()
	# Keep the camp clear of palms and bushes.
	var scatter: ForestScatter = $ForestScatter
	for spot in [_beach, _beach + _along * 14.0 + _inland * 5.0, _beach - _along * 3.0]:
		scatter.clear_area(Vector2(spot.x, spot.z), 9.0)
	# Players wake up on the sand, facing inland.
	spawn_point.position = _beach + Vector3(0, 0.6, 0)
	spawn_point.rotation.y = atan2(-_inland.x, -_inland.z)
	_put($Nina, _beach + _along * 3.0 + _inland * 1.0, -_along)
	_put($Trader, _beach + _along * 14.0 + _inland * 4.0, -_inland)
	var shack := _build_shack()
	shack.position = _ground(_beach + _along * 14.0 + _inland * 6.0)
	shack.rotation.y = atan2(_inland.x, _inland.z)
	var crate := SellCrate.new()
	crate.name = "SellCrate"
	add_child(crate)
	crate.position = _ground(_beach + _along * 11.0 + _inland * 2.5)
	crate.rotation.y = atan2(_inland.x, _inland.z)
	var memorial := GusMemorial.new()
	memorial.name = "Memorial"
	add_child(memorial)
	memorial.position = _ground(_beach - _along * 3.0 + _inland * 0.5)
	_scatter_wreckage()


## Finds a stretch of dry sand on the south shore (just above the water).
func _find_beach() -> void:
	var angle := deg_to_rad(CAMP_ANGLE)
	var out := Vector3(cos(angle), 0, sin(angle))
	var best := out * terrain.coast_radius
	for step in 120:
		var r := terrain.coast_radius + 10.0 - step * 0.5
		var x := out.x * r
		var z := out.z * r
		var h := terrain.get_height(x, z)
		if h > terrain.water_level + 0.7 and h < terrain.water_level + 2.0:
			best = Vector3(x, h, z)
			break
	_beach = best
	_inland = -out
	_along = Vector3(-out.z, 0, out.x)


func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, terrain.get_height(at.x, at.z), at.z)


func _put(node: Node3D, at: Vector3, facing: Vector3) -> void:
	node.position = _ground(at) - Vector3(0, 0.03, 0)
	node.rotation.y = atan2(-facing.x, -facing.z)


func _make_animal_spawner() -> AnimalSpawner:
	var spawner := AnimalSpawner.new()
	spawner.counts = {Toucan: 16, Monkey: 18, Boar: 10, Jaguar: 3}
	spawner.shy_species = [Jaguar, Boar]
	spawner.min_distance = 25.0
	spawner.max_distance = 130.0
	return spawner


## Captain Gus's cap lies on the sand further along the beach until it's brought to Nina.
func _place_story_items() -> void:
	if Network.is_online() and not Network.is_host():
		return
	if Quests.is_done("gus_memorial") or Quests.get_progress("gus_memorial", 0) > 0:
		return
	WorldSync.spawn_item(self, ItemLibrary.get_item(&"gus_hat"), _ground(_beach - _along * 22.0 - _inland * 2.0) + Vector3(0, 0.4, 0), Vector3.ZERO)


func _game_started() -> void:
	# Coming round after the crash: fade in from black.
	var layer := CanvasLayer.new()
	layer.layer = 60
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(black, "color:a", 0.0, 2.5)
	tween.tween_callback(layer.queue_free)
	if hud != null:
		hud.show_tip("Island 2: The Jungle", "You washed up on a strange island. Someone is standing on the beach nearby...", 12.0)


## Bits of the helicopter on the beach: a rotor blade, a red-cross door, scraps.
func _scatter_wreckage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var st := LowPoly.begin()
	var pieces := [
		[Vector3(0.35, 0.05, 4.5), Helicopter.WHITE.darkened(0.3), 0.0],
		[Vector3(1.2, 0.1, 0.9), Helicopter.WHITE, 0.2],
		[Vector3(0.6, 0.08, 0.5), Helicopter.RED, 0.1],
		[Vector3(0.9, 0.06, 0.4), Helicopter.WHITE, 0.15],
	]
	for i in pieces.size():
		var at := _ground(_beach + _along * rng.randf_range(-12.0, 8.0) - _inland * rng.randf_range(1.0, 3.5))
		var box := BoxMesh.new()
		box.size = pieces[i][0]
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, pieces[i][2])
		LowPoly.add_shape(st, box, Transform3D(basis, at + Vector3(0, 0.05, 0)), pieces[i][1], 0.01, 0.06, rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	add_child(mesh)


## Tomas's trading post: a little wooden stall with a striped roof and a counter.
func _build_shack() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 212
	var holder := Node3D.new()
	holder.name = "TradingPost"
	add_child(holder)
	var st := LowPoly.begin()
	var wood := PropLibrary.WOOD_COLOR
	var post := BoxMesh.new()
	post.size = Vector3(0.18, 2.6, 0.18)
	for x in [-1.8, 1.8]:
		for z in [-1.2, 1.2]:
			LowPoly.add_shape(st, post, Transform3D(Basis(), Vector3(x, 1.3, z)), wood.darkened(0.2), 0.01, 0.06, rng)
	var counter := BoxMesh.new()
	counter.size = Vector3(3.6, 1.0, 0.5)
	LowPoly.add_shape(st, counter, Transform3D(Basis(), Vector3(0, 0.5, -1.0)), wood, 0.01, 0.06, rng)
	var back := BoxMesh.new()
	back.size = Vector3(3.8, 2.4, 0.12)
	LowPoly.add_shape(st, back, Transform3D(Basis(), Vector3(0, 1.2, 1.25)), wood.darkened(0.08), 0.01, 0.06, rng)
	for i in 6:
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.66, 0.08, 3.0)
		var color := Color(0.85, 0.3, 0.2) if i % 2 == 0 else Color(0.95, 0.92, 0.85)
		LowPoly.add_shape(st, stripe, Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(-1.65 + i * 0.66, 2.7, -0.1)), color, 0.0, 0.04, rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	holder.add_child(mesh)
	# Guns hanging on the back wall, like the shop in How to Fish.
	var x := -1.3
	for id in [&"double_barrel", &"smg", &"assault_rifle", &"sniper"]:
		var gun := MeshInstance3D.new()
		gun.mesh = ItemLibrary.get_item(id).mesh
		gun.position = Vector3(x, 1.6, 1.15)
		gun.rotation = Vector3(0, PI * 0.5, 0)
		holder.add_child(gun)
		x += 0.85
	var body := StaticBody3D.new()
	for spec in [[Vector3(3.6, 1.0, 0.5), Vector3(0, 0.5, -1.0)], [Vector3(3.8, 2.4, 0.12), Vector3(0, 1.2, 1.25)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		shape.shape = box
		shape.position = spec[1]
		body.add_child(shape)
	holder.add_child(body)
	return holder
