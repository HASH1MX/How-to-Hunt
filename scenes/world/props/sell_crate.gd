class_name SellCrate
extends StaticBody3D
## The trader's big wooden crate on Island 2. Drop an animal body into it and the trader
## pays you its price (whoever dropped it gets the money, like feeding Captain Gus).
## Selling counts for "sell" quests. In multiplayer the host decides (items are the host's).

const INTERACT_LAYER := 1 << 3

var _area: Area3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1 << 2 # Items.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.0, 1.0)
	shape.shape = box
	shape.position.y = 0.9
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_item_entered)


func _on_item_entered(body: Node3D) -> void:
	if not body is WorldItem:
		return
	if Network.is_online() and not Network.is_host():
		return
	var item := body as WorldItem
	if item.puppet or item.eaten or item.item.value <= 0:
		return
	item.eaten = true
	var amount := item.item.value
	var payer := item.dropped_by if item.dropped_by != 0 else Network.get_my_id()
	var sync := WorldSync.find(self)
	var at := global_position + Vector3(0, 1.2, 0)
	Quests.report("sell", String(item.item.id))
	if sync != null and item.net_id >= 0:
		sync.remove_item(item.net_id)
	else:
		item.queue_free()
	if sync != null and payer > 1 and payer != Network.get_my_id():
		sync.pay(payer, amount)
	else:
		var local := get_tree().get_first_node_in_group("players")
		if local != null:
			local.add_money(amount)
			Sfx.play("coins", -2.0, 0.04)
	Sfx.play_at("drop_wood", at, 0.0, 0.05, 20.0)
	FloatingText.spawn(get_parent(), at + Vector3(0, 0.3, 0), "+$%d" % amount)
	if sync != null:
		sync.broadcast_fed(at, amount)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 121
	var st := LowPoly.begin()
	var wood := PropLibrary.WOOD_COLOR
	var plank := BoxMesh.new()
	# Four slatted walls and a floor, open at the top.
	plank.size = Vector3(1.4, 0.1, 1.1)
	LowPoly.add_shape(st, plank, Transform3D(Basis(), Vector3(0, 0.05, 0)), wood.darkened(0.1), 0.0, 0.06, rng)
	for y in [0.2, 0.42, 0.64]:
		for z in [-0.52, 0.52]:
			plank.size = Vector3(1.4, 0.16, 0.06)
			LowPoly.add_shape(st, plank, Transform3D(Basis(), Vector3(0, y, z)), wood.lightened(rng.randf_range(0.0, 0.1)), 0.0, 0.06, rng)
		for x in [-0.67, 0.67]:
			plank.size = Vector3(0.06, 0.16, 1.1)
			LowPoly.add_shape(st, plank, Transform3D(Basis(), Vector3(x, y, 0)), wood.lightened(rng.randf_range(0.0, 0.1)), 0.0, 0.06, rng)
	var post := BoxMesh.new()
	post.size = Vector3(0.1, 0.8, 0.1)
	for x in [-0.67, 0.67]:
		for z in [-0.52, 0.52]:
			LowPoly.add_shape(st, post, Transform3D(Basis(), Vector3(x, 0.4, z)), wood.darkened(0.25), 0.0, 0.04, rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	add_child(mesh)
	# Solid walls only (the inside is open so items fall in).
	for z in [-0.52, 0.52]:
		_wall(Vector3(1.4, 0.75, 0.08), Vector3(0, 0.38, z))
	for x in [-0.67, 0.67]:
		_wall(Vector3(0.08, 0.75, 1.1), Vector3(x, 0.38, 0))
	var sign := Label3D.new()
	sign.text = "SELL HERE"
	sign.font_size = 48
	sign.outline_size = 10
	sign.pixel_size = 0.004
	sign.position = Vector3(0, 0.45, -0.57)
	sign.rotation.y = PI
	sign.modulate = Color(1.0, 0.95, 0.8)
	add_child(sign)


func _wall(size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	add_child(shape)
