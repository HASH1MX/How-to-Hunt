extends Node
## All game settings: mouse, field of view, display, graphics and key bindings.
## This is an autoload, so it is available everywhere as `Settings`.
## Settings are loaded from user://settings.cfg when the game starts, applied
## right away, and saved every time something changes.

signal changed

const SAVE_PATH := "user://settings.cfg"
## Mouse sensitivity 1.0 in the menu equals this many radians per pixel.
const BASE_MOUSE_SENSITIVITY := 0.002

## Actions the player can rebind, in the order shown in the Controls tab.
const REBINDABLE_ACTIONS := [
	["move_forward", "Move Forward"],
	["move_back", "Move Back"],
	["move_left", "Move Left"],
	["move_right", "Move Right"],
	["sprint", "Sprint"],
	["crouch", "Crouch"],
	["jump", "Jump"],
	["attack", "Punch / Use"],
	["aim", "Aim"],
	["reload", "Reload"],
	["interact", "Interact / Talk"],
	["drop", "Drop Item"],
	["slot_1", "Slot 1"],
	["slot_2", "Slot 2"],
	["slot_3", "Slot 3"],
	["slot_4", "Slot 4"],
	["toggle_tip", "Show Quest Tip"],
]

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }
enum AntiAliasing { OFF, FXAA, MSAA_2X, MSAA_4X }
enum Shadows { OFF, LOW, MEDIUM, HIGH }

const PRESET_NAMES := ["Low", "Medium", "High", "Ultra"]
## Each graphics preset sets these values at once.
const PRESETS := [
	{anti_aliasing = AntiAliasing.OFF, shadow_quality = Shadows.LOW, ambient_occlusion = false, glow = false, render_scale = 0.77, detail_distance = 0.6},
	{anti_aliasing = AntiAliasing.FXAA, shadow_quality = Shadows.MEDIUM, ambient_occlusion = false, glow = true, render_scale = 1.0, detail_distance = 1.0},
	{anti_aliasing = AntiAliasing.MSAA_2X, shadow_quality = Shadows.HIGH, ambient_occlusion = true, glow = true, render_scale = 1.0, detail_distance = 1.3},
	{anti_aliasing = AntiAliasing.MSAA_4X, shadow_quality = Shadows.HIGH, ambient_occlusion = true, glow = true, render_scale = 1.0, detail_distance = 1.8},
]

# Game
var mouse_sensitivity := 1.0
var invert_mouse_y := false
var field_of_view := 80.0
# Sound (0 to 1)
var master_volume := 0.8
var effects_volume := 1.0
var ambience_volume := 0.8
# Display
var window_mode := WindowMode.WINDOWED
var vsync := true
## 0 = no limit.
var max_fps := 0
## 1.0 = full resolution. Lower is faster but blurrier.
var render_scale := 1.0
var brightness := 1.0
# Graphics (defaults = the "High" preset)
var anti_aliasing := AntiAliasing.MSAA_2X
var shadow_quality := Shadows.HIGH
var ambient_occlusion := true
var glow := true
## Multiplies how far grass, flowers and small props are drawn.
var detail_distance := 1.3

const SAVED_VALUES := {
	game = ["mouse_sensitivity", "invert_mouse_y", "field_of_view", "master_volume", "effects_volume", "ambience_volume"],
	display = ["window_mode", "vsync", "max_fps", "render_scale", "brightness"],
	graphics = ["anti_aliasing", "shadow_quality", "ambient_occlusion", "glow", "detail_distance"],
}

var _default_bindings := {}
## Worlds (environment + sun) that graphics settings apply to.
var _worlds: Array[Dictionary] = []


func _ready() -> void:
	# Remember the original keys from Project Settings, for "Reset to defaults".
	for entry in REBINDABLE_ACTIONS:
		_default_bindings[entry[0]] = InputMap.action_get_events(entry[0])
	load_settings()
	apply_all()


# --- Changing settings ------------------------------------------------------

## Changes one setting by name, applies it and saves.
func set_value(setting: String, value: Variant) -> void:
	set(setting, value)
	apply_all()
	save_settings()
	changed.emit()


func apply_preset(index: int) -> void:
	for key in PRESETS[index]:
		set(key, PRESETS[index][key])
	apply_all()
	save_settings()
	changed.emit()


## Index of the preset the current graphics match, or -1 for "Custom".
func get_current_preset() -> int:
	for i in PRESETS.size():
		var matches := true
		for key in PRESETS[i]:
			if not is_equal_approx(float(get(key)), float(PRESETS[i][key])):
				matches = false
		if matches:
			return i
	return -1


## Mouse turn speed in radians per pixel, used by the player.
func get_mouse_turn_speed() -> float:
	return BASE_MOUSE_SENSITIVITY * mouse_sensitivity


# --- Key bindings -------------------------------------------------------------

