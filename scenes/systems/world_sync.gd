class_name WorldSync
extends Node
## Shares the living world between players. The HOST owns it:
##
##   Animals - only the host runs their brains. Each joined player gets "puppet" animals
##     that copy the host's animals' positions (only those near them, ten times a second),
##     and punches on a puppet are sent to the host, who decides the damage.
##   Items   - every loose item (dropped by anyone, dropped by animals, lying at the crash
##     site) belongs to the host's physics. Joined players see puppet copies. Picking up,
##     dropping and pushing items are requests to the host, who checks them
##     (is the player close enough?) before anything changes.
##
## Added to the world when a multiplayer game starts (not in solo games).
## The host never trusts a joined player's numbers: distance and damage are checked here.

static var SPECIES: Array = [Rabbit, Chicken, Squirrel, Deer, Boar, Monkey, Toucan, Jaguar]
## Joined players are only sent animals this close to them.
const ANIMAL_VIEW_DISTANCE := 90.0
const SEND_INTERVAL := 0.1
## Furthest a player can be from an animal or item and still hit / pick it up / push it.
const REACH := 6.0
const MAX_PUNCH_DAMAGE := 10.0
const PUSH_STRENGTH_LIMIT := 8.0

var world: Node3D
var terrain: Terrain

var _items := {}
var _animals := {}
var _next_item_id := 1
var _next_animal_id := 1
var _timer := 0.0
var _puppet_seen := {}
var _last_hit_time := {}


func _ready() -> void:
	add_to_group("world_sync")
	if not multiplayer.is_server():
		# Tell the host we're ready; it sends us every item in the world.
		_client_ready.rpc_id(1)


## Tree spots that have already given up their stick (cells 2 m wide), so each tree gives one.
static var _shaken := {}


## Forgets which trees were shaken (a new game starts).
static func reset_shaken() -> void:
	_shaken.clear()


## A punch landed on a tree: one stick falls out the first time. Works in solo games, for the
## host, and for joined players (who ask the host).
static func shake_tree(from: Node, position: Vector3) -> void:
	var sync := find(from)
	if sync != null and Network.is_online():
		if Network.is_host():
			sync.host_shake(position, Network.get_my_id())
		else:
			sync.request_shake(position)
		return
	if _take_tree(position):
		spawn_item(from.get_parent(), ItemLibrary.get_item(&"stick"), _stick_drop_spot(position), _stick_drop_velocity(), 1)


static func _take_tree(position: Vector3) -> bool:
	var cell := Vector2i(floori(position.x / 2.0), floori(position.z / 2.0))
	if _shaken.has(cell):
		return false
	_shaken[cell] = true
	return true


static func _stick_drop_spot(position: Vector3) -> Vector3:
	return position + Vector3(randf_range(-0.4, 0.4), 1.6, randf_range(-0.4, 0.4))


static func _stick_drop_velocity() -> Vector3:
	return Vector3(randf_range(-0.8, 0.8), 0.6, randf_range(-0.8, 0.8))


## The WorldSync of the running game, or null (solo games have none).
static func find(from: Node) -> WorldSync:
	return from.get_tree().get_first_node_in_group("world_sync") as WorldSync


## Spawns an item in the world, from anywhere in the game: the host spawns it and tells
## everyone; a joined player asks the host to; in a solo game it just appears.
static func spawn_item(parent: Node, item: ItemData, position: Vector3, velocity: Vector3, dropper: int = 0) -> WorldItem:
	var sync := find(parent)
	if sync != null and Network.is_online():
		if Network.is_host():
			return sync.host_spawn(item, position, velocity, dropper)
		sync.request_spawn(item, position, velocity)
		return null
	var drop := WorldItem.new()
	drop.item = item
	drop.dropped_by = dropper
	parent.add_child(drop)
	drop.global_position = position
	drop.linear_velocity = velocity
	return drop


func _physics_process(delta: float) -> void:
	_sweep_stale_puppets()
	if not multiplayer.is_server():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SEND_INTERVAL
	# Moving items go to everyone.
	var moving := []
	for item: WorldItem in _items.values():
		if not item.sleeping:
			moving.append([item.net_id, item.global_position, item.rotation])
	if not moving.is_empty():
		_item_states.rpc(moving)
	# Animals go to each player, only the ones near that player.
	for peer in multiplayer.get_peers():
		var remote := Network.get_remote_player(peer)
		if remote == null or not remote.visible:
			continue
		var near := []
		for animal: Animal in _animals.values():
			if animal.state == Animal.State.DEAD:
				continue
			var offset := animal.global_position - remote.global_position
			if Vector2(offset.x, offset.z).length() < ANIMAL_VIEW_DISTANCE:
				near.append([animal.net_id, SPECIES.find(animal.get_script()), animal.global_position,
						animal.rotation.y, Vector2(animal.velocity.x, animal.velocity.z).length()])
		_animal_states.rpc_id(peer, near)


