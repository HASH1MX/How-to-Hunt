class_name ItemIcon
extends SubViewportContainer
## Shows a small 3D picture of an item, for inventory slots.
## It renders the item's own model in a tiny separate 3D world,
## so every item automatically gets an icon without drawing one by hand.
##
## Long items (guns, knives, sticks, antennas) are shown side-on, lying diagonally
## across the slot like How to Fish's hotbar. Everything else is shown from the
## front-top-right. Either way the camera is fitted to the model so it fills the
## slot without being cut off.

## How much of the slot the item fills (1.0 = touching the edges).
const FILL := 0.86
## An item counts as "long" if its longest side is this many times its second longest.
const LONG_RATIO := 2.2
## Long items are tilted this much so they lie diagonally.
const LONG_TILT := deg_to_rad(35.0)

var _viewport: SubViewport
var _camera: Camera3D
var _model: MeshInstance3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true # Separate from the game world.
	_viewport.msaa_3d = Viewport.MSAA_4X # Smooth edges on such a small picture.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.6, 0.58)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.environment = environment
	_viewport.add_child(_camera)

	# A warm main light from the top left, and a softer cool fill from the other side.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.85, -0.55, 0.0)
	key.light_energy = 1.15
	key.light_color = Color(1.0, 0.97, 0.9)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.2, 2.4, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.85, 0.9, 1.0)
	_viewport.add_child(fill)

	_model = MeshInstance3D.new()
	_viewport.add_child(_model)


## Shows this item, or hides the icon when item is null.
func set_item(item: ItemData) -> void:
	visible = item != null
	if item == null:
		return
	_model.mesh = item.mesh
	var bounds := item.mesh.get_aabb()

	var camera_basis: Basis
	if item.icon_from_above:
		# Looking down (tipped a little forward): head to the right, legs toward the bottom.
		_model.basis = Basis(Vector3.UP, -PI * 0.5)
		camera_basis = Basis(Vector3.RIGHT, deg_to_rad(-70.0))
	elif _is_long(bounds.size):
		_model.basis = Basis(Vector3.BACK, LONG_TILT) * _lay_long_side_on(bounds.size)
		camera_basis = Basis() # Looking straight at the item's side.
	else:
		_model.basis = Basis()
		camera_basis = Basis.looking_at(-Vector3(1.0, 0.9, 1.2).normalized())
	_fit_camera(bounds, camera_basis)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _is_long(size: Vector3) -> bool:
	var sides := [size.x, size.y, size.z]
	sides.sort()
	return sides[2] >= sides[1] * LONG_RATIO


## Turns a long item so its long side points left-right across the picture (front
## end to the right), its next-biggest side points up, and its thin side faces us.
func _lay_long_side_on(size: Vector3) -> Basis:
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var lengths := [size.x, size.y, size.z]
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return lengths[a] > lengths[b])
	# Where each of the item's own axes ends up on screen.
	var image := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	image[order[0]] = Vector3.LEFT # Items point forward along -Z, so -Z ends up on the right.
	image[order[1]] = Vector3.UP
	# The thin side faces the camera; pick its direction so the turn is a real rotation.
	image[order[2]] = Vector3.BACK
	var turned := Basis(image[0], image[1], image[2])
	if turned.determinant() < 0.0:
		image[order[2]] = Vector3.FORWARD
		turned = Basis(image[0], image[1], image[2])
	return turned


## Places the camera so the whole model fits the picture, centred.
func _fit_camera(bounds: AABB, camera_basis: Basis) -> void:
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in 8:
		var corner := _model.basis * bounds.get_endpoint(i)
		var on_screen := Vector3(corner.dot(camera_basis.x), corner.dot(camera_basis.y), corner.dot(camera_basis.z))
		low = low.min(on_screen)
		high = high.max(on_screen)
	var middle := (low + high) * 0.5
	var size := high - low
	_camera.size = maxf(maxf(size.x, size.y), 0.01) / FILL
	var depth := size.z + 1.0
	_camera.transform = Transform3D(camera_basis,
			camera_basis.x * middle.x + camera_basis.y * middle.y + camera_basis.z * (high.z + 0.5))
	_camera.near = 0.01
	_camera.far = depth + 0.5
