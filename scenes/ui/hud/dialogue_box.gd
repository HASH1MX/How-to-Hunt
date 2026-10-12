class_name DialogueBox
extends PanelContainer
## Shows a conversation one line at a time, with the text typing itself out.
## E shows the whole line at once, or goes to the next line; after the last
## line the box closes and on_finished is called.

signal closed

## Letters typed per second.
const TYPE_SPEED := 45.0

var _speaker: Label
var _text: Label
var _continue: Label
var _lines: PackedStringArray = []
var _index := 0
var _on_finished: Callable


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_style(0.7))
	custom_minimum_size = Vector2(640, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_speaker = UiStyle.label("", 24, UiStyle.TITLE_COLOR)
	column.add_child(_speaker)
	_text = UiStyle.label("", 21)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(600, 56)
	column.add_child(_text)
	_continue = UiStyle.label("", 15, UiStyle.DIM_TEXT_COLOR)
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_continue)
	visible = false


func is_open() -> bool:
	return visible


func open(speaker: String, lines: PackedStringArray, on_finished: Callable) -> void:
	_speaker.text = speaker
	_lines = lines
	_index = 0
	_on_finished = on_finished
	visible = true
	_show_line()


## Called when the player presses E.
func advance() -> void:
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0 # Finish typing the current line first.
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		closed.emit()
		if _on_finished.is_valid():
			_on_finished.call()
		return
	_show_line()


func _show_line() -> void:
	_text.text = _lines[_index]
	_text.visible_ratio = 0.0
	_continue.text = "[E]  Close" if _index == _lines.size() - 1 else "[E]  Continue"


func _process(delta: float) -> void:
	if visible and _text.visible_ratio < 1.0 and _text.text.length() > 0:
		_text.visible_ratio = minf(_text.visible_ratio + TYPE_SPEED * delta / _text.text.length(), 1.0)