## Makes `event` the key for `action`. If another action already used that key,
## the two swap keys so nothing is left without a key.
func rebind(action: String, event: InputEvent) -> void:
	var old_events := InputMap.action_get_events(action)
	for entry in REBINDABLE_ACTIONS:
		var other: String = entry[0]
		if other == action:
			continue
		for other_event in InputMap.action_get_events(other):
			if _same_input(other_event, event):
				InputMap.action_erase_events(other)
				for old in old_events:
					InputMap.action_add_event(other, old)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_settings()
	changed.emit()


func reset_bindings() -> void:
	for action in _default_bindings:
		InputMap.action_erase_events(action)
		for event in _default_bindings[action]:
			InputMap.action_add_event(action, event)
	save_settings()
	changed.emit()


## The key name shown in menus, e.g. "W", "Space" or "Left Click".
func get_binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "-"
	return event_to_text(events[0])


func event_to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode: Key = event.keycode
		if event.physical_keycode != KEY_NONE:
			keycode = event.physical_keycode
			# Show the key's name on the player's own keyboard layout (e.g. AZERTY),
			# when the window system can tell us.
			if DisplayServer.get_name() != "headless":
				keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
		return OS.get_keycode_string(keycode)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "Left Click"
			MOUSE_BUTTON_RIGHT: return "Right Click"
			MOUSE_BUTTON_MIDDLE: return "Middle Click"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %d" % event.button_index
	return "?"


func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.keycode == b.keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


# --- Applying -------------------------------------------------------------------

## Called by each level so graphics settings reach its sky, fog and sun.
func register_world(environment: Environment, sun: DirectionalLight3D) -> void:
	_worlds.append({environment = environment, sun = sun})
	apply_all()


func apply_all() -> void:
	_apply_display()
	_apply_viewport()
	# Forget worlds that were closed (e.g. leaving the main menu).
	_worlds.assign(_worlds.filter(func(w): return is_instance_valid(w.sun)))
	_apply_shadows()
	for world in _worlds:
		var env: Environment = world.environment
		env.ssao_enabled = ambient_occlusion
		env.glow_enabled = glow
		env.adjustment_enabled = true
		env.adjustment_brightness = brightness
	for node in get_tree().get_nodes_in_group("detail_props"):
		node.visibility_range_end = node.get_meta("base_view_distance") * detail_distance


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	match window_mode:
		WindowMode.BORDERLESS: mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		WindowMode.FULLSCREEN: mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps


func _apply_viewport() -> void:
	var viewport := get_viewport()
	viewport.scaling_3d_scale = render_scale
	# FSR keeps a lower render scale looking sharp.
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if anti_aliasing == AntiAliasing.FXAA else Viewport.SCREEN_SPACE_AA_DISABLED
	match anti_aliasing:
		AntiAliasing.MSAA_2X: viewport.msaa_3d = Viewport.MSAA_2X
		AntiAliasing.MSAA_4X: viewport.msaa_3d = Viewport.MSAA_4X
		_: viewport.msaa_3d = Viewport.MSAA_DISABLED


func _apply_shadows() -> void:
	var atlas_size := 4096
	var shadow_distance := 100.0
	var softness := RenderingServer.SHADOW_QUALITY_SOFT_LOW
	match shadow_quality:
		Shadows.LOW:
			atlas_size = 2048
			shadow_distance = 60.0
			softness = RenderingServer.SHADOW_QUALITY_HARD
		Shadows.HIGH:
			atlas_size = 8192
			shadow_distance = 140.0
			softness = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	RenderingServer.directional_shadow_atlas_set_size(atlas_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(softness)
	for world in _worlds:
		var sun: DirectionalLight3D = world.sun
		if is_instance_valid(sun):
			sun.shadow_enabled = shadow_quality != Shadows.OFF
			sun.directional_shadow_max_distance = shadow_distance


# --- Saving and loading -------------------------------------------------------------

func save_settings() -> void:
	var config := ConfigFile.new()
	for section in SAVED_VALUES:
		for key in SAVED_VALUES[section]:
			config.set_value(section, key, get(key))
	for entry in REBINDABLE_ACTIONS:
		var events := InputMap.action_get_events(entry[0])
		if events.is_empty():
			continue
		var event: InputEvent = events[0]
		if event is InputEventKey:
			config.set_value("keys", entry[0], "key:%d:%d" % [event.physical_keycode, event.keycode])
		elif event is InputEventMouseButton:
			config.set_value("keys", entry[0], "mouse:%d" % event.button_index)
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # First time playing: keep the defaults.
	for section in SAVED_VALUES:
		for key in SAVED_VALUES[section]:
			if config.has_section_key(section, key):
				set(key, config.get_value(section, key))
	if config.has_section("keys"):
		for action in config.get_section_keys("keys"):
			if not InputMap.has_action(action):
				continue
			var event := _event_from_text(str(config.get_value("keys", action)))
			if event != null:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)


func _event_from_text(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts[0] == "key" and parts.size() == 3:
		var key := InputEventKey.new()
		key.physical_keycode = int(parts[1]) as Key
		key.keycode = int(parts[2]) as Key
		return key
	if parts[0] == "mouse" and parts.size() == 2:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(parts[1]) as MouseButton
		return mouse
	return null
