class_name WorldSelectMenu
extends Control
## The save-game picker: every world the player has, with when it was last played and
## for how long. Choose one to play (or host), make a new one, or delete one.
## Emits `world_chosen(id)` with the world already opened in the SaveManager.

signal world_chosen(id: String)
signal closed

## What the window is for, shown in its title (e.g. "Choose a world" or "Host which world?").
var title_text := "Choose a world"

var _list: VBoxContainer
var _name_edit: LineEdit
var _pending_delete := ""


func _ready() -> void:
	theme = UiStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.94))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -280
	panel.offset_bottom = 280
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiStyle.label(title_text, 36, Color(1.0, 0.95, 0.84)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	column.add_child(UiStyle.label("New world", 22, UiStyle.TITLE_COLOR))
	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 10)
	column.add_child(new_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "World name"
	_name_edit.max_length = 30
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_text): _create())
	new_row.add_child(_name_edit)
	new_row.add_child(_button("Create", _create))

	var back := _button("Back", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.custom_minimum_size = Vector2(160, 0)
	column.add_child(back)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _name_edit.has_focus():
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var worlds := SaveManager.list_worlds()
	if worlds.is_empty():
		var hint := UiStyle.label("No worlds yet. Make one below to start playing.", 20, UiStyle.DIM_TEXT_COLOR)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(hint)
		return
	for world in worlds:
		_list.add_child(_world_row(world))


func _world_row(world: Dictionary) -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.07)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiStyle.label(world.name, 26))
	text.add_child(UiStyle.label("Last played %s  |  %s played" % [_date(world.last_played), _duration(world.play_seconds)], 16, UiStyle.DIM_TEXT_COLOR))

	row.add_child(_button("Play", func(): _choose(world.id)))
	var delete := _button("Really delete?" if _pending_delete == world.id else "Delete", func():
		if _pending_delete == world.id:
			SaveManager.delete_world(world.id)
			_pending_delete = ""
		else:
			_pending_delete = world.id
		_refresh())
	row.add_child(delete)
	return box


func _create() -> void:
	var id := SaveManager.create_world(_name_edit.text)
	_choose(id)


func _choose(id: String) -> void:
	if SaveManager.load_world(id):
		world_chosen.emit(id)
		queue_free()
	else:
		_refresh()


func _date(unix: int) -> String:
	if unix <= 0:
		return "never"
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().bias) * 60)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


func _duration(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 1:
		return "under a minute"
	if minutes < 60:
		return "%d min" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(on_pressed)
	return button
