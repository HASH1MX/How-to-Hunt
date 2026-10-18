class_name WorldSelectMenu
extends Control
## The save-game picker, in the same look as the game's other panels (dark see-through
## box, white-outlined rows, soft shadowed text): one row per world with how long it has
## been played and when, Play and Delete, and a line at the bottom to start a new world.
## Emits `world_chosen(id)` with the world already opened in the SaveManager.
## Used for Play and for choosing which world to host.

signal world_chosen(id: String)
signal closed

const ADJECTIVES := ["Lucky", "Sleepy", "Wild", "Cozy", "Stormy", "Sunny", "Grumpy", "Brave", "Mossy", "Salty", "Wobbly", "Sneaky"]
const NOUNS := ["Island", "Cove", "Camp", "Hideout", "Isle", "Shores", "Outpost", "Hollow"]
const ACCENT := Color(0.93, 0.45, 0.3)
const WIDTH := 540.0
const ROW_HEIGHT := 76.0
const MAX_LIST_HEIGHT := 290.0

## What the window is for, shown as its title (e.g. "Choose a world" or "Host which world?").
var title_text := "Choose a world"

var _scroll: ScrollContainer
var _list: VBoxContainer
var _name_edit: LineEdit
var _pending_delete := ""
var _suggestion := ""


func _ready() -> void:
	theme = UiStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# The box is only as tall as what is in it, centred on screen.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.88))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := UiStyle.label(title_text, 36, Color(1.0, 0.95, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	column.add_child(_new_world_row())

	var back := Button.new()
	back.text = "Back"
	back.flat = true
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", UiStyle.DIM_TEXT_COLOR)
	back.add_theme_color_override("font_hover_color", ACCENT)
	back.add_theme_color_override("font_outline_color", UiStyle.SHADOW_COLOR)
	back.add_theme_constant_override("outline_size", 5)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(close)
	column.add_child(back)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _name_edit.has_focus():
		close()
		get_viewport().set_input_as_handled()


# --- The list of worlds -------------------------------------------------------------------

func _refresh() -> void:
	var keep_scroll := _scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var worlds := SaveManager.list_worlds()
	if worlds.is_empty():
		var hint := UiStyle.label("No worlds yet. Start one below!", 22, UiStyle.DIM_TEXT_COLOR)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.custom_minimum_size = Vector2(0, 70)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(hint)
	for world in worlds:
		_list.add_child(_world_row(world))
	_scroll.custom_minimum_size.y = minf(maxf(worlds.size(), 1) * (ROW_HEIGHT + 8.0) - 8.0, MAX_LIST_HEIGHT)
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _world_row(world: Dictionary) -> Control:
	var row_box := PanelContainer.new()
	row_box.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var normal := UiStyle.outline_style()
	normal.content_margin_left = 16
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.09)
	hover.border_color = Color(1, 1, 1, 1.0)
	row_box.add_theme_stylebox_override("panel", normal)
	row_box.mouse_entered.connect(func(): row_box.add_theme_stylebox_override("panel", hover))
	row_box.mouse_exited.connect(func(): row_box.add_theme_stylebox_override("panel", normal))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row_box.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", -2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var name_label := UiStyle.label(world.name, 26)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	info.add_child(UiStyle.label("%s played  -  %s" % [_duration(world.play_seconds), _last_played(world.last_played)], 15, UiStyle.DIM_TEXT_COLOR))

	var confirming: bool = _pending_delete == world.id
	var delete := _text_button("Really?" if confirming else "Delete", 17)
	delete.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4) if confirming else UiStyle.DIM_TEXT_COLOR)
	delete.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.45))
	delete.pressed.connect(func():
		if _pending_delete == world.id:
			SaveManager.delete_world(world.id)
			_pending_delete = ""
		else:
			_pending_delete = world.id
		_refresh())
	row.add_child(delete)

	var play := _pill_button("Play")
	play.pressed.connect(func(): _choose(world.id))
	row.add_child(play)
	return row_box


# --- Starting a new world ------------------------------------------------------------------------

func _new_world_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_suggestion = _random_name()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = _suggestion
	_name_edit.max_length = 30
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_text): _create())
	row.add_child(_name_edit)
	var dice := _text_button("New name", 17)
	dice.pressed.connect(func():
		_suggestion = _random_name()
		_name_edit.placeholder_text = _suggestion
		_name_edit.text = "")
	row.add_child(dice)
	var create := _pill_button("Create")
	create.pressed.connect(_create)
	row.add_child(create)
	return row


func _create() -> void:
	var chosen := _name_edit.text.strip_edges()
	_choose(SaveManager.create_world(chosen if chosen != "" else _suggestion))


func _choose(id: String) -> void:
	if SaveManager.load_world(id):
		Sfx.play("ui_confirm", -6.0, 0.02, "UI")
		world_chosen.emit(id)
		queue_free()
	else:
		_refresh()


func _random_name() -> String:
	return "%s %s" % [ADJECTIVES[randi() % ADJECTIVES.size()], NOUNS[randi() % NOUNS.size()]]


# --- Looks -----------------------------------------------------------------------------------------

## A rounded white-outlined button, like the game's other outlined boxes.
func _pill_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", UiStyle.SHADOW_COLOR)
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_stylebox_override("normal", _pill_style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.85)))
	button.add_theme_stylebox_override("hover", _pill_style(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5), ACCENT))
	button.add_theme_stylebox_override("pressed", _pill_style(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75), ACCENT))
	return button


## Plain text that lights up when hovered, for the small actions.
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


# --- Wording -----------------------------------------------------------------------------------------

func _last_played(unix: int) -> String:
	if unix <= 0:
		return "never played"
	var offset := int(Time.get_time_zone_from_system().bias) * 60
	var then := Time.get_datetime_dict_from_unix_time(unix + offset)
	var today_start := int(Time.get_unix_time_from_system()) + offset
	var days := int(floor(today_start / 86400.0)) - int(floor((unix + offset) / 86400.0))
	var clock := "%02d:%02d" % [then.hour, then.minute]
	if days <= 0:
		return "today %s" % clock
	if days == 1:
		return "yesterday %s" % clock
	if days < 7:
		return "%d days ago" % days
	return "%04d-%02d-%02d" % [then.year, then.month, then.day]


func _duration(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 1:
		return "Under a minute"
	if minutes < 60:
		return "%d min" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]
