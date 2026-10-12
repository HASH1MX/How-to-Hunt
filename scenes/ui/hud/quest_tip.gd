class_name QuestTip
extends PanelContainer
## A How to Fish-style tip box: an orange title and a short explanation.
## Use show_tip() to tell the player what to do. It fades out after a while;
## the player can bring it back with J.

const FADE_TIME := 0.6

var _title: Label
var _body: Label
var _hide_timer := 0.0
var _tween: Tween


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_style())
	custom_minimum_size = Vector2(380, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_title = UiStyle.label("", 24, UiStyle.TITLE_COLOR)
	column.add_child(_title)
	_body = UiStyle.label("", 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)
	modulate.a = 0.0
	visible = false


## Shows a tip. It hides by itself after `seconds` (0 = stays until hidden).
func show_tip(title: String, body: String, seconds: float = 20.0) -> void:
	_title.text = title
	_body.text = body
	_hide_timer = seconds
	_fade_to(1.0)


func toggle() -> void:
	if visible and modulate.a > 0.5:
		_fade_to(0.0)
	else:
		_hide_timer = 0.0
		_fade_to(1.0)


func _process(delta: float) -> void:
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, FADE_TIME)
	if alpha <= 0.0:
		_tween.tween_callback(func(): visible = false)
