class_name FloatingText
## Text that floats up from a spot in the world and fades ("+$18" when feeding Captain Gus).

static func spawn(parent: Node, at: Vector3, text: String, color: Color = Color(0.55, 1.0, 0.55)) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.7)
	parent.add_child(label)
	label.global_position = at
	var tween := label.create_tween()
	tween.tween_property(label, "global_position:y", at.y + 1.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tween.tween_callback(label.queue_free)
