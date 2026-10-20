class_name WeaponEffects
## Short-lived visual effects for guns: bullet tracers, impact puffs and muzzle flashes.
## Used for your own shots and for other players' shots (see Network.send_shot).

static var _tracer_material: StandardMaterial3D
static var _puff_material: StandardMaterial3D


## A thin bright streak from `from` to `to` that fades almost at once.
static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 0.5:
		return
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tracer_material.albedo_color = Color(1.0, 0.85, 0.45, 0.8)
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, 1.0)
	streak.mesh = box
	streak.material_override = _tracer_material
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(streak)
	var length := from.distance_to(to)
	streak.global_position = (from + to) * 0.5
	streak.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	streak.scale = Vector3(1, 1, length)
	var tween := streak.create_tween()
	tween.tween_interval(0.04)
	tween.tween_callback(streak.queue_free)


## A little puff of dust and chips where a bullet hit something.
static func impact(parent: Node, at: Vector3, normal: Vector3, color: Color = Color(0.75, 0.7, 0.6)) -> void:
	if _puff_material == null:
		_puff_material = StandardMaterial3D.new()
		_puff_material.vertex_color_use_as_albedo = false
		_puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff_material.roughness = 1.0
	for i in 5:
		var chip := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * randf_range(0.03, 0.06)
		chip.mesh = cube
		var material := _puff_material.duplicate() as StandardMaterial3D
		material.albedo_color = color.lightened(randf_range(0.0, 0.2))
		chip.material_override = material
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(chip)
		chip.global_position = at + normal * 0.03
		var fly := (normal + Vector3(randf_range(-0.7, 0.7), randf_range(0.0, 0.8), randf_range(-0.7, 0.7))).normalized() * randf_range(0.25, 0.6)
		var tween := chip.create_tween().set_parallel(true)
		tween.tween_property(chip, "global_position", chip.global_position + fly, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
		tween.chain().tween_callback(chip.queue_free)


## A quick flash of light and a bright blob at a gun's muzzle.
static func muzzle_flash(parent: Node3D, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = at
	var flash := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	ball.radial_segments = 6
	ball.rings = 3
	flash.mesh = ball
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.5)
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(flash)
	var tween := light.create_tween()
	tween.tween_interval(0.05)
	tween.tween_callback(light.queue_free)
