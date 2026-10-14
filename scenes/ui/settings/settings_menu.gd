class_name SettingsMenu
extends Control
## The settings window, with three tabs: Game, Graphics and Controls.
## Every change is applied and saved straight away (see the Settings autoload).
## Used from the start page and the in-game pause menu. Emits `closed` on Back.

signal closed

const LABEL_WIDTH := 260
const CONTROL_WIDTH := 300

var _tabs: TabContainer
var _preset_option: OptionButton
var _listening_action := ""
var _listening_button: Button
var _key_buttons := {}


func _ready() -> void:
	theme = UiStyle.menu_theme()
	# Fill the whole screen (offsets too, since the menu is already on screen here).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks to what's behind.

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.92))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 540)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -280
	panel.offset_bottom = 280
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiStyle.label("Settings", 36, Color(1.0, 0.95, 0.84)))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_game_tab()
	_build_graphics_tab()
	_build_controls_tab()

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(close)
	column.add_child(back)


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _listening_action != "":
		_listen_for_key(event)
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Tabs ---------------------------------------------------------------------------

func _build_game_tab() -> void:
	var page := _make_page("Game")
	_slider_row(page, "Mouse sensitivity", 0.1, 3.0, 0.05, Settings.mouse_sensitivity,
			func(v): return "%.2f" % v, func(v): Settings.set_value("mouse_sensitivity", v))
	_check_row(page, "Invert mouse Y", Settings.invert_mouse_y,
			func(v): Settings.set_value("invert_mouse_y", v))
	_slider_row(page, "Field of view", 60.0, 110.0, 1.0, Settings.field_of_view,
			func(v): return "%d°" % int(v), func(v): Settings.set_value("field_of_view", v))


func _build_graphics_tab() -> void:
	var page := _make_page("Graphics")
	var preset_names: Array = Settings.PRESET_NAMES.duplicate()
	preset_names.append("Custom")
	var current := Settings.get_current_preset()
	_preset_option = _option_row(page, "Quality preset", preset_names, current if current >= 0 else preset_names.size() - 1,
			func(i):
				if i < Settings.PRESETS.size():
					Settings.apply_preset(i)
					_rebuild_tab.call_deferred(1))
	_option_row(page, "Window mode", ["Windowed", "Borderless fullscreen", "Fullscreen"], Settings.window_mode,
			func(i): Settings.set_value("window_mode", i))
	_check_row(page, "V-Sync", Settings.vsync, func(v): Settings.set_value("vsync", v))
	var fps_values := [30, 60, 120, 144, 240, 0]
	_option_row(page, "FPS limit", ["30", "60", "120", "144", "240", "Unlimited"], maxi(fps_values.find(Settings.max_fps), 0),
			func(i): Settings.set_value("max_fps", fps_values[i]))
	var scale_values := [0.5, 0.67, 0.77, 0.87, 1.0]
	_option_row(page, "Render scale", ["50%", "67%", "77%", "87%", "100%"], _closest_index(scale_values, Settings.render_scale),
			func(i): _set_graphic("render_scale", scale_values[i]))
	_option_row(page, "Anti-aliasing", ["Off", "FXAA", "MSAA 2x", "MSAA 4x"], Settings.anti_aliasing,
			func(i): _set_graphic("anti_aliasing", i))
	_option_row(page, "Shadows", ["Off", "Low", "Medium", "High"], Settings.shadow_quality,
			func(i): _set_graphic("shadow_quality", i))
	_check_row(page, "Ambient occlusion", Settings.ambient_occlusion,
			func(v): _set_graphic("ambient_occlusion", v))
	_check_row(page, "Glow", Settings.glow, func(v): _set_graphic("glow", v))
	var distance_values := [0.6, 1.0, 1.3, 1.8]
	_option_row(page, "Grass & detail distance", ["Short", "Normal", "Far", "Very far"], _closest_index(distance_values, Settings.detail_distance),
			func(i): _set_graphic("detail_distance", distance_values[i]))
	_slider_row(page, "Brightness", 0.7, 1.3, 0.01, Settings.brightness,
			func(v): return "%d%%" % roundi(v * 100.0), func(v): Settings.set_value("brightness", v))


