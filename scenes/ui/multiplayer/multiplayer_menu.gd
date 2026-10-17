class_name MultiplayerMenu
extends Control
## The multiplayer window on the start page: enter a name, then either Host a game
## or Join a friend's game by typing their address. Emits `started` once the game
## is ready to begin (the start page then drops everyone into the world).

signal started
signal closed

var _name_edit: LineEdit
var _address_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _host_button: Button
var _join_button: Button


func _ready() -> void:
	theme = UiStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.92))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -270
	panel.offset_bottom = 270
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiStyle.label("Multiplayer", 36, Color(1.0, 0.95, 0.84)))

	_name_edit = _row(column, "Your name", Network.player_name)
	_name_edit.max_length = 16

	column.add_child(_heading("Host a game"))
	_port_edit = _row(column, "Port", str(Network.last_port))
	_host_button = _button("Host game", _on_host_pressed)
	column.add_child(_host_button)

	column.add_child(_heading("Join a friend"))
	_address_edit = _row(column, "Host address", Network.last_address)
	_join_button = _button("Join game", _on_join_pressed)
	column.add_child(_join_button)

	_status = UiStyle.label("", 18, UiStyle.DIM_TEXT_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 50)
	column.add_child(_status)

	var back := _button("Back", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.custom_minimum_size = Vector2(160, 0)
	column.add_child(back)

	Network.joined_game.connect(_on_joined, CONNECT_ONE_SHOT)
	Network.join_failed.connect(_on_join_failed)


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_host_pressed() -> void:
	Network.set_player_name(_name_edit.text)
	var error := Network.host(_get_port())
	if error != "":
		_status.text = error


func _on_join_pressed() -> void:
	Network.set_player_name(_name_edit.text)
	_set_busy(true)
	_status.text = "Connecting..."
	Network.join(_address_edit.text, _get_port())


func _on_joined() -> void:
	started.emit()
	queue_free()


func _on_join_failed(reason: String) -> void:
	_set_busy(false)
	_status.text = reason
	# Listen again in case they try another address.
	if not Network.joined_game.is_connected(_on_joined):
		Network.joined_game.connect(_on_joined, CONNECT_ONE_SHOT)


func _set_busy(busy: bool) -> void:
	_host_button.disabled = busy
	_join_button.disabled = busy


func _get_port() -> int:
	var port := _port_edit.text.to_int()
	return port if port > 0 and port < 65536 else Network.DEFAULT_PORT


func _heading(text: String) -> Label:
	return UiStyle.label(text, 24, UiStyle.TITLE_COLOR)


func _row(parent: Control, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := UiStyle.label(label_text, 20)
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(on_pressed)
	return button