# --- Host: registering what exists ---------------------------------------------------------

func register_animal(animal: Animal) -> void:
	animal.net_id = _next_animal_id
	_next_animal_id += 1
	_animals[animal.net_id] = animal
	animal.tree_exited.connect(func(): _animals.erase(animal.net_id))


## An item that was already in the scene (the stones and sticks at the crash site).
func register_existing_item(item: WorldItem) -> void:
	item.net_id = _next_item_id
	_next_item_id += 1
	_items[item.net_id] = item
	item.tree_exited.connect(func(): _items.erase(item.net_id))
	item.sleeping_state_changed.connect(func():
		if is_instance_valid(item) and item.sleeping:
			_item_settled.rpc(item.net_id, item.global_position, item.rotation))


func host_spawn(item: ItemData, position: Vector3, velocity: Vector3, dropper: int = 0) -> WorldItem:
	var drop := WorldItem.new()
	drop.item = item
	drop.dropped_by = dropper
	world.add_child(drop)
	drop.global_position = position
	drop.linear_velocity = velocity
	register_existing_item(drop)
	_item_spawned.rpc(drop.net_id, String(item.id), position, velocity)
	return drop


## Host: a tree was punched (by the host, or a joined player's request that checked out).
func host_shake(position: Vector3, who: int) -> void:
	if _take_tree(position):
		host_spawn(ItemLibrary.get_item(&"stick"), _stick_drop_spot(position), _stick_drop_velocity(), who)


func request_shake(position: Vector3) -> void:
	_request_shake.rpc_id(1, position)


func remove_item(id: int) -> void:
	var item: WorldItem = _items.get(id)
	if item != null:
		item.queue_free()
	_items.erase(id)
	_item_removed.rpc(id)


## Host: an animal bit a joined player; they lose health on their own computer.
func hurt_player(peer: int, amount: float) -> void:
	_hurt.rpc_id(peer, amount)


