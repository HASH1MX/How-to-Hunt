class_name NetNotice
extends CanvasLayer
## Small messages in the top right when players join or leave
## ("Sam joined the game"). They fade away after a few seconds.

var _column: VBoxContainer


func _ready() -> void:
	layer = 5
	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.offset_right = -24
	_column.offset_top = 24
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	Network.player_joined.connect(func(_id, player_name): show_message("%s joined the game" % player_name))
	Network.player_left.connect(func(_id, player_name): show_message("%s left the game" % player_name))


func show_message(text: String) -> void:
	var label := UiStyle.label(text, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_column.add_child(label)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
