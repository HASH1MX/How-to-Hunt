class_name FlareShot
extends Node3D
## A distress flare: shoots up into the sky trailing sparks, bursts into a bright red light
## that hangs and slowly drifts down, then fades. Seen from all over the island.

const RISE_TIME := 2.2
const HANG_TIME := 9.0

var velocity := Vector3.ZERO

var _age := 0.0
var _light: OmniLight3D
var _ball: MeshInstance3D
var _sparks: GPUParticles3D
var _burst := false


## Fires a flare from `from` towards `direction` (always aimed fairly upwards).
static func fire(parent: Node, from: Vector3, direction: Vector3) -> FlareShot:
	var flare := FlareShot.new()
	var aim := direction.normalized()
	aim.y = maxf(aim.y, 0.75)
	flare.velocity = aim.normalized() * 34.0
	parent.add_child(flare)
	flare.global_position = from
	return flare


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.25, 0.15)
	_light.light_energy = 1.5
	_light.omni_range = 12.0
	_light.shadow_enabled = false
	add_child(_light)

	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	_ball.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.35, 0.25)
	_ball.material_override = glow
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, -1, 0)
	process.spread = 25.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0, -2.0, 0)
	process.scale_min = 0.4
	process.scale_max = 0.8
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	fade.set_color(1, Color(1.0, 0.2, 0.1, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.06
	spark_mesh.height = 0.12
	spark_mesh.radial_segments = 4
	spark_mesh.rings = 2
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mesh.material = spark_material
	_sparks = GPUParticles3D.new()
	_sparks.amount = 60
	_sparks.lifetime = 1.4
	_sparks.local_coords = false
	_sparks.process_material = process
	_sparks.draw_pass_1 = spark_mesh
	_sparks.visibility_aabb = AABB(Vector3(-20, -40, -20), Vector3(40, 60, 40))
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


func _process(delta: float) -> void:
	_age += delta
	if _age < RISE_TIME:
		velocity += Vector3(0, -9.0, 0) * delta * 0.6
		global_position += velocity * delta
		return
	if not _burst:
		_burst = true
		_light.light_energy = 9.0
		_light.omni_range = 60.0
		_ball.scale = Vector3.ONE * 3.0
		Sfx.play_at("flare_shot", global_position, 6.0, 0.05, 400.0)
	# Hanging under its little parachute, drifting down and flickering.
	global_position += Vector3(0.4, -1.1, 0.2) * delta
	_light.light_energy = 8.0 + sin(_age * 23.0) * 1.5
	var left := RISE_TIME + HANG_TIME - _age
	if left < 1.5:
		_light.light_energy *= maxf(left / 1.5, 0.0)
		_ball.scale = Vector3.ONE * 3.0 * maxf(left / 1.5, 0.01)
	if left <= 0.0:
		queue_free()
