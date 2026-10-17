class_name WorldItem
extends RigidBody3D
## An item lying in the world that the player can pick up with E.
## Place one in a scene and set item_id, or create one in code and set `item`.

## Physics layer 3 is used only for items, so the pick-up ray finds only items.
const ITEM_LAYER := 1 << 2

@export var item_id: StringName

var item: ItemData


func _ready() -> void:
	if item == null:
		item = ItemLibrary.get_item(item_id)
	collision_layer = ITEM_LAYER
	collision_mask = 1 # Rests on the ground and props; players walk through it.
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


func interact(player: Node) -> void:
	# If the stack is full and no slot has room, the item stays where it is.
	if player.inventory.pick_up(item):
		queue_free()
