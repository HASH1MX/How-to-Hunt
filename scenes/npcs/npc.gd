class_name NPC
extends StaticBody3D
## A character the player can talk to by looking at it and pressing E.
## The first conversation uses first_lines; after that, repeat_lines.
## After the first conversation, an optional quest tip is shown.
## The NPC turns its head to look at a nearby player.

signal talked_to(first_time: bool)

## Physics layer 4 is for things the player can interact with (besides items).
const INTERACT_LAYER := 1 << 3

@export var display_name := "Stranger"
@export_multiline var first_lines: PackedStringArray = []
@export_multiline var repeat_lines: PackedStringArray = []
@export_group("Quest after first talk")
@export var quest_title := ""
@export_multiline var quest_body := ""
@export_group("Behaviour")
## Sits on an airplane seat instead of standing.
@export var sits_on_seat := false
## Looks at players closer than this.
@export var look_distance := 7.0

@onready var model: CharacterModel = $Model
@onready var name_label: Label3D = $NameLabel

var has_talked := false


func _ready() -> void:
	collision_layer = 1 | INTERACT_LAYER # Solid, and found by the interact ray.
	collision_mask = 0
	if sits_on_seat:
		model.sitting = true
		var seat := MeshInstance3D.new()
		seat.mesh = PropLibrary.airplane_seat(21)
		add_child(seat)
	name_label.text = display_name


func get_interact_text() -> String:
	return "Talk to %s" % display_name


func interact(player: Node) -> void:
	var first_time := not has_talked
	var lines := first_lines if first_time or repeat_lines.is_empty() else repeat_lines
	has_talked = true
	model.talking = true
	player.start_dialogue(display_name, lines, _on_dialogue_finished.bind(first_time))


func _on_dialogue_finished(first_time: bool) -> void:
	model.talking = false
	talked_to.emit(first_time)
	if first_time and quest_title != "":
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.show_tip(quest_title, quest_body, 30.0)


func _process(_delta: float) -> void:
	# Look at the closest player within reach, otherwise look around.
	var closest: Node3D = null
	var closest_distance := look_distance
	for player in get_tree().get_nodes_in_group("players"):
		var distance := global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest = player
			closest_distance = distance
	model.look_target = closest.camera.global_position if closest != null else null
