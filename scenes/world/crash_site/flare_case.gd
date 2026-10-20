class_name FlareCase
extends StaticBody3D
## The plane's emergency case, thrown out by the cockpit and dented shut. It's locked:
## Captain Gus gives you the key during "Signal for Help". Open it (hold the key, press E)
## and the flare gun is inside. Every player sees it open (it follows the quest state).

const QUEST := "signal_for_help"
const INTERACT_LAYER := 1 << 3

var _lid: Node3D
var _open := false


func _ready() -> void:
	collision_layer = 1 | INTERACT_LAYER
	collision_mask = 0
	_build()
	_set_open(_is_opened(), false)


## Opened once the quest's first step (opening it) is done, or the quest is finished.
func _is_opened() -> bool:
	return Quests.get_progress(QUEST, 0) > 0 or Quests.is_done(QUEST)


func get_interact_text() -> String:
	if _open:
		return "Emergency case (empty)"
	var player := get_tree().get_first_node_in_group("players")
	if player != null and player.inventory.get_active_item() != null and player.inventory.get_active_item().id == &"case_key":
		return "Open the emergency case"
	return "Emergency case (locked)"


func interact(player: Node) -> void:
	if _open:
		return
	var held: ItemData = player.inventory.get_active_item()
	if held == null or held.id != &"case_key":
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.show_tip("Locked", "The emergency case is dented shut and locked. Captain Gus might have the key.", 7.0)
		return
	player.inventory.take_from_active(1)
	Sfx.play_at("reload", global_position + Vector3(0, 0.4, 0), 0.0, 0.05, 20.0)
	_set_open(true, true)
	WorldSync.spawn_item(get_parent(), ItemLibrary.get_item(&"flare_gun"), global_position + Vector3(0, 0.55, 0), Vector3(0, 1.0, 0.0), Network.get_my_id())
	Quests.report("flag", "case_opened")


func _process(_delta: float) -> void:
	if not _open and _is_opened():
		_set_open(true, true)


func _set_open(open: bool, animate: bool) -> void:
	_open = open
	var angle := -1.9 if open else 0.0
	if animate:
		create_tween().tween_property(_lid, "rotation:x", angle, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lid.rotation.x = angle


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var orange := Color(0.92, 0.45, 0.12)
	var st := LowPoly.begin()
	var box := BoxMesh.new()
	box.size = Vector3(0.72, 0.26, 0.46)
	LowPoly.add_shape(st, box, Transform3D(Basis(Vector3.BACK, 0.04), Vector3(0, 0.13, 0)), orange, 0.015, 0.08, rng)
	var foam := BoxMesh.new()
	foam.size = Vector3(0.64, 0.02, 0.38)
	LowPoly.add_shape(st, foam, Transform3D(Basis(), Vector3(0, 0.255, 0)), Color(0.15, 0.15, 0.17), 0.0, 0.05, rng)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.73, 0.05, 0.47)
	LowPoly.add_shape(st, stripe, Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.95, 0.95, 0.9), 0.0, 0.0, rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	add_child(mesh)

	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.26, 0.23) # Hinged at the back.
	add_child(_lid)
	var lid_tool := LowPoly.begin()
	var lid := BoxMesh.new()
	lid.size = Vector3(0.72, 0.07, 0.46)
	LowPoly.add_shape(lid_tool, lid, Transform3D(Basis(Vector3.FORWARD, 0.05), Vector3(0, 0.035, -0.23)), orange.darkened(0.08), 0.012, 0.08, rng)
	var latch := BoxMesh.new()
	latch.size = Vector3(0.1, 0.06, 0.03)
	LowPoly.add_shape(lid_tool, latch, Transform3D(Basis(), Vector3(0, 0.0, -0.46)), Color(0.75, 0.75, 0.78), 0.0, 0.0, rng)
	var lid_mesh := MeshInstance3D.new()
	lid_mesh.mesh = LowPoly.commit(lid_tool)
	_lid.add_child(lid_mesh)

	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(0.72, 0.32, 0.46)
	shape.shape = collider
	shape.position.y = 0.16
	add_child(shape)
