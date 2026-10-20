class_name GusMemorial
extends Node3D
## A little driftwood cross on Island 2's beach with Captain Gus's cap hanging on it and a
## ring of shells. It appears once the quest "Gus's Memorial" is done (for every player).

const QUEST := "gus_memorial"

var _visual: Node3D


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	var st := LowPoly.begin()
	var drift := Color(0.72, 0.62, 0.5)
	var post := BoxMesh.new()
	post.size = Vector3(0.1, 1.3, 0.08)
	LowPoly.add_shape(st, post, Transform3D(Basis(Vector3.BACK, 0.04), Vector3(0, 0.6, 0)), drift, 0.01, 0.08, rng)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.6, 0.09, 0.07)
	LowPoly.add_shape(st, arm, Transform3D(Basis(Vector3.BACK, -0.06), Vector3(0, 0.95, 0)), drift, 0.01, 0.08, rng)
	var shell := SphereMesh.new()
	shell.radius = 0.06
	shell.height = 0.06
	shell.radial_segments = 6
	shell.rings = 3
	for i in 10:
		var angle := TAU * i / 10.0
		var colour := Color(0.98, 0.9, 0.85) if i % 2 == 0 else Color(0.95, 0.7, 0.6)
		LowPoly.add_shape(st, shell, Transform3D(Basis(), Vector3(cos(angle) * 0.5, 0.02, sin(angle) * 0.5)), colour, 0.0, 0.05, rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	_visual.add_child(mesh)
	var cap := MeshInstance3D.new()
	cap.mesh = ItemLibrary.get_item(&"gus_hat").mesh
	cap.position = Vector3(0, 1.25, 0)
	cap.rotation = Vector3(0.15, 0.0, 0.1)
	_visual.add_child(cap)
	var label := Label3D.new()
	label.text = "Captain Gus"
	label.font_size = 36
	label.outline_size = 8
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.75, 0)
	label.visibility_range_end = 12.0
	_visual.add_child(label)
	_visual.visible = Quests.is_done(QUEST)


func _process(_delta: float) -> void:
	var done := Quests.is_done(QUEST)
	if done and not _visual.visible:
		_visual.visible = true
		_visual.scale = Vector3.ONE * 0.05
		create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not done:
		_visual.visible = false
