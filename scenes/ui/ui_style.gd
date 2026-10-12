class_name UiStyle
## Shared look for all game text and panels, so everything matches.
## The font itself (Kurale) is set for the whole project in Project Settings
## (GUI > Theme > Custom Font), so every Label uses it automatically.

const TEXT_COLOR := Color(0.96, 0.94, 0.9)
const TITLE_COLOR := Color(0.93, 0.45, 0.3)
const DIM_TEXT_COLOR := Color(0.85, 0.84, 0.8, 0.85)
const SHADOW_COLOR := Color(0, 0, 0, 0.55)


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