@rpc("authority", "call_remote", "reliable")
func _hurt(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player != null:
		player.take_damage(clampf(amount, 0.0, 60.0))


## Host: pays money to a joined player (they fed Captain Gus).
func pay(peer: int, amount: int) -> void:
	_pay.rpc_id(peer, amount)


## Host: everyone sees the "+$" float up where Captain Gus ate.
func broadcast_fed(position: Vector3, amount: int) -> void:
	_fed_popup.rpc(position, amount)


func broadcast_animal_hit(id: int, amount: float, at: Vector3, died: bool) -> void:
	_animal_hit.rpc(id, amount, at, died)


# --- Joined player: asking the host -----------------------------------------------------------

func request_spawn(item: ItemData, position: Vector3, velocity: Vector3) -> void:
	_request_spawn.rpc_id(1, String(item.id), position, velocity)


func request_pickup(id: int) -> void:
	_request_pickup.rpc_id(1, id)


func request_push(id: int, impulse: Vector3) -> void:
	_request_push.rpc_id(1, id, impulse)


func request_animal_hit(id: int, amount: float, at: Vector3, weapon_id: String = "") -> void:
	_request_animal_hit.rpc_id(1, id, amount, at, weapon_id)


@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
	var list := []
	for item: WorldItem in _items.values():
		list.append([item.net_id, String(item.item.id), item.global_position, item.rotation])
	_full_items.rpc_id(multiplayer.get_remote_sender_id(), list)


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(item_id: String, position: Vector3, velocity: Vector3) -> void:
	var remote := _checked_player(position, 4.0)
	if remote == null or not ItemLibrary.has_item(StringName(item_id)):
		return
	host_spawn(ItemLibrary.get_item(StringName(item_id)), position, velocity.limit_length(8.0), multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_shake(position: Vector3) -> void:
	if _checked_player(position, REACH + 2.0) != null:
		host_shake(position, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_pickup(id: int) -> void:
	var item: WorldItem = _items.get(id)
	if item == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var remote := Network.get_remote_player(sender)
	if remote == null or remote.global_position.distance_to(item.global_position) > REACH:
		return
	var item_id := String(item.item.id)
	remove_item(id)
	_pickup_granted.rpc_id(sender, item_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_push(id: int, impulse: Vector3) -> void:
	var item: WorldItem = _items.get(id)
	if item == null or _checked_player(item.global_position, REACH) == null:
		return
	item.apply_impulse(impulse.limit_length(PUSH_STRENGTH_LIMIT))


@rpc("any_peer", "call_remote", "reliable")
func _request_animal_hit(id: int, amount: float, at: Vector3, weapon_id: String) -> void:
	var animal: Animal = _animals.get(id)
	var sender := multiplayer.get_remote_sender_id()
	var remote := Network.get_remote_player(sender)
	if animal == null or remote == null or animal.state == Animal.State.DEAD:
		return
	# What it was hit with decides how far away it can be, how hard, and how often.
	var weapon: ItemData = ItemLibrary.get_item(StringName(weapon_id)) if weapon_id != "" and ItemLibrary.has_item(StringName(weapon_id)) else null
	var reach := weapon.reach + 3.0 if weapon != null else REACH
	var max_damage := weapon.damage * weapon.pellets if weapon != null else MAX_PUNCH_DAMAGE
	var min_gap := weapon.fire_gap * 0.6 if weapon != null else 0.06
	if remote.global_position.distance_to(animal.global_position) > reach:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_hit_time.get(sender, -1.0)) < min_gap:
		return
	_last_hit_time[sender] = now
	animal.take_hit(clampf(amount, 0.0, max_damage), remote, at)


## The sender's character, if it is within `reach` of `position`.
func _checked_player(position: Vector3, reach: float) -> RemotePlayer:
	var remote := Network.get_remote_player(multiplayer.get_remote_sender_id())
	if remote == null or remote.global_position.distance_to(position) > reach:
		return null
	return remote


# --- Joined player: showing the host's world ------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _full_items(list: Array) -> void:
	for id in _items.keys():
		if is_instance_valid(_items[id]):
			_items[id].queue_free()
	_items.clear()
	for entry in list:
		_make_item_puppet(entry[0], entry[1], entry[2], entry[3])


@rpc("authority", "call_remote", "reliable")
func _item_spawned(id: int, item_id: String, position: Vector3, _velocity: Vector3) -> void:
	_make_item_puppet(id, item_id, position, Vector3.ZERO)


@rpc("authority", "call_remote", "reliable")
func _item_removed(id: int) -> void:
	var item: WorldItem = _items.get(id)
	if item != null:
		item.queue_free()
	_items.erase(id)


@rpc("authority", "call_remote", "reliable")
func _item_settled(id: int, position: Vector3, rotation: Vector3) -> void:
	var item: WorldItem = _items.get(id)
	if item != null:
		item.puppet_update(position, rotation)


@rpc("authority", "call_remote", "unreliable_ordered")
func _item_states(list: Array) -> void:
	for entry in list:
		var item: WorldItem = _items.get(entry[0])
		if item != null:
			item.puppet_update(entry[1], entry[2])


@rpc("authority", "call_remote", "reliable")
func _pay(amount: int) -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player != null:
		player.add_money(amount)
		Sfx.play("coins", -2.0, 0.04)


@rpc("authority", "call_remote", "reliable")
func _fed_popup(position: Vector3, amount: int) -> void:
	FloatingText.spawn(world, position + Vector3(0, 0.3, 0), "+$%d" % amount)
	Sfx.play_at("munch", position, 0.0, 0.05, 30.0)


@rpc("authority", "call_remote", "reliable")
func _pickup_granted(item_id: String) -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player == null or not ItemLibrary.has_item(StringName(item_id)):
		return
	var item := ItemLibrary.get_item(StringName(item_id))
	# If the inventory filled up in the meantime, put it back down at the player's feet.
	if not player.inventory.pick_up(item):
		request_spawn(item, player.global_position + Vector3(0, 1.0, 0), Vector3.ZERO)


@rpc("authority", "call_remote", "unreliable_ordered")
func _animal_states(list: Array) -> void:
	var now := Time.get_ticks_msec()
	for entry in list:
		var id: int = entry[0]
		var animal: Animal = _animals.get(id)
		if animal == null:
			var species: GDScript = SPECIES[entry[1]] if entry[1] >= 0 and entry[1] < SPECIES.size() else null
			if species == null:
				continue
			animal = species.new()
			animal.puppet = true
			animal.net_id = id
			animal.terrain = terrain
			world.add_child(animal)
			animal.global_position = entry[2]
			_animals[id] = animal
		animal.puppet_update(entry[2], entry[3], entry[4])
		_puppet_seen[id] = now


@rpc("authority", "call_remote", "reliable")
func _animal_hit(id: int, amount: float, at: Vector3, died: bool) -> void:
	var animal: Animal = _animals.get(id)
	if animal != null:
		animal.puppet_hit(amount, at, died)
		if died:
			_animals.erase(id)
			_puppet_seen.erase(id)


func _make_item_puppet(id: int, item_id: String, position: Vector3, rotation: Vector3) -> void:
	if _items.has(id) or not ItemLibrary.has_item(StringName(item_id)):
		return
	var item := WorldItem.new()
	item.item = ItemLibrary.get_item(StringName(item_id))
	item.net_id = id
	item.puppet = true
	world.add_child(item)
	item.global_position = position
	item.rotation = rotation
	item.puppet_update(position, rotation)
	_items[id] = item


## Puppet animals the host has stopped mentioning (out of range, or gone) disappear.
func _sweep_stale_puppets() -> void:
	if multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	for id in _puppet_seen.keys():
		if now - _puppet_seen[id] > 1500:
			var animal: Animal = _animals.get(id)
			if animal != null and is_instance_valid(animal):
				animal.queue_free()
			_animals.erase(id)
			_puppet_seen.erase(id)
