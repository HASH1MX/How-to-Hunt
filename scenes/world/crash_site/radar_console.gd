class_name RadarConsole
extends StaticBody3D
## The plane's radar, pulled out of the wreck: a metal console with a round screen and a
## dish on a pole. Dead until the quest "Scrap Hunt" brings its parts back; then the screen
## glows green, a sweep line goes round, the dish turns and it beeps. Its screen shows
## another island to the east. Look at it and press E to read it.

const QUEST := "scrap_hunt"
const INTERACT_LAYER := 1 << 3

var _screen_material: StandardMaterial3D
var _sweep: Node3D
var _blip: MeshInstance3D
var _dish: Node3D
var _on := false
var _beep_timer := 1.0


func _ready() -> void:
	collision_layer = 1 | INTERACT_LAYER
	collision_mask = 0
	_build()
	_set_on(Quests.is_done(QUEST))


func get_interact_text() -> String:
	return "Look at the radar"


func interact(_player: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if _on:
		hud.show_tip("Radar", "A blip far to the EAST: another island! If we can signal for help, a rescue could come from there.", 10.0)
	else:
		hud.show_tip("Radar", "Dead. It needs a wire bundle, a battery and an antenna to work. Captain Gus might know where they went.", 10.0)


func _process(delta: float) -> void:
	var want := Quests.is_done(QUEST)
	if want != _on:
		_set_on(want)
	if not _on:
		return
	_sweep.rotation.y -= delta * 2.2
	_dish.rotation.y += delta * 0.8
	_blip.visible = fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.7
	_beep_timer -= delta
	if _beep_timer <= 0.0:
		_beep_timer = 2.5
		Sfx.play_at("beep", global_position + Vector3(0, 1.0, 0), -10.0, 0.02, 14.0)


func _set_on(on: bool) -> void:
	_on = on
	_screen_material.albedo_color = Color(0.25, 0.95, 0.45) if on else Color(0.06, 0.08, 0.07)
	_screen_material.emission_enabled = on
	_sweep.visible = on
	_blip.visible = on


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var st := LowPoly.begin()
	var metal := Color(0.5, 0.52, 0.55)
	var dark := Color(0.2, 0.21, 0.24)
	_add_box(st, Vector3(0.8, 0.85, 0.5), Vector3(0, 0.425, 0), metal, Basis(), rng)                      # cabinet
	_add_box(st, Vector3(0.82, 0.08, 0.6), Vector3(0, 0.88, -0.04), dark, Basis(Vector3.RIGHT, -0.35), rng) # slanted top
	for x in [-0.3, -0.2, 0.25, 0.32]:
		_add_box(st, Vector3(0.05, 0.04, 0.03), Vector3(x, 0.72, -0.26), Color(0.9, 0.3, 0.2) if x > 0.0 else Color(0.95, 0.8, 0.2), Basis(), rng)  # knobs
	# The dish on its pole, behind the console.
	_add_box(st, Vector3(0.06, 1.1, 0.06), Vector3(0.3, 1.4, 0.3), dark, Basis(), rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	add_child(mesh)

	_dish = Node3D.new()
	_dish.position = Vector3(0.3, 1.95, 0.3)
	add_child(_dish)
	var dish_tool := LowPoly.begin()
	var cup := SphereMesh.new()
	cup.radius = 0.32
	cup.height = 0.64
	cup.radial_segments = 10
	cup.rings = 5
	cup.is_hemisphere = true
	LowPoly.add_shape(dish_tool, cup, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.4).scaled(Vector3(1, 0.35, 1)), Vector3(0, 0, -0.05)), Color(0.85, 0.86, 0.88), 0.0, 0.05, rng)
	var dish_mesh := MeshInstance3D.new()
	dish_mesh.mesh = LowPoly.commit(dish_tool, true)
	_dish.add_child(dish_mesh)

	# Round screen on the slanted top, with a sweep line and a blinking blip.
	var screen_holder := Node3D.new()
	screen_holder.position = Vector3(-0.05, 0.93, -0.06)
	screen_holder.rotation.x = -0.35
	add_child(screen_holder)
	var screen := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.02
	disc.radial_segments = 16
	screen.mesh = disc
	_screen_material = StandardMaterial3D.new()
	_screen_material.emission = Color(0.2, 0.9, 0.4)
	_screen_material.emission_energy_multiplier = 1.4
	_screen_material.roughness = 0.4
	screen.material_override = _screen_material
	screen_holder.add_child(screen)
	_sweep = Node3D.new()
	_sweep.position.y = 0.014
	screen_holder.add_child(_sweep)
	var line := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.18, 0.004, 0.012)
	line.mesh = bar
	line.position.x = 0.09
	var bright := StandardMaterial3D.new()
	bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bright.albedo_color = Color(0.7, 1.0, 0.75)
	line.material_override = bright
	_sweep.add_child(line)
	_blip = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.018
	dot.height = 0.036
	_blip.mesh = dot
	_blip.material_override = bright
	_blip.position = Vector3(0.13, 0.016, 0.02) # East (to the right on the screen).
	screen_holder.add_child(_blip)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, 1.0, 0.55)
	shape.shape = box
	shape.position.y = 0.5
	add_child(shape)


func _add_box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, rot: Basis, rng: RandomNumberGenerator) -> void:
	var box := BoxMesh.new()
	box.size = size
	LowPoly.add_shape(st, box, Transform3D(rot, at), color, 0.0, 0.05, rng)
