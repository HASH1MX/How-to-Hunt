class_name Campfire
extends Node3D
## Captain Gus's campfire: a ring of stones and crossed logs. It is unlit until the quest
## "Light a Fire" is done, then flames burst up with a whoosh, a warm light flickers and
## the fire crackles. Every player sees it, because it follows the shared quest state.

const QUEST := "light_a_fire"

var _flames: GPUParticles3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _lit := false
var _flicker := 0.0


func _ready() -> void:
	_build_pit()
	_build_flames()
	Quests.session_started.connect(func(): _set_lit(Quests.is_done(QUEST), false))
	_set_lit(Quests.is_done(QUEST), false)


func _process(delta: float) -> void:
	var want := Quests.is_done(QUEST)
	if want != _lit:
		_set_lit(want, true)
	if _lit:
		_flicker += delta * 11.0
		_light.light_energy = 2.2 + sin(_flicker) * 0.3 + sin(_flicker * 2.3) * 0.2


func _build_pit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var st := LowPoly.begin()
	var stone := SphereMesh.new()
	stone.radius = 0.5
	stone.height = 1.0
	stone.radial_segments = 7
	stone.rings = 4
	for i in 8:
		var angle := i / 8.0 * TAU
		var size := Vector3(rng.randf_range(0.26, 0.36), rng.randf_range(0.18, 0.26), rng.randf_range(0.24, 0.32))
		LowPoly.add_shape(st, stone, Transform3D(Basis(Vector3.UP, angle).scaled(size), Vector3(cos(angle) * 0.62, 0.1, sin(angle) * 0.62)), PropLibrary.ROCK_COLOR, 0.02, 0.12, rng)
	# Burnt ground and three crossed logs.
	var ash := CylinderMesh.new()
	ash.top_radius = 0.55
	ash.bottom_radius = 0.58
	ash.height = 0.04
	ash.radial_segments = 10
	ash.rings = 1
	LowPoly.add_shape(st, ash, Transform3D(Basis(), Vector3(0, 0.02, 0)), Color(0.12, 0.1, 0.09), 0.0, 0.05, rng)
	var log := CylinderMesh.new()
	log.top_radius = 0.07
	log.bottom_radius = 0.08
	log.height = 0.85
	log.radial_segments = 7
	log.rings = 1
	for i in 3:
		var yaw := i / 3.0 * PI + 0.3
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.5 + 0.12)
		LowPoly.add_shape(st, log, Transform3D(basis, Vector3(0, 0.14 + i * 0.015, 0)), PropLibrary.TRUNK_COLOR.darkened(0.25), 0.0, 0.08, rng)
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.commit(st)
	add_child(mesh)

	# Solid, so nobody walks through the middle of the fire.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.7
	cylinder.height = 0.5
	shape.shape = cylinder
	shape.position.y = 0.25
	body.add_child(shape)
	add_child(body)


func _build_flames() -> void:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 14.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0, 1.2, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.28
	process.scale_min = 0.5
	process.scale_max = 1.0
	var shrink := Curve.new()
	shrink.max_value = 1.2
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.1))
	var shrink_texture := CurveTexture.new()
	shrink_texture.curve = shrink
	process.scale_curve = shrink_texture
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 0.9, 0.35, 0.95))
	colors.add_point(0.45, Color(1.0, 0.5, 0.1, 0.8))
	colors.set_color(1, Color(0.8, 0.15, 0.05, 0.0))
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = colors
	process.color_ramp = color_texture

	var flame_tool := LowPoly.begin()
	var puff := SphereMesh.new()
	puff.radius = 0.2
	puff.height = 0.5
	puff.radial_segments = 6
	puff.rings = 4
	LowPoly.add_shape(flame_tool, puff, Transform3D(), Color.WHITE, 0.03)
	var flame_mesh := LowPoly.commit(flame_tool)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	flame_mesh.surface_set_material(0, material)

	_flames = GPUParticles3D.new()
	_flames.amount = 36
	_flames.lifetime = 0.85
	_flames.position = Vector3(0, 0.25, 0)
	_flames.process_material = process
	_flames.draw_pass_1 = flame_mesh
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	_flames.emitting = false
	add_child(_flames)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.28)
	_light.omni_range = 8.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)

	_crackle = AudioStreamPlayer3D.new()
	_crackle.stream = Sfx.get_loop("fire_loop")
	_crackle.bus = "Effects"
	_crackle.unit_size = 3.0
	_crackle.max_distance = 22.0
	_crackle.volume_db = -5.0
	add_child(_crackle)


func _set_lit(lit: bool, animate: bool) -> void:
	if lit == _lit and _flames.emitting == lit:
		return
	_lit = lit
	_flames.emitting = lit
	if lit:
		if not _crackle.playing:
			_crackle.play()
		if animate:
			Sfx.play_at("whoosh", global_position + Vector3(0, 0.6, 0), -2.0, 0.05, 30.0)
			_flames.scale = Vector3.ONE * 0.05
			create_tween().tween_property(_flames, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_flames.scale = Vector3.ONE
	else:
		_crackle.stop()
		_light.light_energy = 0.0
