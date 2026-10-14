class_name DamageNumber
extends Label3D
## A How to Fish-style damage number: pops up where something was hit,
## floats upward a little to the side, then fades away.
## Use: DamageNumber.spawn(some_node_in_the_world, hit_position, 10)

const FONT := preload("res://assets/fonts/Kurale-Regular.ttf")
const LIFETIME := 0.9


static func spawn(world_node: Node, at: Vector3, amount: float) -> void:
	var number := DamageNumber.new()
	number.text = str(roundi(amount))
	world_node.get_tree().current_scene.add_child(number)
	number.global_position = at
	number._play()


func _init() -> void:
	font = FONT
	font_size = 72
	outline_size = 14
	pixel_size = 0.0045
	modulate = Color(1.0, 0.98, 0.94)
	outline_modulate = Color(0, 0, 0, 0.6)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true # Always visible, even if the hit point is inside the animal.
	render_priority = 10


func _play() -> void:
	# Random sideways drift, so several hits in a row don't stack on top of each other.
	var drift := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
	scale = Vector3.ONE * 1.5
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", global_position + Vector3(0, 0.9, 0) + drift, LIFETIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(LIFETIME - 0.35)
	tween.tween_property(self, "outline_modulate:a", 0.0, 0.35).set_delay(LIFETIME - 0.35)
	tween.chain().tween_callback(queue_free)
