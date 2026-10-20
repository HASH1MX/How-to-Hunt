extends Node
## Your character's look (autoload "Appearance"): one colour for each body part, chosen on
## the Customize screen. Saved on this computer (user://appearance.cfg), used by your
## first-person arms, and sent to the other players so they see you the way you made
## yourself (see Network.send_appearance).
##
## Body parts (each one independent): head, torso, left and right arm (sleeves), left and
## right hand, left and right leg, left and right foot.
## Accessories (hats, masks, moustaches...) will be added here later as extra entries.

signal changed

const SAVE_PATH := "user://appearance.cfg"
const PARTS := ["head", "torso", "left_arm", "right_arm", "left_hand", "right_hand", "left_leg", "right_leg", "left_foot", "right_foot"]
const PART_NAMES := {
	"head": "Head", "torso": "Body", "left_arm": "Left arm", "right_arm": "Right arm",
	"left_hand": "Left hand", "right_hand": "Right hand", "left_leg": "Left leg", "right_leg": "Right leg",
	"left_foot": "Left foot", "right_foot": "Right foot",
}
const DEFAULTS := {
	"head": Color(0.88, 0.7, 0.48), "torso": Color(0.27, 0.45, 0.85),
	"left_arm": Color(0.27, 0.45, 0.85), "right_arm": Color(0.27, 0.45, 0.85),
	"left_hand": Color(0.88, 0.7, 0.48), "right_hand": Color(0.88, 0.7, 0.48),
	"left_leg": Color(0.2, 0.22, 0.3), "right_leg": Color(0.2, 0.22, 0.3),
	"left_foot": Color(0.1, 0.1, 0.11), "right_foot": Color(0.1, 0.1, 0.11),
}

## part -> Color
var colors := {}


func _ready() -> void:
	colors = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		for part in PARTS:
			colors[part] = file.get_value("colors", part, DEFAULTS[part])


func get_color(part: String) -> Color:
	return colors.get(part, DEFAULTS.get(part, Color.WHITE))


func set_color(part: String, color: Color) -> void:
	if not PARTS.has(part):
		return
	colors[part] = color
	_save()
	changed.emit()


func reset_part(part: String) -> void:
	set_color(part, DEFAULTS[part])


func reset_all() -> void:
	colors = DEFAULTS.duplicate()
	_save()
	changed.emit()


## The look as plain data (for sending to other players): part -> [r, g, b].
func to_data() -> Dictionary:
	var data := {}
	for part in PARTS:
		var c := get_color(part)
		data[part] = [c.r, c.g, c.b]
	return data


## Turns data from to_data() back into part -> Color (unknown or broken parts are skipped).
static func from_data(data: Dictionary) -> Dictionary:
	var result := {}
	for part in PARTS:
		var value = data.get(part)
		if value is Array and value.size() == 3:
			result[part] = Color(clampf(float(value[0]), 0.0, 1.0), clampf(float(value[1]), 0.0, 1.0), clampf(float(value[2]), 0.0, 1.0))
	return result


func _save() -> void:
	var file := ConfigFile.new()
	for part in PARTS:
		file.set_value("colors", part, colors[part])
	file.save(SAVE_PATH)
