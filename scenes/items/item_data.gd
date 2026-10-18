class_name ItemData
extends Resource
## Describes one kind of item: its name, icon color and 3D model.
## Every item in the game (loot, food, weapons...) will be one of these.

@export var id: StringName
@export var display_name: String
## Color used for the item's icon in the inventory.
@export var icon_color: Color = Color.WHITE
## The 3D model, used when the item lies in the world or is held in the hand.
@export var mesh: Mesh
## How much money the merchant pays for it (used in a later stage).
@export var value: int = 0
## Gives off a soft glow where it lies, so important story items are easy to spot.
@export var glows := false
## Size of the item's collision box when it lies in the world.
@export var collision_size: Vector3 = Vector3(0.3, 0.3, 0.3)
