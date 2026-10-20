class_name Helicopter
extends Node3D
## The medical rescue helicopter ("medi-copter"): white with red stripes and a red cross,
## a bubble cockpit, a tail boom, skids, and spinning rotors. Built in code, faces -Z.
## The pilot and Nurse Nina sit inside. rotor_speed spins the blades; smoking makes the
## engine pour out black smoke (it's about to crash...).

const WHITE := Color(0.95, 0.95, 0.93)
const RED := Color(0.85, 0.15, 0.15)
const GLASS := Color(0.45, 0.62, 0.78)
const DARK := Color(0.18, 0.19, 0.22)
const INTERACT_LAYER := 1 << 3

## Turns per second of the main rotor.
var rotor_speed := 0.0
var smoking := false:
	set(value):
		smoking = value
		if _smoke != null:
			_smoke.emitting = value
## Called when a player presses E on the helicopter (boarding). Set by the RescueEvent.
var on_board: Callable
var boarding_open := false

var _rotor: Node3D
var _tail_rotor: Node3D
var _smoke: GPUParticles3D
var _crew: Array[CharacterModel] = []


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_rotor.rotation.y += rotor_speed * TAU * delta
	_tail_rotor.rotation.x += rotor_speed * TAU * 1.6 * delta


## Shows Captain Gus sitting in the back (during the flight).
func show_passenger(visible_now: bool) -> void:
	if _crew.size() > 2:
		_crew[2].visible = visible_now


# --- Boarding (players press E on it) ------------------------------------------------------

func get_interact_text() -> String:
	return "Board the helicopter" if boarding_open else ""


func interact(player: Node) -> void:
	if boarding_open and on_board.is_valid():
		on_board.call(player)


