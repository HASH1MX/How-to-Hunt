class_name WorldItem
extends RigidBody3D
## An item lying in the world that the player can pick up with E.
## Place one in a scene and set item_id, or create one in code and set `item`.

## Physics layer 3 is used only for items, so the pick-up ray finds only items.
const ITEM_LAYER := 1 << 2

@export var item_id: StringName

var item: ItemData
## In a multiplayer game: the host's number for this item (-1 = not shared).
var net_id := -1
## A joined player's copy of an item that really lives on the host: it only shows
## where the host's item is, and picking it up is a request to the host.
var puppet := false

var _target_position := Vector3.ZERO
var _target_rotation := Vector3.ZERO


func _ready() -> void:
	if item == null:
		item = ItemLibrary.get_item(item_id)
	collision_layer = ITEM_LAYER
	collision_mask = 1 # Rests on the ground and props; players walk through it.
	if puppet:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
	# Check collisions along the whole path each step, so small fast items
	# can't pass through the ground.
	continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = item.mesh
	add_child(mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = item.collision_size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)


func get_interact_text() -> String:
	return "Pick up %s" % item.display_name


## Where the host says this item is (puppets only).
func puppet_update(position: Vector3, rotation_euler: Vector3) -> void:
	_target_position = position
	_target_rotation = rotation_euler


func _process(delta: float) -> void:
	if not puppet:
		return
	var blend := 1.0 - exp(-14.0 * delta)
	global_position = global_position.lerp(_target_position, blend)
	rotation = Vector3(lerp_angle(rotation.x, _target_rotation.x, blend), lerp_angle(rotation.y, _target_rotation.y, blend),
			lerp_angle(rotation.z, _target_rotation.z, blend))


func interact(player: Node) -> void:
	var sync := WorldSync.find(self)
	if net_id >= 0 and sync != null:
		if Network.is_host():
			if player.inventory.pick_up(item):
				sync.remove_item(net_id)
		elif player.inventory.can_pick_up(item):
			# The host checks we're close enough, removes it, and tells us it's ours.
			sync.request_pickup(net_id)
		return
	# If the stack is full and no slot has room, the item stays where it is.
	if player.inventory.pick_up(item):
		queue_free()