func _build_controls_tab() -> void:
	var page := _make_page("Controls")
	page.add_child(UiStyle.label("Click a key, then press the new key or mouse button. Esc cancels.", 16, UiStyle.DIM_TEXT_COLOR))
	for entry in Settings.REBINDABLE_ACTIONS:
		var action: String = entry[0]
		var button := Button.new()
		button.text = Settings.get_binding_text(action)
		button.custom_minimum_size = Vector2(CONTROL_WIDTH, 0)
		button.pressed.connect(_start_listening.bind(action, button))
		_key_buttons[action] = button
		_add_row(page, entry[1], button)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func():
		Settings.reset_bindings()
		_refresh_key_buttons())
	page.add_child(reset)


## A scrollable page in the tab container. Returns the column to add rows to.
func _make_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	return page


## Rebuilds one tab so it shows new values (e.g. after choosing a preset).
func _rebuild_tab(index: int) -> void:
	var old := _tabs.get_child(index)
	_tabs.remove_child(old)
	old.queue_free()
	match index:
		1: _build_graphics_tab()
	_tabs.move_child(_tabs.get_child(_tabs.get_child_count() - 1), index)
	_tabs.current_tab = index


## Changes one graphics option. That can turn the preset into "Custom".
func _set_graphic(setting: String, value: Variant) -> void:
	Settings.set_value(setting, value)
	var current := Settings.get_current_preset()
	_preset_option.selected = current if current >= 0 else Settings.PRESETS.size()


# --- Rows ------------------------------------------------------------------------------

func _add_row(page: Control, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := UiStyle.label(text, 20)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	row.add_child(control)
	page.add_child(row)


func _slider_row(page: Control, text: String, min_value: float, max_value: float, step: float,
		value: float, format: Callable, on_change: Callable) -> void:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(CONTROL_WIDTH, 0)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var number := UiStyle.label(format.call(value), 18)
	number.custom_minimum_size = Vector2(60, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v):
		number.text = format.call(v)
		on_change.call(v))
	box.add_child(slider)
	box.add_child(number)
	_add_row(page, text, box)


func _option_row(page: Control, text: String, options: Array, selected: int, on_change: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(CONTROL_WIDTH, 0)
	for option_name in options:
		option.add_item(option_name)
	option.selected = selected
	option.item_selected.connect(on_change)
	_add_row(page, text, option)
	return option


func _check_row(page: Control, text: String, value: bool, on_change: Callable) -> void:
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(on_change)
	_add_row(page, text, check)


func _closest_index(values: Array, value: float) -> int:
	var best := 0
	for i in values.size():
		if absf(values[i] - value) < absf(values[best] - value):
			best = i
	return best


# --- Rebinding keys --------------------------------------------------------------------

func _start_listening(action: String, button: Button) -> void:
	_refresh_key_buttons()
	_listening_action = action
	_listening_button = button
	button.text = "Press a key..."


func _listen_for_key(event: InputEvent) -> void:
	var is_key: bool = event is InputEventKey and event.pressed and not event.echo
	var is_mouse: bool = event is InputEventMouseButton and event.pressed
	if not is_key and not is_mouse:
		return
	get_viewport().set_input_as_handled()
	if is_key and event.physical_keycode == KEY_ESCAPE:
		_listening_action = ""
		_refresh_key_buttons()
		return
	var new_event: InputEvent
	if is_key:
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode
		new_event = key
	else:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		new_event = mouse
	Settings.rebind(_listening_action, new_event)
	_listening_action = ""
	_refresh_key_buttons()


func _refresh_key_buttons() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = Settings.get_binding_text(action)
