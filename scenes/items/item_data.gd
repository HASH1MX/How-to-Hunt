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
## Also shows a tall faint beam of light, visible from far away (for items hidden around the island).
@export var beacon := false
## How many fit in one inventory slot.
@export var max_stack := 5

@export_group("Using it")
## What left click does while holding it: "" (punch), "melee" (knife), "gun", "flare".
@export var use := ""
## Damage per hit (for a gun: per pellet).
@export var damage := 0.0
## Melee reach, or how far a gun shoots (meters).
@export var reach := 2.4
## Seconds between swings or shots.
@export var fire_gap := 0.3
## Hold the button to keep firing.
@export var automatic := false
## Pellets per shot (a shotgun fires several).
@export var pellets := 1
## How far shots stray from the crosshair (degrees).
@export var spread := 0.0
## Rounds in a full magazine (0 = no ammo needed).
@export var magazine := 0
@export var reload_time := 1.5
## Which ammo it uses ("pistol", "shells", "smg", "rifle", "sniper").
@export var ammo := ""
## Aiming (right click) zooms the view to this field of view (0 = a small zoom only).
@export var zoom_fov := 0.0
## How hard it kicks back when fired.
@export var recoil := 0.4
## Sound group (see Sfx) played when firing.
@export var sound := ""
## How the first-person arms hold it: "" (in the fist), "pistol" or "rifle".
@export var hold := ""
## Price at the trader (0 = not for sale).
@export var price := 0

## Size of the item's collision box when it lies in the world.
@export var collision_size: Vector3 = Vector3(0.3, 0.3, 0.3)
