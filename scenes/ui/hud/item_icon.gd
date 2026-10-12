class_name ItemIcon
extends SubViewportContainer
## Shows a small 3D picture of an item, for inventory slots.
## It renders the item's own model in a tiny separate 3D world,
## so every item automatically gets an icon without drawing one by hand.

var _viewport: SubViewport
var _camera: Camera3D
var _model: MeshInstance3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true # Separate from the game world.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.environment = environment
	_viewport.add_child(_camera)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.5, 0.0)
	_viewport.add_child(light)

	_model = MeshInstance3D.new()
	_viewport.add_child(_model)


## Shows this item, or hides the icon when item is null.
func set_item(item: ItemData) -> void:
	visible = item != null
	if item == null:
		return
	_model.mesh = item.mesh
	# Frame the camera so the whole model fits, seen from the front-top-right.
	var bounds := item.mesh.get_aabb()
	var center := bounds.get_center()
	var extent := bounds.size.length()
	var view_dir := Vector3(1.0, 0.9, 1.2).normalized()
	_camera.transform = Transform3D(Basis.looking_at(-view_dir), center + view_dir * extent * 2.0)
	_camera.size = extent * 0.85
	_camera.near = 0.01
	_camera.far = extent * 5.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
