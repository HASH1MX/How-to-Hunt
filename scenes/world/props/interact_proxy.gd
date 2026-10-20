class_name InteractProxy
extends StaticBody3D
## A solid shape that passes "look at it and press E" on to another node (for things whose
## collision is a child body, like the helicopter). `target` needs get_interact_text() and
## interact(player).

const INTERACT_LAYER := 1 << 3

var target: Node


func _ready() -> void:
	collision_layer = 1 | INTERACT_LAYER
	collision_mask = 0


func get_interact_text() -> String:
	return target.get_interact_text() if target != null else ""


func interact(player: Node) -> void:
	if target != null:
		target.interact(player)
