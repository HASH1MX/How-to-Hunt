class_name QuestTracker
extends PanelContainer
## The "what do I do now" box in the top left: the active quest's name in orange and its
## steps underneath with how many are done. Finished steps turn green. J shows and hides it.

const FADE_TIME := 0.4
const DONE_COLOR := Color(0.55, 0.9, 0.55)

var _column: VBoxContainer
var _shown := true
var _tween: Tween


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_style())
	custom_minimum_size = Vector2(380, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 3)
	add_child(_column)
	visible = false


## Redraws the list from the quest system's current state.
func refresh() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var active := Quests.get_active()
	for id in active:
		var def := QuestLibrary.get_def(id)
		var title := UiStyle.label(def.title, 24, UiStyle.TITLE_COLOR)
		_column.add_child(title)
		for i in def.objectives.size():
			var objective: Dictionary = def.objectives[i]
			var done: int = Quests.get_progress(id, i)
			var text: String = objective.text
			if int(objective.count) > 1:
				text += "   %d/%d" % [done, int(objective.count)]
			var finished := done >= int(objective.count)
			_column.add_child(UiStyle.label(("- " if not finished else "+ ") + text, 18, DONE_COLOR if finished else UiStyle.TEXT_COLOR))
	visible = _shown and not active.is_empty()
	modulate.a = 1.0 if visible else 0.0


func toggle() -> void:
	_shown = not _shown
	if _tween != null:
		_tween.kill()
	if _shown and not Quests.get_active().is_empty():
		visible = true
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		_tween.tween_callback(func(): visible = false)
