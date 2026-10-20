class_name CustomizeMenu
extends Control
## The Customize screen: your character turning slowly on the left (drag to spin it), and
## on the right a button for each body part, a grid of colours and a custom colour picker.
## Every part is coloured on its own. "Reset part" puts back the chosen part's colour,
## "Reset all" the whole character. Changes are saved straight away (Appearance autoload)
## and, in multiplayer, sent to the other players.

signal closed

const ACCENT := Color(0.93, 0.45, 0.3)
const SWATCHES := [
	Color(0.98, 0.98, 0.96), Color(0.62, 0.63, 0.65), Color(0.25, 0.26, 0.28), Color(0.1, 0.1, 0.11),
	Color(0.95, 0.8, 0.64), Color(0.88, 0.7, 0.48), Color(0.68, 0.48, 0.32), Color(0.42, 0.28, 0.18),
	Color(0.9, 0.22, 0.2), Color(0.96, 0.52, 0.12), Color(0.98, 0.82, 0.2), Color(0.55, 0.78, 0.25),
	Color(0.2, 0.6, 0.32), Color(0.2, 0.7, 0.75), Color(0.27, 0.45, 0.85), Color(0.2, 0.22, 0.3),
	Color(0.55, 0.35, 0.8), Color(0.92, 0.45, 0.7), Color(0.98, 0.7, 0.72), Color(0.55, 0.3, 0.22),
]

var _part := "torso"
var _model: CharacterModel
var _pivot: Node3D
var _spin := 0.4
var _dragging := false
var _idle_time := 0.0
var _part_buttons := {}
var _swatch_buttons: Array[Button] = []
var _picker: ColorPickerButton
var _part_title: Label


func _ready() -> void:
	theme = UiStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.9))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := UiStyle.label("Customize", 32, Color(1.0, 0.95, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	row.add_child(_build_preview())
	row.add_child(_build_controls())

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(bottom)
	var hint := UiStyle.label("Drag the character to turn it", 15, UiStyle.DIM_TEXT_COLOR)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	var reset_all := _text_button("Reset all", 18)
	reset_all.pressed.connect(func():
		Appearance.reset_all()
		Sfx.play("ui_close", -8.0, 0.02, "UI"))
	bottom.add_child(reset_all)
	var done := _pill_button("Done")
	done.pressed.connect(close)
	bottom.add_child(done)

	Appearance.changed.connect(_refresh)
	_select(_part)
	_refresh()


func close() -> void:
	Sfx.play("ui_confirm", -8.0, 0.02, "UI")
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_idle_time += delta
	if not _dragging and _idle_time > 1.5:
		_spin += delta * 0.5
	_pivot.rotation.y = _spin


# --- The turning character --------------------------------------------------------------------

func _build_preview() -> Control:
	var frame := PanelContainer.new()
	var style := UiStyle.outline_style()
	style.border_color = Color(1, 1, 1, 0.35)
	style.bg_color = Color(1, 1, 1, 0.04)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(270, 380)
	holder.gui_input.connect(_on_preview_input)
	frame.add_child(holder)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	holder.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0.0)
	sun.light_energy = 1.25
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, 0.98, 4.1)
	viewport.add_child(camera)

	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_model = CharacterModel.new()
	_model.name = "Preview"
	_model.part_colors = Appearance.colors.duplicate()
	_model.rotation.y = PI # The model faces -Z; turn it towards the camera.
	_pivot.add_child(_model)
	return frame


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_idle_time = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_spin += event.relative.x * 0.012
		_idle_time = 0.0


# --- Choosing parts and colours -----------------------------------------------------------------

func _build_controls() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(380, 0)

	box.add_child(UiStyle.label("Body part", 18, UiStyle.DIM_TEXT_COLOR))
	var parts := GridContainer.new()
	parts.columns = 2
	parts.add_theme_constant_override("h_separation", 6)
	parts.add_theme_constant_override("v_separation", 6)
	box.add_child(parts)
	for part in Appearance.PARTS:
		var button := Button.new()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 32)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = Appearance.PART_NAMES[part]
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("pressed", _pill_style(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4), ACCENT))
		button.add_theme_constant_override("icon_max_width", 18)
		button.pressed.connect(_select.bind(part))
		parts.add_child(button)
		_part_buttons[part] = button

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	_part_title = UiStyle.label("", 22)
	box.add_child(_part_title)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for color in SWATCHES:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(66, 28)
		swatch.tooltip_text = "#" + color.to_html(false)
		swatch.set_meta("color", color)
		swatch.pressed.connect(func(): _set_color(color))
		grid.add_child(swatch)
		_swatch_buttons.append(swatch)

	var custom := HBoxContainer.new()
	custom.add_theme_constant_override("separation", 10)
	box.add_child(custom)
	custom.add_child(UiStyle.label("Custom colour", 18, UiStyle.DIM_TEXT_COLOR))
	_picker = ColorPickerButton.new()
	_picker.edit_alpha = false
	_picker.custom_minimum_size = Vector2(110, 34)
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.color_changed.connect(_set_color)
	custom.add_child(_picker)
	var reset_part := _text_button("Reset part", 18)
	reset_part.pressed.connect(func():
		Appearance.reset_part(_part)
		Sfx.play("ui_close", -8.0, 0.02, "UI"))
	custom.add_child(reset_part)
	return box


func _select(part: String) -> void:
	_part = part
	for key in _part_buttons:
		_part_buttons[key].set_pressed_no_signal(key == part)
	Sfx.play("ui_open", -12.0, 0.04, "UI")
	_refresh()


func _set_color(color: Color) -> void:
	Appearance.set_color(_part, color)


## Shows the current colours: on the model, the part buttons, the swatches and the picker.
func _refresh() -> void:
	if _model != null:
		_model.apply_part_colors(Appearance.colors)
	var current := Appearance.get_color(_part)
	_part_title.text = Appearance.PART_NAMES[_part]
	_picker.set_pick_color(current)
	for part in _part_buttons:
		_part_buttons[part].icon = _dot(Appearance.get_color(part))
	for swatch in _swatch_buttons:
		var color: Color = swatch.get_meta("color")
		var chosen := color.is_equal_approx(current)
		var border := ACCENT if chosen else Color(1, 1, 1, 0.25)
		for state in ["normal", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, _swatch_style(color, border, 3 if chosen else 1))
		swatch.add_theme_stylebox_override("hover", _swatch_style(color, Color.WHITE, 3 if chosen else 2))


# --- Looks -----------------------------------------------------------------------------------------

## A small round dot of colour (shown next to each body part's name).
func _dot(color: Color) -> Texture2D:
	var size := 18
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - middle, y - middle).length()
			if d <= middle - 1.5:
				image.set_pixel(x, y, color)
			elif d <= middle:
				image.set_pixel(x, y, Color(1, 1, 1, 0.9))
	return ImageTexture.create_from_image(image)


func _swatch_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(8)
	style.set_border_width_all(width)
	style.border_color = border
	return style


func _pill_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 44)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_outline_color", UiStyle.SHADOW_COLOR)
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_stylebox_override("normal", _pill_style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.85)))
	button.add_theme_stylebox_override("hover", _pill_style(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5), ACCENT))
	button.add_theme_stylebox_override("pressed", _pill_style(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75), ACCENT))
	return button


func _text_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", UiStyle.DIM_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", UiStyle.SHADOW_COLOR)
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _pill_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 2
	style.content_margin_bottom = 5
	return style