# --- Building ------------------------------------------------------------------------------

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var st := LowPoly.begin()
	# Cabin: a rounded body, wider at the front, with the glass bubble cockpit.
	_blob(st, Vector3(0, 1.45, 0.2), Vector3(1.05, 1.0, 1.9), WHITE, rng)
	_blob(st, Vector3(0, 1.45, -1.2), Vector3(0.95, 0.9, 0.9), GLASS, rng)
	_blob(st, Vector3(0, 1.0, 0.3), Vector3(1.0, 0.45, 1.7), WHITE.darkened(0.06), rng)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(0.02, 0.18, 2.6), Vector3(1.02 * side, 1.3, 0.25), RED, Basis(), rng)        # side stripe
		# Red cross on each side.
		_box(st, Vector3(0.03, 0.55, 0.16), Vector3(1.0 * side, 1.6, 0.8), RED, Basis(), rng)
		_box(st, Vector3(0.03, 0.16, 0.55), Vector3(1.0 * side, 1.6, 0.8), RED, Basis(), rng)
		# Skids.
		_box(st, Vector3(0.1, 0.08, 3.4), Vector3(0.85 * side, 0.08, 0.1), DARK, Basis(), rng)
		for z in [-0.8, 0.9]:
			_box(st, Vector3(0.07, 0.7, 0.07), Vector3(0.75 * side, 0.42, z), DARK, Basis(Vector3.BACK, 0.25 * side), rng)
	# Tail boom with fins.
	_box(st, Vector3(0.35, 0.35, 4.2), Vector3(0, 1.75, 3.8), WHITE, Basis(Vector3.RIGHT, -0.05), rng)
	_box(st, Vector3(0.36, 0.1, 4.2), Vector3(0, 1.6, 3.8), RED, Basis(Vector3.RIGHT, -0.05), rng)
	_box(st, Vector3(0.12, 1.1, 0.7), Vector3(0, 2.3, 5.8), RED, Basis(Vector3.RIGHT, -0.3), rng)
	_box(st, Vector3(1.4, 0.08, 0.4), Vector3(0, 1.85, 5.4), WHITE, Basis(), rng)
	# Engine housing and the rotor mast on top.
	_box(st, Vector3(0.9, 0.45, 1.4), Vector3(0, 2.45, 0.6), WHITE.darkened(0.05), Basis(), rng)
	_box(st, Vector3(0.18, 0.4, 0.18), Vector3(0, 2.85, 0.3), DARK, Basis(), rng)
	var body := MeshInstance3D.new()
	body.mesh = LowPoly.commit(st)
	add_child(body)

	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 3.1, 0.3)
	add_child(_rotor)
	var blades := LowPoly.begin()
	for i in 4:
		_box(blades, Vector3(0.35, 0.05, 5.2), Vector3.ZERO, DARK, Basis(Vector3.UP, i * PI * 0.25) * Basis(Vector3.FORWARD, 0.04), rng)
	_box(blades, Vector3(0.4, 0.15, 0.4), Vector3.ZERO, DARK.lightened(0.1), Basis(), rng)
	var blade_mesh := MeshInstance3D.new()
	blade_mesh.mesh = LowPoly.commit(blades)
	_rotor.add_child(blade_mesh)

	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.25, 2.3, 5.85)
	add_child(_tail_rotor)
	var tail_blades := LowPoly.begin()
	for i in 2:
		_box(tail_blades, Vector3(0.04, 1.2, 0.14), Vector3.ZERO, DARK, Basis(Vector3.RIGHT, i * PI * 0.5), rng)
	var tail_mesh := MeshInstance3D.new()
	tail_mesh.mesh = LowPoly.commit(tail_blades)
	_tail_rotor.add_child(tail_mesh)

	# The crew: the pilot up front, Nurse Nina next to him, and a seat for Gus in the back.
	for i in 3:
		var person := CharacterModel.new()
		if i == 0:
			person.shirt_color = Color(0.25, 0.35, 0.25)
			person.hat = CharacterModel.Hat.BEANIE
			person.hat_color = Color(0.2, 0.2, 0.22)
		elif i == 1:
			CharacterLooks.nurse(person)
		else:
			person.shirt_color = Color(0.95, 0.95, 0.93)
			person.short_sleeves = true
			person.pants_color = Color(0.16, 0.18, 0.26)
			person.hat = CharacterModel.Hat.PILOT_CAP
			person.tie = true
			person.mustache = true
			person.splinted_leg = true
		person.position = [Vector3(-0.4, 0.75, -0.9), Vector3(0.4, 0.75, -0.9), Vector3(0.0, 0.75, 0.6)][i]
		add_child(person)
		person.set_sitting_instantly(true)
		person.visible = i < 2
		_crew.append(person)

	# Smoke from the engine when it fails.
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0.3)
	process.spread = 25.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 3.0
	process.gravity = Vector3(0, 1.0, 2.0)
	process.scale_min = 0.8
	process.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.1, 0.1, 0.1, 0.8))
	fade.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	var puff := SphereMesh.new()
	puff.radius = 0.4
	puff.height = 0.8
	puff.radial_segments = 6
	puff.rings = 3
	var puff_material := StandardMaterial3D.new()
	puff_material.vertex_color_use_as_albedo = true
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_material
	_smoke = GPUParticles3D.new()
	_smoke.amount = 40
	_smoke.lifetime = 3.0
	_smoke.local_coords = false
	_smoke.process_material = process
	_smoke.draw_pass_1 = puff
	_smoke.position = Vector3(0, 2.6, 1.0)
	_smoke.emitting = false
	_smoke.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	add_child(_smoke)

	# Something to press E on (and stand against) while it's on the ground.
	var body_collision := InteractProxy.new()
	body_collision.target = self
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.2, 3.4)
	shape.shape = box
	shape.position = Vector3(0, 1.3, 0.0)
	body_collision.add_child(shape)
	add_child(body_collision)


func _blob(st: SurfaceTool, at: Vector3, radii: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 7
	LowPoly.add_shape(st, ball, Transform3D(Basis.from_scale(radii), at), color, 0.0, 0.04, rng)


func _box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, rot: Basis, rng: RandomNumberGenerator) -> void:
	var box := BoxMesh.new()
	box.size = size
	LowPoly.add_shape(st, box, Transform3D(rot, at), color, 0.0, 0.04, rng)
