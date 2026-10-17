class_name MultiplayerMenu
extends Control
## The multiplayer window on the start page.
##   Steam tab:     play over the internet through Steam's free relay. Host a game and
##                  share the join code, join with a code, or pick a game from the list.
##   Direct IP tab: connect by IP address (same home network, a VPN, or a forwarded port).
## Emits `started` once the game is ready to begin (the start page then drops everyone
## into the world).

signal started
signal closed

var _name_edit: LineEdit
var _tabs: TabContainer
var _status: Label
var _friends_only: CheckBox
var _code_edit: LineEdit
var _games_list: VBoxContainer
var _address_edit: LineEdit
var _port_edit: LineEdit
var _buttons: Array[Button] = []


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
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiStyle.label("Multiplayer", 36, Color(1.0, 0.95, 0.84)))

	# Use the Steam name as the starting player name.
	if Network.player_name == "Hunter" and Network.steam.ensure_ready() == "":
		Network.set_player_name(Network.steam.get_persona_name())
	_name_edit = _row(column, "Your name", Network.player_name)
	_name_edit.max_length = 16

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_steam_tab()
	_build_direct_tab()

	_status = UiStyle.label("", 18, UiStyle.DIM_TEXT_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 46)
	column.add_child(_status)

	var back := _button("Back", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.custom_minimum_size = Vector2(160, 0)
	column.add_child(back)

	Network.joined_game.connect(_on_joined, CONNECT_ONE_SHOT)
	Network.join_failed.connect(_on_join_failed)
	Network.steam.games_listed.connect(_on_games_listed)
	_refresh_steam_status()


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _name_edit.has_focus():
		close()
		get_viewport().set_input_as_handled()


# --- Steam tab ---------------------------------------------------------------------------

func _build_steam_tab() -> void:
	var page := _page("Steam (internet)")
	page.add_child(UiStyle.label("Play with friends anywhere. Everyone needs Steam running. No router setup.", 17, UiStyle.DIM_TEXT_COLOR))
	page.get_child(0).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	page.add_child(_heading("Host a game"))
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 14)
	page.add_child(host_row)
	host_row.add_child(_button("Host on Steam", _on_host_steam_pressed))
	_friends_only = CheckBox.new()
	_friends_only.text = "Friends only"
	host_row.add_child(_friends_only)

	page.add_child(_heading("Join a game"))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	page.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Paste the join code"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_code_edit)
	join_row.add_child(_button("Join", _on_join_code_pressed))

	var list_header := HBoxContainer.new()
	page.add_child(list_header)
	var title := _heading("Open games")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(title)
	list_header.add_child(_button("Refresh", _on_refresh_pressed))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 90)
	page.add_child(scroll)
	_games_list = VBoxContainer.new()
	_games_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_games_list)


func _refresh_steam_status() -> void:
	var problem := Network.steam.ensure_ready()
	_status.text = problem if problem != "" else "Steam is connected as %s." % Network.steam.get_persona_name()
	if problem == "":
		Network.steam.request_games()


func _on_host_steam_pressed() -> void:
	Network.set_player_name(_name_edit.text)
	var problem := Network.host_steam(_friends_only.button_pressed)
	if problem != "":
		_status.text = problem
		return
	_set_busy(true)
	_status.text = "Creating your game on Steam..."


func _on_join_code_pressed() -> void:
	Network.set_player_name(_name_edit.text)
	var problem := Network.join_steam(_code_edit.text)
	if problem != "":
		_status.text = problem
		return
	_set_busy(true)
	_status.text = "Joining through Steam..."


func _on_refresh_pressed() -> void:
	_refresh_steam_status()
	for child in _games_list.get_children():
		child.queue_free()
	_games_list.add_child(UiStyle.label("Searching...", 18, UiStyle.DIM_TEXT_COLOR))


func _on_games_listed(games: Array) -> void:
	for child in _games_list.get_children():
		child.queue_free()
	if games.is_empty():
		_games_list.add_child(UiStyle.label("No open games found. Ask a friend to host, or paste their code.", 18, UiStyle.DIM_TEXT_COLOR))
		return
	for game in games:
		var row := HBoxContainer.new()
		var text := "%s's game   %d/%d players" % [game.host, game.players, game.max]
		if not game.compatible:
			text += "   (different version)"
		var label := UiStyle.label(text, 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var join := _button("Join", func():
			Network.set_player_name(_name_edit.text)
			_code_edit.text = str(game.id)
			_on_join_code_pressed())
		join.disabled = not game.compatible
		row.add_child(join)
		_games_list.add_child(row)


# --- Direct IP tab -------------------------------------------------------------------------

func _build_direct_tab() -> void:
	var page := _page("Direct IP")
	page.add_child(UiStyle.label("For the same home network, a VPN (Radmin/ZeroTier) or a forwarded port.", 17, UiStyle.DIM_TEXT_COLOR))
	page.get_child(0).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_heading("Host a game"))
	_port_edit = _row(page, "Port", str(Network.last_port))
	page.add_child(_button("Host game", _on_host_pressed))
	page.add_child(_heading("Join a friend"))
	_address_edit = _row(page, "Host address", Network.last_address)
	page.add_child(_button("Join game", _on_join_pressed))


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


# --- Shared ---------------------------------------------------------------------------------

func _on_joined() -> void:
	started.emit()
	queue_free()


func _on_join_failed(reason: String) -> void:
	_set_busy(false)
	_status.text = reason
	# Listen again in case they try another game.
	if not Network.joined_game.is_connected(_on_joined):
		Network.joined_game.connect(_on_joined, CONNECT_ONE_SHOT)


func _set_busy(busy: bool) -> void:
	for button in _buttons:
		button.disabled = busy


func _get_port() -> int:
	var port := _port_edit.text.to_int()
	return port if port > 0 and port < 65536 else Network.DEFAULT_PORT


func _page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)
	return page


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
	_buttons.append(button)
	return button
