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
## Hungry: eats animal bodies dropped in front of his face and pays the player for them.
@export var eats_items := false
## Sits on an airplane seat instead of standing.
@export var sits_on_seat := false
## Looks at players closer than this.
@export var look_distance := 7.0

@onready var model: CharacterModel = $Model
@onready var name_label: Label3D = $NameLabel

var has_talked := false
var _mouth: Area3D


func _ready() -> void:
	collision_layer = 1 | INTERACT_LAYER # Solid, and found by the interact ray.
	collision_mask = 0
	if sits_on_seat:
		model.sitting = true
		var seat := MeshInstance3D.new()
		seat.mesh = PropLibrary.airplane_seat(21)
		add_child(seat)
	name_label.text = display_name
	if eats_items:
		# A sphere in front of his face. Items that enter it are fed to him.
		_mouth = Area3D.new()
		_mouth.name = "Mouth"
		_mouth.collision_layer = 0
		_mouth.collision_mask = 1 << 2 # Items.
		var sphere := SphereShape3D.new()
		sphere.radius = 0.5
		var shape := CollisionShape3D.new()
		shape.shape = sphere
		_mouth.add_child(shape)
		_mouth.position = Vector3(0, 1.22 if sits_on_seat else 1.72, -0.2)
		add_child(_mouth)
		_mouth.body_entered.connect(_on_mouth_entered)


func get_interact_text() -> String:
	return "Talk to %s" % display_name


## Anything worth money that comes into his mouth gets eaten: it flies in, he chews,
## and whoever dropped it is paid. In multiplayer the host decides (see WorldSync).
func _on_mouth_entered(body: Node3D) -> void:
	if not eats_items or not body is WorldItem:
		return
	if Network.is_online() and not Network.is_host():
		return
	var food := body as WorldItem
	if food.puppet or food.eaten or food.item.value <= 0:
		return
	food.eaten = true
	var amount := food.item.value
	var mouth_position := _mouth.global_position
	food.set_deferred("freeze", true)
	food.set_deferred("collision_layer", 0)
	var tween := create_tween()
	tween.tween_property(food, "global_position", mouth_position, 0.18)
	tween.parallel().tween_property(food, "scale", Vector3.ONE * 0.1, 0.18)
	tween.tween_callback(_finish_eating.bind(food, amount, mouth_position))


func _finish_eating(food: WorldItem, amount: int, mouth_position: Vector3) -> void:
	var payer := food.dropped_by if food.dropped_by != 0 else _nearest_player(mouth_position)
	var sync := WorldSync.find(self)
	if is_instance_valid(food):
		if sync != null and food.net_id >= 0:
			sync.remove_item(food.net_id)
		else:
			food.queue_free()
	if sync != null and payer > 1 and payer != Network.get_my_id():
		sync.pay(payer, amount)
	else:
		var local := get_tree().get_first_node_in_group("players")
		if local != null:
			local.add_money(amount)
			Sfx.play("coins", -2.0, 0.04)
	model.play_chew()
	Sfx.play_at("munch", mouth_position, 0.0, 0.05, 30.0)
	FloatingText.spawn(get_parent(), mouth_position + Vector3(0, 0.3, 0), "+$%d" % amount)
	if sync != null:
		sync.broadcast_fed(mouth_position, amount)


## The peer id of whoever is closest (when nobody is recorded as having dropped it).
func _nearest_player(at: Vector3) -> int:
	var best := 1
	var best_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if player.global_position.distance_to(at) < best_distance:
			best_distance = player.global_position.distance_to(at)
			best = Network.get_my_id()
	for remote in get_tree().get_nodes_in_group("remote_players"):
		if remote.global_position.distance_to(at) < best_distance:
			best_distance = remote.global_position.distance_to(at)
			best = remote.peer_id
	return best


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
