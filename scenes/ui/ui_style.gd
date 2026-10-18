class_name UiStyle
## Shared look for all game text and panels, so everything matches.
## The font itself (Kurale) is set for the whole project in Project Settings
## (GUI > Theme > Custom Font), so every Label uses it automatically.

const TEXT_COLOR := Color(0.96, 0.94, 0.9)
const TITLE_COLOR := Color(0.93, 0.45, 0.3)
const DIM_TEXT_COLOR := Color(0.85, 0.84, 0.8, 0.85)
const SHADOW_COLOR := Color(0, 0, 0, 0.55)


static var _menu_theme: Theme


## The look for menu controls (buttons, dropdowns, sliders, tabs), shared by
## the settings, pause menu and start page.
static func menu_theme() -> Theme:
	if _menu_theme != null:
		return _menu_theme
	var theme := Theme.new()
	theme.default_font_size = 20

	var normal := _box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15))
	var hover := _box(Color(1, 1, 1, 0.16), TITLE_COLOR)
	var pressed := _box(Color(0.93, 0.45, 0.3, 0.35), TITLE_COLOR)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_stylebox("disabled", type, normal)
		theme.set_color("font_color", type, TEXT_COLOR)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, TEXT_COLOR)
	theme.set_color("font_color", "Label", TEXT_COLOR)

	# Text boxes: dark and rounded, with an orange outline while typing.
	var field := _box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.14))
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 8
	field.content_margin_bottom = 10
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = TITLE_COLOR
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_color("font_color", "LineEdit", TEXT_COLOR)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.85, 0.84, 0.8, 0.4))
	theme.set_color("caret_color", "LineEdit", TITLE_COLOR)
	theme.set_color("selection_color", "LineEdit", Color(0.93, 0.45, 0.3, 0.4))
	theme.set_font_size("font_size", "LineEdit", 22)

	# Scroll bars: thin and soft.
	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color(1, 1, 1, 0.04)
	scroll_track.set_corner_radius_all(6)
	var scroll_grab := StyleBoxFlat.new()
	scroll_grab.bg_color = Color(1, 1, 1, 0.25)
	scroll_grab.set_corner_radius_all(6)
	var scroll_grab_hover := scroll_grab.duplicate() as StyleBoxFlat
	scroll_grab_hover.bg_color = Color(1, 1, 1, 0.4)
	theme.set_stylebox("scroll", "VScrollBar", scroll_track)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grab_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grab_hover)

	var popup := _box(Color(0.08, 0.09, 0.1, 0.97), Color(1, 1, 1, 0.2))
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _box(Color(0.93, 0.45, 0.3, 0.45), Color(0, 0, 0, 0)))
	theme.set_color("font_color", "PopupMenu", TEXT_COLOR)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# Slider: a thin track that fills orange, with a round grab handle.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.18)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = TITLE_COLOR
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)

	# Tabs: plain text, the open tab underlined in orange.
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(0, 0, 0, 0)
	tab.content_margin_left = 18
	tab.content_margin_right = 18
	tab.content_margin_top = 6
	tab.content_margin_bottom = 8
	var tab_selected := tab.duplicate() as StyleBoxFlat
	tab_selected.border_width_bottom = 3
	tab_selected.border_color = TITLE_COLOR
	theme.set_stylebox("tab_unselected", "TabContainer", tab)
	theme.set_stylebox("tab_hovered", "TabContainer", tab)
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	theme.set_color("font_selected_color", "TabContainer", Color.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", DIM_TEXT_COLOR)
	theme.set_color("font_hovered_color", "TabContainer", TITLE_COLOR)
	theme.set_font_size("font_size", "TabContainer", 22)
	_menu_theme = theme
	return theme


static func _box(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	return style


## A label with the game's soft drop shadow.
static func label(text: String, font_size: int, color: Color = TEXT_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 3)
	return l


## A dark see-through rounded box, like How to Fish's tip panels.
static func panel_style(alpha: float = 0.55) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, alpha)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	return style


## A rounded white outline box, like How to Fish's money counter.
static func outline_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.15)
	style.set_corner_radius_all(9)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	return style
