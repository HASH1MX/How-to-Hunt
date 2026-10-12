@tool
class_name Water
extends MeshInstance3D
## A big sea surface around the island. Sits at the terrain's water_level.
## The player reads this node's height to know when it is swimming.

const WATER_SHADER := preload("res://scenes/world/water/water.gdshader")

@export var terrain: Terrain
## Width of the water plane. Big enough to reach the horizon.
@export var size: float = 4000.0
## More subdivisions = smoother waves near the island.
@export var subdivisions: int = 300


func _ready() -> void:
	if terrain != null:
		position.y = terrain.water_level
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	plane.material = material
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Height of the water surface in the world.
func get_level() -> float:
	return global_position.y
