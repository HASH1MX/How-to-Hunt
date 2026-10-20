class_name PlayerNetSync
extends Node
## Added under the local player when the game starts. Tells the other players
## where this player is and what it is doing (about 20 times a second), and when it
## punches. It only reads from the player, so the player's own code is untouched.

var player: CharacterBody3D
var _timer := 0.0


func _ready() -> void:
	if player.view_model != null:
		player.view_model.punch_hit.connect(Network.send_punch)
	player.held_changed.connect(Network.send_held)
	# Tell everyone what we're already holding.
	var item: ItemData = player.inventory.get_active_item()
	Network.send_held.call_deferred(String(item.id) if item != null else "")
	# Someone new arrived: tell them too.
	Network.player_joined.connect(func(_id, _name):
		var now: ItemData = player.inventory.get_active_item()
		Network.send_held(String(now.id) if now != null else ""))


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0 / Network.SEND_RATE
	var flags := 0
	if player.is_crouching:
		flags |= RemotePlayer.FLAG_CROUCH
	if player.view_model.sprinting:
		flags |= RemotePlayer.FLAG_SPRINT
	if player.is_on_floor():
		flags |= RemotePlayer.FLAG_ON_FLOOR
	if player.is_in_deep_water:
		flags |= RemotePlayer.FLAG_SWIM
	Network.send_state(player.global_position, player.rotation.y, player.head.rotation.x, flags)
