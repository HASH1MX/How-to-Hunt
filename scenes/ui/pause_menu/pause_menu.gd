class_name PauseMenu
extends CanvasLayer
## The in-game menu, opened with Esc: Resume, Settings, Main Menu and Quit.
## The world keeps running (like How to Fish, and so multiplayer works later),
## but the player can't move, punch or look around while it's open.
## Set `player` before adding it to the scene.

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"

var player: Node

var _root: Control
var _settings: SettingsMenu
var _info: Label
var _copy_button: Button


func _ready() -> void:
	layer = 10 # Above the HUD.
	_root = Control.new()
	_root.theme = UiStyle.menu_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -230
	column.offset_right = 230
	column.offset_top = -230
	column.offset_bottom = 230
	_root.add_child(column)
	var title := UiStyle.label("Paused", 48, Color(1.0, 0.95, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_info = UiStyle.label("", 18, UiStyle.DIM_TEXT_COLOR)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info)
	_copy_button = _add_button(column, "Copy join code", func():
		DisplayServer.clipboard_set(Network.lobby_code))
	_add_button(column, "Resume", close)
	_add_button(column, "Settings", _open_settings)
	_add_button(column, "Main Menu", func():
		_set_paused(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Network.leave()
		get_tree().change_scene_to_file(MAIN_MENU))
	_add_button(column, "Quit Game", func(): get_tree().quit())
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_info.text = _multiplayer_info()
	_info.visible = _info.text != ""
	_copy_button.visible = Network.transport == "steam"
	_root.visible = true
	_set_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if _settings != null:
		_settings.close()
	_root.visible = false
	_set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


## Who is playing, and (for the host) the address friends can join with.
func _multiplayer_info() -> String:
	if not Network.is_online():
		return ""
	var text := "Players: %s" % ", ".join(Network.get_player_names())
	if Network.transport == "steam":
		text += "
Steam join code: %s" % Network.lobby_code
	elif Network.is_host():
		var addresses := Network.get_local_addresses()
		text += "\nSame Wi-Fi/home network: %s  (port %d)" % [addresses[0] if addresses.size() > 0 else "?", Network.last_port]
		if Network.public_ip != "":
			text += "\nOver the internet: %s  (port %d)" % [Network.public_ip, Network.last_port]
		text += "\n" + Network.upnp_message
	return text


func _open_settings() -> void:
	_settings = SettingsMenu.new()
	_settings.closed.connect(func(): _settings = null)
	_root.add_child(_settings)


func _set_paused(paused: bool) -> void:
	if player != null:
		player.in_menu = paused


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 48)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
