class_name StatRing
extends Control
## A round How to Fish-style stat icon: a symbol with a thin ring around it
## that empties as the value goes down. The ring slides smoothly to new values
## and blinks red when the value is low.

enum Kind { HEART, FOOD, BREATH }

const LOW_COLOR := Color(0.95, 0.3, 0.25)
const ICON_COLOR := Color(1.0, 0.97, 0.94)
const HEART_COLOR := Color(1.0, 0.8, 0.8)
## How quickly the ring catches up with a new value (higher = faster).
const SMOOTHING := 12.0

var kind: Kind
var ring_color: Color
var _target := 1.0 # 0 = empty, 1 = full
var _shown := 1.0


func _init(icon_kind: Kind = Kind.HEART, color: Color = Color.WHITE) -> void:
	kind = icon_kind
	ring_color = color
	custom_minimum_size = Vector2(46, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(current: float, maximum: float) -> void:
	_target = clampf(current / maximum, 0.0, 1.0)


## Jump straight to the value without sliding (e.g. when first shown).
func snap() -> void:
	_shown = _target
	queue_redraw()


func _process(delta: float) -> void:
	if not is_equal_approx(_shown, _target) or _shown < 0.2:
		_shown = lerpf(_shown, _target, 1.0 - exp(-SMOOTHING * delta))
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(c, r, Color(0, 0, 0, 0.18))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0, true)
	var color := ring_color
	if _shown < 0.2 and fmod(Time.get_ticks_msec() / 300.0, 2.0) < 1.0:
		color = LOW_COLOR
	if _shown > 0.001:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * _shown, 48, color, 3.0, true)
	var s := r / 13.0
	match kind:
		Kind.HEART:
			_draw_heart(c, s)
		Kind.FOOD:
			_draw_fork_and_knife(c, s)
		Kind.BREATH:
			_draw_droplet(c, s)


func _draw_heart(c: Vector2, s: float) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		points.append(c + Vector2(x, y + 1.5) * 0.44 * s)
	draw_colored_polygon(points, HEART_COLOR)


func _draw_fork_and_knife(c: Vector2, s: float) -> void:
	var w := 1.6 * s
	# Fork: three prongs joined at the bottom, then a handle.
	for x in [-6.0, -4.0, -2.0]:
		draw_line(c + Vector2(x, -8) * s, c + Vector2(x, -3) * s, ICON_COLOR, w)
	draw_line(c + Vector2(-6.8, -2.5) * s, c + Vector2(-1.2, -2.5) * s, ICON_COLOR, w)
	draw_line(c + Vector2(-4, -2.5) * s, c + Vector2(-4, 8.5) * s, ICON_COLOR, w * 1.4)
	# Knife: a blade and a handle.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(2.5, -8.5) * s, c + Vector2(6.0, -6.0) * s,
		c + Vector2(6.0, 1.0) * s, c + Vector2(2.5, 1.0) * s]), ICON_COLOR)
	draw_line(c + Vector2(4.2, 1.0) * s, c + Vector2(4.2, 8.5) * s, ICON_COLOR, w * 1.4)


func _draw_droplet(c: Vector2, s: float) -> void:
	var center := c + Vector2(0, 2.5) * s
	var points := PackedVector2Array([c + Vector2(0, -9.0) * s])
	for i in 21:
		var angle := deg_to_rad(-35.0 + 250.0 * i / 20.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * 5.8 * s)
	draw_colored_polygon(points, Color(0.75, 0.9, 1.0))
