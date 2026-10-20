extends Node3D
## The start page. The real Crash Forest is shown in the background with a
## camera slowly circling the crashed plane, and the title and buttons on top.

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
var _ui: CanvasLayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_update_camera(0.0)
	# Fade in from black.
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0)
	if Network.notice != "":
		var notice := UiStyle.label(Network.notice, 26, UiStyle.TITLE_COLOR)
		notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
		notice.offset_top = 40
		notice.offset_left = -200
		_ui.add_child(notice)
		Network.notice = ""
	_run_command_line.call_deferred()


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
	_ui = ui

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
	column.offset_top = -220
	column.offset_bottom = 220
	column.add_theme_constant_override("separation", 6)
	ui.add_child(column)

	column.add_child(UiStyle.label("How to Hunt", 86, Color(1.0, 0.95, 0.84)))
	column.add_child(UiStyle.label("Stranded. Hungry. Armed with fists.", 22, UiStyle.DIM_TEXT_COLOR))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	column.add_child(gap)
	_add_button(column, "Play", _open_worlds)
	_add_button(column, "Multiplayer", _open_multiplayer)
	_add_button(column, "Settings", _open_settings)
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


func _open_multiplayer() -> void:
	var menu := MultiplayerMenu.new()
	menu.started.connect(_on_play_pressed)
	_ui.add_child(menu)


## Handy for testing two copies of the game on one computer:
##   --host            starts hosting straight away
##   --join=ADDRESS    joins that address straight away
##   --name=NAME       sets the player name
func _run_command_line() -> void:
	var host := false
	var join := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			host = true
		elif arg.begins_with("--join="):
			join = arg.trim_prefix("--join=")
		elif arg.begins_with("--name="):
			Network.set_player_name(arg.trim_prefix("--name="))
	if host or join != "":
		SaveManager.ensure_world()
	if host:
		if Network.host() == "":
			_on_play_pressed()
	elif join != "":
		Network.joined_game.connect(_on_play_pressed, CONNECT_ONE_SHOT)
		Network.join(join)


## Play: pick (or make) a save-game world first.
func _open_worlds() -> void:
	var menu := WorldSelectMenu.new()
	menu.world_chosen.connect(func(_id): _on_play_pressed())
	_ui.add_child(menu)


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	_ui.add_child(settings)


func _on_play_pressed() -> void:
	for button in _buttons:
		button.disabled = true
	# The world behind the menu is already built, so just fade out and drop the player in.
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	tween.tween_callback(_start_game)


func _start_game() -> void:
	set_process(false)
	# The background is the first island; a save (or host) on another island loads that one.
	var world: IslandWorld = $World
	var island := IslandWorld.current_island()
	if island != world.island_id and IslandWorld.ISLAND_SCENES.has(island):
		world.name = "OldWorld"
		world.queue_free()
		world = load(IslandWorld.ISLAND_SCENES[island]).instantiate()
		world.spawn_player = false
		world.name = "World"
		add_child(world)
	world.start_game()
	camera.queue_free()
	_ui.queue_free()
	# Fade back in on a separate layer that outlives the menu UI.
	var layer := CanvasLayer.new()
	layer.layer = 100
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)
