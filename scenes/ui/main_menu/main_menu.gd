extends Node3D
## The start page. The real Crash Forest is shown in the background with a
## camera slowly circling the crashed plane, and the title and buttons on top.

const GAME_SCENE := "res://scenes/world/crash_forest/crash_forest.tscn"
## The point the camera circles around (the crash site).
const ORBIT_CENTER := Vector3(-1.0, 1.5, -11.0)
const ORBIT_RADIUS := 21.0
const ORBIT_HEIGHT := 6.5
## Radians per second. Small = slow, calm movement.
const ORBIT_SPEED := 0.05

@onready var camera: Camera3D = $MenuCamera

var _orbit_angle := 0.6
var _fade: ColorRect
var _loading: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_update_camera(0.0)
	# Fade in from black.
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0)


func _process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	_orbit_angle += ORBIT_SPEED * delta
	var offset := Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * ORBIT_RADIUS
	camera.global_position = ORBIT_CENTER + offset + Vector3(0.0, ORBIT_HEIGHT, 0.0)
	camera.look_at(ORBIT_CENTER)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# Darker on the left so the text is easy to read over the world.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.6))
	gradient.set_color(1, Color(0, 0, 0, 0.0))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 620
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 80
	column.offset_top = -190
	column.offset_bottom = 190
	column.add_theme_constant_override("separation", 6)
	ui.add_child(column)

	column.add_child(UiStyle.label("How to Hunt", 86, Color(1.0, 0.95, 0.84)))
	column.add_child(UiStyle.label("Stranded. Hungry. Armed with fists.", 22, UiStyle.DIM_TEXT_COLOR))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	column.add_child(gap)
	_add_button(column, "Play", _on_play_pressed)
	_add_button(column, "Quit", func(): get_tree().quit())

	var version := UiStyle.label("v0.1  prototype", 16, UiStyle.DIM_TEXT_COLOR)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 22
	version.offset_top = -40
	ui.add_child(version)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)

	_loading = UiStyle.label("Loading...", 30)
	_loading.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loading.offset_left = -200
	_loading.offset_top = -70
	_loading.visible = false
	ui.add_child(_loading)


## A text-only button that turns orange and grows a little on hover.
func _add_button(parent: Control, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(240, 0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", UiStyle.TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", UiStyle.TITLE_COLOR)
	button.add_theme_color_override("font_pressed_color", UiStyle.TITLE_COLOR)
	button.add_theme_color_override("font_focus_color", UiStyle.TEXT_COLOR)
	button.add_theme_color_override("font_outline_color", UiStyle.SHADOW_COLOR)
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(func(): _grow(button, 1.08))
	button.mouse_exited.connect(func(): _grow(button, 1.0))
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	_buttons.append(button)


func _grow(button: Button, amount: float) -> void:
	button.pivot_offset = Vector2(0, button.size.y * 0.5)
	create_tween().tween_property(button, "scale", Vector2.ONE * amount, 0.12)


func _on_play_pressed() -> void:
	for button in _buttons:
		button.disabled = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	tween.tween_callback(func(): _loading.visible = true)
	# Wait one more frame so "Loading..." appears before the world builds.
	tween.tween_interval(0.05)
	tween.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))
