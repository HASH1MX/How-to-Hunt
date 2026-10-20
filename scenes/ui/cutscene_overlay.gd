class_name CutsceneOverlay
extends CanvasLayer
## The film look for story moments: black bars slide in at the top and bottom, subtitles
## ("Gus: We did it!") appear above the bottom bar, the screen can fade to black, and big
## centred text can appear ("Hours later...").

const BAR_HEIGHT := 90.0

var _top: ColorRect
var _bottom: ColorRect
var _subtitle: Label
var _fade: ColorRect
var _title: Label
var _subtitle_tween: Tween


func _ready() -> void:
	layer = 50
	_top = _bar(true)
	_bottom = _bar(false)
	_subtitle = UiStyle.label("", 28)
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.offset_bottom = -BAR_HEIGHT - 18
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_title = UiStyle.label("", 44, Color(1.0, 0.95, 0.84))
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	add_child(_title)
	var slide := create_tween().set_parallel(true)
	slide.tween_property(_top, "offset_bottom", BAR_HEIGHT, 0.6).set_ease(Tween.EASE_OUT)
	slide.tween_property(_bottom, "offset_top", -BAR_HEIGHT, 0.6).set_ease(Tween.EASE_OUT)


func _bar(top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		bar.offset_bottom = 0.0
	else:
		bar.offset_top = 0.0
	add_child(bar)
	return bar


## Shows a line of dialogue for a few seconds, with a voice blip.
func say(speaker: String, text: String, seconds: float = 3.0) -> void:
	_subtitle.text = "%s:  %s" % [speaker, text] if speaker != "" else text
	if _subtitle_tween != null:
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.2)
	_subtitle_tween.tween_interval(seconds)
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.4)
	Sfx.play("blip", -10.0, 0.15)


func fade_to(alpha: float, seconds: float) -> void:
	create_tween().tween_property(_fade, "color:a", alpha, seconds)


## Big words in the middle of the screen (shown over the black).
func show_title(text: String, seconds: float = 2.0) -> void:
	_title.text = text
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.5)
	tween.tween_interval(seconds)
	tween.tween_property(_title, "modulate:a", 0.0, 0.5)
